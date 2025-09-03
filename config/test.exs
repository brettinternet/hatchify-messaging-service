import Config

config :logger, level: "TEST_LOG_LEVEL" |> System.get_env("info") |> String.to_existing_atom()

config :messaging, Messaging.Repo,
  database: "messaging_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 20

config :messaging,
  server_port: 3090,
  hash_secret: "test-hash-secret-not-for-production",
  rate_limit_message_disabled: false
