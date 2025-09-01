defmodule Messaging.Conversations.Participant do
  @moduledoc """
  Schema for conversation participants.
  Links conversations to participant addresses (phone numbers or emails).
  """

  use Messaging.Schema, prefix: "part"

  import Ecto.Changeset

  alias Messaging.Conversations.Conversation

  @type t :: %__MODULE__{
          id: String.t(),
          conversation_id: String.t(),
          participant_address: String.t(),
          conversation: Conversation.t() | Ecto.Association.NotLoaded.t(),
          inserted_at: NaiveDateTime.t()
        }

  schema "participant" do
    field :conversation_id, :string
    field :participant_address, :string

    belongs_to :conversation, Conversation, define_field: false, references: :id

    timestamps(updated_at: false)
  end

  @doc false
  def changeset(participant, attrs) do
    participant
    |> cast(attrs, [:conversation_id, :participant_address])
    |> validate_required([:conversation_id, :participant_address])
    |> validate_participant_address()
    |> unique_constraint([:conversation_id, :participant_address])
  end

  @doc """
  Creates participants for a conversation from a list of addresses.
  """
  def create_for_conversation(conversation_id, addresses) when is_list(addresses) do
    Enum.map(addresses, fn address ->
      changeset(%__MODULE__{}, %{
        conversation_id: conversation_id,
        participant_address: address
      })
    end)
  end

  @doc """
  Extracts participant addresses from a message (from + to).
  """
  def addresses_from_message(%{from_address: from, to_address: to}) do
    [from, to] |> Enum.uniq() |> Enum.sort()
  end

  defp validate_participant_address(changeset) do
    case get_change(changeset, :participant_address) do
      nil ->
        changeset

      address when is_binary(address) and byte_size(address) > 0 ->
        if valid_address?(address) do
          changeset
        else
          add_error(changeset, :participant_address, "must be a valid phone number or email")
        end

      _ ->
        add_error(changeset, :participant_address, "must be a non-empty string")
    end
  end

  defp valid_address?(address) do
    # Basic validation - phone number starts with + or email contains @
    String.starts_with?(address, "+") or String.contains?(address, "@")
  end
end
