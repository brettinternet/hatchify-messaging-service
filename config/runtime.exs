import Config

if Config.config_env() != :prod and File.exists?(".env") do
  DotenvParser.load_file(".env")
end

build_version = System.get_env("BUILD_VERSION", "dev")
environment = System.get_env("ENVIRONMENT", "development")

defmodule Secret do
  @moduledoc """
  Read secrets from the environment in test and dev.
  In production, read from secret files mounted in the container and fallback to environment variables.
  """
  @path if config_env() == :prod, do: "/etc/secrets/", else: "docker/messaging/secrets/"

  def read(name, default_value \\ nil) do
    case config_env() do
      :prod ->
        case File.read(@path <> name) do
          {:ok, value} -> value
          _error -> System.get_env(name, default_value)
        end

      _env ->
        System.get_env(name, default_value)
    end
  end
end

if config_env() != :test do
  config :logger, level: "LOG_LEVEL" |> System.get_env("info") |> String.to_existing_atom()

  config :messaging,
    rate_limit_message_disabled: System.get_env("RATE_LIMIT_MESSAGE_DISABLED", "false") == "true"
end

config :messaging, Messaging.Repo,
  username: Secret.read("POSTGRES_USER", "postgres"),
  password: Secret.read("POSTGRES_PASSWORD", "postgres"),
  hostname: Secret.read("POSTGRES_HOST", "localhost"),
  port: "POSTGRES_PORT" |> System.get_env("5432") |> String.to_integer(),
  database: System.get_env("POSTGRES_DB", "messaging")

config :messaging,
  environment: environment,
  rate_limit_connection_tokens: String.to_integer(System.get_env("RATE_LIMIT_CONNECTION_TOKENS", "6")),
  rate_limit_connection_interval_seconds:
    String.to_integer(System.get_env("RATE_LIMIT_CONNECTION_INTERVAL_SECONDS", "120")),
  rate_limit_message_tokens: String.to_integer(System.get_env("RATE_LIMIT_MESSAGE_TOKENS", "5000")),
  rate_limit_message_interval_seconds: String.to_integer(System.get_env("RATE_LIMIT_MESSAGE_INTERVAL_SECONDS", "60"))

if config_env() == :prod do
  ssl? = System.get_env("POSTGRES_SSL", "false") == "true"

  config :messaging, Messaging.Repo,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    ssl: ssl?,
    ssl_opts:
      (ssl? &&
         [
           cacertfile: "/etc/secrets/ca.cert",
           keyfile: "/etc/secrets/client.key",
           certfile: "/etc/secrets/client.cert",
           verify: :verify_none
         ]) || []

  # server port also explicitly defined in dev.exs & test.exs
  config :messaging,
    server_port: "SERVER_PORT" |> System.get_env("8080") |> String.to_integer()
end
