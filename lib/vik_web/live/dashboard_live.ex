defmodule VikWeb.DashboardLive do
  @moduledoc false
  use VikWeb, :live_view

  alias Vik.Repo
  alias Vik.Store
  alias Vik.Shard
  alias Vik.PubSub

  @memory_usage_sections [
    {:atom, "Atoms", "#22C55ED9"},
    {:binary, "Binary", "#3B82F6D9"},
    {:code, "Code", "#A855F7D9"},
    {:ets, "ETS", "#EAB308D9"},
    {:process, "Processes", "#F97316D9"},
    {:other, "Other", "#374151D9"}
  ]

  import Ecto.Query

  on_mount {VikWeb.SystemHandler, :realtime}

  @impl true
  def mount(_params, _session, socket) do
    PubSub.subscribe("vik:dashboard")
    {:ok, assign(socket, shards: load_shards())}
  end

  @impl true
  def handle_info({:status, _}, socket) do
    {:noreply, assign(socket, shards: load_shards())}
  end

  @impl true
  def handle_info({:new, _}, socket) do
    {:noreply, assign(socket, shards: load_shards())}
  end

  @impl true
  def handle_info(_, socket) do
    {:noreply, socket}
  end

  defp load_shards do
    Shard
    |> order_by([s], desc: s.updated_at)
    |> Repo.all()
    |> subscribe_shards()
    |> group_shards()
  end

  defp subscribe_shards(shards) do
    for %Shard{} = shard <- shards do
      PubSub.subscribe(shard.slug)
      {shard, Store.status(shard)}
    end
  end

  # Excuse me for the mess below. Claude wrote it and I honestly cannot
  # be bothered to clean this blood bath up. Viewer discretion advised.

  defp group_shards(shards) do
    {flat, grouped} = Enum.split_with(shards, fn {shard, _} ->
      not String.contains?(shard.slug, "/")
    end)

    groups = Enum.group_by(grouped, fn {shard, _} ->
      shard.slug |> String.split("/", parts: 2) |> hd()
    end)

    {remaining_flat, enhance_pls} = Enum.split_with(flat, fn {shard, _} ->
      shard.slug not in Map.keys(groups)
    end)

    enhanced = Enum.group_by(enhance_pls, fn {s, _} -> s.slug end)

    groups
    |> Map.merge(enhanced, fn _, grouped, extra -> extra ++ grouped end)
    |> Map.new(fn {group, items} -> {{:group, group}, items} end)
    |> Map.put(:flat, remaining_flat)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <main class="wide">
      <.system_info
        versions={@versions}
        usage={@usage}
        info={@info}
        debug={assigns[:debug]}
      />
      
      <div id="dashboard">
        <.shards_listing shards={@shards} />
        <.system_limits usage={@usage} limits={@limits} />
        <.memory_usage usage={@usage} />
      </div>
    </main>
    """
  end

  attr :versions, :map, required: true
  attr :usage, :map, required: true  
  attr :info, :map, required: true
  attr :debug, :boolean, default: false

  defp system_info(assigns) do
    ~H"""
    <section>
      <h2 hidden>System information</h2>
      <div class="stats">
        <.card title="Erlang" value={@versions.erlang} class="erl" />
        <.card title="Elixir" value={@versions.elixir} class="ex" />
        <.card title="Phoenix" value={@versions.phoenix} class="phx" />
        <.card title="Uptime" value={format_uptime(@usage.uptime)} />
        <.card title="Network in" value={@usage.io |> elem(0) |> format_bytes()} />
        <.card title="Network out" value={@usage.io |> elem(1) |> format_bytes()} />
        <.card title="Memory" value={format_bytes(@usage.memory.total)} />
      </div>

      <p :if={@debug} class="flex justify-between">
        <code>{extract_flags(@info.banner)}</code>
        <code>[{@info.architecture}]</code>
      </p>
    </section>
    """
  end

  attr :shards, :map, required: true

  defp shards_listing(assigns) do
    ~H"""
    <section class="row-span-2">
      <header class="bar">
        <h2>Shards</h2>
        <.link class="button" navigate={~p"/new"}>New shard</.link>
      </header>
      <ul>
        <li :for={{shard, status} <- Map.get(@shards, :flat, [])}>
          <.link navigate={~p"/#{shard.slug}"}>
            {shard.title} <small>({shard.slug})</small>
            <span class="dot" style={"color: #{dot_color(status)}"}></span>
            <time datetime={shard.updated_at}>{Vik.Dates.humanize(shard.updated_at)}</time>
          </.link>
        </li>
      </ul>
      <div :for={{{:group, group}, group_shards} <- assigns.shards}>
        <h3>
          <%= case List.first(group_shards) do
            {%{slug: ^group}, _} -> List.first(group_shards) |> elem(0) |> Map.get(:title)
            _ -> String.capitalize(group)
          end %> <small>({length(group_shards)})</small>
        </h3>
        <ul>
          <li :for={{shard, status} <- group_shards}>
            <.link navigate={~p"/#{shard.slug}"}>
              {shard.title} <small>({shard.slug})</small>
              <span class="dot" style={"color: #{dot_color(status)}"}></span>
              <time datetime={shard.updated_at}>{Vik.Dates.humanize(shard.updated_at)}</time>
            </.link>
          </li>
        </ul>
      </div>
    </section>
    """
  end

  attr :usage, :map, required: true
  attr :limits, :map, required: true

  defp system_limits(assigns) do
    ~H"""
    <section>
      <h2>System limits</h2>
      <.limit_usage
        :for={type <- [:atoms, :ports, :processes]}
        title={Phoenix.Naming.humanize(type)}
        current={@usage[type]}
        limit={@limits[type]}
      />
    </section>
    """
  end

  attr :usage, :map, required: true

  defp memory_usage(assigns) do
    ~H"""
    <section>
      <h2>Memory</h2>
      <div class="line-chart">
        <div
          :for={{name, value, color} <- calculate_memory_usage(@usage.memory)}
          class="segment"
          style={"color: #{color}; width: #{value / @usage.memory.total * 100}%"}
          title={"#{name}: #{format_bytes(value)}"}
        ></div>
      </div>

      <div class="legend">
        <p
          :for={{name, value, color} <- calculate_memory_usage(@usage.memory)}
          class="split"
        >
          <span>
            <span class="square" style={"color: #{color}"}></span>
            {name}
          </span>
          <span>{format_bytes(value)}</span>
        </p>
      </div>
    </section>
    """
  end

  attr :title, :string, required: true
  attr :value, :string, required: true
  attr :rest, :global

  defp card(assigns) do
    ~H"""
    <hgroup class={["stat", @rest[:class]]} {@rest}>
      <h3>{@title}</h3>
      <p>{@value}</p>
    </hgroup>
    """
  end

  attr :title, :integer, required: true
  attr :current, :integer, required: true
  attr :limit, :integer, required: true

  defp limit_usage(assigns) do
    ~H"""
    <p class="split">
      <span><b>{@title}</b> <small>({@current} / {@limit})</small></span>
      <span>{format_percentage(@current, @limit)}%</span>
    </p>
    <progress max={@limit} value={@current}>
      {format_percentage(@current, @limit)}%
    </progress>
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
      d > 0 -> "#{d}d#{h}h#{m}min"
      h > 0 -> "#{h}h#{m}min"
      true -> "#{m}min"
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
    "#{:erlang.float_to_binary(value, decimals: 1)}#{unit}"
  end

  defp memory_unit(:TB), do: 1024 * 1024 * 1024 * 1024
  defp memory_unit(:GB), do: 1024 * 1024 * 1024
  defp memory_unit(:MB), do: 1024 * 1024
  defp memory_unit(:KB), do: 1024

  def dot_color(:stale), do: "#fbbf24"
  def dot_color(:up), do: "#4ade80"
  def dot_color(:down), do: "#f87171"
end
