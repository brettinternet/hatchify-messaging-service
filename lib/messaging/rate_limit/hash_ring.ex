defmodule Messaging.RateLimit.HashRing do
  @moduledoc false
  use GenServer

  alias Messaging.RateLimit.DistributionRing

  require Logger

  @spec start_link(term()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl GenServer
  def init(_opts) do
    :net_kernel.monitor_nodes(true)

    for node <- [Node.self() | Node.list()] do
      ExHashRing.Ring.add_node(DistributionRing, node)
    end

    {:ok, []}
  end

  @impl GenServer
  def handle_info({:nodeup, node}, state) do
    Logger.info("Node #{node} connected")
    ExHashRing.Ring.add_node(DistributionRing, node)
    {:noreply, state}
  end

  def handle_info({:nodedown, node}, state) do
    Logger.info("Node #{node} disconnected")
    ExHashRing.Ring.remove_node(DistributionRing, node)
    {:noreply, state}
  end
end
