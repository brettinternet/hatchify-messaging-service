defmodule MessagingWeb.Controllers.MockTwilio do
  @moduledoc """
  Mock Twilio service for testing SMS/MMS sending functionality.

  Simulates Twilio API endpoints and webhook callbacks to test the complete
  message flow without requiring actual Twilio integration.
  """

  import Plug.Conn

  require Logger

  @doc """
  Handle outbound SMS/MMS messages sent to the mock Twilio API.

  Expected payload format:
  {
    "from": "from-phone-number",
    "to": "to-phone-number",
    "type": "sms" | "mms",
    "body": "text message",
    "attachments": ["attachment-url"] | [] | null,
    "timestamp": "2024-11-01T14:00:00Z"
  }
  """
  def send_message(%Plug.Conn{} = conn) do
    case conn.body_params do
      %{"from" => from, "to" => to, "body" => body} = params ->
        message_type = Map.get(params, "type", "sms")
        attachments = Map.get(params, "attachments", [])

        # Simulate message ID generation
        message_id = "mock_twilio_" <> UXID.generate!()

        Logger.info("Mock Twilio: Sending #{message_type} from #{from} to #{to}")
        Logger.debug("Mock Twilio: Message body: #{body}")

        # Simulate success response like Twilio API
        response = %{
          "account_sid" => "ACmock123456789",
          "sid" => message_id,
          "messaging_service_sid" => nil,
          "from" => from,
          "to" => to,
          "body" => body,
          "status" => "queued",
          "direction" => "outbound-api",
          "api_version" => "2010-04-01",
          "uri" => "/2010-04-01/Accounts/ACmock123456789/Messages/#{message_id}.json"
        }

        # Schedule a simulated webhook callback (optional, for testing)
        schedule_webhook_callback(from, to, message_type, body, attachments, message_id)

        conn
        |> put_resp_header("content-type", "application/json")
        |> send_resp(201, Jason.encode!(response))

      _ ->
        conn
        |> put_resp_header("content-type", "application/json")
        |> send_resp(400, Jason.encode!(%{"error" => "Invalid request format"}))
    end
  end

  # Private helper to schedule webhook callback (simulates delayed message delivery)
  defp schedule_webhook_callback(from, to, type, body, attachments, provider_id) do
    # In a real system, this might use a job queue
    # For now, we'll just log that we could send a callback
    Logger.debug("Mock Twilio: Could schedule webhook callback for message #{provider_id}")
  end
end
