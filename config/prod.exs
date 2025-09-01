import Config

config :libcluster,
  debug: true,
  topologies: [
    docker: [
      strategy: Cluster.Strategy.Gossip
    ]
  ]

config :logger,
  level: :debug,
  default_handler: [formatter: {LoggerJSON.Formatters.Basic, []}]

config :messaging, :server_port, 3085
