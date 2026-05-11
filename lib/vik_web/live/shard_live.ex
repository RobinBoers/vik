defmodule VikWeb.ShardLive do
  @moduledoc false
  use VikWeb, :live_view

  alias Vik.Authority
  alias Vik.Presence
  alias Vik.Repo
  alias Vik.Store
  alias Vik.Shard
  alias Vik.Result
  alias Vik.PubSub
  alias Vik.Thread
  alias Vik.Webhook

  import Ecto.Query
  import Structo

  import VikWeb.CodeMirror, only: [codemirror: 1]
  import VikWeb.LogLive, only: [terminal: 1]

  require Logger

  on_mount VikWeb.Auth
  on_mount {VikWeb.SystemHandler, :static}

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    case Repo.get_by(Shard, slug: slug) do
      %Shard{} = shard -> {:ok, mount_shard(socket, shard)}
      nil -> raise Vik.ShardNotFound, slug
    end
  end

  defp mount_shard(socket, shard) do
    uid = to_uid(socket.assigns.current_user) # or: "#{socket.id}-collab"
    participants = Presence.list_participants(shard.slug)

    if connected?(socket) do
      Authority.join(shard.slug, uid)
      Presence.subscribe(shard.slug)
      PubSub.subscribe(shard.slug)
    end

    socket
    |> assign(:task, nil)
    |> assign(:status, Store.status(shard))
    |> stream(:participants, participants)
    |> assign_compiled(shard)
    |> assign_group(shard)
    |> assign_dependents(shard)
    |> assign_changeset(shard)
    |> stream_lines(:logs)
  end

  defp assign_compiled(socket, shard) do
    if compiled = Store.get(shard) do
      deps = Repo.all(from s in Shard, where: s.slug in ^compiled.includes)

      socket
      |> assign(:compiled, compiled)
      |> assign(:dependencies, deps)
    else
      socket
      |> assign(:compiled, nil)
      |> assign(:dependencies, [])
    end
  end

  defp assign_group(socket, shard) do
    case String.split(shard.slug, "/", parts: 2) do
      [group, _] -> assign(socket, :group, query_siblings(group))
      [_] -> assign(socket, :group, query_siblings(shard.slug))
    end
  end

  defp query_siblings(group) do
    Repo.all(from s in Shard, 
      where: like(s.slug, ^"#{group}/%") or s.slug == ^group,
      order_by: [asc: s.slug])
  end

  defp assign_dependents(socket, shard) do
    dependents = 
      Store.all()
      |> Enum.filter(fn {_, r} -> shard.slug in r.includes end)
      |> Enum.map(fn {slug, _} -> slug end)
      |> then(&Repo.all(from s in Shard,
        where: s.slug in ^&1,
        order_by: [asc: s.slug]))

    assign(socket, :dependents, dependents)
  end

  defp assign_changeset(socket, shard) do
    %Ecto.Changeset{} = changeset = Shard.save_changeset(shard)
    assign(socket, shard: shard, changeset: changeset)
  end

  @impl true
  def handle_event("submit", %{"action" => "save", "shard" => params}, socket) do
    %Shard{} = shard = save_shard(socket.assigns.shard, params)
    Thread.mark_stale(shard)
    Webhook.push("shard.save", shard)
    {:noreply, assign_changeset(socket, shard)}
  end

  @impl true
  def handle_event("submit", %{"action" => "deploy", "shard" => params}, socket) do
    %Shard{} = shard = save_shard(socket.assigns.shard, params)
    %Socket{} = socket = assign_changeset(socket, shard)

    if socket.assigns.task do
      Webhook.push("shard.save", shard)
      {:noreply, put_flash(socket, :error, "Cannot run deploy in parallel.")}
    else
      Webhook.push("shard.save", shard)
      Webhook.push("shard.deploy", shard)
      {:noreply, assign(socket, task: launch_compile_worker(shard))}
    end
  end

  @impl true
  def handle_event("cancel-deploy", _params, socket) do
    if task = socket.assigns.task do
      Task.shutdown(task)
      {:noreply, assign(socket, :task, nil)}
    else
      {:noreply, put_flash(socket, :error, "Terminating deploy failed: task not alive.")}
    end
  end

  @impl true
  def handle_info({:exception, e}, socket) do
    message = Exception.format(:error, e)
    {:noreply, stream(socket, :logs, [message])}
  end

  @ansi_escape ~r/\e\[[0-9;]*m/

  @impl true
  def handle_info({:stdout, output}, socket) do
    output = Regex.replace(@ansi_escape, output, "")
    {:noreply, stream(socket, :logs, [output])}
  end

  @impl true
  def handle_info({:stderr, output}, socket) do
    output = Regex.replace(@ansi_escape, output, "")
    {:noreply, stream(socket, :logs, [output])}
  end

  @impl true
  def handle_info({:status, status}, socket) do
    {:noreply, socket 
     |> assign(:status, status)
     |> assign_compiled(socket.assigns.shard)}
  end

  @impl true
  def handle_info({:collab, updates}, socket) do
    VikWeb.CodeMirror.sync("source-code", updates)
    {:noreply, socket}
  end

  @impl true
  def handle_info({ref, _outcome}, socket) when socket.assigns.task.ref == ref do
    Process.demonitor(ref, [:flush])
    {:noreply, assign(socket, :task, nil)}
  end

  @impl true
  def handle_info({:join, suid, presence}, socket)
    when socket.assigns.shard.slug == suid do
    {:noreply, stream_insert(socket, :participants, presence)}
  end

  @impl true
  def handle_info({:leave, suid, presence}, socket)
    when socket.assigns.shard.slug == suid do
    if presence.metas == [] do
      {:noreply, stream_delete(socket, :participants, presence)}
    else
      {:noreply, stream_insert(socket, :participants, presence)}
    end
  end

  def save_shard(shard, params) do
    shard
    |> Shard.save_changeset(params)
    |> Repo.update!()
  end

  defp launch_compile_worker(shard) do
    Task.async(fn -> Thread.eval(shard) end)
  end

  # TODO(robin): disable deploy button during long compilations

  @impl true
  def render(assigns) do
    ~H"""
    <main class="wide">
      <.form
        :let={f}
        id="shard"
        for={@changeset}
        phx-submit={JS.push("submit", page_loading: true)}
        phx-hook="SlowSubmit"
      >
        <style>
          /* Hacks to prevent grid layouts overflowing */
          main {   
            display: flex;
            flex-direction: column;
          }
          main > * {
            width: 100%;
          }
        </style>

        <.codemirror
          id="source-code"
          field={f[:source_code]}
          suid={@shard.slug}
          uid={to_uid(@current_user)}
        />

        <div id="sidebar">
          <header class="bar">
            <h2>{@shard.title} <span class="dot" style={"color: #{dot_color(@status)}"}></span></h2>
            <a
              :if={plug_exposed?(@compiled)}
              href={"/api/#{@shard.slug}"}
              target="_blank"
              title="Open in new tab"
              class="button"
            >
              <.icon name="hero-globe-alt" />
            </a>
          </header>
          <div class="split">
            <.button id="save" class="action-button" name="action" value="save">
              <.icon name="hero-server" /> <span data-disable-with="Saving...">Save</span>
            </.button>
            <.button id="deploy" class="action-button" name="action" value="deploy">
              <.icon name="hero-cloud" /> <span data-disable-with="Compiling...">Deploy</span>
            </.button>
          </div>
          <div :if={@compiled} class="box">
            <h3>Exports</h3>

            <p :if={@compiled.exports == []} class="placeholder-text">None</p>

            <ul :if={@compiled.exports != []}>
              <li :for={export <- @compiled.exports}>
                <code>
                  {String.replace_prefix(format_export(export), to_string(@compiled.module) <> ".", "")}
                </code>
              </li>
            </ul>
          </div>
          <div :if={length(@dependencies) >= 1} class="box">
            <h3>Dependencies</h3>

            <ul>
              <li :for={%Shard{} = shard <- @dependencies}>
                <.link navigate={~p"/#{shard.slug}"}>
                  {shard.title} <small>({shard.slug})</small>
                </.link>
              </li>
            </ul>
          </div>
          <div :if={length(@dependents) >= 1} class="box">
            <h3>Dependents</h3>

            <ul>
              <li :for={%Shard{} = shard <- @dependents}>
                <.link navigate={~p"/#{shard.slug}"}>
                  {shard.title} <small>({shard.slug})</small>
                </.link>
              </li>
            </ul>
          </div>
          <div :if={length(@group) > 1} class="box">
            <h3>Group</h3>

            <ul>
              <li :for={%Shard{} = shard <- @group}>
                <.link navigate={~p"/#{shard.slug}"}>
                  {shard.title} <small>({shard.slug})</small>
                </.link>
              </li>
            </ul>
          </div>

          <div class="box collab">
            <h3 >Collaboration session</h3>
            <ul id="participants" phx-update="stream">
              <li :for={{dom_id, p} <- @streams.participants} id={dom_id} title={p.name}>
                <span class="avatar" style={"background: #{random_color(p.id)}"}>
                  {initials(p.name)}<small :if={length(p.metas) > 1}>+{length(p.metas) - 1}</small>
                </span>
              </li>
            </ul>
          </div>
        </div>

        <.terminal id="logs" lines={@streams.logs} scroll />
      </.form>
    </main>
    """
  end

  @colors [
    "#f59e0b",
    "#14b8a6",
    "#0891b2",
    "#818cf8",
    "#8b5cf6",
    "#f87171",
    "#f472b6",
    "#fb7185",
  ]

  defp random_color(uid) do
    Enum.at(@colors, :erlang.phash2(uid, length(@colors)))
  end

  defp initials(name) when name in ["", nil] do
    "#"
  end

  defp initials(name) do
    name
    |> String.split()
    |> Enum.take(2)
    |> Enum.map(&String.first/1)
    |> Enum.join()
    |> String.upcase()
  end

  def dot_color(:stale), do: "#fbbf24"
  def dot_color(:up), do: "#4ade80"
  def dot_color(:down), do: "#f87171"

  defp format_export(export) when is_atom(export) do
    to_string(export)
  end

  defp format_export({_mod, fun, arity}) do
    inspect({fun, arity})
  end

  defp plug_exposed?(nil), do: false
  defp plug_exposed?(~m{:Result, module}) do
    function_exported?(module, :__call__, 0)
  end

  defp to_uid(name) when is_binary(name), do: name
  defp to_uid(%{"displayname" => name}), do: name
end
