defmodule MessagingWeb.Controllers.TwilioTest do
  use Messaging.DataCase
  use Mimic

  import Plug.Test

  alias Messaging.Conversations
  alias Messaging.Conversations.Message
  alias MessagingWeb.Controllers.Twilio

  setup :set_mimic_global
  setup :verify_on_exit!

  setup do
    copy(Conversations)
  end

  # Helper function to create a mock Plug.Conn
  defp mock_conn(body_params) do
    :post
    |> conn("/", "")
    |> Map.put(:body_params, body_params)
  end

  describe "sms_webhook/1" do
    test "processes valid SMS webhook successfully" do
      body_params = %{
        "from" => "+18045551234",
        "to" => "+12016661234",
        "type" => "sms",
        "messaging_provider_id" => "msg-123",
        "body" => "Hello from webhook",
        "timestamp" => "2024-11-01T14:00:00Z"
      }

      expect(Conversations, :handle_message, fn %Message{} = message ->
        assert message.from_address == "+18045551234"
        assert message.to_address == "+12016661234"
        assert message.message_type == "sms"
        assert message.body == "Hello from webhook"
        assert message.provider_id == "msg-123"
        assert message.direction == "inbound"
        :ok
      end)

      conn = mock_conn(body_params)
      result_conn = Twilio.sms_webhook(conn)

      assert result_conn.status == 200
      response = Jason.decode!(result_conn.resp_body)
      assert response["status"] == "message_processed"
    end

    test "processes valid MMS webhook successfully" do
      body_params = %{
        "from" => "+18045551234",
        "to" => "+12016661234",
        "type" => "mms",
        "messaging_provider_id" => "msg-456",
        "body" => "MMS with attachment",
        "attachments" => ["https://example.com/image.jpg"],
        "timestamp" => "2024-11-01T14:00:00Z"
      }

      expect(Conversations, :handle_message, fn %Message{} = message ->
        assert message.from_address == "+18045551234"
        assert message.to_address == "+12016661234"
        assert message.message_type == "mms"
        assert message.body == "MMS with attachment"
        assert message.attachments == ["https://example.com/image.jpg"]
        assert message.provider_id == "msg-456"
        assert message.direction == "inbound"
        :ok
      end)

      conn = mock_conn(body_params)
      result_conn = Twilio.sms_webhook(conn)

      assert result_conn.status == 200
      response = Jason.decode!(result_conn.resp_body)
      assert response["status"] == "message_processed"
    end

    test "defaults to SMS type when type not provided" do
      body_params = %{
        "from" => "+18045551234",
        "to" => "+12016661234",
        "messaging_provider_id" => "msg-789",
        "body" => "Default SMS type",
        "timestamp" => "2024-11-01T14:00:00Z"
      }

      expect(Conversations, :handle_message, fn %Message{} = message ->
        assert message.message_type == "sms"
        :ok
      end)

      conn = mock_conn(body_params)
      result_conn = Twilio.sms_webhook(conn)

      assert result_conn.status == 200
    end

    test "handles conversation processing failure" do
      body_params = %{
        "from" => "+18045551234",
        "to" => "+12016661234",
        "type" => "sms",
        "body" => "Test message",
        "timestamp" => "2024-11-01T14:00:00Z"
      }

      expect(Conversations, :handle_message, fn _message ->
        {:error, %Ecto.Changeset{}}
      end)

      conn = mock_conn(body_params)
      result_conn = Twilio.sms_webhook(conn)

      assert result_conn.status == 422
      response = Jason.decode!(result_conn.resp_body)
      assert response["error"] == "Message processing failed"
    end

    test "returns error for invalid webhook format" do
      body_params = %{
        "invalid" => "format"
      }

      conn = mock_conn(body_params)
      result_conn = Twilio.sms_webhook(conn)

      assert result_conn.status == 400
      response = Jason.decode!(result_conn.resp_body)
      assert response["error"] == "Invalid webhook format"
    end

    test "handles missing optional fields gracefully" do
      body_params = %{
        "from" => "+18045551234",
        "to" => "+12016661234",
        "body" => "Minimal webhook"
      }

      expect(Conversations, :handle_message, fn %Message{} = message ->
        assert message.message_type == "sms"
        assert message.attachments == nil
        assert message.provider_id == nil
        assert is_struct(message.timestamp, DateTime)
        :ok
      end)

      conn = mock_conn(body_params)
      result_conn = Twilio.sms_webhook(conn)

      assert result_conn.status == 200
    end
  end

  describe "email_webhook/1" do
    test "processes valid email webhook successfully" do
      body_params = %{
        "from" => "sender@example.com",
        "to" => "recipient@example.com",
        "xillio_id" => "email-123",
        "body" => "<html><body>HTML email content</body></html>",
        "attachments" => ["https://example.com/document.pdf"],
        "timestamp" => "2024-11-01T14:00:00Z"
      }

      expect(Conversations, :handle_message, fn %Message{} = message ->
        assert message.from_address == "sender@example.com"
        assert message.to_address == "recipient@example.com"
        assert message.message_type == "email"
        assert message.body == "<html><body>HTML email content</body></html>"
        assert message.attachments == ["https://example.com/document.pdf"]
        assert message.provider_id == "email-123"
        assert message.direction == "inbound"
        :ok
      end)

      conn = mock_conn(body_params)
      result_conn = Twilio.email_webhook(conn)

      assert result_conn.status == 200
      response = Jason.decode!(result_conn.resp_body)
      assert response["status"] == "message_processed"
    end

    test "handles email without attachments" do
      body_params = %{
        "from" => "sender@example.com",
        "to" => "recipient@example.com",
        "body" => "Plain text email"
      }

      expect(Conversations, :handle_message, fn %Message{} = message ->
        assert message.message_type == "email"
        assert message.attachments == nil
        :ok
      end)

      conn = mock_conn(body_params)
      result_conn = Twilio.email_webhook(conn)

      assert result_conn.status == 200
    end

    test "handles conversation processing failure" do
      body_params = %{
        "from" => "sender@example.com",
        "to" => "recipient@example.com",
        "body" => "Test email"
      }

      expect(Conversations, :handle_message, fn _message ->
        {:error, %Ecto.Changeset{}}
      end)

      conn = mock_conn(body_params)
      result_conn = Twilio.email_webhook(conn)

      assert result_conn.status == 422
      response = Jason.decode!(result_conn.resp_body)
      assert response["error"] == "Message processing failed"
    end

    test "returns error for invalid webhook format" do
      body_params = %{
        "missing_required" => "fields"
      }

      conn = mock_conn(body_params)
      result_conn = Twilio.email_webhook(conn)

      assert result_conn.status == 400
      response = Jason.decode!(result_conn.resp_body)
      assert response["error"] == "Invalid webhook format"
    end
  end

  describe "timestamp parsing" do
    test "parses valid ISO8601 timestamp" do
      body_params = %{
        "from" => "+18045551234",
        "to" => "+12016661234",
        "body" => "Test timestamp",
        "timestamp" => "2024-11-01T14:30:45Z"
      }

      expect(Conversations, :handle_message, fn %Message{} = message ->
        assert message.timestamp.year == 2024
        assert message.timestamp.month == 11
        assert message.timestamp.day == 1
        assert message.timestamp.hour == 14
        assert message.timestamp.minute == 30
        assert message.timestamp.second == 45
        :ok
      end)

      conn = mock_conn(body_params)
      Twilio.sms_webhook(conn)
    end

    test "falls back to current time for invalid timestamp" do
      body_params = %{
        "from" => "+18045551234",
        "to" => "+12016661234",
        "body" => "Test timestamp",
        "timestamp" => "invalid-timestamp"
      }

      expect(Conversations, :handle_message, fn %Message{} = message ->
        # Should be close to now
        time_diff = DateTime.diff(DateTime.utc_now(), message.timestamp, :second)
        assert abs(time_diff) < 5
        :ok
      end)

      conn = mock_conn(body_params)
      Twilio.sms_webhook(conn)
    end
  end

  describe "attachment normalization" do
    test "handles nil attachments" do
      body_params = %{
        "from" => "+18045551234",
        "to" => "+12016661234",
        "body" => "No attachments",
        "attachments" => nil
      }

      expect(Conversations, :handle_message, fn %Message{} = message ->
        assert message.attachments == nil
        :ok
      end)

      conn = mock_conn(body_params)
      Twilio.sms_webhook(conn)
    end

    test "handles empty attachment list" do
      body_params = %{
        "from" => "+18045551234",
        "to" => "+12016661234",
        "body" => "Empty attachments",
        "attachments" => []
      }

      expect(Conversations, :handle_message, fn %Message{} = message ->
        assert message.attachments == nil
        :ok
      end)

      conn = mock_conn(body_params)
      Twilio.sms_webhook(conn)
    end

    test "preserves valid attachment list" do
      attachments = ["https://example.com/file1.jpg", "https://example.com/file2.pdf"]

      body_params = %{
        "from" => "+18045551234",
        "to" => "+12016661234",
        "body" => "With attachments",
        "attachments" => attachments
      }

      expect(Conversations, :handle_message, fn %Message{} = message ->
        assert message.attachments == attachments
        :ok
      end)

      conn = mock_conn(body_params)
      Twilio.sms_webhook(conn)
    end
  end
end
