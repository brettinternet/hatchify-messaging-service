defmodule Messaging.Release do
  @moduledoc """
  Utilities for executing database tasks in production when Mix is unavailable.
  """
  @app :messaging

  @spec migrate() :: [term()]
  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _migrations, _status} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  @spec rollback(module(), integer()) :: {:ok, term(), term()}
  def rollback(repo, version) do
    load_app()
    {:ok, _migrations, _status} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    Application.load(@app)
  end
end
