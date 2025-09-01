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
  List messages from a conversation.
  """
  @spec list(Plug.Conn.t()) :: Plug.Conn.t()
  def list(%Plug.Conn{} = conn) do
    send_resp(conn, 200, "Listing messages is not implemented yet")
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
