defmodule VikWeb.ShardLive do
  @moduledoc false
  use VikWeb, :live_view

  alias Vik.Repo
  alias Vik.Store
  alias Vik.Shard
  alias Vik.Compiled

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    %Shard{} = shard = Repo.get_by(Shard, slug: slug)
    {:ok, assign_changeset(socket, shard)}
  end

  @impl true
  def handle_event("submit", %{"action" => "save", "shard" => params}, socket) do
     %Shard{} = shard = save_shard(socket.assigns.shard, params)
     :ok = Store.mark_stale(shard.slug)
    {:noreply, assign_changeset(socket, shard)}
  end

  @impl true
  def handle_event("submit", %{"action" => "deploy", "shard" => params}, socket) do
    %Shard{} = shard = save_shard(socket.assigns.shard, params)
    :ok = Store.recompile!(shard.slug)
    {:noreply, assign_changeset(socket, shard)}
  end

  defp assign_changeset(socket, shard) do
    %Ecto.Changeset{} = changeset = Shard.save_changeset(shard)
    assign(socket, shard: shard, changeset: changeset)
  end

  def save_shard(shard, params) do
    shard
    |> Shard.save_changeset(params)
    |> Repo.update!()
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