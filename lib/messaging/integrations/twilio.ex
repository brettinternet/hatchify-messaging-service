defmodule Messaging.Integrations.Twilio do
  @moduledoc """
  Provider client module for sending messages through Twilio
  for message SMS, MMS, Email.
  """

  @behaviour Messaging.Integrations.Provider

  alias Messaging.Conversations.Message

  require Logger

  @doc """
  Route a message to the appropriate provider based on message type.
  """
  @spec send_message(Message.t()) :: {:ok, map()} | {:error, :provider_error}
  def send_message(%Message{message_type: "sms"} = message), do: send_sms_mms(message)
  def send_message(%Message{message_type: "mms"} = message), do: send_sms_mms(message)
  def send_message(%Message{message_type: "email"} = message), do: send_email(message)
  def send_message(%Message{message_type: type}), do: {:error, {:unsupported_type, type}}
  def send_message(_), do: {:error, :invalid_message}

  @spec send_sms_mms(Message.t()) :: {:ok, map()} | {:error, :provider_error}
  defp send_sms_mms(%Message{} = message) do
    endpoint = get_twilio_sms_endpoint()

    payload = %{
      "from" => message.from_address,
      "to" => message.to_address,
      "type" => message.message_type,
      "body" => message.body,
      "attachments" => message.attachments,
      "timestamp" => DateTime.to_iso8601(message.timestamp)
    }

    Logger.info("Sending #{message.message_type} via Twilio to #{message.to_address}")

    case simulate_http_post(endpoint, payload) do
      {:ok, response} ->
        Logger.info("Twilio SMS/MMS API success: #{inspect(response)}")
        {:ok, response}

      {:error, reason} ->
        Logger.error("Twilio SMS/MMS API error: #{inspect(reason)}")
        {:error, :provider_error}
    end
  end

  @spec send_email(Message.t()) :: {:ok, map()} | {:error, :provider_error}
  defp send_email(%Message{} = message) do
    endpoint = get_twilio_email_endpoint()

    payload = %{
      "from" => message.from_address,
      "to" => message.to_address,
      "body" => message.body,
      "attachments" => message.attachments,
      "timestamp" => DateTime.to_iso8601(message.timestamp)
    }

    Logger.info("Sending email via Twilio Email API to #{message.to_address}")

    case simulate_http_post(endpoint, payload) do
      {:ok, response} ->
        Logger.info("Twilio Email API success: #{inspect(response)}")
        {:ok, response}

      {:error, reason} ->
        Logger.error("Twilio Email API error: #{inspect(reason)}")
        {:error, :provider_error}
    end
  end

  defp get_twilio_sms_endpoint do
    "http://twilio.arpa/api/sms"
  end

  defp get_twilio_email_endpoint do
    "http://twilio.arpa/api/email"
  end

  # Simulate HTTP POST request
  defp simulate_http_post(endpoint, payload) do
    Logger.debug("Simulating POST to #{endpoint} with payload: #{Jason.encode!(payload)}")

    # Simulate various response scenarios
    case :rand.uniform(10) do
      n when n <= 8 ->
        # 80% success rate
        {:ok, %{"status" => "sent", "id" => "provider_" <> UXID.generate!()}}

      9 ->
        # 10% rate limit
        {:error, {:rate_limit, 429}}

      10 ->
        # 10% server error
        {:error, {:server_error, 500}}
    end
  end
end
