import Config

config :libcluster,
  debug: false,
  topologies: [
    gossip: [
      strategy: Cluster.Strategy.Gossip
    ]
  ]

config :messaging, Messaging.Repo,
  database: "messaging",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

config :messaging, :server_port, 3085
