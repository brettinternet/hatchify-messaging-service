defmodule MessagingWeb.Router do
  use Plug.Router

  alias MessagingWeb.Controllers.Message
  alias MessagingWeb.Controllers.Twilio

  plug Plug.Parsers,
    parsers: [:urlencoded, :json],
    pass: ["text/*"],
    json_decoder: Jason,
    length: 1_000_000,
    read_length: 1_000_000,
    read_timeout: 15_000

  plug :match
  plug :dispatch

  get "/" do
    body = Jason.encode!(%{status: "ok"})

    conn
    |> put_resp_header("content-type", "application/json")
    |> send_resp(200, body)
  end

  get "/health" do
    send_resp(conn, 204, "")
  end

  # Main messaging API
  post "/api/messages", do: Message.create(conn)
  post "/api/messages/:type", do: Message.create(conn)
  get "/api/conversations", do: Message.list_conversations(conn)
  get "/api/conversations/:conversation_id/messages", do: Message.list_conversation_messages(conn)

  # Webhooks
  post "/api/webhooks/sms", do: Twilio.sms_webhook(conn)
  post "/api/webhooks/email", do: Twilio.email_webhook(conn)

  match _ do
    send_resp(conn, 404, "not found")
  end
end
