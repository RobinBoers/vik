defmodule VikWeb.DashboardLive do
  @moduledoc false
  use VikWeb, :live_view

  alias Vik.Repo
  alias Vik.Store
  alias Vik.Shard
  alias Vik.PubSub

  import Ecto.Query

  @impl true
  def mount(_params, _session, socket) do
    PubSub.subscribe("vik:dashboard")
    {:ok, assign(socket, :shards, load_shards())}
  end

  @impl true
  def handle_info({:status, _}, socket) do
    {:noreply, assign(socket, :shards, load_shards())}
  end

  @impl true
  def handle_info({:new, _}, socket) do
    {:noreply, assign(socket, :shards, load_shards())}
  end

  defp load_shards do
    query = from s in Shard, order_by: [desc: s.updated_at]

    for %Shard{} = shard <- Repo.all(query), into: %{} do
      PubSub.subscribe(shard.slug)
      {shard.slug, {shard, Store.status(shard)}}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="px-4 py-8">
      <h2 class="font-bold text-2xl mb-1">Shards</h2>
      <table class="mt-6 w-full text-left whitespace-nowrap">
        <colgroup>
          <col class="w-full sm:w-4/12">
          <col class="lg:w-1/12">
          <col class="lg:w-1/12">
        </colgroup>
        <thead class="border-b border-zinc-900/10 text-sm/6">
          <tr>
            <th scope="col" class="py-2 pr-8 font-semibold pl-4">Title</th>
            <th scope="col" class="py-2 pr-4 pl-0 text-right font-semibold sm:pr-8 lg:pr-20">Status</th>
            <th scope="col" class="hidden py-2 pl-0 text-right font-semibold sm:table-cell pr-4">Deployed at</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-zinc-900/5">
          <tr
            :for={{shard, status} <- Map.values(@shards)}
            phx-click={JS.navigate(~p"/#{shard.slug}")}
            class="hover:bg-zinc-50 cursor-pointer"
          >
            <td class="py-4 pr-8">
              <h2 class="px-4">{shard.title} <span class="text-xs font-mono text-zinc-400 pl-1">({shard.slug})</span></h2>
            </td>
            <td class="py-4 pr-4 pl-0 text-sm/6 sm:pr-8 lg:pr-20">
              <div class="flex items-center justify-end gap-x-2">
                <div class={"flex-none rounded-full p-1 #{dot_color(status)}"}>
                  <div class="size-1.5 rounded-full bg-current"></div>
                </div>
              </div>
            </td>
            <td class="hidden py-4 pl-0 text-right text-sm/6 text-gray-400 sm:table-cell">
              <time class="px-4" datetime={shard.updated_at}>{Vik.Dates.humanize(shard.updated_at)}</time>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end

  defp dot_color(:stale), do: "bg-amber-400/10 text-amber-400"
  defp dot_color(:up), do: "bg-green-400/10 text-green-400"
  defp dot_color(:down), do: "bg-red-400/10 text-red-400"
end

