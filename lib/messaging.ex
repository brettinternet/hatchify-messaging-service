defmodule Messaging do
  @moduledoc false

  @spec environment() :: String.t()
  def environment do
    Application.fetch_env!(:messaging, :environment)
  end

  @spec server_port() :: integer()
  def server_port do
    Application.get_env(:messaging, :server_port, 3085)
  end

  @spec config_env() :: atom()
  def config_env do
    Application.fetch_env!(:messaging, :config_env)
  end

  @spec rate_limit_message() :: {integer(), integer()}
  def rate_limit_message do
    if Application.get_env(:messaging, :rate_limit_message_disabled, false) do
      {0, 0}
    else
      tokens = Application.get_env(:messaging, :rate_limit_message_tokens, 5000)
      interval_secs = Application.get_env(:messaging, :rate_limit_message_interval_seconds, 120)
      {tokens, interval_secs}
    end
  end
end
