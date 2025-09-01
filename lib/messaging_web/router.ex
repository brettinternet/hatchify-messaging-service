defmodule MessagingWeb.Router do
  use Plug.Router

  alias MessagingWeb.Controllers.Message

  plug :match
  plug :dispatch

  get "/_health" do
    send_resp(conn, 204, "")
  end

  get "/status" do
    body = Jason.encode!(%{status: "ok"})

    conn
    |> put_resp_header("content-type", "application/json")
    |> send_resp(200, body)
  end

  get "/v1/messages", do: conn |> Message.call([]) |> Message.list()
  post "/v1/messages", do: conn |> Message.call([]) |> Message.create()

  match _ do
    send_resp(conn, 404, "not found")
  end
end
