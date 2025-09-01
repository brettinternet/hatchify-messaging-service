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
  @spec validate_message(map() | nil) :: {:ok, Message.t()} | {:error, atom()}
  def validate_message(nil), do: {:error, :missing_body}

  def validate_message(payload) when is_map(payload) do
    # Transform provider-specific fields to common schema
    attrs = transform_payload(payload)

    # Create changeset and validate
    changeset = Message.changeset(%Message{}, attrs)

    if changeset.valid? do
      {:ok, Ecto.Changeset.apply_changes(changeset)}
    else
      {:error, :invalid_message}
    end
  end

  def validate_message(_), do: {:error, :invalid_format}

  # Generate a conversation ID based on participants
  # This is a placeholder - the real implementation should find or create conversation
  defp generate_conversation_id(payload) do
    from = get_from_address(payload)
    to = get_to_address(payload)

    case {from, to} do
      {nil, _} ->
        "conv-" <> UXID.generate!()

      {_, nil} ->
        "conv-" <> UXID.generate!()

      {from_addr, to_addr} ->
        # Create deterministic conversation ID from sorted participants
        participants = Enum.sort([from_addr, to_addr])

        "conv-" <>
          (:md5 |> :crypto.hash(Enum.join(participants, ":")) |> Base.encode16(case: :lower) |> String.slice(0, 12))
    end
  end

  # Transform different provider formats into our internal schema
  defp transform_payload(payload) do
    %{
      conversation_id: generate_conversation_id(payload),
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
