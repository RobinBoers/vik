defmodule VikWeb.SystemHandler do
  @moduledoc false
  use VikWeb, :live_hook

  alias Vik.System

  import Structo

  @interval :timer.seconds(1)

  def on_mount(type, _params, session, socket) do
    if connected?(socket) do
      :net_kernel.monitor_nodes(true, node_type: :all)

      if type == :realtime do
        Process.send_after(self(), :refresh, @interval)
      end
    end


    {:cont, socket
     |> assign_node(session)
     |> assign_system_info()
     |> attach_hook(:refresh, :handle_info, &handle_info/2)}
  end

  def handle_info(:refresh, socket) do
    Process.send_after(self(), :refresh, @interval)
    {:halt, assign_system_info(socket)}
  end
  
  def handle_info(message, socket) do
    {:cont, socket}
  end

  defp assign_node(socket, session) do
    socket
    |> assign(:node, find_node(session))
    |> assign(:nodes, System.nodes())
  end

  defp assign_system_info(socket) do
    ~m{versions, system_info, system_usage, system_limits} = 
      System.fetch_system_info(socket.assigns.node)

    socket
    |> assign(:versions, versions)
    |> assign(:info, system_info)
    |> assign(:limits, system_limits)
    |> assign(:usage, system_usage)
  end

  defp find_node(session) do
    if node = session["node"] do
      Enum.find(System.nodes(), &(Atom.to_string(&1) == node))
    else
      node()
    end
  end
end