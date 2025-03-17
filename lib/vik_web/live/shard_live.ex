defmodule VikWeb.ShardLive do
  @moduledoc false
  use VikWeb, :live_view

  alias Vik.Repo
  alias Vik.Store
  alias Vik.Shard
  alias Vik.Compiled
  alias Vik.PubSub
  alias Vik.Thread

  # TODO(robin): disable deploy button during long compilations

  require Logger
  
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
    |> assign_changeset(shard)
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
  def handle_info({:status, status}, socket) do
    {:noreply, assign(socket, :status, status)}
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
      
      <div id="sidebar" class="flex flex-col gap-1">
        <div class="flex gap-1">
          <.button id="save" class="flex-1 flex justify-center items-center gap-2" name="action" value="save">
            <.icon name="hero-server" /> <span data-disable-with="Saving...">Save</span>
          </.button>
          <.button id="deploy" class="flex-1 flex justify-center items-center gap-2" name="action" value="deploy">
            <.icon name="hero-cloud" /> <span data-disable-with="Compiling...">Deploy</span>
          </.button>
        </div>
      </div>
    </.form>
    """
  end
end