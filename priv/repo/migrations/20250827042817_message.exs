defmodule Messaging.Repo.Migrations.Message do
  @moduledoc false
  use Ecto.Migration

  def change do
    create table(:message, primary_key: false) do
      add :id, :text, primary_key: true
      add :conversation_id, :text, null: false
      add :from_address, :text, null: false
      add :to_address, :text, null: false
      add :message_type, :text, null: false
      add :body, :text, null: false
      # map instead of array for flexibility
      add :attachments, {:array, :text}
      add :provider_id, :text
      add :direction, :text, null: false
      add :timestamp, :utc_datetime, null: false

      timestamps(updated_at: false)
    end

    create index(:message, [:conversation_id])
    create index(:message, [:from_address])
    create index(:message, [:to_address])
    create index(:message, [:timestamp])
    create index(:message, [:provider_id])
    create unique_index(:message, [:provider_id, :message_type], where: "provider_id IS NOT NULL")

    # create constraint(:message, :valid_message_type, check: "message_type IN ('sms', 'mms', 'email')")
    # create constraint(:message, :valid_direction, check: "direction IN ('inbound', 'outbound')")
  end
end
