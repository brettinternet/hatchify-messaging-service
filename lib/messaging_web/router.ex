defmodule MessagingWeb.Router do
  use Plug.Router

  alias MessagingWeb.Controllers.Message
  alias MessagingWeb.Controllers.MockTwilio
  alias MessagingWeb.Controllers.Twilio

  plug :match
  plug :dispatch

  plug Plug.Parsers,
    parsers: [:urlencoded, :json],
    pass: ["text/*"],
    json_decoder: Jason,
    length: 1_000_000,
    read_length: 1_000_000,
    read_timeout: 15_000

  get "/_health" do
    send_resp(conn, 204, "")
  end

  get "/status" do
    body = Jason.encode!(%{status: "ok"})

    conn
    |> put_resp_header("content-type", "application/json")
    |> send_resp(200, body)
  end

  # Main messaging API
  get "/v1/messages", do: Message.list(conn)
  post "/v1/messages", do: Message.create(conn)

  # Webhooks
  post "/v1/webhooks/twilio", do: Twilio.webhook(conn)

  # Mock API for testing inbound messages
  post "/mock/twilio/messages", do: MockTwilio.send_message(conn)

  match _ do
    send_resp(conn, 404, "not found")
  end
end
