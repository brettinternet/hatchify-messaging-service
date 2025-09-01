defmodule MessagingWeb.RouterTest do
  use ExUnit.Case, async: true

  import Plug.Test

  describe "GET /_health" do
    test "returns no content" do
      conn = conn(:get, "/_health")
      conn = MessagingWeb.Router.call(conn, [])
      assert conn.state == :sent
      assert conn.status == 204
    end
  end

  describe "GET /status" do
    test "returns ok" do
      conn = conn(:get, "/status")
      conn = MessagingWeb.Router.call(conn, [])
      assert conn.state == :sent
      assert conn.status == 200
      assert conn.resp_body == ~s({"status":"ok"})
    end
  end

  describe "404" do
    test "not found" do
      conn = conn(:get, "/")
      conn = MessagingWeb.Router.call(conn, [])
      assert conn.state == :sent
      assert conn.status == 404
      assert conn.resp_body == "not found"
    end
  end
end
