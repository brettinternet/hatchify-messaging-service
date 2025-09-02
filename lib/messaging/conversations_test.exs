defmodule Messaging.ConversationsTest do
  use Messaging.DataCase

  alias Messaging.Conversations
  alias Messaging.Conversations.Conversation
  alias Messaging.Conversations.Message
  alias Messaging.Conversations.OutboxEvent
  alias Messaging.Conversations.Participant
  alias Messaging.Repo

  describe "list_conversations/1" do
    test "returns empty list when no conversations exist" do
      assert Conversations.list_conversations() == []
    end

    test "returns conversation with participants and message count" do
      # Create a conversation with message
      message = %Message{
        id: "msg_list_test",
        from_address: "+1234567890",
        to_address: "+0987654321",
        message_type: "sms",
        body: "Test message for listing",
        direction: "outbound",
        timestamp: DateTime.utc_now()
      }

      assert :ok = Conversations.handle_message(message)

      conversations = Conversations.list_conversations()

      assert [%{conversation: conv, participants: participants, message_count: count}] = conversations
      assert Enum.sort(participants) == ["+0987654321", "+1234567890"]
      assert count == 1
      assert is_binary(conv.id)
      assert %DateTime{} = conv.inserted_at
    end

    test "returns multiple conversations ordered by most recent" do
      # Create first conversation
      message1 = %Message{
        id: "msg_first",
        from_address: "+1111111111",
        to_address: "+2222222222",
        message_type: "sms",
        body: "First message",
        direction: "outbound",
        timestamp: DateTime.utc_now()
      }

      assert :ok = Conversations.handle_message(message1)

      # Wait a moment to ensure different timestamps
      Process.sleep(10)

      # Create second conversation
      message2 = %Message{
        id: "msg_second",
        from_address: "+3333333333",
        to_address: "+4444444444",
        message_type: "sms",
        body: "Second message",
        direction: "outbound",
        timestamp: DateTime.utc_now()
      }

      assert :ok = Conversations.handle_message(message2)

      conversations = Conversations.list_conversations()

      assert length(conversations) == 2

      # Should be ordered by most recent first
      [first_result, second_result] = conversations
      assert DateTime.compare(first_result.conversation.inserted_at, second_result.conversation.inserted_at) != :lt
    end

    test "counts multiple messages in same conversation correctly" do
      # Create first message
      message1 = %Message{
        id: "msg_count_1",
        from_address: "+5555555555",
        to_address: "+6666666666",
        message_type: "sms",
        body: "First message",
        direction: "outbound",
        timestamp: DateTime.utc_now()
      }

      assert :ok = Conversations.handle_message(message1)

      # Create second message in same conversation
      message2 = %Message{
        id: "msg_count_2",
        from_address: "+6666666666",
        to_address: "+5555555555",
        message_type: "sms",
        body: "Reply message",
        direction: "inbound",
        timestamp: DateTime.utc_now()
      }

      assert :ok = Conversations.handle_message(message2)

      conversations = Conversations.list_conversations()

      assert [%{conversation: _conv, participants: participants, message_count: count}] = conversations
      assert Enum.sort(participants) == ["+5555555555", "+6666666666"]
      assert count == 2
    end

    test "filters conversations by 'from' parameter" do
      # Create two different conversations
      message1 = %Message{
        id: "msg_filter_1",
        from_address: "+1111111111",
        to_address: "+2222222222",
        message_type: "sms",
        body: "First conversation",
        direction: "outbound",
        timestamp: DateTime.utc_now()
      }

      message2 = %Message{
        id: "msg_filter_2",
        from_address: "+3333333333",
        to_address: "+4444444444",
        message_type: "sms",
        body: "Second conversation",
        direction: "outbound",
        timestamp: DateTime.utc_now()
      }

      assert :ok = Conversations.handle_message(message1)
      assert :ok = Conversations.handle_message(message2)

      # Filter by first participant
      filtered_conversations = Conversations.list_conversations(%{"from" => "+1111111111"})

      assert [%{participants: participants}] = filtered_conversations
      assert "+1111111111" in participants
      refute "+3333333333" in participants
    end

    test "filters conversations by 'to' parameter" do
      # Create two different conversations
      message1 = %Message{
        id: "msg_to_filter_1",
        from_address: "+7777777777",
        to_address: "+8888888888",
        message_type: "sms",
        body: "First conversation",
        direction: "outbound",
        timestamp: DateTime.utc_now()
      }

      message2 = %Message{
        id: "msg_to_filter_2",
        from_address: "+5555555555",
        to_address: "+9999999999",
        message_type: "sms",
        body: "Second conversation",
        direction: "outbound",
        timestamp: DateTime.utc_now()
      }

      assert :ok = Conversations.handle_message(message1)
      assert :ok = Conversations.handle_message(message2)

      # Filter by 'to' participant - should only return the first conversation
      filtered_conversations = Conversations.list_conversations(%{"to" => "+8888888888"})

      assert [%{participants: participants}] = filtered_conversations
      assert "+8888888888" in participants
      assert "+7777777777" in participants
      # Second conversation participants should not be present
      refute "+5555555555" in participants
      refute "+9999999999" in participants
    end

    test "applies limit parameter correctly" do
      # Create 5 conversations
      for i <- 1..5 do
        message = %Message{
          id: "msg_limit_#{i}",
          from_address: "+111111111#{i}",
          to_address: "+999999999#{i}",
          message_type: "sms",
          body: "Message #{i}",
          direction: "outbound",
          timestamp: DateTime.utc_now()
        }

        assert :ok = Conversations.handle_message(message)
      end

      # Test string limit
      limited_conversations = Conversations.list_conversations(%{"limit" => "2"})
      assert length(limited_conversations) == 2

      # Test integer limit
      limited_conversations_int = Conversations.list_conversations(%{"limit" => 3})
      assert length(limited_conversations_int) == 3
    end

    test "ignores invalid limit parameters" do
      # Create 3 conversations
      for i <- 1..3 do
        message = %Message{
          id: "msg_invalid_limit_#{i}",
          from_address: "+222222222#{i}",
          to_address: "+888888888#{i}",
          message_type: "sms",
          body: "Message #{i}",
          direction: "outbound",
          timestamp: DateTime.utc_now()
        }

        assert :ok = Conversations.handle_message(message)
      end

      # Test invalid limit values - should return all results
      for invalid_limit <- ["invalid", "0", "-1", "101"] do
        conversations = Conversations.list_conversations(%{"limit" => invalid_limit})
        assert length(conversations) == 3
      end
    end

    test "handles email conversations" do
      message = %Message{
        id: "msg_email_test",
        from_address: "user@example.com",
        to_address: "contact@example.com",
        message_type: "email",
        body: "<html><body>HTML email content</body></html>",
        direction: "outbound",
        timestamp: DateTime.utc_now()
      }

      assert :ok = Conversations.handle_message(message)

      conversations = Conversations.list_conversations()

      assert [%{conversation: _conv, participants: participants, message_count: count}] = conversations
      assert Enum.sort(participants) == ["contact@example.com", "user@example.com"]
      assert count == 1
    end

    test "handles MMS conversations with attachments" do
      message = %Message{
        id: "msg_mms_test",
        from_address: "+9999999999",
        to_address: "+8888888888",
        message_type: "mms",
        body: "MMS with image",
        attachments: ["https://example.com/image.jpg"],
        direction: "outbound",
        timestamp: DateTime.utc_now()
      }

      assert :ok = Conversations.handle_message(message)

      conversations = Conversations.list_conversations()

      assert [%{conversation: _conv, participants: participants, message_count: count}] = conversations
      assert Enum.sort(participants) == ["+8888888888", "+9999999999"]
      assert count == 1
    end
  end

  describe "list_conversation_messages/1" do
    test "returns empty list for non-existent conversation" do
      messages = Conversations.list_conversation_messages("nonexistent_id")
      assert messages == []
    end

    test "returns message with outbox status false when not processed" do
      message = %Message{
        id: "msg_outbox_false",
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
      assert message_result.id == "msg_outbox_false"
      assert message_result.from_address == "+5555555555"
      assert message_result.to_address == "+6666666666"
      assert message_result.body == "Outbox test message"
      # Not processed yet
      assert outbox_sent == false
    end

    test "returns message with outbox status true when processed" do
      message = %Message{
        id: "msg_outbox_true",
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

      assert [%{message: message_result, outbox_sent: outbox_sent}] = messages
      assert message_result.id == "msg_outbox_true"
      # Now processed
      assert outbox_sent == true
    end

    test "returns multiple messages in chronological order" do
      # Create first message
      message1 = %Message{
        id: "msg_chrono_1",
        from_address: "+1111111111",
        to_address: "+2222222222",
        message_type: "sms",
        body: "First message",
        direction: "outbound",
        # 1 minute ago
        timestamp: DateTime.add(DateTime.utc_now(), -60, :second)
      }

      assert :ok = Conversations.handle_message(message1)

      # Create second message in same conversation
      message2 = %Message{
        id: "msg_chrono_2",
        from_address: "+2222222222",
        to_address: "+1111111111",
        message_type: "sms",
        body: "Reply message",
        direction: "inbound",
        # Now
        timestamp: DateTime.utc_now()
      }

      assert :ok = Conversations.handle_message(message2)

      conversation = Repo.one!(Conversation)
      messages = Conversations.list_conversation_messages(conversation.id)

      assert length(messages) == 2

      # Should be ordered by timestamp (earliest first)
      [first_msg, second_msg] = messages
      assert first_msg.message.id == "msg_chrono_1"
      assert second_msg.message.id == "msg_chrono_2"
      assert DateTime.before?(first_msg.message.timestamp, second_msg.message.timestamp)
    end

    test "returns all message fields correctly" do
      message = %Message{
        id: "msg_all_fields",
        from_address: "+9999999999",
        to_address: "+8888888888",
        message_type: "mms",
        body: "Complete message test",
        attachments: ["https://example.com/file1.jpg", "https://example.com/file2.pdf"],
        provider_id: "provider_123",
        direction: "inbound",
        timestamp: DateTime.utc_now()
      }

      assert :ok = Conversations.handle_message(message)

      conversation = Repo.one!(Conversation)
      messages = Conversations.list_conversation_messages(conversation.id)

      assert [%{message: msg, outbox_sent: _}] = messages
      assert msg.id == "msg_all_fields"
      assert msg.from_address == "+9999999999"
      assert msg.to_address == "+8888888888"
      assert msg.message_type == "mms"
      assert msg.body == "Complete message test"
      assert msg.attachments == ["https://example.com/file1.jpg", "https://example.com/file2.pdf"]
      assert msg.provider_id == "provider_123"
      assert msg.direction == "inbound"
      assert %DateTime{} = msg.timestamp
      assert %DateTime{} = msg.inserted_at
    end

    test "handles email messages correctly" do
      message = %Message{
        id: "msg_email_detailed",
        from_address: "sender@example.com",
        to_address: "recipient@example.com",
        message_type: "email",
        body: "<html><body><h1>Email Subject</h1><p>Email body with <b>formatting</b>.</p></body></html>",
        attachments: ["https://example.com/document.pdf"],
        direction: "outbound",
        timestamp: DateTime.utc_now()
      }

      assert :ok = Conversations.handle_message(message)

      conversation = Repo.one!(Conversation)
      messages = Conversations.list_conversation_messages(conversation.id)

      assert [%{message: msg, outbox_sent: outbox_sent}] = messages
      assert msg.message_type == "email"
      assert msg.from_address == "sender@example.com"
      assert msg.to_address == "recipient@example.com"
      assert String.contains?(msg.body, "<html>")
      assert outbox_sent == false
    end

    test "handles messages with nil attachments" do
      message = %Message{
        id: "msg_nil_attachments",
        from_address: "+1111111111",
        to_address: "+2222222222",
        message_type: "sms",
        body: "Simple SMS message",
        attachments: nil,
        direction: "outbound",
        timestamp: DateTime.utc_now()
      }

      assert :ok = Conversations.handle_message(message)

      conversation = Repo.one!(Conversation)
      messages = Conversations.list_conversation_messages(conversation.id)

      assert [%{message: msg, outbox_sent: _}] = messages
      assert msg.attachments == nil
    end
  end

  describe "handle_message/1" do
    test "creates new conversation and message for new participants" do
      message = %Message{
        id: "msg_new_conversation",
        from_address: "+1234567890",
        to_address: "+0987654321",
        message_type: "sms",
        body: "Hello, new conversation!",
        direction: "outbound",
        timestamp: DateTime.utc_now()
      }

      assert :ok = Conversations.handle_message(message)

      # Verify conversation was created
      conversations = Repo.all(Conversation)
      assert length(conversations) == 1
      conversation = hd(conversations)

      # Verify participants were created
      participants = Participant |> Repo.all() |> Enum.sort_by(& &1.address)
      assert length(participants) == 2
      assert Enum.map(participants, & &1.address) == ["+0987654321", "+1234567890"]
      assert Enum.all?(participants, &(&1.conversation_id == conversation.id))

      # Verify message was created and linked to conversation
      messages = Repo.all(Message)
      assert length(messages) == 1
      saved_message = hd(messages)
      assert saved_message.conversation_id == conversation.id
      assert saved_message.from_address == message.from_address
      assert saved_message.to_address == message.to_address
      assert saved_message.body == message.body

      # Verify outbox event was created
      outbox_events = Repo.all(OutboxEvent)
      assert length(outbox_events) == 1
      outbox_event = hd(outbox_events)
      assert outbox_event.event_type == "message.send"
      assert outbox_event.message_id == saved_message.id
    end

    test "uses existing conversation for same participants" do
      # Create an existing conversation with participants
      conversation = Repo.insert!(%Conversation{id: "conv_existing"})

      Repo.insert!(%Participant{
        conversation_id: conversation.id,
        address: "+1234567890"
      })

      Repo.insert!(%Participant{
        conversation_id: conversation.id,
        address: "+0987654321"
      })

      # Create a message with the same participants (order shouldn't matter)
      message = %Message{
        id: "msg_existing_conversation",
        # Note: from/to reversed from participant creation
        from_address: "+0987654321",
        to_address: "+1234567890",
        message_type: "sms",
        body: "Hello, existing conversation!",
        direction: "inbound",
        timestamp: DateTime.utc_now()
      }

      assert :ok = Conversations.handle_message(message)

      # Verify no new conversation was created
      conversations = Repo.all(Conversation)
      assert length(conversations) == 1
      assert hd(conversations).id == conversation.id

      # Verify no new participants were created
      participants = Repo.all(Participant)
      assert length(participants) == 2

      # Verify message was added to existing conversation
      messages = Repo.all(Message)
      assert length(messages) == 1
      saved_message = hd(messages)
      assert saved_message.conversation_id == conversation.id
    end

    test "handles message with attachments" do
      message = %Message{
        id: "msg_with_attachments",
        from_address: "+1111111111",
        to_address: "+2222222222",
        message_type: "mms",
        body: "Check out this image!",
        attachments: ["https://example.com/image1.jpg", "https://example.com/image2.png"],
        direction: "outbound",
        timestamp: DateTime.utc_now()
      }

      assert :ok = Conversations.handle_message(message)

      # Verify message with attachments was saved
      saved_message = Repo.one!(Message)
      assert saved_message.attachments == message.attachments

      # Verify outbox event was created
      outbox_event = Repo.one!(OutboxEvent)
      assert outbox_event.event_type == "message.send"
      assert outbox_event.message_id == saved_message.id
    end

    test "handles message with nil attachments" do
      message = %Message{
        id: "msg_nil_attachments",
        from_address: "+3333333333",
        to_address: "+4444444444",
        message_type: "sms",
        body: "Simple text message",
        attachments: nil,
        direction: "outbound",
        timestamp: DateTime.utc_now()
      }

      assert :ok = Conversations.handle_message(message)

      # Verify outbox event was created
      outbox_event = Repo.one!(OutboxEvent)
      assert outbox_event.event_type == "message.send"
    end

    test "handles email messages" do
      message = %Message{
        id: "msg_email",
        from_address: "user@example.com",
        to_address: "contact@example.com",
        message_type: "email",
        body: "<html><body>Hello <b>world</b>!</body></html>",
        attachments: [],
        direction: "outbound",
        timestamp: DateTime.utc_now()
      }

      assert :ok = Conversations.handle_message(message)

      # Verify conversation was created with email participants
      participants = Participant |> Repo.all() |> Enum.sort_by(& &1.address)

      assert Enum.map(participants, & &1.address) == [
               "contact@example.com",
               "user@example.com"
             ]

      # Verify message and outbox event were created correctly
      saved_message = Repo.one!(Message)
      assert saved_message.message_type == "email"
      assert saved_message.body == message.body

      outbox_event = Repo.one!(OutboxEvent)
      assert outbox_event.event_type == "message.send"
      assert outbox_event.message_id == saved_message.id
    end

    test "rolls back entire transaction on failure" do
      # Create invalid message data that will cause changeset validation to fail
      message = %Message{
        id: "msg_invalid",
        # Empty from_address should cause validation failure
        from_address: "",
        to_address: "+1234567890",
        message_type: "sms",
        body: "This should fail",
        direction: "outbound",
        timestamp: DateTime.utc_now()
      }

      assert {:error, _changeset} = Conversations.handle_message(message)

      # Verify nothing was created due to transaction rollback
      assert Repo.aggregate(Conversation, :count) == 0
      assert Repo.aggregate(Participant, :count) == 0
      assert Repo.aggregate(Message, :count) == 0
      assert Repo.aggregate(OutboxEvent, :count) == 0
    end

    test "finds conversation with participants in different order" do
      # Create conversation with participants in one order
      conversation = Repo.insert!(%Conversation{id: "conv_order_test"})

      Repo.insert!(%Participant{
        conversation_id: conversation.id,
        address: "alice@example.com"
      })

      Repo.insert!(%Participant{
        conversation_id: conversation.id,
        address: "bob@example.com"
      })

      # Create message with participants in reverse order
      message = %Message{
        id: "msg_order_test",
        # Different order
        from_address: "bob@example.com",
        to_address: "alice@example.com",
        message_type: "email",
        body: "Order shouldn't matter",
        direction: "outbound",
        timestamp: DateTime.utc_now()
      }

      assert :ok = Conversations.handle_message(message)

      # Verify existing conversation was found and used
      conversations = Repo.all(Conversation)
      assert length(conversations) == 1
      assert hd(conversations).id == conversation.id

      # Verify message was added to existing conversation
      saved_message = Repo.one!(Message)
      assert saved_message.conversation_id == conversation.id
    end
  end

  describe "conversation participant matching" do
    test "distinguishes between different participant sets" do
      # Create first conversation with two participants
      message1 = %Message{
        id: "msg_conv1",
        from_address: "+1111111111",
        to_address: "+2222222222",
        message_type: "sms",
        body: "First conversation",
        direction: "outbound",
        timestamp: DateTime.utc_now()
      }

      assert :ok = Conversations.handle_message(message1)

      # Create second conversation with different participants
      message2 = %Message{
        id: "msg_conv2",
        from_address: "+1111111111",
        # Different to_address
        to_address: "+3333333333",
        message_type: "sms",
        body: "Second conversation",
        direction: "outbound",
        timestamp: DateTime.utc_now()
      }

      assert :ok = Conversations.handle_message(message2)

      # Verify two separate conversations were created
      conversations = Repo.all(Conversation)
      assert length(conversations) == 2

      # Verify participants are correctly associated
      participants = Participant |> Repo.all() |> Enum.group_by(& &1.conversation_id)
      assert map_size(participants) == 2

      # Each conversation should have exactly 2 participants
      Enum.each(participants, fn {_conv_id, parts} ->
        assert length(parts) == 2
      end)
    end
  end
end
