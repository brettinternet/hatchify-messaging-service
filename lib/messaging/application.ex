defmodule Messaging.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    topologies = Application.get_env(:libcluster, :topologies, [])

    children = [
      {Cluster.Supervisor, [topologies, [name: Messaging.ClusterSupervisor]]},
      Messaging.RateLimit.Supervisor,
      Messaging.Repo,
      {Bandit, plug: MessagingWeb.Router, scheme: :http, port: Messaging.server_port()},
      {Task.Supervisor, name: Messaging.TaskSupervisor},
      {Messaging.OutboxProcessor, Messaging.config_env() != :test}
    ]

    opts = [strategy: :one_for_one, name: Messaging.Supervisor]

    children
    # Conditional children
    |> Enum.map(fn
      {child, true} -> child
      {_child, false} -> nil
      child -> child
    end)
    |> Enum.reject(&is_nil/1)
    |> Supervisor.start_link(opts)
  end
end
