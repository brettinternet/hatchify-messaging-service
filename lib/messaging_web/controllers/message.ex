defmodule MessagingWeb.Controllers.Message do
  @moduledoc """
  Handle messages - create and list.
  """

  import Plug.Conn

  alias Messaging.Conversations
  alias Messaging.Messages
  alias Messaging.RateLimit

  require Logger

  @doc """
  List conversations with optional search parameters.
  Supports query parameters: from, to, limit
  """
  @spec list_conversations(Plug.Conn.t()) :: Plug.Conn.t()
  def list_conversations(%Plug.Conn{} = conn) do
    params = conn.query_params

    conversations = Conversations.list_conversations(params)

    response = %{
      conversations:
        Enum.map(conversations, fn %{conversation: conv, participants: participants, message_count: count} ->
          %{
            id: conv.id,
            participants: participants,
            message_count: count,
            inserted_at: conv.inserted_at
          }
        end)
    }

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(response))
  end

  @doc """
  List messages for a specific conversation with outbox status.
  """
  @spec list_conversation_messages(Plug.Conn.t()) :: Plug.Conn.t()
  def list_conversation_messages(%Plug.Conn{} = conn) do
    conversation_id = conn.path_params["conversation_id"]
    messages = Conversations.list_conversation_messages(conversation_id)

    response = %{
      conversation_id: conversation_id,
      messages:
        Enum.map(messages, fn %{message: msg, outbox_sent: sent} ->
          %{
            id: msg.id,
            from_address: msg.from_address,
            to_address: msg.to_address,
            message_type: msg.message_type,
            body: msg.body,
            attachments: msg.attachments,
            direction: msg.direction,
            timestamp: msg.timestamp,
            outbox_sent: sent,
            inserted_at: msg.inserted_at
          }
        end)
    }

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(response))
  end

  @doc """
  Create a new message.

  When a new message arrives:
    1. Extract participant set from from and to addresses
    2. Query for existing conversation with exactly those participants
    3. If found, add message to that conversation
    4. If not found, create new conversation and add participants
  """
  @spec create(Plug.Conn.t()) :: Plug.Conn.t()
  def create(%Plug.Conn{} = conn) do
    with {:ok, body} <- get_body(conn),
         :ok <- RateLimit.message(body["from"]),
         {:ok, validated_message} <- Messages.validate_message(body),
         :ok <- Conversations.handle_message(validated_message) do
      send_resp(conn, 204, "")
    else
      {:error, :rate_limit_exceeded} ->
        conn
        |> put_resp_header("retry-after", "60")
        |> send_resp(429, "Rate limit exceeded")

      {:error, :missing_body} ->
        send_resp(conn, 400, "Missing request body")

      {:error, :invalid_format} ->
        send_resp(conn, 400, "Invalid JSON format")

      {:error, :invalid_message} ->
        send_resp(conn, 400, "Invalid message format")
    end
  end

  @spec get_body(Plug.Conn.t()) :: {:ok, map()} | {:error, :invalid_message}
  def get_body(conn) do
    case conn.body_params do
      %{"from" => from} = params when is_map(params) and is_binary(from) ->
        {:ok, params}

      nil ->
        {:error, :missing_body}

      %{"from" => nil} = body ->
        Logger.debug("Missing 'from' field in JSON: #{inspect(body)}")
        {:error, :invalid_message}

      body ->
        Logger.debug("Invalid body: #{inspect(body)}")
        {:error, :invalid_message}
    end
  end
end
