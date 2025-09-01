defmodule Messaging.OutboxProcessor do
  @moduledoc """
  Process outbox events in order to ensure reliable delivery to third-party services.
  """
  use GenServer

  import Ecto.Query

  alias Messaging.Conversations.Message
  alias Messaging.Conversations.OutboxEvent
  alias Messaging.Integrations.Twilio
  alias Messaging.Repo

  require Logger

  @schedule_timeout 5_000
  @batch_size 500

  @type state :: %{}

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl GenServer
  @spec init(keyword()) :: {:ok, state()}
  def init(_opts) do
    schedule_work()
    {:ok, %{}}
  end

  @impl GenServer
  @spec handle_info(:process_events, state()) :: {:noreply, state()}
  def handle_info(:process_events, state) do
    process_all_pending_events()
    schedule_work()
    {:noreply, state}
  end

  @spec process_all_pending_events() :: :ok
  defp process_all_pending_events do
    process_all_pending_events(0)
  end

  # process until no more pending events
  @spec process_all_pending_events(non_neg_integer()) :: :ok
  defp process_all_pending_events(total_processed) do
    events = fetch_pending_events()

    case length(events) do
      0 ->
        if total_processed > 0 do
          Logger.info("Processed #{total_processed} outbox events in this cycle")
        end

        :ok

      count ->
        Enum.each(events, &process_event/1)
        Logger.debug("Processed batch of #{count} events")
        # Continue processing more batches if available
        process_all_pending_events(total_processed + count)
    end
  end

  @spec fetch_pending_events() :: [OutboxEvent.t()]
  defp fetch_pending_events do
    OutboxEvent
    |> where([e], is_nil(e.processed_at))
    |> where([e], e.scheduled_for <= ^DateTime.utc_now())
    |> where([e], e.retry_count < e.max_retries)
    |> order_by([e], asc: e.scheduled_for, asc: e.inserted_at)
    |> limit(^@batch_size)
    |> Repo.all()
  end

  @spec process_event(OutboxEvent.t()) :: any()
  defp process_event(event) do
    case execute_event(event) do
      :ok ->
        mark_processed(event)

      {:error, reason} ->
        handle_retry(event, reason)
    end
  end

  @spec execute_event(OutboxEvent.t()) :: :ok | {:error, any()}
  defp execute_event(%OutboxEvent{event_type: "message.send", message_id: message_id}) do
    case Repo.get(Message, message_id) do
      nil ->
        Logger.error("Message not found: #{message_id}")
        {:error, :message_not_found}

      %Message{} = message ->
        message
        |> Twilio.send_message()
        |> handle_sent_message(message)
    end
  end

  defp execute_event(%OutboxEvent{event_type: event_type}) do
    Logger.warning("Unknown event type: #{event_type}")
    {:error, :unknown_event_type}
  end

  defp handle_sent_message({:ok, result}, %Message{} = message) do
    # Update message with external provider ID if available
    updates = %{status: :sent}

    updates =
      if Map.has_key?(result, "id") do
        Map.put(updates, :provider_id, result["id"])
      else
        updates
      end

    case Repo.update(Message.changeset(message, updates)) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp handle_sent_message({:error, reason}, %Message{} = message) do
    Logger.error("Failed to send message #{message.id}: #{inspect(reason)}")
    {:error, reason}
  end

  @spec mark_processed(OutboxEvent.t()) :: OutboxEvent.t()
  defp mark_processed(event) do
    event
    |> OutboxEvent.changeset(%{processed_at: DateTime.utc_now()})
    |> Repo.update!()
  end

  @spec handle_retry(OutboxEvent.t(), any()) :: OutboxEvent.t()
  defp handle_retry(event, reason) do
    retry_count = event.retry_count + 1

    if retry_count < event.max_retries do
      # Exponential backoff
      scheduled_for = DateTime.add(DateTime.utc_now(), 2 |> :math.pow(retry_count) |> trunc(), :second)

      event
      |> OutboxEvent.changeset(%{
        retry_count: retry_count,
        scheduled_for: scheduled_for,
        error_message: inspect(reason)
      })
      |> Repo.update!()
    else
      # Mark as failed, send to dead letter queue, etc.
      handle_max_retries_exceeded(event, reason)
    end
  end

  @spec handle_max_retries_exceeded(OutboxEvent.t(), any()) :: OutboxEvent.t()
  defp handle_max_retries_exceeded(event, reason) do
    Logger.error("Max retries exceeded for event #{event.id}: #{inspect(reason)}")

    event
    |> OutboxEvent.changeset(%{
      error_message: "Max retries exceeded: #{inspect(reason)}"
    })
    |> Repo.update!()
  end

  @spec schedule_work() :: reference()
  defp schedule_work do
    Process.send_after(self(), :process_events, @schedule_timeout)
  end
end
