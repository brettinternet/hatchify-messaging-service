defmodule Messaging.Repo.Migrations.AddStatusToMessage do
  @moduledoc false
  use Ecto.Migration

  def change do
    alter table(:message) do
      add :status, :string, default: "pending", null: false
    end
  end
end
