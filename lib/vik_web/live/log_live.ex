defmodule VikWeb.LogLive do
  @moduledoc false
  use VikWeb, :live_view

  alias Vik.Logger

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
  def handle_event("keydown", %{"ctrl" => true, "key" => "k"}, socket) do
    Logger.clear()
    {:noreply, stream(socket, :logs, [], reset: true)}
  end

  @impl true
  def handle_event("keydown", _, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info({:lines, lines}, socket) do
    {:noreply, stream(socket, :logs, lines, at: 0)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div
      id="log"
      class="flex flex-col h-full px-4 py-8"
      phx-window-keydown="shortcut"
      phx-throttle="500"
    >
      <h1 class="font-bold text-2xl mb-1">Logs</h1>
      <.terminal id="logs" lines={@streams.logs} />
    </div>
    """
  end

  attr :id, :string, required: true
  attr :lines, :list, required: true
  attr :scroll, :boolean, default: false

  def terminal(assigns) do
    ~H"""
    <div id={@id} phx-update="stream" phx-hook={@scroll && "Scroll"} class="font-mono overflow-auto bg-zinc-100 flex-grow">
      <pre
        :for={{dom_id, line} <- @lines}
        id={dom_id}
        class="whitespace-pre-wrap p-2 empty:hidden hover:bg-zinc-50"
      >{line}</pre>
    </div>
    """
  end
end
