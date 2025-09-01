defmodule Messaging.DataCase do
  @moduledoc """
  This module defines the setup for tests requiring
  access to the application's data layer.

  You may define functions here to be used as helpers in
  your tests.
  """

  use ExUnit.CaseTemplate

  alias Ecto.Adapters.SQL.Sandbox

  using do
    quote do
      use Mimic
      use Messaging.Factory

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import Messaging.DataCase

      alias Messaging.Repo

      setup :verify_on_exit!
    end
  end

  setup tags do
    Messaging.DataCase.setup_sandbox(tags)
    :ok
  end

  @doc """
  Sets up the sandbox based on the test tags.
  """
  @spec setup_sandbox(map()) :: :ok
  def setup_sandbox(tags) do
    pid = Sandbox.start_owner!(Messaging.Repo, shared: not tags[:async])
    on_exit(fn -> Sandbox.stop_owner(pid) end)
  end
end
