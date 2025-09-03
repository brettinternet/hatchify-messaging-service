defmodule Messaging.RateLimit do
  @moduledoc """
  Provides rate limiting functionality for the messaging application.
  """

  alias Messaging.RateLimit.DistributionRing
  alias Messaging.RateLimit.Local

  require Logger

  @type return_t() :: :ok | {:error, :rate_limit_exceeded}

  @spec message(String.t() | nil) :: return_t()
  def message(nil), do: {:error, :rate_limit_exceeded}

  def message(client_id) do
    {tokens, interval} = Messaging.rate_limit_message()
    check(client_id, tokens, interval)
  end

  @spec check(String.t(), non_neg_integer(), non_neg_integer()) :: return_t()
  defp check(_key, 0, 0), do: :ok

  defp check(key, limit, interval) do
    scale = to_timeout(minute: interval)

    {:ok, node} = ExHashRing.Ring.find_node(DistributionRing, key)

    {Messaging.RateLimit.RateLimiter, node}
    |> GenServer.call({:check, key, scale, limit})
    |> normalize_hammer_response()
  catch
    :exit, reason ->
      # coveralls-ignore-start not easy to test
      Logger.warning("Tried to check rate limit but failed: #{inspect(reason)}")

      # As a fallback, do a local check. It's better than nothing!
      check_local(key, limit, interval)
      # coveralls-ignore-stop
  end

  @spec check_local(String.t(), non_neg_integer(), non_neg_integer()) :: return_t()
  defp check_local(_key, 0, 0), do: :ok

  defp check_local(key, limit, interval) do
    scale = to_timeout(minute: interval)

    key
    |> Local.hit(scale, limit)
    |> normalize_hammer_response()
  end

  @spec normalize_hammer_response({:allow, non_neg_integer()} | {:deny, non_neg_integer()}) :: return_t()
  defp normalize_hammer_response({:allow, _count}), do: :ok
  defp normalize_hammer_response({:deny, _limit}), do: {:error, :rate_limit_exceeded}
end
