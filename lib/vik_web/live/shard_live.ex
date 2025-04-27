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
  import Structo
  import VikWeb.LogLive, only: [terminal: 1]

  require Logger

  on_mount {VikWeb.SystemHandler, :static}

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    case Repo.get_by(Shard, slug: slug) do
      %Shard{} = shard -> {:ok, mount_shard(socket, shard)}
      nil -> raise Vik.ShardNotFound, slug
    end
  end

  defp mount_shard(socket, shard) do
    PubSub.subscribe(shard.slug)

    socket
    |> assign(:task, nil)
    |> assign(:status, Store.status(shard))
    |> stream_lines(:logs)
    |> assign_compiled(shard)
    |> assign_changeset(shard)
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

  # TODO(robin): disable deploy button during long compilations

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
      <style>
        /* Hacks to prevent grid layouts overflowing */
        main {   
          display: flex;
          flex-direction: column;
          overflow: hidden;
        }
        main > * {
          width: 100%;
        }
      </style>

      <.codemirror id="source-code" field={f[:source_code]} />

      <div id="sidebar" class="flex flex-col gap-4">
        <div class="flex items-center gap-2 -mb-1.5">
          <h2 class="font-bold text-2xl ml-2">{@shard.title}</h2>
          <div class={"flex-none rounded-full p-1 #{dot_color(@status)}"}>
            <div class="size-1.5 rounded-full bg-current"></div>
          </div>
          <div class="flex-grow"></div>
          <a
            :if={plug_exposed?(@compiled)}
            href={~p"/api/#{@shard.slug}"}
            target="_blank"
            title="Open in new tab"
            class="rounded-full bg-gray-100 hover:bg-gray-200 p-2 flex items-center justify-center"
          >
            <.icon name="hero-globe-alt" />
          </a>
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
                {String.replace_prefix(format_export(export), to_string(@compiled.module) <> ".", "")}
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
     
      <.terminal id="logs" lines={@streams.logs} scroll />
    </.form>
    """
  end

  def dot_color(:stale), do: "bg-amber-400/10 text-amber-400"
  def dot_color(:up), do: "bg-green-400/10 text-green-400"
  def dot_color(:down), do: "bg-red-400/10 text-red-400"

  attr :id, :string
  attr :name, :string
  attr :value, :string
  attr :field, Phoenix.FormField

  attr :rest, :global

  def codemirror(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign_new(:name, fn -> field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> codemirror()
  end
  
  def codemirror(assigns) do
    ~H"""
    <div
      id={"#{@id}-wrapper"}
      phx-hook="CodeMirror"
      class="codemirror"
    >
      <div
        id={"#{@id}-target"}
        class="target"
        phx-update="ignore"
      ></div>
      <textarea
        id={@id}
        name={@name}
        data-update-ignore="hidden"
        {@rest}
      >{Phoenix.HTML.Form.normalize_value("textarea", @value)}</textarea>
    </div>
    """
  end

  defp format_export(export) when is_atom(export) do
    to_string(export)
  end

  defp format_export({_mod, fun, arity}) do
    inspect({fun, arity})
  end

  defp plug_exposed?(nil), do: false
  defp plug_exposed?(~m{:Compiled, module}) do
    function_exported?(module, :__call__, 0)
  end
end
