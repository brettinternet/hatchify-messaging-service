defmodule MessagingWeb.Controllers.Twilio do
  @moduledoc """
  Webhook controller for handling inbound messages from various providers.

  Processes webhook callbacks from SMS/MMS providers (like Twilio) and email
  providers (like Xillio) to handle incoming messages in the messaging service.
  """

  import Plug.Conn

  require Logger

  alias Messaging.Conversations
  alias Messaging.Conversations.Message

  @doc """
  Handle incoming SMS/MMS webhook from providers like Twilio.
  """
  def sms_webhook(%Plug.Conn{} = conn) do
    case conn.body_params do
      %{"from" => from, "to" => to, "body" => body} = params ->
        message_type = Map.get(params, "type", "sms")
        attachments = Map.get(params, "attachments")
        provider_id = Map.get(params, "messaging_provider_id")
        timestamp = parse_timestamp(params["timestamp"])

        message_attrs = %{
          from_address: from,
          to_address: to,
          message_type: message_type,
          body: body,
          attachments: normalize_attachments(attachments),
          provider_id: provider_id,
          direction: "inbound",
          timestamp: timestamp
        }

        Logger.info("Processing inbound #{message_type} webhook from #{from} to #{to}")

        case create_message_struct(message_attrs) do
          {:ok, message} ->
            case Conversations.handle_message(message) do
              :ok ->
                conn
                |> put_resp_header("content-type", "application/json")
                |> send_resp(200, Jason.encode!(%{"status" => "message_processed"}))

              {:error, changeset} ->
                Logger.error("Failed to process message: #{inspect(changeset)}")
                conn
                |> put_resp_header("content-type", "application/json")
                |> send_resp(422, Jason.encode!(%{"error" => "Message processing failed"}))
            end

          {:error, reason} ->
            Logger.error("Invalid message format: #{inspect(reason)}")
            conn
            |> put_resp_header("content-type", "application/json")
            |> send_resp(400, Jason.encode!(%{"error" => "Invalid message format"}))
        end

      _ ->
        conn
        |> put_resp_header("content-type", "application/json")
        |> send_resp(400, Jason.encode!(%{"error" => "Invalid webhook format"}))
    end
  end

  @doc """
  Handle incoming email webhook from providers like Xillio.
  """
  def email_webhook(%Plug.Conn{} = conn) do
    case conn.body_params do
      %{"from" => from, "to" => to, "body" => body} = params ->
        attachments = Map.get(params, "attachments")
        provider_id = Map.get(params, "xillio_id")
        timestamp = parse_timestamp(params["timestamp"])

        message_attrs = %{
          from_address: from,
          to_address: to,
          message_type: "email",
          body: body,
          attachments: normalize_attachments(attachments),
          provider_id: provider_id,
          direction: "inbound",
          timestamp: timestamp
        }

        Logger.info("Processing inbound email webhook from #{from} to #{to}")

        case create_message_struct(message_attrs) do
          {:ok, message} ->
            case Conversations.handle_message(message) do
              :ok ->
                conn
                |> put_resp_header("content-type", "application/json")
                |> send_resp(200, Jason.encode!(%{"status" => "message_processed"}))

              {:error, changeset} ->
                Logger.error("Failed to process message: #{inspect(changeset)}")
                conn
                |> put_resp_header("content-type", "application/json")
                |> send_resp(422, Jason.encode!(%{"error" => "Message processing failed"}))
            end

          {:error, reason} ->
            Logger.error("Invalid message format: #{inspect(reason)}")
            conn
            |> put_resp_header("content-type", "application/json")
            |> send_resp(400, Jason.encode!(%{"error" => "Invalid message format"}))
        end

      _ ->
        conn
        |> put_resp_header("content-type", "application/json")
        |> send_resp(400, Jason.encode!(%{"error" => "Invalid webhook format"}))
    end
  end

  # Create a Message struct from webhook attributes
  defp create_message_struct(attrs) do
    # Validate required fields manually to avoid changeset complexity with conversation_id
    case validate_webhook_attrs(attrs) do
      :ok ->
        {:ok, struct(Message, attrs)}
      
      {:error, reason} ->
        {:error, reason}
    end
  end

  # Validate required webhook attributes
  defp validate_webhook_attrs(attrs) do
    required_fields = [:from_address, :to_address, :message_type, :body, :direction, :timestamp]
    
    case Enum.find(required_fields, fn field -> is_nil(Map.get(attrs, field)) end) do
      nil -> :ok
      _missing_field -> {:error, :invalid_message}
    end
  end

  # Parse timestamp from webhook, fallback to current time
  defp parse_timestamp(nil), do: DateTime.utc_now()
  defp parse_timestamp(timestamp_str) when is_binary(timestamp_str) do
    case DateTime.from_iso8601(timestamp_str) do
      {:ok, datetime, _offset} -> 
        # Ensure microsecond precision for database compatibility
        %{datetime | microsecond: {elem(datetime.microsecond, 0), 6}}
      {:error, _} -> DateTime.utc_now()
    end
  end
  defp parse_timestamp(_), do: DateTime.utc_now()

  # Normalize attachments to list format
  defp normalize_attachments(nil), do: nil
  defp normalize_attachments([]), do: nil
  defp normalize_attachments(attachments) when is_list(attachments), do: attachments
  defp normalize_attachments(_), do: nil
end
