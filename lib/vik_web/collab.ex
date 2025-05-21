defmodule VikWeb.Collab do
  @moduledoc false
  use VikWeb, :live_hook

  alias Vik.Authority
  alias Vik.Authority.Update

  import Structo

  def on_mount(:default, _params, _session, socket) do
    {:cont, attach_hook(socket, :collab, :handle_event, &handle_event/3)}
  end

  def handle_event("collab:pull", ~m{version}s, socket) do
    suid = socket.assigns.shard.slug
    {:reply, Authority.pull_changes(suid, version), socket}
  end

  def handle_event("collab:push", ~m{version, updates}s, socket) do
    suid = socket.assigns.shard.slug
    updates = deserialize_changes(updates)
  
    case Authority.push_updates(suid, version, updates) do
      :ok -> {:reply, true, socket}
      :rejected -> {:reply, false, socket}
    end
  end

  defp deserialize_changes(updates) do
    Enum.map(updates, &%Update{
      client_id: &1["clientID"],
      changes: &1["changes"]
    })
  end

  def handle_event(_event, _params, socket) do
    {:cont, socket}
  end
end