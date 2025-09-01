defmodule Messaging.RateLimit.Supervisor do
  @moduledoc false
  @spec child_spec(term()) :: Supervisor.child_spec()
  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :supervisor
    }
  end

  @spec start_link(term()) :: Supervisor.on_start()
  def start_link(_opts) do
    children = [
      Messaging.RateLimit.Local,
      {ExHashRing.Ring, name: Messaging.RateLimit.DistributionRing},
      Messaging.RateLimit.RateLimiter,
      Messaging.RateLimit.HashRing
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
