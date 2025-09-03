defmodule Messaging.Conversations.OutboxEvent do
  @moduledoc """
  Schema for outbox events.
  """

  use Messaging.Schema, prefix: "outev"

  import Ecto.Changeset

  alias Messaging.Conversations.Message

  @type t :: %__MODULE__{
          id: String.t(),
          event_type: String.t(),
          message_id: String.t(),
          processed_at: DateTime.t() | nil,
          retry_count: integer(),
          max_retries: integer(),
          scheduled_for: DateTime.t(),
          error_message: String.t() | nil,
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  schema "outbox_event" do
    field :event_type, :string
    field :processed_at, :utc_datetime_usec
    field :retry_count, :integer, default: 0
    field :max_retries, :integer, default: 3
    field :scheduled_for, :utc_datetime_usec, default: DateTime.utc_now()
    field :error_message, :string

    belongs_to :message, Message, references: :id

    timestamps()
  end

  @doc false
  def changeset(event, attrs) do
    event
    |> cast(attrs, [
      :event_type,
      :message_id,
      :processed_at,
      :retry_count,
      :max_retries,
      :scheduled_for,
      :error_message
    ])
    |> validate_required([:event_type, :message_id])
  end
end
