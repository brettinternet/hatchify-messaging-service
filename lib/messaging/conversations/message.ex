defmodule Messaging.Conversations.Message do
  @moduledoc """
  Schema for messages in conversations.
  Supports SMS, MMS, and Email messages.
  """

  use Messaging.Schema, prefix: "msg"

  import Ecto.Changeset

  alias Messaging.Conversations.Conversation
  alias Messaging.Conversations.OutboxEvent

  @type t :: %__MODULE__{
          id: String.t(),
          conversation_id: String.t(),
          from_address: String.t(),
          to_address: String.t(),
          message_type: String.t(),
          body: String.t(),
          attachments: [String.t()] | nil,
          provider_id: String.t() | nil,
          direction: String.t(),
          timestamp: DateTime.t(),
          conversation: Conversation.t() | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t()
        }

  @message_types ~w(sms mms email)
  @directions ~w(inbound outbound)

  schema "message" do
    field :from_address, :string
    field :to_address, :string
    field :message_type, :string
    field :body, :string
    field :attachments, {:array, :string}
    field :provider_id, :string
    field :direction, :string
    field :timestamp, :utc_datetime_usec

    belongs_to :conversation, Conversation, references: :id
    has_one :outbox_event, OutboxEvent, foreign_key: :message_id, references: :id

    timestamps(updated_at: false)
  end

  @doc false
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = message, attrs) do
    message
    |> cast(attrs, [
      :conversation_id,
      :from_address,
      :to_address,
      :message_type,
      :body,
      :attachments,
      :provider_id,
      :direction,
      :timestamp
    ])
    |> validate_required([
      :conversation_id,
      :from_address,
      :to_address,
      :message_type,
      :body,
      :direction,
      :timestamp
    ])
    |> validate_length(:from_address, min: 1, max: 255)
    |> validate_length(:to_address, min: 1, max: 255)
    |> validate_inclusion(:message_type, @message_types)
    |> validate_inclusion(:direction, @directions)
    |> validate_attachments()
    |> unique_constraint([:provider_id, :message_type], name: :message_provider_id_message_type_index)
  end

  # Validate attachments array
  defp validate_attachments(changeset) do
    case get_field(changeset, :attachments) do
      nil ->
        changeset

      [] ->
        changeset

      attachments when is_list(attachments) ->
        valid_attachments = Enum.filter(attachments, &is_binary/1)

        if Enum.all?(valid_attachments, &valid_attachment_url?/1) do
          changeset
        else
          add_error(changeset, :attachments, "contains invalid or overly long URLs")
        end

      _ ->
        add_error(changeset, :attachments, "must be a list of strings")
    end
  end

  # Validate individual attachment URL
  # with reasonable URL length limit to prevent abuse
  defp valid_attachment_url?(url) when is_binary(url) do
    length = String.length(url)
    length >= 5 and length <= 2048
  end

  defp valid_attachment_url?(_), do: false
end
