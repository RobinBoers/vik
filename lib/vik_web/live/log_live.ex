defmodule VikWeb.LogLive do
  @moduledoc false
  use VikWeb, :live_view

  alias Vik.Logger

  on_mount VikWeb.Auth
  on_mount {VikWeb.SystemHandler, :static}

  @initial_lines 50

  @impl true
  def mount(%{"n" => n}, _session, socket) do
    {:ok, mount_logs(socket, n)}
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, mount_logs(socket, @initial_lines)}
  end

  defp mount_logs(socket, n) do
    Logger.subscribe()
    stream_lines(socket, :logs, Logger.tail(n))
  end

  @impl true
  def handle_event("shortcut", %{"ctrl" => true, "key" => "k"}, socket) do
    Logger.clear()
    {:noreply, stream(socket, :logs, [], reset: true)}
  end

  @impl true
  def handle_event("shortcut", _, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info({:lines, lines}, socket) do
    {:noreply, stream(socket, :logs, lines, at: 0)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <main class="wide">
      <div
        id="log"
        class="shell"
        phx-window-keydown="shortcut"
        phx-throttle="500"
      >
        <header class="bar"><h2>Logs</h2></header>
        <.terminal id="logs" lines={@streams.logs} />
      </div>
    </main>
    """
  end

  attr :id, :string, required: true
  attr :lines, :list, required: true
  attr :scroll, :boolean, default: false

  def terminal(assigns) do
    ~H"""
    <div class="terminal" id={@id} phx-update="stream" phx-hook={@scroll && "Scroll"}>
      <pre
        :for={{dom_id, line} <- @lines}
        id={dom_id}
        class="line"
      >{line}</pre>
    </div>
    """
  end
end
