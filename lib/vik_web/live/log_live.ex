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
  def handle_info({:lines, lines}, socket) do
    {:noreply, stream(socket, :logs, lines, at: 0)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="grid grid-rows-[40px_1fr] max-h-[calc(100vh-100px)]">
      <h1 class="font-bold text-2xl mb-1">Logs</h1>
      <div id="logs" class="font-mono overflow-auto" phx-update="stream">
        <pre class="whitespace-pre-wrap" :for={{dom_id, line} <- @streams.logs} id={dom_id}>{line}</pre>
      </div>
    </div>
    """
  end
end
