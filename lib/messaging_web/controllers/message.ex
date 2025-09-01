defmodule MessagingWeb.Controllers.Message do
  @moduledoc """
  Handle incoming messages.

  When a new message arrives:
   1. Extract participant set from from and to addresses
   2. Query for existing conversation with exactly those participants
   3. If found, add message to that conversation
   4. If not found, create new conversation and add participants
  """

  use Plug.Builder

  import Plug.Conn

  alias Messaging.Conversations
  alias Messaging.Messages
  alias Messaging.RateLimit

  require Logger

  plug Plug.Parsers,
    parsers: [:urlencoded, :json],
    pass: ["text/*"],
    body_reader: {__MODULE__, :read_body, []},
    json_decoder: Jason,
    length: 1_000_000,
    read_length: 1_000_000,
    read_timeout: 15_000

  @spec list(Plug.Conn.t()) :: Plug.Conn.t()
  def list(%Plug.Conn{} = conn) do
    send_resp(conn, 200, "Listing messages is not implemented yet")
  end

  @spec create(Plug.Conn.t()) :: Plug.Conn.t()
  def create(%Plug.Conn{} = conn) do
    with :ok <- RateLimit.message(conn.assigns[:from]),
         {:ok, validated_message} <- Messages.validate_message(conn.assigns[:parsed_body]),
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

        # {:error, :internal_error} ->
        #   send_resp(conn, 500, "Internal server error")
    end
  end

  @spec read_body(Plug.Conn.t(), keyword()) :: {:ok, binary(), Plug.Conn.t()}
  def read_body(conn, opts) do
    {:ok, body, conn} = Plug.Conn.read_body(conn, opts)
    conn = extract_sender(conn, body)
    {:ok, body, conn}
  end

  @spec extract_sender(Plug.Conn.t(), binary() | nil) :: Plug.Conn.t()
  defp extract_sender(conn, body) when is_binary(body) and byte_size(body) <= 1_000_000 do
    case Jason.decode(body) do
      {:ok, %{"from" => from} = parsed_body} when is_binary(from) ->
        conn
        |> put_in([Access.key(:assigns), :from], from)
        |> put_in([Access.key(:assigns), :parsed_body], parsed_body)

      {:ok, json} ->
        Logger.debug("Missing 'from' field in JSON: #{inspect(json)}")
        put_in(conn.assigns[:from], nil)

      {:error, reason} ->
        Logger.warning("Failed to decode JSON body: #{inspect(reason)}")
        put_in(conn.assigns[:from], nil)
    end
  end

  defp extract_sender(conn, _body) do
    put_in(conn.assigns[:from], nil)
  end
end
