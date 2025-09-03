defmodule Messaging.Repo.Migrations.Conversation do
  @moduledoc false
  use Ecto.Migration

  def change do
    create table(:conversation, primary_key: false) do
      add :id, :text, primary_key: true

      timestamps()
    end

    create index(:conversation, [:inserted_at])
  end
end
