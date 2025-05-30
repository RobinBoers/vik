defmodule Vik.Application do
  @moduledoc false
  use Application

  # TODO(robin): attempt to deploy all Shards on startup :)

  @impl true
  def start(_type, _args) do
    children = [
      {KV, kv_opts()},
      VikWeb.Telemetry,
      Vik.Repo,
      Vik.Store,
      Vik.PubSub,
      Vik.Logger,
      Vik.Thread,
      Vik.Presence,
      Vik.Authority,
      VikWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: Vik.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp kv_opts do
    [root: System.get_env("KV_ROOT")]
  end

  @impl true
  def config_change(changed, _new, removed) do
    VikWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
