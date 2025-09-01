defmodule Messaging.Conversations.Conversation do
  @moduledoc """
  Schema for conversations that group related messages.
  """

  use Messaging.Schema, prefix: "conv"

  import Ecto.Changeset

  alias Ecto.Association.NotLoaded
  alias Messaging.Conversations.Message
  alias Messaging.Conversations.Participant

  @type t :: %__MODULE__{
          id: binary() | nil,
          messages: [Message.t()] | NotLoaded.t(),
          participants: [Participant.t()] | NotLoaded.t(),
          inserted_at: NaiveDateTime.t() | nil,
          updated_at: NaiveDateTime.t() | nil
        }

  schema "conversation" do
    has_many :messages, Message
    has_many :participants, Participant

    timestamps()
  end

  @doc false
  def changeset(%__MODULE__{} = conversation, attrs) do
    cast(conversation, attrs, [])
  end
end
