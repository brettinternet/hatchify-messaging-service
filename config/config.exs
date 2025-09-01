import Config

alias Tesla.Adapter.Finch

config :hammer,
  backend: {Hammer.Backend.ETS, [expiry_ms: to_timeout(second: 240), cleanup_interval_ms: to_timeout(second: 120)]}

config :libcluster,
  topologies: [
    messaging: [
      strategy: Cluster.Strategy.Gossip
    ]
  ]

config :messaging, Messaging.Repo,
  migration_primary_key: [type: :text],
  migration_timestamps: [type: :utc_datetime_usec],
  queue_target: 500,
  queue_interval: 2000

config :messaging, :config_env, config_env()
config :messaging, :port, 4003

config :messaging,
  ecto_repos: [Messaging.Repo],
  generators: [timestamp_type: :utc_datetime, binary_id: true]

config :tesla, :adapter, {Finch, name: Messaging.Finch}

import_config "#{config_env()}.exs"
