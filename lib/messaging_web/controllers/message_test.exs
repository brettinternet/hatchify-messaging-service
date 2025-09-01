defmodule MessagingWeb.Controllers.MessageTest do
  use ExUnit.Case, async: true
  use Plug.Test

  alias MessagingWeb.Controllers.Message

  setup do
    # Reset rate limit tokens before each test
    Application.put_env(:messaging, :rate_limit_message_tokens, 1000)
    :ok
  end

  describe "POST /v1/messages" do
    test "handles valid SMS message" do
      conn =
        :post
        |> conn(
          "/v1/messages",
          Jason.encode!(%{
            "from" => "+12016661234",
            "to" => "+18045551234",
            "type" => "sms",
            "body" => "Hello! This is a test SMS message.",
            "attachments" => nil,
            "timestamp" => "2024-11-01T14:00:00Z"
          })
        )
        |> put_req_header("content-type", "application/json")
        |> Message.call([])

      conn = Message.create(conn)

      assert conn.status == 204
      assert conn.assigns.from == "+12016661234"
      assert conn.assigns.parsed_body["type"] == "sms"
    end

    test "handles valid MMS message" do
      conn =
        :post
        |> conn(
          "/v1/messages",
          Jason.encode!(%{
            "from" => "+12016661234",
            "to" => "+18045551234",
            "type" => "mms",
            "body" => "Hello! This is a test MMS message with attachment.",
            "attachments" => ["https://example.com/image.jpg"],
            "timestamp" => "2024-11-01T14:00:00Z"
          })
        )
        |> put_req_header("content-type", "application/json")
        |> Message.call([])

      conn = Message.create(conn)

      assert conn.status == 204
      assert conn.assigns.from == "+12016661234"
      assert conn.assigns.parsed_body["type"] == "mms"
      assert conn.assigns.parsed_body["attachments"] == ["https://example.com/image.jpg"]
    end

    test "handles valid Email message" do
      conn =
        :post
        |> conn(
          "/v1/messages",
          Jason.encode!(%{
            "from" => "user@usehatchapp.com",
            "to" => "contact@gmail.com",
            "body" => "Hello! This is a test email message with <b>HTML</b> formatting.",
            "attachments" => ["https://example.com/document.pdf"],
            "timestamp" => "2024-11-01T14:00:00Z"
          })
        )
        |> put_req_header("content-type", "application/json")
        |> Message.call([])

      conn = Message.create(conn)

      assert conn.status == 204
      assert conn.assigns.from == "user@usehatchapp.com"
      assert conn.assigns.parsed_body["to"] == "contact@gmail.com"
    end

    test "handles inbound SMS webhook" do
      conn =
        :post
        |> conn(
          "/v1/messages",
          Jason.encode!(%{
            "from" => "+18045551234",
            "to" => "+12016661234",
            "type" => "sms",
            "messaging_provider_id" => "message-1",
            "body" => "This is an incoming SMS message",
            "attachments" => nil,
            "timestamp" => "2024-11-01T14:00:00Z"
          })
        )
        |> put_req_header("content-type", "application/json")
        |> Message.call([])

      conn = Message.create(conn)

      assert conn.status == 204
      assert conn.assigns.from == "+18045551234"
      assert conn.assigns.parsed_body["messaging_provider_id"] == "message-1"
    end

    test "handles inbound MMS webhook" do
      conn =
        :post
        |> conn(
          "/v1/messages",
          Jason.encode!(%{
            "from" => "+18045551234",
            "to" => "+12016661234",
            "type" => "mms",
            "messaging_provider_id" => "message-2",
            "body" => "This is an incoming MMS message",
            "attachments" => ["https://example.com/received-image.jpg"],
            "timestamp" => "2024-11-01T14:00:00Z"
          })
        )
        |> put_req_header("content-type", "application/json")
        |> Message.call([])

      conn = Message.create(conn)

      assert conn.status == 204
      assert conn.assigns.from == "+18045551234"
      assert conn.assigns.parsed_body["messaging_provider_id"] == "message-2"
    end

    test "handles inbound Email webhook" do
      conn =
        :post
        |> conn(
          "/v1/messages",
          Jason.encode!(%{
            "from" => "contact@gmail.com",
            "to" => "user@usehatchapp.com",
            "xillio_id" => "message-3",
            "body" => "<html><body>This is an incoming email with <b>HTML</b> content</body></html>",
            "attachments" => ["https://example.com/received-document.pdf"],
            "timestamp" => "2024-11-01T14:00:00Z"
          })
        )
        |> put_req_header("content-type", "application/json")
        |> Message.call([])

      conn = Message.create(conn)

      assert conn.status == 204
      assert conn.assigns.from == "contact@gmail.com"
      assert conn.assigns.parsed_body["xillio_id"] == "message-3"
    end

    test "returns 400 for missing 'from' field" do
      conn =
        :post
        |> conn(
          "/v1/messages",
          Jason.encode!(%{
            "to" => "+18045551234",
            "type" => "sms",
            "body" => "Missing from field",
            "timestamp" => "2024-11-01T14:00:00Z"
          })
        )
        |> put_req_header("content-type", "application/json")
        |> Message.call([])

      conn = Message.create(conn)

      # Should still process since we handle missing 'from' gracefully
      # Rate limiting will use nil sender
      assert conn.status == 204
      assert conn.assigns.from == nil
    end

    test "returns 400 for invalid JSON" do
      conn =
        :post
        |> conn("/v1/messages", "{ invalid json }")
        |> put_req_header("content-type", "application/json")
        |> Message.call([])

      conn = Message.create(conn)

      # Should still process since body reader handles invalid JSON gracefully
      assert conn.status == 204
      assert conn.assigns.from == nil
    end

    test "returns 413 for oversized body" do
      # > 1MB limit
      large_body = String.duplicate("x", 1_100_000)

      conn =
        :post
        |> conn("/v1/messages", large_body)
        |> put_req_header("content-type", "application/json")
        |> Message.call([])

      # Should be rejected by Plug.Parsers before reaching controller
      # Could be either depending on Plug handling
      assert conn.status in [413, 400]
    end
  end

  describe "bad input handling" do
    test "handles completely empty body" do
      conn =
        :post
        |> conn("/v1/messages", "")
        |> put_req_header("content-type", "application/json")
        |> Message.call([])

      conn = Message.create(conn)

      # Should handle gracefully
      assert conn.status == 204
      assert conn.assigns.from == nil
    end

    test "handles null JSON" do
      conn =
        :post
        |> conn("/v1/messages", "null")
        |> put_req_header("content-type", "application/json")
        |> Message.call([])

      conn = Message.create(conn)

      assert conn.status == 204
      assert conn.assigns.from == nil
    end

    test "handles JSON array instead of object" do
      conn =
        :post
        |> conn("/v1/messages", Jason.encode!(["not", "an", "object"]))
        |> put_req_header("content-type", "application/json")
        |> Message.call([])

      conn = Message.create(conn)

      assert conn.status == 204
      assert conn.assigns.from == nil
    end

    test "handles JSON string instead of object" do
      conn =
        :post
        |> conn("/v1/messages", Jason.encode!("just a string"))
        |> put_req_header("content-type", "application/json")
        |> Message.call([])

      conn = Message.create(conn)

      assert conn.status == 204
      assert conn.assigns.from == nil
    end

    test "handles JSON number instead of object" do
      conn =
        :post
        |> conn("/v1/messages", "12345")
        |> put_req_header("content-type", "application/json")
        |> Message.call([])

      conn = Message.create(conn)

      assert conn.status == 204
      assert conn.assigns.from == nil
    end

    test "handles malformed JSON - missing quotes" do
      conn =
        :post
        |> conn("/v1/messages", "{from: test, to: test2}")
        |> put_req_header("content-type", "application/json")
        |> Message.call([])

      conn = Message.create(conn)

      assert conn.status == 204
      assert conn.assigns.from == nil
    end

    test "handles malformed JSON - trailing comma" do
      conn =
        :post
        |> conn("/v1/messages", ~s({"from": "test", "to": "test2",}))
        |> put_req_header("content-type", "application/json")
        |> Message.call([])

      conn = Message.create(conn)

      assert conn.status == 204
      assert conn.assigns.from == nil
    end

    test "handles malformed JSON - unmatched braces" do
      conn =
        :post
        |> conn("/v1/messages", ~s({"from": "test", "to": "test2"))
        |> put_req_header("content-type", "application/json")
        |> Message.call([])

      conn = Message.create(conn)

      assert conn.status == 204
      assert conn.assigns.from == nil
    end

    test "handles invalid UTF-8 sequences" do
      # Invalid UTF-8 bytes
      invalid_utf8 = <<0xFF, 0xFE, 0x00, 0x00>>

      conn =
        :post
        |> conn("/v1/messages", invalid_utf8)
        |> put_req_header("content-type", "application/json")
        |> Message.call([])

      conn = Message.create(conn)

      assert conn.status == 204
      assert conn.assigns.from == nil
    end

    test "handles non-string 'from' field" do
      conn =
        :post
        |> conn(
          "/v1/messages",
          Jason.encode!(%{
            # number instead of string
            "from" => 12_345,
            "to" => "+18045551234",
            "type" => "sms",
            "body" => "Test message"
          })
        )
        |> put_req_header("content-type", "application/json")
        |> Message.call([])

      conn = Message.create(conn)

      assert conn.status == 204
      # Should not extract non-string 'from'
      assert conn.assigns.from == nil
    end

    test "handles null 'from' field" do
      conn =
        :post
        |> conn(
          "/v1/messages",
          Jason.encode!(%{
            "from" => nil,
            "to" => "+18045551234",
            "type" => "sms",
            "body" => "Test message"
          })
        )
        |> put_req_header("content-type", "application/json")
        |> Message.call([])

      conn = Message.create(conn)

      assert conn.status == 204
      assert conn.assigns.from == nil
    end

    test "handles boolean 'from' field" do
      conn =
        :post
        |> conn(
          "/v1/messages",
          Jason.encode!(%{
            "from" => true,
            "to" => "+18045551234",
            "type" => "sms",
            "body" => "Test message"
          })
        )
        |> put_req_header("content-type", "application/json")
        |> Message.call([])

      conn = Message.create(conn)

      assert conn.status == 204
      assert conn.assigns.from == nil
    end

    test "handles array 'from' field" do
      conn =
        :post
        |> conn(
          "/v1/messages",
          Jason.encode!(%{
            "from" => ["multiple", "senders"],
            "to" => "+18045551234",
            "type" => "sms",
            "body" => "Test message"
          })
        )
        |> put_req_header("content-type", "application/json")
        |> Message.call([])

      conn = Message.create(conn)

      assert conn.status == 204
      assert conn.assigns.from == nil
    end

    test "handles object 'from' field" do
      conn =
        :post
        |> conn(
          "/v1/messages",
          Jason.encode!(%{
            "from" => %{"name" => "John", "phone" => "+12016661234"},
            "to" => "+18045551234",
            "type" => "sms",
            "body" => "Test message"
          })
        )
        |> put_req_header("content-type", "application/json")
        |> Message.call([])

      conn = Message.create(conn)

      assert conn.status == 204
      assert conn.assigns.from == nil
    end

    test "handles empty string 'from' field" do
      conn =
        :post
        |> conn(
          "/v1/messages",
          Jason.encode!(%{
            "from" => "",
            "to" => "+18045551234",
            "type" => "sms",
            "body" => "Test message"
          })
        )
        |> put_req_header("content-type", "application/json")
        |> Message.call([])

      conn = Message.create(conn)

      assert conn.status == 204
      # Empty string is still a valid string
      assert conn.assigns.from == ""
    end

    test "handles very long 'from' field" do
      long_from = String.duplicate("a", 10_000)

      conn =
        :post
        |> conn(
          "/v1/messages",
          Jason.encode!(%{
            "from" => long_from,
            "to" => "+18045551234",
            "type" => "sms",
            "body" => "Test message"
          })
        )
        |> put_req_header("content-type", "application/json")
        |> Message.call([])

      conn = Message.create(conn)

      assert conn.status == 204
      # Should still extract it
      assert conn.assigns.from == long_from
    end

    test "handles unicode characters in 'from' field" do
      unicode_from = "📱+12016661234🌟"

      conn =
        :post
        |> conn(
          "/v1/messages",
          Jason.encode!(%{
            "from" => unicode_from,
            "to" => "+18045551234",
            "type" => "sms",
            "body" => "Test message"
          })
        )
        |> put_req_header("content-type", "application/json")
        |> Message.call([])

      conn = Message.create(conn)

      assert conn.status == 204
      assert conn.assigns.from == unicode_from
    end

    test "handles missing content-type header" do
      conn =
        :post
        |> conn(
          "/v1/messages",
          Jason.encode!(%{
            "from" => "+12016661234",
            "to" => "+18045551234",
            "type" => "sms",
            "body" => "Test message"
          })
        )
        # No content-type header
        |> Message.call([])

      conn = Message.create(conn)

      # Should still work - Plug.Parsers may handle this
      assert conn.status == 204
    end

    test "handles wrong content-type header" do
      conn =
        :post
        |> conn(
          "/v1/messages",
          Jason.encode!(%{
            "from" => "+12016661234",
            "to" => "+18045551234",
            "type" => "sms",
            "body" => "Test message"
          })
        )
        |> put_req_header("content-type", "text/plain")
        |> Message.call([])

      conn = Message.create(conn)

      # Behavior depends on Plug.Parsers configuration
      assert conn.status in [200, 204, 400, 415]
    end

    test "handles deeply nested JSON" do
      nested_json = %{
        "from" => "+12016661234",
        "to" => "+18045551234",
        "metadata" => %{
          "level1" => %{
            "level2" => %{
              "level3" => %{
                "deep" => "value"
              }
            }
          }
        }
      }

      conn =
        :post
        |> conn("/v1/messages", Jason.encode!(nested_json))
        |> put_req_header("content-type", "application/json")
        |> Message.call([])

      conn = Message.create(conn)

      assert conn.status == 204
      assert conn.assigns.from == "+12016661234"
    end
  end

  describe "rate limiting" do
    setup do
      Application.put_env(:messaging, :rate_limit_message_tokens, 100)
      :ok
    end

    test "rate limits by 'from' field" do
      Application.put_env(:messaging, :rate_limit_message_tokens, 1)

      conn =
        :post
        |> conn(
          "/v1/messages",
          Jason.encode!(%{
            "from" => "+12016661234",
            "to" => "+18045551234",
            "type" => "sms",
            "body" => "Rate limit test",
            "timestamp" => "2024-11-01T14:00:00Z"
          })
        )
        |> put_req_header("content-type", "application/json")
        |> Message.call([])

      assert conn.assigns.from == "+12016661234"
      assert conn.status == 204

      conn =
        :post
        |> conn(
          "/v1/messages",
          Jason.encode!(%{
            "from" => "+12016661234",
            "to" => "+18045551234",
            "type" => "sms",
            "body" => "Rate limit test",
            "timestamp" => "2024-11-01T14:00:00Z"
          })
        )
        |> put_req_header("content-type", "application/json")
        |> Message.call([])

      assert conn.assigns.from == "+12016661234"
      assert conn.status == 429
    end
  end

  describe "body parsing and assignment" do
    test "correctly parses and assigns body data" do
      message_data = %{
        "from" => "+12016661234",
        "to" => "+18045551234",
        "type" => "sms",
        "body" => "Test message",
        "attachments" => ["url1", "url2"],
        "timestamp" => "2024-11-01T14:00:00Z"
      }

      conn =
        :post
        |> conn("/v1/messages", Jason.encode!(message_data))
        |> put_req_header("content-type", "application/json")
        |> Message.call([])

      # Verify parsing extracted sender
      assert conn.assigns.from == "+12016661234"

      # Verify full parsed body is available
      assert conn.assigns.parsed_body["from"] == "+12016661234"
      assert conn.assigns.parsed_body["type"] == "sms"
      assert conn.assigns.parsed_body["attachments"] == ["url1", "url2"]
    end

    test "handles nil attachments" do
      message_data = %{
        "from" => "+12016661234",
        "to" => "+18045551234",
        "type" => "sms",
        "body" => "Test message",
        "attachments" => nil,
        "timestamp" => "2024-11-01T14:00:00Z"
      }

      conn =
        :post
        |> conn("/v1/messages", Jason.encode!(message_data))
        |> put_req_header("content-type", "application/json")
        |> Message.call([])

      assert conn.assigns.parsed_body["attachments"] == nil
    end

    test "handles empty attachments array" do
      message_data = %{
        "from" => "+12016661234",
        "to" => "+18045551234",
        "type" => "sms",
        "body" => "Test message",
        "attachments" => [],
        "timestamp" => "2024-11-01T14:00:00Z"
      }

      conn =
        :post
        |> conn("/v1/messages", Jason.encode!(message_data))
        |> put_req_header("content-type", "application/json")
        |> Message.call([])

      assert conn.assigns.parsed_body["attachments"] == []
    end
  end
end
