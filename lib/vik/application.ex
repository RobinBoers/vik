defmodule Vik.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      VikWeb.Telemetry,
      Vik.Repo,
      Vik.Store,
      {DNSCluster, query: Application.get_env(:vik, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Vik.PubSub},
      VikWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: Vik.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    VikWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
