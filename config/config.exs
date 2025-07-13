import Config

config :vik,
  ecto_repos: [Vik.Repo],
  generators: [timestamp_type: :utc_datetime]

config :vik, VikWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: VikWeb.ErrorHTML, json: VikWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Vik.PubSub,
  live_view: [signing_salt: "81lzfZui"]

config :esbuild,
  version: "0.17.11",
  vik: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

config :tailwind,
  version: "3.4.3",
  vik: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :phoenix, :json_library, Jason

import_config "#{config_env()}.exs"
