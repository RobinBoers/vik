defmodule VikWeb.ShardLive do
  @moduledoc false
  use VikWeb, :live_view

  alias Vik.Repo
  alias Vik.Store
  alias Vik.Shard
  alias Vik.Compiled
  alias Vik.PubSub
  alias Vik.Thread

  import Ecto.Query
  import VikWeb, only: [dot_color: 1]

  require Logger

  # TODO(robin): disable deploy button during long compilations

  on_mount {VikWeb.SystemHandler, :static}

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    case Repo.get_by(Shard, slug: slug) do
      %Shard{} = shard -> {:ok, mount_shard(socket, shard)}
      nil -> raise Vik.ShardNotFound
    end
  end

  defp mount_shard(socket, shard) do
    PubSub.subscribe(shard.slug)

    socket
    |> assign(:task, nil)
    |> assign(:status, Store.status(shard))
    |> stream_configure(:logs, dom_id: &dom_id/1)
    |> stream(:logs, [])
    |> assign_compiled(shard)
    |> assign_changeset(shard)
  end

  defp dom_id(_), do: :crypto.strong_rand_bytes(8) |> Base.encode16()

  defp assign_compiled(socket, shard) do
    if compiled = Store.get(shard) do
      deps = Repo.all(from s in Shard, where: s.slug in ^compiled.includes)

      socket
      |> assign(:compiled, compiled)
      |> assign(:dependencies, deps)
    else
      socket
      |> assign(:compiled, nil)
      |> assign(:dependencies, nil)
    end
  end

  defp assign_changeset(socket, shard) do
    %Ecto.Changeset{} = changeset = Shard.save_changeset(shard)
    assign(socket, shard: shard, changeset: changeset)
  end

  @impl true
  def handle_event("submit", %{"action" => "save", "shard" => params}, socket) do
     %Shard{} = shard = save_shard(socket.assigns.shard, params)
     Thread.mark_stale(shard)
    {:noreply, assign_changeset(socket, shard)}
  end

  @impl true
  def handle_event("submit", %{"action" => "deploy", "shard" => params}, socket) do
    %Shard{} = shard = save_shard(socket.assigns.shard, params)
    %Socket{} = socket = assign_changeset(socket, shard)

    if socket.assigns.task do
      {:noreply, put_flash(socket, :error, "Cannot run deploy in parallel.")}
    else
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
  def handle_info({:lines, lines}, socket) do
    {:noreply, stream(socket, :logs, List.wrap(lines))}
  end

  @impl true
  def handle_info({:exception, e}, socket) do
    message = Exception.format(:error, e)
    {:noreply, stream(socket, :logs, [message])}
  end
  
  @impl true
  def handle_info({:stdout, lines}, socket) do
    {:noreply, stream(socket, :logs, [lines])}
  end
  
  @impl true
  def handle_info({:stderr, lines}, socket) do
    {:noreply, stream(socket, :logs, [lines])}
  end

  @impl true
  def handle_info({:status, status}, socket) do
    {:noreply, socket 
     |> assign(:status, status)
     |> assign_compiled(socket.assigns.shard)}
  end

  @impl true
  def handle_info({ref, _outcome}, socket) when socket.assigns.task.ref == ref do
    Process.demonitor(ref, [:flush])
    {:noreply, assign(socket, :task, nil)}
  end

  def save_shard(shard, params) do
    shard
    |> Shard.save_changeset(params)
    |> Repo.update!()
  end

  defp launch_compile_worker(shard) do
    Task.async(fn -> Thread.eval(shard) end)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.form
      :let={f}
      id="shard"
      for={@changeset}
      phx-submit={JS.push("submit", page_loading: true)}
      phx-hook="SlowSubmit"
    >
      <.input
        type="textarea"
        field={f[:source_code]}
        class="font-mono !text-lg !m-0"
        rows="20"
      />
      
      <div id="sidebar" class="flex flex-col gap-4">
        <div class="flex items-center gap-2">
          <h2 class="font-bold text-2xl ml-2">{@shard.title}</h2>
          <div class={"flex-none rounded-full p-1 #{dot_color(@status)}"}>
            <div class="size-1.5 rounded-full bg-current"></div>
          </div>
        </div>
        <div class="flex gap-1">
          <.button id="save" class="flex-1 flex justify-center items-center gap-2" name="action" value="save">
            <.icon name="hero-server" /> <span data-disable-with="Saving...">Save</span>
          </.button>
          <.button id="deploy" class="flex-1 flex justify-center items-center gap-2" name="action" value="deploy">
            <.icon name="hero-cloud" /> <span data-disable-with="Compiling...">Deploy</span>
          </.button>
        </div>
        <div :if={@compiled} class="p-2 shadow rounded bg-zinc-100/85">
          <h3 class="font-semibold text-lg mb-1">Exports</h3>

          <p :if={@compiled.exports == []} class="text-zinc-500">None</p>

          <ul>
            <li :for={export <- @compiled.exports}>
              <code>
                {String.replace_prefix(to_string(export), to_string(@compiled.module) <> ".", "")}
              </code>
            </li>
          </ul>
        </div>
        <div :if={@dependencies} class="p-2 shadow rounded bg-zinc-100/85">
          <h3 class="font-semibold text-lg mb-1">Dependencies</h3>

          <p :if={@dependencies == []} class="text-zinc-500">None</p>

          <ul>
            <li :for={%Shard{} = shard <- @dependencies}>
              <.link navigate={~p"/#{shard.slug}"}>
                {shard.title} <span class="text-xs font-mono text-zinc-400 pl-1">({shard.slug})</span>
              </.link>
            </li>
          </ul>
        </div>
      </div>

      <div id="logs" class="font-mono overflow-auto" phx-update="stream" phx-hook="Scroll">
        <pre class="line" :for={{dom_id, line} <- @streams.logs} id={dom_id}>{line}</pre>
      </div>
    </.form>
    """
  end
end
