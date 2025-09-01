defmodule Messaging.Conversations.Participant do
  @moduledoc """
  Schema for conversation participants.
  Links conversations to participant addresses (phone numbers or emails).
  """

  use Messaging.Schema, prefix: "part"

  import Ecto.Changeset

  alias Messaging.Conversations.Conversation
  alias Messaging.Conversations.Message

  @type t :: %__MODULE__{
          conversation_id: String.t(),
          address: String.t(),
          conversation: Conversation.t() | Ecto.Association.NotLoaded.t(),
          inserted_at: NaiveDateTime.t()
        }

  @primary_key false

  schema "participant" do
    field :address, :string

    belongs_to :conversation, Conversation, references: :id

    timestamps(updated_at: false)
  end

  @doc false
  def changeset(participant, attrs) do
    participant
    |> cast(attrs, [:conversation_id, :address])
    |> validate_required([:conversation_id, :address])
    |> validate_address()
    |> unique_constraint([:conversation_id, :address])
  end

  @doc """
  Creates participants for a conversation from a list of addresses.
  """
  def create_for_conversation(conversation_id, addresses) when is_list(addresses) do
    Enum.map(addresses, fn address ->
      changeset(%__MODULE__{}, %{
        conversation_id: conversation_id,
        address: address
      })
    end)
  end

  @doc """
  Extracts participant addresses from a message (from + to).
  """
  @spec addresses_from_message(Message.t()) :: [String.t()]
  def addresses_from_message(%{from_address: from, to_address: to}) do
    [from, to] |> Enum.uniq() |> Enum.sort()
  end

  defp validate_address(changeset) do
    case get_change(changeset, :address) do
      nil ->
        changeset

      address when is_binary(address) and byte_size(address) > 0 ->
        if valid_address?(address) do
          changeset
        else
          add_error(changeset, :address, "must be a valid phone number or email")
        end

      _ ->
        add_error(changeset, :address, "must be a non-empty string")
    end
  end

  defp valid_address?(address) do
    # Basic validation - phone number starts with + or email contains @
    String.starts_with?(address, "+") or String.contains?(address, "@")
  end
end
