defmodule Messaging.OutboxProcessorTest do
  use Messaging.DataCase

  import Ecto.Query

  alias Messaging.Conversations.Message
  alias Messaging.Conversations.OutboxEvent
  alias Messaging.OutboxProcessor
  alias Messaging.Repo

  setup :verify_on_exit!

  describe "OutboxProcessor" do
    setup do
      # Clean up any existing events
      Repo.delete_all(OutboxEvent)
      Repo.delete_all(Message)
      :ok
    end

    test "processes message.send events successfully" do
      # Create a message
      message =
        Repo.insert!(%Message{
          id: "msg_test123",
          conversation_id: "conv_test123",
          from_address: "+1234567890",
          to_address: "+0987654321",
          message_type: "sms",
          body: "Hello, World!",
          direction: "outbound",
          timestamp: DateTime.utc_now()
        })

      # Create an outbox event
      event =
        Repo.insert!(%OutboxEvent{
          id: "outev_test123",
          event_type: "message.send",
          message_id: message.id,
          scheduled_for: DateTime.utc_now()
        })

      # Mock Twilio success response
      expect(Messaging.TwilioMock, :send_message, fn _message ->
        {:ok, %{"status" => "sent", "id" => "provider_12345"}}
      end)

      # Start the processor temporarily
      {:ok, pid} = OutboxProcessor.start_link([])

      # Send process_events message manually for testing
      send(pid, :process_events)

      # Wait a moment for processing
      Process.sleep(100)

      # Verify event was processed
      processed_event = Repo.get!(OutboxEvent, event.id)
      assert processed_event.processed_at

      # Verify message was updated
      updated_message = Repo.get!(Message, message.id)
      assert updated_message.status == :sent
      assert updated_message.provider_id == "provider_12345"

      # Clean up
      GenServer.stop(pid)
    end

    test "handles message not found error" do
      # Create an outbox event for non-existent message
      event =
        Repo.insert!(%OutboxEvent{
          id: "outev_test456",
          event_type: "message.send",
          message_id: "nonexistent_message_id",
          scheduled_for: DateTime.utc_now()
        })

      # Start the processor temporarily
      {:ok, pid} = OutboxProcessor.start_link([])

      # Send process_events message manually
      send(pid, :process_events)

      # Wait for processing
      Process.sleep(100)

      # Verify event was retried (not processed)
      retried_event = Repo.get!(OutboxEvent, event.id)
      assert retried_event.processed_at == nil
      assert retried_event.retry_count == 1
      assert retried_event.error_message =~ "message_not_found"

      # Clean up
      GenServer.stop(pid)
    end

    test "handles provider errors with exponential backoff" do
      # Create a message
      message =
        Repo.insert!(%Message{
          id: "msg_test789",
          conversation_id: "conv_test789",
          from_address: "+1234567890",
          to_address: "+0987654321",
          message_type: "sms",
          body: "Hello, Error!",
          direction: "outbound",
          timestamp: DateTime.utc_now()
        })

      # Create an outbox event
      event =
        Repo.insert!(%OutboxEvent{
          id: "outev_test789",
          event_type: "message.send",
          message_id: message.id,
          scheduled_for: DateTime.utc_now()
        })

      # Mock Twilio error response
      expect(Messaging.TwilioMock, :send_message, fn _message ->
        {:error, {:rate_limit, 429}}
      end)

      # Start the processor temporarily
      {:ok, pid} = OutboxProcessor.start_link([])

      # Send process_events message manually
      send(pid, :process_events)

      # Wait for processing
      Process.sleep(100)

      # Verify event was retried
      retried_event = Repo.get!(OutboxEvent, event.id)
      assert retried_event.processed_at == nil
      assert retried_event.retry_count == 1
      assert retried_event.scheduled_for > DateTime.utc_now()
      assert retried_event.error_message =~ "rate_limit"

      # Clean up
      GenServer.stop(pid)
    end

    test "handles max retries exceeded" do
      # Create a message
      message =
        Repo.insert!(%Message{
          id: "msg_test999",
          conversation_id: "conv_test999",
          from_address: "+1234567890",
          to_address: "+0987654321",
          message_type: "sms",
          body: "Hello, Max Retries!",
          direction: "outbound",
          timestamp: DateTime.utc_now()
        })

      # Create an outbox event that's already at max retries
      event =
        Repo.insert!(%OutboxEvent{
          id: "outev_test999",
          event_type: "message.send",
          message_id: message.id,
          retry_count: 3,
          max_retries: 3,
          scheduled_for: DateTime.utc_now()
        })

      # Mock Twilio error response
      expect(Messaging.TwilioMock, :send_message, fn _message ->
        {:error, {:server_error, 500}}
      end)

      # Start the processor temporarily
      {:ok, pid} = OutboxProcessor.start_link([])

      # Send process_events message manually
      send(pid, :process_events)

      # Wait for processing
      Process.sleep(100)

      # Verify event was marked as failed
      failed_event = Repo.get!(OutboxEvent, event.id)
      assert failed_event.processed_at == nil
      # Should not increment beyond max
      assert failed_event.retry_count == 3
      assert failed_event.error_message =~ "Max retries exceeded"

      # Clean up
      GenServer.stop(pid)
    end

    test "handles unknown event types" do
      # Create an outbox event with unknown type
      event =
        Repo.insert!(%OutboxEvent{
          id: "outev_unknown",
          event_type: "unknown.event",
          message_id: "some_id",
          scheduled_for: DateTime.utc_now()
        })

      # Start the processor temporarily
      {:ok, pid} = OutboxProcessor.start_link([])

      # Send process_events message manually
      send(pid, :process_events)

      # Wait for processing
      Process.sleep(100)

      # Verify event was retried with unknown event type error
      retried_event = Repo.get!(OutboxEvent, event.id)
      assert retried_event.processed_at == nil
      assert retried_event.retry_count == 1
      assert retried_event.error_message =~ "unknown_event_type"

      # Clean up
      GenServer.stop(pid)
    end

    test "processes events in batches" do
      # Create multiple events (more than batch size to test batching)
      events =
        for i <- 1..10 do
          message =
            Repo.insert!(%Message{
              id: "msg_batch_#{i}",
              conversation_id: "conv_batch_#{i}",
              from_address: "+1234567890",
              to_address: "+098765432#{i}",
              message_type: "sms",
              body: "Batch message #{i}",
              direction: "outbound",
              timestamp: DateTime.utc_now()
            })

          Repo.insert!(%OutboxEvent{
            id: "outev_batch_#{i}",
            event_type: "message.send",
            message_id: message.id,
            scheduled_for: DateTime.utc_now()
          })
        end

      # Mock Twilio success responses
      expect(Messaging.TwilioMock, :send_message, 10, fn _message ->
        {:ok, %{"status" => "sent", "id" => "provider_batch_#{:rand.uniform(1000)}"}}
      end)

      # Start the processor temporarily
      {:ok, pid} = OutboxProcessor.start_link([])

      # Send process_events message manually
      send(pid, :process_events)

      # Wait for processing
      Process.sleep(200)

      # Verify all events were processed
      processed_count =
        OutboxEvent
        |> where([e], not is_nil(e.processed_at))
        |> Repo.aggregate(:count)

      assert processed_count == 10

      # Clean up
      GenServer.stop(pid)
    end
  end
end
