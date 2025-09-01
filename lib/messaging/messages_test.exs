defmodule Messaging.MessagesTest do
  use ExUnit.Case, async: true

  alias Messaging.Conversations.Message
  alias Messaging.Messages

  @valid_payload %{
    "from" => "+12016661234",
    "to" => "+18045551234",
    "type" => "sms",
    "body" => "Test message",
    "timestamp" => "2024-11-01T14:00:00Z"
  }

  describe "validate_message/1" do
    test "validates basic SMS message" do
      {:ok, %Message{} = message} = Messages.validate_message(@valid_payload)

      assert message.from_address == "+12016661234"
      assert message.to_address == "+18045551234"
      assert message.message_type == "sms"
      assert message.body == "Test message"
      assert message.direction == "outbound"
      assert message.provider_id == nil
    end

    test "validates MMS message with attachments" do
      payload =
        Map.merge(@valid_payload, %{
          "type" => "mms",
          "attachments" => ["https://example.com/image.jpg"]
        })

      {:ok, message} = Messages.validate_message(payload)

      assert message.message_type == "mms"
      assert message.attachments == ["https://example.com/image.jpg"]
    end

    test "validates inbound SMS webhook" do
      payload =
        Map.merge(@valid_payload, %{
          "messaging_provider_id" => "msg-123",
          "from" => "+18045551234",
          "to" => "+12016661234"
        })

      {:ok, message} = Messages.validate_message(payload)

      assert message.direction == "inbound"
      assert message.provider_id == "msg-123"
    end

    test "validates email message" do
      payload = %{
        "from" => "user@example.com",
        "to" => "contact@example.com",
        "body" => "Email body",
        "xillio_id" => "email-456",
        "timestamp" => "2024-11-01T14:00:00Z"
      }

      {:ok, message} = Messages.validate_message(payload)

      assert message.message_type == "email"
      assert message.direction == "inbound"
      assert message.provider_id == "email-456"
    end

    test "returns error for nil payload" do
      assert {:error, :missing_body} = Messages.validate_message(nil)
    end

    test "returns error for invalid format" do
      assert {:error, :invalid_format} = Messages.validate_message("not a map")
    end

    test "returns error for missing required fields" do
      payload = Map.delete(@valid_payload, "from")
      assert {:error, :invalid_message} = Messages.validate_message(payload)
    end
  end

  describe "timestamp parsing" do
    test "parses UTC ISO 8601 timestamp" do
      payload = Map.put(@valid_payload, "timestamp", "2024-11-01T14:00:00Z")
      {:ok, message} = Messages.validate_message(payload)

      expected = "2024-11-01T14:00:00Z" |> DateTime.from_iso8601() |> elem(1)
      assert message.timestamp == expected
    end

    test "converts timezone to UTC" do
      # EST timestamp (-05:00)
      payload = Map.put(@valid_payload, "timestamp", "2024-11-01T09:00:00-05:00")
      {:ok, message} = Messages.validate_message(payload)

      # Should be converted to 14:00 UTC
      expected = "2024-11-01T14:00:00Z" |> DateTime.from_iso8601() |> elem(1)
      assert message.timestamp == expected
    end

    test "converts positive timezone offset to UTC" do
      # Tokyo time (+09:00)
      payload = Map.put(@valid_payload, "timestamp", "2024-11-01T23:00:00+09:00")
      {:ok, message} = Messages.validate_message(payload)

      # Should be converted to 14:00 UTC
      expected = "2024-11-01T14:00:00Z" |> DateTime.from_iso8601() |> elem(1)
      assert message.timestamp == expected
    end

    test "assumes UTC for naive datetime (no timezone)" do
      payload = Map.put(@valid_payload, "timestamp", "2024-11-01T14:00:00")
      {:ok, message} = Messages.validate_message(payload)

      expected = "2024-11-01T14:00:00Z" |> DateTime.from_iso8601() |> elem(1)
      assert message.timestamp == expected
    end

    test "uses current time for invalid timestamp" do
      payload = Map.put(@valid_payload, "timestamp", "invalid-timestamp")
      {:ok, message} = Messages.validate_message(payload)

      # Should be a recent timestamp (within last minute)
      assert DateTime.diff(DateTime.utc_now(), message.timestamp) < 60
    end

    test "uses current time for nil timestamp" do
      payload = Map.delete(@valid_payload, "timestamp")
      {:ok, message} = Messages.validate_message(payload)

      # Should be a recent timestamp (within last minute)
      assert DateTime.diff(DateTime.utc_now(), message.timestamp) < 60
    end

    test "handles invalid timestamps by falling back to current time" do
      malformed_timestamps = [
        "",
        "not-a-date",
        # Non-ISO format
        "2024-11-01 14:00:00"
      ]

      for timestamp <- malformed_timestamps do
        payload = Map.put(@valid_payload, "timestamp", timestamp)
        {:ok, message} = Messages.validate_message(payload)

        # Should fall back to current time
        assert %DateTime{} = message.timestamp
        # Should be close to now (within last minute)
        assert DateTime.diff(DateTime.utc_now(), message.timestamp) < 60
      end
    end

    test "handles non-string timestamps by falling back to current time" do
      non_string_timestamps = [123, %{"time" => "2024-11-01"}]

      for timestamp <- non_string_timestamps do
        payload = Map.put(@valid_payload, "timestamp", timestamp)
        {:ok, message} = Messages.validate_message(payload)

        # Should fall back to current time
        assert %DateTime{} = message.timestamp
        # Should be close to now (within last minute)
        assert DateTime.diff(DateTime.utc_now(), message.timestamp) < 60
      end
    end
  end

  describe "provider-specific handling" do
    test "handles SMS provider fields" do
      payload =
        Map.merge(@valid_payload, %{
          "messaging_provider_id" => "sms-msg-123",
          "type" => "sms"
        })

      {:ok, message} = Messages.validate_message(payload)

      assert message.message_type == "sms"
      assert message.provider_id == "sms-msg-123"
      assert message.direction == "inbound"
    end

    test "handles MMS provider fields" do
      payload =
        Map.merge(@valid_payload, %{
          "messaging_provider_id" => "mms-msg-456",
          "type" => "mms",
          "attachments" => ["https://provider.com/media/123.jpg"]
        })

      {:ok, message} = Messages.validate_message(payload)

      assert message.message_type == "mms"
      assert message.provider_id == "mms-msg-456"
      assert message.direction == "inbound"
      assert message.attachments == ["https://provider.com/media/123.jpg"]
    end

    test "handles email provider fields" do
      payload = %{
        "from" => "sender@example.com",
        "to" => "recipient@example.com",
        "body" => "<html><body>Email content</body></html>",
        "xillio_id" => "email-789",
        "attachments" => ["https://emailprovider.com/attachment/doc.pdf"],
        "timestamp" => "2024-11-01T14:00:00Z"
      }

      {:ok, message} = Messages.validate_message(payload)

      assert message.message_type == "email"
      assert message.provider_id == "email-789"
      assert message.direction == "inbound"
      assert String.contains?(message.body, "<html>")
    end

    test "treats messages without provider IDs as outbound" do
      # No messaging_provider_id or xillio_id = outbound message
      {:ok, message} = Messages.validate_message(@valid_payload)

      assert message.direction == "outbound"
      assert message.provider_id == nil
    end
  end

  describe "attachment handling" do
    test "handles nil attachments" do
      payload = Map.put(@valid_payload, "attachments", nil)
      {:ok, message} = Messages.validate_message(payload)

      assert message.attachments == nil
    end

    test "handles empty attachments" do
      payload = Map.put(@valid_payload, "attachments", [])
      {:ok, message} = Messages.validate_message(payload)

      assert message.attachments == []
    end

    test "handles list of attachment URLs" do
      urls = ["https://example.com/file1.jpg", "https://example.com/file2.pdf"]
      payload = Map.put(@valid_payload, "attachments", urls)
      {:ok, message} = Messages.validate_message(payload)

      assert message.attachments == urls
    end

    test "ignores non-list attachment values" do
      invalid_attachments = [
        "single-string",
        123,
        %{"files" => ["url"]},
        true
      ]

      for attachments <- invalid_attachments do
        payload = Map.put(@valid_payload, "attachments", attachments)
        {:ok, message} = Messages.validate_message(payload)

        # Should normalize to nil for non-list values
        assert message.attachments == nil
      end
    end
  end
end
