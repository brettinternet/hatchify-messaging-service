defmodule Messaging.MixProject do
  use Mix.Project

  @spec project() :: keyword()
  def project do
    [
      app: :messaging,
      version: "0.0.1",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      aliases: aliases(),
      deps: deps(),
      test_paths: ["lib"],
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.json": :test,
        "coveralls.html": :test
      ]
    ]
  end

  @spec application() :: keyword()
  def application do
    [
      extra_applications: [:logger],
      mod: {Messaging.Application, []}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_env), do: ["lib"]

  defp deps do
    [
      {:bandit, "~> 1.0"},
      {:benchee, "~> 1.0", only: [:dev]},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:dotenv_parser, "~> 2.0", only: [:dev, :test]},
      {:ecto_sql, "~> 3.0"},
      {:ecto, "~> 3.10"},
      {:ex_hash_ring, "~> 6.0"},
      {:ex_machina, "~> 2.7", only: :test},
      {:excoveralls, "~> 0.10", only: :test},
      {:hackney, "~> 1.17"},
      {:hammer, "~> 7.0"},
      {:jason, "~> 1.2"},
      {:libcluster, "~> 3.0"},
      {:logger_json, "~> 6.0"},
      {:mimic, "~> 1.10", only: :test},
      {:mix_audit, "~> 2.0", only: [:dev, :test], runtime: false},
      {:plug_cowboy, "~> 2.7"},
      {:postgrex, ">= 0.0.0"},
      {:sobelow, "~> 0.13", only: [:dev, :test], runtime: false},
      {:styler, "~> 1.3", only: [:dev, :test], runtime: false},
      {:tesla, "~> 1.4"},
      {:uxid, "~> 0.2"}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "ecto.setup"],
      start: ["run --no-halt"],
      "ecto.setup": ["ecto.create --quiet", "ecto.migrate"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"]
    ]
  end
end
