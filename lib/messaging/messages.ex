defmodule Messaging.Messages do
  @moduledoc """
  Message validation and transformation for incoming HTTP requests.
  Converts raw JSON payloads into validated Message structs.
  """

  alias Messaging.Conversations.Message

  @doc """
  Validates and transforms a raw message payload into a Message struct.

  Handles different provider formats:
  - SMS/MMS: uses `messaging_provider_id`
  - Email: uses `xillio_id`
  """
  @spec validate_message(nil) :: {:error, atom()}
  def validate_message(nil), do: {:error, :missing_body}

  @spec validate_message(map()) :: {:ok, Message.t()} | {:error, atom()}
  def validate_message(payload) when is_map(payload) do
    # Transform provider-specific fields to common schema
    attrs = transform_payload(payload)

    # Validate required fields manually to avoid changeset complexity
    case validate_required_fields(attrs) do
      :ok ->
        {:ok, struct(Message, attrs)}
      
      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec validate_message(any()) :: {:error, atom()}
  def validate_message(_), do: {:error, :invalid_format}

  # Validate required fields manually
  defp validate_required_fields(attrs) do
    required_fields = [:from_address, :to_address, :message_type, :body, :direction, :timestamp]
    
    case Enum.find(required_fields, fn field -> is_nil(Map.get(attrs, field)) end) do
      nil -> :ok
      _missing_field -> {:error, :invalid_message}
    end
  end

  # Transform different provider formats into our internal schema
  defp transform_payload(payload) do
    %{
      from_address: get_from_address(payload),
      to_address: get_to_address(payload),
      message_type: get_message_type(payload),
      body: Map.get(payload, "body"),
      attachments: normalize_attachments(Map.get(payload, "attachments")),
      provider_id: get_provider_id(payload),
      direction: determine_direction(payload),
      timestamp: parse_timestamp(Map.get(payload, "timestamp"))
    }
  end

  # Extract 'from' field
  defp get_from_address(%{"from" => from}) when is_binary(from), do: extract_email_from_markdown(from)
  defp get_from_address(_), do: nil

  # Extract 'to' field
  defp get_to_address(%{"to" => to}) when is_binary(to), do: extract_email_from_markdown(to)
  defp get_to_address(_), do: nil

  # Extract email from formatted or return as-is
  defp extract_email_from_markdown(value) do
    case Regex.run(~r/\[(.+?)\]\(mailto:(.+?)\)/, value) do
      [_full, _display, email] -> email
      nil -> value
    end
  end

  # Determine message type based on payload
  defp get_message_type(%{"type" => type}) when type in ["sms", "mms"], do: type
  defp get_message_type(%{"xillio_id" => _}), do: "email"
  defp get_message_type(_), do: nil

  # Get provider ID from different provider formats
  defp get_provider_id(%{"messaging_provider_id" => id}), do: id
  defp get_provider_id(%{"xillio_id" => id}), do: id
  defp get_provider_id(_), do: nil

  # Determine if this is inbound (webhook) or outbound (send request)
  defp determine_direction(%{"messaging_provider_id" => _}), do: "inbound"
  defp determine_direction(%{"xillio_id" => _}), do: "inbound"
  defp determine_direction(_), do: "outbound"

  # Normalize attachments to array of strings
  defp normalize_attachments(nil), do: nil
  defp normalize_attachments([]), do: []
  defp normalize_attachments(attachments) when is_list(attachments), do: attachments
  defp normalize_attachments(_), do: nil

  # Parse timestamp with timezone handling - ISO 8601 only
  defp parse_timestamp(nil), do: DateTime.utc_now()

  defp parse_timestamp(timestamp) when is_binary(timestamp) do
    case DateTime.from_iso8601(timestamp) do
      # Timezone-aware timestamp - convert to UTC
      {:ok, datetime, _offset} ->
        DateTime.shift_zone!(datetime, "Etc/UTC")

      # No timezone - only accept strict ISO 8601 format with 'T' separator
      {:error, :missing_offset} ->
        if String.contains?(timestamp, "T") do
          case NaiveDateTime.from_iso8601(timestamp) do
            {:ok, naive_dt} ->
              DateTime.from_naive!(naive_dt, "Etc/UTC")

            {:error, _} ->
              DateTime.utc_now()
          end
        else
          # Reject space-separated datetime format
          DateTime.utc_now()
        end

      # Invalid format - fall back to current time
      {:error, _reason} ->
        DateTime.utc_now()
    end
  end

  defp parse_timestamp(_), do: DateTime.utc_now()
end
