defmodule VikWeb.Collab do
  @moduledoc false
  use VikWeb, :live_hook

  alias Vik.Authority
  alias Vik.Authority.Update

  import Structo

  def on_mount(:default, _params, _session, socket) do
    {:cont, socket 
     |> attach_hook(:collab_event, :handle_event, &handle_event/3)
     |> attach_hook(:collab_info, :handle_info, &handle_info/3)}
  end

  def handle_info({:collab, updates}, socket) do
    {:halt, push_event(socket, "collab:pull", updates)}
  end

  def handle_info(_, socket) do
    {:cont, socket}
  end

  def handle_event("collab:fetch", ~m{version}s, socket) do
    suid = socket.assigns.shard.slug
    {:reply, Authority.fetch_changes(suid, version), socket}
  end

  def handle_event("collab:push", ~m{version, updates}s, socket) do
    suid = socket.assigns.shard.slug
    updates = deserialize_changes(updates)
  
    case Authority.push_updates(suid, version, updates) do
      :ok -> {:reply, true, socket}
      :rejected -> {:reply, false, socket}
    end
  end

  def handle_event("collab:doc", _params, socket) do
    suid = socket.assigns.shard.slug
    {:reply, Authority.get_document(suid), socket}
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