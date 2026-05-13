defmodule Vik.MixProject do
  use Mix.Project

  @documentation "https://hexdocs.pm/vik"
  @git_repository "https://git.dupunkto.org/~axcelott/vik"
  
  def project do
    [
      name: "Vik",
      app: :vik,
      version: "0.0.1-rc2",
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),

      # Docs
      source_url: @git_repository,
      homepage_url: @documentation,
      description: description(),
      package: package(),
      docs: docs()
    ]
  end

  def description do
    "What if GitHub gists, AWS Lambdas and Elixir Plugs had a baby?"
  end

  defp package do
    [
      licenses: ["Unlicense"],
      links: %{"Sources" => @git_repository}
    ]
  end

  def application do
    [
      mod: {Vik.Application, []},
      extra_applications: [:logger, :runtime_tools, :ex_unit]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:phoenix, "~> 1.7.18"},
      {:phoenix_ecto, "~> 4.5"},
      {:ecto_sql, "~> 3.10"},
      {:postgrex, ">= 0.0.0"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 1.0.0"},
      {:floki, ">= 0.30.0", only: :test},
      {:esbuild, "~> 0.8", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.2", runtime: Mix.env() == :dev},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:bandit, "~> 1.5"},
      {:decorator, "~> 1.3"},
      {:typedstruct, "~> 0.5.3"},
      {:structo, "~> 0.2.0"},
      {:req, "~> 0.5.10"},
      {:gen_smtp, "~> 1.2"},
      {:earmark, "~> 1.4"},
      {:nym, "~> 0.0.1-rc2"},

      # For documentation :)
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},

      # Useful in Shards
      {:wallaby, "~> 0.30.0"},
      {:nimble_csv, "~> 1.3"},
      {:nimble_options, "~> 1.1"}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["tailwind vik", "esbuild vik"],
      "assets.deploy": [
        "tailwind vik --minify",
        "esbuild vik --minify",
        "phx.digest"
      ]
    ]
  end

  defp docs do
    [
      main: "Vik",
      api_reference: false,
      authors: ["Robijntje"],
      formatters: ["html"],
      groups_for_modules: [
        "Applications": [KV],
        "Compilation": [Vik.Shard, Vik.Result, Vik.Compiler, Vik.Store, Vik.Thread],
        "Collaborative": [~r/Vik.Authority/, Vik.Presence],
        "Web Layer": [~r/VikWeb/]
      ]
    ]
  end
end
