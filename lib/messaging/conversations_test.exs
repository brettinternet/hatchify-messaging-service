defmodule Messaging.ConversationsTest do
  use Messaging.DataCase

  alias Messaging.Conversations
  alias Messaging.Conversations.Conversation
  alias Messaging.Conversations.Message
  alias Messaging.Conversations.OutboxEvent
  alias Messaging.Conversations.Participant
  alias Messaging.Repo

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
