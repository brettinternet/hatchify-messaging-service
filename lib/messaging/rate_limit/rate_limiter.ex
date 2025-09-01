defmodule Messaging.RateLimit.RateLimiter do
  @moduledoc false
  use GenServer

  alias Messaging.RateLimit.Local

  require Logger

  @spec start_link(term()) :: GenServer.on_start()
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @spec init(term()) :: {:ok, []}
  def init(_opts) do
    {:ok, []}
  end

  @spec handle_call({:check, String.t(), pos_integer(), pos_integer()}, GenServer.from(), []) ::
          {:reply, {:allow, pos_integer()} | {:deny, timeout()}, []}
  def handle_call({:check, key, scale, limit}, _from, state) do
    {:reply, Local.hit(key, scale, limit), state}
  end
end
