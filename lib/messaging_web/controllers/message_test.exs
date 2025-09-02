defmodule MessagingWeb.Controllers.MessageTest do
  use Messaging.DataCase
  use Mimic
  
  import Plug.Test
  import Plug.Conn

  alias Messaging.Conversations
  alias Messaging.Conversations.Conversation
  alias Messaging.Conversations.Message
  alias Messaging.Conversations.OutboxEvent
  alias Messaging.Conversations.Participant
  alias Messaging.Messages
  alias Messaging.RateLimit
  alias Messaging.Repo
  alias MessagingWeb.Controllers.Message, as: MessageController

  setup :set_mimic_global
  setup :verify_on_exit!

  # Helper function to create a mock Plug.Conn
  defp mock_conn(body_params \\ %{}, query_params \\ %{}) do
    conn(:post, "/", "")
    |> Map.put(:body_params, body_params)
    |> Map.put(:query_params, query_params)
  end

  # Helper to extract response data
  defp get_response(conn) do
    {conn.status, conn.resp_body}
  end

  describe "Conversations.list_conversations/1" do
    test "returns empty list when no conversations exist" do
      assert Conversations.list_conversations() == []
    end

    test "returns conversations with participant and message information" do
      # Create a conversation with message
      message = %Message{
        id: "msg_test",
        from_address: "+1234567890",
        to_address: "+0987654321",
        message_type: "sms",
        body: "Test message",
        direction: "outbound",
        timestamp: DateTime.utc_now()
      }

      assert :ok = Conversations.handle_message(message)

      conversations = Conversations.list_conversations()

      assert [%{conversation: conv, participants: participants, message_count: count}] = conversations
      assert Enum.sort(participants) == ["+0987654321", "+1234567890"]
      assert count == 1
      assert is_binary(conv.id)
    end

    test "filters conversations by 'from' parameter" do
      # Create two conversations with different participants
      message1 = %Message{
        id: "msg_test1",
        from_address: "+1111111111",
        to_address: "+2222222222",
        message_type: "sms",
        body: "Message 1",
        direction: "outbound",
        timestamp: DateTime.utc_now()
      }

      message2 = %Message{
        id: "msg_test2",
        from_address: "+3333333333",
        to_address: "+4444444444",
        message_type: "sms",
        body: "Message 2",
        direction: "outbound",
        timestamp: DateTime.utc_now()
      }

      assert :ok = Conversations.handle_message(message1)
      assert :ok = Conversations.handle_message(message2)

      # Filter by first participant
      conversations = Conversations.list_conversations(%{"from" => "+1111111111"})

      assert [%{participants: participants}] = conversations
      assert "+1111111111" in participants
      refute "+3333333333" in participants
    end

    test "limits results when limit parameter is provided" do
      # Create multiple conversations
      for i <- 1..5 do
        message = %Message{
          id: "msg_test_#{i}",
          from_address: "+111111111#{i}",
          to_address: "+999999999#{i}",
          message_type: "sms",
          body: "Message #{i}",
          direction: "outbound",
          timestamp: DateTime.utc_now()
        }

        assert :ok = Conversations.handle_message(message)
      end

      conversations = Conversations.list_conversations(%{"limit" => "2"})
      assert length(conversations) == 2
    end
  end

  describe "Conversations.list_conversation_messages/1" do
    test "returns empty list for non-existent conversation" do
      messages = Conversations.list_conversation_messages("nonexistent")
      assert messages == []
    end

    test "returns messages with outbox status" do
      # Create conversation with message
      message = %Message{
        id: "msg_outbox_test",
        from_address: "+5555555555",
        to_address: "+6666666666",
        message_type: "sms",
        body: "Outbox test message",
        direction: "outbound",
        timestamp: DateTime.utc_now()
      }

      assert :ok = Conversations.handle_message(message)

      # Get the conversation ID
      conversation = Repo.one!(Conversation)

      messages = Conversations.list_conversation_messages(conversation.id)

      assert [%{message: message_result, outbox_sent: outbox_sent}] = messages
      assert message_result.id == "msg_outbox_test"
      assert message_result.from_address == "+5555555555"
      assert message_result.to_address == "+6666666666"
      assert message_result.body == "Outbox test message"
      # Not processed yet
      assert outbox_sent == false
    end

    test "shows outbox_sent as true when outbox event is processed" do
      # Create conversation with message
      message = %Message{
        id: "msg_processed_test",
        from_address: "+7777777777",
        to_address: "+8888888888",
        message_type: "sms",
        body: "Processed message",
        direction: "outbound",
        timestamp: DateTime.utc_now()
      }

      assert :ok = Conversations.handle_message(message)

      # Mark the outbox event as processed
      outbox_event = Repo.one!(OutboxEvent)
      Repo.update!(OutboxEvent.changeset(outbox_event, %{processed_at: DateTime.utc_now()}))

      conversation = Repo.one!(Conversation)

      messages = Conversations.list_conversation_messages(conversation.id)

      assert [%{message: _message_result, outbox_sent: outbox_sent}] = messages
      # Now processed
      assert outbox_sent == true
    end
  end

  describe "create/1" do
    setup do
      # Copy modules for mocking
      copy(RateLimit)
      copy(Messages)
      
      # Default stub for rate limiting - allow by default
      stub(RateLimit, :message, fn _from -> :ok end)
      :ok
    end

    test "creates message successfully with valid data" do
      valid_message = %Message{
        id: "msg_create_test",
        from_address: "+1234567890",
        to_address: "+0987654321",
        message_type: "sms",
        body: "Test message creation",
        direction: "outbound",
        timestamp: DateTime.utc_now()
      }

      # Mock the Messages.validate_message to return our test message
      stub(Messages, :validate_message, fn _body -> {:ok, valid_message} end)

      body_params = %{
        "from" => "+1234567890",
        "to" => "+0987654321",
        "message_type" => "sms",
        "body" => "Test message creation",
        "direction" => "outbound"
      }

      conn = mock_conn(body_params)
      result_conn = MessageController.create(conn)

      assert {status, body} = get_response(result_conn)
      assert status == 204
      assert body == ""

      # Verify the message was actually created in the database
      assert Repo.aggregate(Conversation, :count) == 1
      assert Repo.aggregate(Message, :count) == 1
      assert Repo.aggregate(OutboxEvent, :count) == 1
    end

    test "returns 400 when request body is missing" do
      conn = mock_conn(nil)
      result_conn = MessageController.create(conn)

      assert {400, "Missing request body"} = get_response(result_conn)
      
      # Verify nothing was created
      assert Repo.aggregate(Conversation, :count) == 0
      assert Repo.aggregate(Message, :count) == 0
      assert Repo.aggregate(OutboxEvent, :count) == 0
    end

    test "returns 400 when 'from' field is missing" do
      body_params = %{
        "to" => "+0987654321",
        "message_type" => "sms",
        "body" => "Test message"
      }

      conn = mock_conn(body_params)
      result_conn = MessageController.create(conn)

      assert {400, "Invalid message format"} = get_response(result_conn)
    end

    test "returns 400 when 'from' field is nil" do
      body_params = %{
        "from" => nil,
        "to" => "+0987654321",
        "message_type" => "sms",
        "body" => "Test message"
      }

      conn = mock_conn(body_params)
      result_conn = MessageController.create(conn)

      assert {400, "Invalid message format"} = get_response(result_conn)
    end

    test "returns 429 when rate limit is exceeded" do
      # Mock rate limiting to return error
      stub(RateLimit, :message, fn _from -> {:error, :rate_limit_exceeded} end)

      body_params = %{
        "from" => "+1234567890",
        "to" => "+0987654321",
        "message_type" => "sms",
        "body" => "Rate limited message"
      }

      conn = mock_conn(body_params)
      result_conn = MessageController.create(conn)

      assert {429, "Rate limit exceeded"} = get_response(result_conn)
      
      # Check that retry-after header is set
      retry_after_header = Enum.find(result_conn.resp_headers, fn {key, _value} -> 
        key == "retry-after" 
      end)
      assert {"retry-after", "60"} = retry_after_header

      # Verify nothing was created due to rate limiting
      assert Repo.aggregate(Message, :count) == 0
    end

    test "returns 400 when message validation fails" do
      # Mock Messages.validate_message to return error
      stub(Messages, :validate_message, fn _body -> {:error, :invalid_message} end)

      body_params = %{
        "from" => "+1234567890",
        "to" => "+0987654321",
        "message_type" => "invalid_type",
        "body" => "Invalid message"
      }

      conn = mock_conn(body_params)
      result_conn = MessageController.create(conn)

      assert {400, "Invalid message format"} = get_response(result_conn)
      
      # Verify nothing was created
      assert Repo.aggregate(Message, :count) == 0
    end

    test "handles SMS message creation" do
      valid_message = %Message{
        id: "msg_sms_test",
        from_address: "+1111111111",
        to_address: "+2222222222",
        message_type: "sms",
        body: "SMS test message",
        direction: "outbound",
        timestamp: DateTime.utc_now()
      }

      stub(Messages, :validate_message, fn _body -> {:ok, valid_message} end)

      body_params = %{
        "from" => "+1111111111",
        "to" => "+2222222222",
        "message_type" => "sms",
        "body" => "SMS test message",
        "direction" => "outbound"
      }

      conn = mock_conn(body_params)
      result_conn = MessageController.create(conn)

      assert {204, ""} = get_response(result_conn)

      # Verify SMS message was created correctly
      message = Repo.one!(Message)
      assert message.message_type == "sms"
      assert message.from_address == "+1111111111"
      assert message.to_address == "+2222222222"
      assert message.body == "SMS test message"
    end

    test "handles MMS message creation with attachments" do
      valid_message = %Message{
        id: "msg_mms_test",
        from_address: "+3333333333",
        to_address: "+4444444444",
        message_type: "mms",
        body: "MMS test message",
        attachments: ["https://example.com/image.jpg"],
        direction: "outbound",
        timestamp: DateTime.utc_now()
      }

      stub(Messages, :validate_message, fn _body -> {:ok, valid_message} end)

      body_params = %{
        "from" => "+3333333333",
        "to" => "+4444444444",
        "message_type" => "mms",
        "body" => "MMS test message",
        "attachments" => ["https://example.com/image.jpg"],
        "direction" => "outbound"
      }

      conn = mock_conn(body_params)
      result_conn = MessageController.create(conn)

      assert {204, ""} = get_response(result_conn)

      # Verify MMS message was created correctly
      message = Repo.one!(Message)
      assert message.message_type == "mms"
      assert message.attachments == ["https://example.com/image.jpg"]
    end

    test "handles email message creation" do
      valid_message = %Message{
        id: "msg_email_test",
        from_address: "sender@example.com",
        to_address: "recipient@example.com",
        message_type: "email",
        body: "<html><body>Email test message</body></html>",
        direction: "outbound",
        timestamp: DateTime.utc_now()
      }

      stub(Messages, :validate_message, fn _body -> {:ok, valid_message} end)

      body_params = %{
        "from" => "sender@example.com",
        "to" => "recipient@example.com",
        "message_type" => "email",
        "body" => "<html><body>Email test message</body></html>",
        "direction" => "outbound"
      }

      conn = mock_conn(body_params)
      result_conn = MessageController.create(conn)

      assert {204, ""} = get_response(result_conn)

      # Verify email message was created correctly
      message = Repo.one!(Message)
      assert message.message_type == "email"
      assert message.from_address == "sender@example.com"
      assert message.to_address == "recipient@example.com"
    end

    test "handles inbound message creation" do
      valid_message = %Message{
        id: "msg_inbound_test",
        from_address: "+5555555555",
        to_address: "+6666666666",
        message_type: "sms",
        body: "Inbound test message",
        provider_id: "provider_123",
        direction: "inbound",
        timestamp: DateTime.utc_now()
      }

      stub(Messages, :validate_message, fn _body -> {:ok, valid_message} end)

      body_params = %{
        "from" => "+5555555555",
        "to" => "+6666666666",
        "message_type" => "sms",
        "body" => "Inbound test message",
        "provider_id" => "provider_123",
        "direction" => "inbound"
      }

      conn = mock_conn(body_params)
      result_conn = MessageController.create(conn)

      assert {204, ""} = get_response(result_conn)

      # Verify inbound message was created correctly
      message = Repo.one!(Message)
      assert message.direction == "inbound"
      assert message.provider_id == "provider_123"
    end

    test "creates conversation and participants for new message" do
      valid_message = %Message{
        id: "msg_new_conv_test",
        from_address: "+7777777777",
        to_address: "+8888888888",
        message_type: "sms",
        body: "New conversation message",
        direction: "outbound",
        timestamp: DateTime.utc_now()
      }

      stub(Messages, :validate_message, fn _body -> {:ok, valid_message} end)

      body_params = %{
        "from" => "+7777777777",
        "to" => "+8888888888",
        "message_type" => "sms",
        "body" => "New conversation message",
        "direction" => "outbound"
      }

      conn = mock_conn(body_params)
      result_conn = MessageController.create(conn)

      assert {204, ""} = get_response(result_conn)

      # Verify conversation was created
      conversation = Repo.one!(Conversation)
      assert is_binary(conversation.id)

      # Verify participants were created
      participants = Repo.all(Participant)
      participant_addresses = Enum.map(participants, & &1.address) |> Enum.sort()
      assert participant_addresses == ["+7777777777", "+8888888888"]

      # Verify all participants belong to the same conversation
      assert Enum.all?(participants, &(&1.conversation_id == conversation.id))

      # Verify message is linked to the conversation
      message = Repo.one!(Message)
      assert message.conversation_id == conversation.id

      # Verify outbox event was created
      outbox_event = Repo.one!(OutboxEvent)
      assert outbox_event.message_id == message.id
      assert outbox_event.event_type == "message.send"
    end

    test "handles conversation creation failure gracefully" do
      valid_message = %Message{
        id: "msg_failure_test",
        from_address: "",  # This will cause validation failure
        to_address: "+8888888888",
        message_type: "sms",
        body: "Failure test message",
        direction: "outbound",
        timestamp: DateTime.utc_now()
      }

      stub(Messages, :validate_message, fn _body -> {:ok, valid_message} end)

      body_params = %{
        "from" => "",
        "to" => "+8888888888",
        "message_type" => "sms",
        "body" => "Failure test message",
        "direction" => "outbound"
      }

      conn = mock_conn(body_params)
      
      # The validation failure causes the with clause to not match, so it raises an error
      assert_raise WithClauseError, fn ->
        MessageController.create(conn)
      end

      # Verify transaction rollback - nothing should be created
      assert Repo.aggregate(Conversation, :count) == 0
      assert Repo.aggregate(Participant, :count) == 0
      assert Repo.aggregate(Message, :count) == 0
      assert Repo.aggregate(OutboxEvent, :count) == 0
    end
  end

  describe "get_body/1" do
    test "returns ok with valid body params containing from field" do
      body_params = %{
        "from" => "+1234567890",
        "to" => "+0987654321",
        "body" => "Test message"
      }
      
      conn = mock_conn(body_params)
      
      assert {:ok, result} = MessageController.get_body(conn)
      assert result == body_params
    end

    test "returns error when body_params is nil" do
      conn = mock_conn(nil)
      
      assert {:error, :missing_body} = MessageController.get_body(conn)
    end

    test "returns error when from field is nil" do
      body_params = %{"from" => nil, "body" => "Test"}
      conn = mock_conn(body_params)
      
      assert {:error, :invalid_message} = MessageController.get_body(conn)
    end

    test "returns error when from field is missing" do
      body_params = %{"body" => "Test message"}
      conn = mock_conn(body_params)
      
      assert {:error, :invalid_message} = MessageController.get_body(conn)
    end

    test "returns error when body_params is not a map" do
      conn = %Plug.Conn{body_params: "invalid"}
      
      assert {:error, :invalid_message} = MessageController.get_body(conn)
    end

    test "accepts additional fields beyond from" do
      body_params = %{
        "from" => "+1234567890",
        "to" => "+0987654321",
        "message_type" => "sms",
        "body" => "Test message",
        "extra_field" => "extra_value"
      }
      
      conn = mock_conn(body_params)
      
      assert {:ok, result} = MessageController.get_body(conn)
      assert result == body_params
    end
  end
end
