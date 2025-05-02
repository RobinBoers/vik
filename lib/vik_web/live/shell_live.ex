defmodule VikWeb.ShellLive do
  @moduledoc false
  use VikWeb, :live_view

  alias Vik.IO

  import VikWeb.LogLive, only: [terminal: 1]

  on_mount {VikWeb.SystemHandler, :static}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket
     |> assign(:binding, [])
     |> stream_lines(:logs, [])}
  end

  @impl true
  def handle_info({:response, result}, socket) do
    {:noreply, stream_color(socket, :logs, [result], "text-cyan-600")}
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
  def handle_event("clear", _, socket) do
    {:noreply, stream(socket, :logs, [], reset: true)}
  end

  @impl true
  def handle_event("execute", %{"source" => source}, socket) do
    {_result, binding} = eval(source, socket.assigns.binding)

    {:noreply, socket
     |> assign(:binding, binding)
     |> stream(:logs, ["vik> #{source}"])}
  end

  defp eval(source, binding) do
    {result, stdout, stderr} =
      IO.capture(fn -> safe_eval(source, binding) end)

    send(self(), {:stdout, stdout})
    send(self(), {:stderr, stderr})

    case result do
      {e, _} when is_exception(e) -> send(self(), {:exception, e})
      {result, _} -> send(self(), {:response, inspect(result)})
    end

    result
  end

  defp safe_eval(source, binding) do
    Code.eval_string(source, binding)
  rescue
    e -> {e, binding}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div
      id="shell"
      class="flex flex-col h-full px-4 py-8"
      phx-window-keydown="clear"
      phx-key="k"
      phx-key-meta="true"
      phx-key-ctrl="true"
    >
      <h1 class="font-bold text-2xl mb-1">Shell</h1>
      <.terminal id="logs" lines={@streams.logs} scroll />
      <input id="repl" phx-hook="Shell" type="text" name="source" autofocus autocomplete="off" />
    </div>
    """
  end
end
