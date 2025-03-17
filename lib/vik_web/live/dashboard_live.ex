defmodule VikWeb.DashboardLive do
  @moduledoc false
  use VikWeb, :live_view

  alias Vik.Repo
  alias Vik.Store
  alias Vik.Shard
  alias Vik.PubSub

  @memory_usage_sections [
    {:atom, "Atoms", "bg-green-500/85"},
    {:binary, "Binary", "bg-blue-500/85"},
    {:code, "Code", "bg-purple-500/85"},
    {:ets, "ETS", "bg-yellow-500/85"},
    {:process, "Processes", "bg-orange-500/85"},
    {:other, "Other", "bg-gray-700/85"}
  ]

  import VikWeb, only: [dot_color: 1]
  import Ecto.Query

  on_mount {VikWeb.SystemHandler, :realtime}

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
    query = from s in Shard, order_by: [desc: s.updated_at], limit: 7

    for %Shard{} = shard <- Repo.all(query), into: %{} do
      PubSub.subscribe(shard.slug)
      {shard.slug, {shard, Store.status(shard)}}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="px-4 py-2 space-y-10">
      <section>
        <h2 class="sr-only">System information</h2>
        <div class="grid sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-5 xl:grid-cols-6 2xl:grid-cols-7 gap-3 mb-4">
          <.card
            title="Erlang"
            value={@versions.erlang}
            class="bg-red-600/5 text-red-600"
          />
          <.card
            title="Elixir"
            value={@versions.elixir}
            class="bg-purple-600/5 text-purple-600"
          />
          <.card
            title="Phoenix"
            value={@versions.phoenix}
            class="bg-brand/5 text-brand"
          />
          <.card
            title="Uptime"
            value={format_uptime(@usage.uptime)}
          />
          <.card
            title="Network in"
            value={@usage.io |> elem(0) |> format_bytes()}
          />
          <.card
            title="Network out"
            value={@usage.io |> elem(1) |> format_bytes()}
          />
          <.card
            title="Memory"
            value={format_bytes(@usage.memory.total)}
          />
        </div>

        <p :if={assigns[:debug]} class="flex justify-between">
          <code>{extract_flags(@info.banner)}</code>
          <code>[{@info.architecture}]</code>
        </p>
      </section>

      <div class="grid gap-4 grid-cols-1 lg:grid-cols-2">
        <section class="row-span-2">
          <h2 class="font-bold text-2xl mb-6">Shards</h2>
          <table class="-ml-4 w-full text-left whitespace-nowrap">
            <colgroup>
              <col class="w-full lg:w-4/8">
              <col class="lg:w-1/8">
              <col class="lg:w-3/8">
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
        </section>
        <section>
          <h2 class="font-bold text-2xl mb-6">System limits</h2>

          <div class="mb-8">
            <.usage
              :for={type <- [:atoms, :ports, :processes]}
              title={Phoenix.Naming.humanize(type)}
              current={@usage[type]}
              limit={@limits[type]}
            />
          </div>
        </section>
        <section>
          <h2 class="font-bold text-2xl mb-6">Memory</h2>

          <div class="space-y-5">
            <div class="w-full h-6 flex rounded overflow-hidden">
              <div
                :for={{name, value, color} <- calculate_memory_usage(@usage.memory)}
                class={["h-full", color]}
                style={"width: #{value / @usage.memory.total * 100}%"}
                title={"#{name}: #{format_bytes(value)}"}
              ></div>
            </div>

            <div class="grid grid-cols-2 grid-rows-3 grid-flow-col gap-x-4">
              <p
                :for={{name, value, color} <- calculate_memory_usage(@usage.memory)}
                class="flex items-center gap-2 justify-between"
              >
                <span class="flex items-center gap-2">
                  <span class={["size-4 block rounded", color]}></span>
                  <span>{name}</span>
                </span>

                <span class="text-xs text-zinc-400">{format_bytes(value)}</span>
              </p>
            </div>
          </div>
        </section>
      </div>
    </div>
    """
  end

  attr :title, :string, required: true
  attr :value, :string, required: true

  attr :rest, :global

  defp card(assigns) do
    ~H"""
    <div class={["shadow p-4 rounded-md flex flex-col justify-center", @rest[:class]]} {@rest}>
      <h3 class="text-lg">{@title}</h3>
      <p class="font-bold text-4xl mb-6">{@value}</p>
    </div>
    """
  end

  attr :title, :integer, required: true
  attr :current, :integer, required: true
  attr :limit, :integer, required: true
  attr :percent, :float, required: true

  defp usage(assigns) do
    ~H"""
    <div class="mb-1 flex gap-2 items-center justify-between">
      <span class="flex gap-2 items-center">
        <h4 class="font-semibold text-md">{@title}</h4>
        <span class="text-xs text-zinc-400">({@current} / {@limit})</span>
      </span>

      <span class="font-bold text-md">{format_percentage(@current, @limit)}%</span>
    </div>
    <div class="flex gap-2 items-center mb-3">
      <progress class="flex-grow" max={@limit} value={@current}>
        {format_percentage(@current, @limit)}%
      </progress>
    </div>
    """
  end

  defp calculate_memory_usage(memory_usage) do
    for {key, name, color} <- @memory_usage_sections,
        value = memory_usage[key] do
      {name, value, color}
    end
  end

  defp format_percentage(value, total) do
    Float.round(value / total * 100, 1)
  end

  def extract_flags(banner) do
    ["Erlang/OTP", _version, flags] = 
      banner |> to_string() |> String.split(" ", parts: 3)

    flags
  end

  def format_uptime(uptime) do
    {d, {h, m, _s}} = :calendar.seconds_to_daystime(div(uptime, 1000))

    cond do
      d > 0 -> "#{d}d#{h}h#{m}m"
      h > 0 -> "#{h}h#{m}m"
      true -> "#{m}m"
    end
  end

  def format_bytes(bytes) when is_integer(bytes) do
    cond do
      bytes >= memory_unit(:TB) -> format_bytes(bytes, :TB)
      bytes >= memory_unit(:GB) -> format_bytes(bytes, :GB)
      bytes >= memory_unit(:MB) -> format_bytes(bytes, :MB)
      bytes >= memory_unit(:KB) -> format_bytes(bytes, :KB)
      true -> format_bytes(bytes, :B)
    end
  end

  defp format_bytes(bytes, :B) when is_integer(bytes), do: "#{bytes} B"

  defp format_bytes(bytes, unit) when is_integer(bytes) do
    value = bytes / memory_unit(unit)
    "#{:erlang.float_to_binary(value, decimals: 1)} #{unit}"
  end

  defp memory_unit(:TB), do: 1024 * 1024 * 1024 * 1024
  defp memory_unit(:GB), do: 1024 * 1024 * 1024
  defp memory_unit(:MB), do: 1024 * 1024
  defp memory_unit(:KB), do: 1024
end
