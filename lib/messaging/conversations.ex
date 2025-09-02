defmodule Messaging.Conversations do
  @moduledoc """
  Handle conversations between participants.
  """

  import Ecto.Query

  alias Ecto.Multi
  alias Messaging.Conversations.Conversation
  alias Messaging.Conversations.Message
  alias Messaging.Conversations.OutboxEvent
  alias Messaging.Conversations.Participant
  alias Messaging.Repo

  @doc """
  Goal: transactional output for idempotency, atomicity, ordered, and consistency

  Handle conversation message:
    1. Find or create conversation with those participants
    2. Add message to conversation
    3. Store in database (along with outbox event)
  """
  @spec handle_message(Message.t()) :: :ok | {:error, atom()}
  def handle_message(%Message{} = message) do
    Multi.new()
    |> Multi.run(:conversation, fn repo, _changes ->
      find_or_create_conversation(repo, message)
    end)
    |> Multi.run(:message, fn _repo, %{conversation: conversation} ->
      message_with_conversation = %{message | conversation_id: conversation.id}
      {:ok, Message.changeset(message_with_conversation, %{})}
    end)
    |> Multi.insert(:inserted_message, & &1.message)
    |> Multi.insert(:outbox_event, fn %{inserted_message: message} ->
      OutboxEvent.changeset(%OutboxEvent{}, %{
        event_type: "message.send",
        message_id: message.id
      })
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{inserted_message: _message}} -> :ok
      {:error, _failed_op, changeset, _changes} -> {:error, changeset}
    end
  end

  @doc """
  List conversations with optional search parameters.
  Supports filtering by participant addresses (to/from).
  """
  @spec list_conversations(map()) :: [
          %{conversation: Conversation.t(), participants: [String.t()], message_count: integer()}
        ]
  def list_conversations(params \\ %{}) do
    # First get the conversation IDs that match our filter criteria
    filtered_conversation_ids = get_filtered_conversation_ids(params)

    # Then get full conversation details for those IDs
    query =
      from c in Conversation,
        join: p in Participant,
        on: c.id == p.conversation_id,
        left_join: m in Message,
        on: c.id == m.conversation_id,
        where: c.id in ^filtered_conversation_ids,
        group_by: c.id,
        select: %{
          conversation: c,
          participants: fragment("array_agg(DISTINCT ?)", p.address),
          message_count: count(m.id, :distinct)
        },
        order_by: [desc: c.inserted_at]

    query
    |> limit_results(params["limit"])
    |> Repo.all()
  end

  # Get conversation IDs that match filter criteria
  defp get_filtered_conversation_ids(params) do
    base_query =
      from c in Conversation, join: p in Participant, on: c.id == p.conversation_id, select: c.id, distinct: true

    query = apply_conversation_filters_for_ids(base_query, params)
    Repo.all(query)
  end

  @doc """
  List messages for a specific conversation with outbox status.
  """
  @spec list_conversation_messages(String.t()) :: [%{message: Message.t(), outbox_sent: boolean()}]
  def list_conversation_messages(conversation_id) do
    Repo.all(
      from(m in Message,
        where: m.conversation_id == ^conversation_id,
        left_join: o in OutboxEvent,
        on: o.message_id == m.id,
        select: %{message: m, outbox_sent: not is_nil(o.processed_at)},
        order_by: [asc: m.timestamp]
      )
    )
  end

  # Apply filters for getting conversation IDs (no limit)
  defp apply_conversation_filters_for_ids(query, params) do
    query
    |> filter_by_participant(params["from"])
    |> filter_by_participant(params["to"])
  end

  defp filter_by_participant(query, nil), do: query

  defp filter_by_participant(query, address) when is_binary(address) do
    from [c, p] in query,
      where: p.address == ^address
  end

  defp limit_results(query, nil), do: query

  defp limit_results(query, limit_str) when is_binary(limit_str) do
    case Integer.parse(limit_str) do
      {limit, _} when limit > 0 and limit <= 100 ->
        from q in query, limit: ^limit

      _ ->
        query
    end
  end

  defp limit_results(query, limit) when is_integer(limit) and limit > 0 and limit <= 100 do
    from q in query, limit: ^limit
  end

  defp limit_results(query, _), do: query

  @spec find_or_create_conversation(Ecto.Repo.t(), Message.t()) :: {:ok, Conversation.t()} | {:error, any()}
  defp find_or_create_conversation(repo, %Message{} = message) do
    addresses = Participant.addresses_from_message(message)

    # Try to find existing conversation with exactly these participants
    case find_conversation_by_participants(repo, addresses) do
      %Conversation{} = conversation ->
        {:ok, conversation}

      nil ->
        create_conversation_with_participants(repo, addresses)
    end
  end

  @spec find_conversation_by_participants(Ecto.Repo.t(), [String.t()]) :: Conversation.t() | nil
  defp find_conversation_by_participants(repo, addresses) do
    # Find conversations that have exactly the same set of participants
    subquery =
      from p in Participant,
        where: p.address in ^addresses,
        group_by: p.conversation_id,
        having: count(p.address) == ^length(addresses),
        select: p.conversation_id

    repo.one(
      from(c in Conversation,
        join: p in Participant,
        on: c.id == p.conversation_id,
        where: c.id in subquery(subquery),
        group_by: c.id,
        having: count(p.address) == ^length(addresses),
        limit: 1
      )
    )
  end

  # Create conversation and participants
  @spec create_conversation_with_participants(Ecto.Repo.t(), [String.t()]) :: {:ok, Conversation.t()} | {:error, any()}
  defp create_conversation_with_participants(repo, addresses) do
    case repo.insert(Conversation.changeset(%Conversation{}, %{})) do
      {:ok, conversation} ->
        participant_changesets = Participant.create_for_conversation(conversation.id, addresses)

        result =
          Enum.reduce_while(participant_changesets, [], fn changeset, acc ->
            case repo.insert(changeset) do
              {:ok, participant} -> {:cont, [participant | acc]}
              {:error, reason} -> {:halt, {:error, reason}}
            end
          end)

        case result do
          {:error, reason} -> {:error, reason}
          _participants -> {:ok, conversation}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end
end
