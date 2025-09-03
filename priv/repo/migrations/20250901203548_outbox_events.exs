defmodule Messaging.Repo.Migrations.OutboxEvents do
  @moduledoc false
  use Ecto.Migration

  def change do
    create table(:outbox_event, primary_key: false) do
      add :id, :text, primary_key: true
      add :event_type, :string, null: false
      add :message_id, references(:message, type: :text), null: false
      add :processed_at, :utc_datetime_usec
      add :retry_count, :integer, null: false, default: 0
      add :max_retries, :integer, null: false, default: 3
      add :scheduled_for, :utc_datetime_usec, null: false, default: fragment("NOW()")
      add :error_message, :text

      timestamps()
    end

    # Index to find unprocessed events
    create index(:outbox_event, [:processed_at, :scheduled_for], where: "processed_at IS NULL")
    # Composite index for the main query pattern
    create index(:outbox_event, [:scheduled_for, :retry_count, :max_retries], where: "processed_at IS NULL")
  end
end
