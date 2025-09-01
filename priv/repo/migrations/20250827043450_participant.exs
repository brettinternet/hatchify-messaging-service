defmodule Messaging.Repo.Migrations.Participant do
  @moduledoc false
  use Ecto.Migration

  def change do
    create table(:participant, primary_key: false) do
      add :conversation_id, references(:conversation, type: :text), null: false
      add :address, :text, null: false

      timestamps(updated_at: false)
    end

    create index(:participant, [:conversation_id])
    create index(:participant, [:address])
    create unique_index(:participant, [:conversation_id, :address])
  end
end
