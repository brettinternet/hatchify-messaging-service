defmodule MessagingWeb.Controllers.Twilio do
  @moduledoc """
  Mock Twilio service for testing SMS/MMS sending functionality.

  Simulates Twilio API endpoints and webhook callbacks to test the complete
  message flow without requiring actual Twilio integration.
  """

  import Plug.Conn

  require Logger

  @doc """
  Webhook callback from Twilio.
  """
  def webhook(%Plug.Conn{} = conn) do
    case conn.body_params do
      %{"from" => from, "to" => to, "body" => body} = params ->
        message_type = Map.get(params, "type", "sms")
        attachments = Map.get(params, "attachments", [])

        # Create inbound message payload in the format expected by our service
        webhook_payload = %{
          "from" => from,
          "to" => to,
          "type" => message_type,
          "messaging_provider_id" => "mock_inbound_" <> UXID.generate!(),
          "body" => body,
          "attachments" => attachments,
          "timestamp" => DateTime.to_iso8601(DateTime.utc_now())
        }

        Logger.info("Mock Twilio: Simulating inbound #{message_type} webhook from #{from} to #{to}")

        # Send webhook to our own message endpoint
        send_webhook_to_service(webhook_payload)

        conn
        |> put_resp_header("content-type", "application/json")
        |> send_resp(200, Jason.encode!(%{"status" => "webhook_sent"}))

      _ ->
        conn
        |> put_resp_header("content-type", "application/json")
        |> send_resp(400, Jason.encode!(%{"error" => "Invalid webhook format"}))
    end
  end

  # Private helper to schedule webhook callback (simulates delayed message delivery)
  defp schedule_webhook_callback(from, to, type, body, attachments, provider_id) do
    # In a real system, this might use a job queue
    # For now, we'll just log that we could send a callback
    Logger.debug("Mock Twilio: Could schedule webhook callback for message #{provider_id}")
  end

  # Private helper to send webhook to our service
  defp send_webhook_to_service(payload) do
    # This would typically use HTTPoison or similar to POST to our webhook endpoint
    # For now, just log what we would send
    Logger.info("Mock Twilio: Would send webhook: #{Jason.encode!(payload)}")
  end
end
