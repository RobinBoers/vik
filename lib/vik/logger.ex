defmodule Vik.Logger do
  @moduledoc """
  Simple logging server.

  The server holds a list of all log entries in memory;
  this comprises all exceptions and related messages
  emitted since application boot.

  This server also supports webhooks to push notifications
  to other platforms (eg. Discord).

  To utilize this functionality, export the `WEBHOOK_URL`
  variable in your system's environment:

      export WEBHOOK_URL="https://discord.com/api/webhooks/..."

  The webhook will receive messages in the following JSON
  structured format (as defined by `t:Vik.Webhook.payload/0`):

      {"event": "logger.message", "content": "** (RuntimeError) hewwo world :3"}

  """
  use GenServer

  alias Vik.PubSub
  alias Vik.Webhook

  @doc """
  Starts the server.
  """
  @spec start_link([]) :: :ok
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @topic "vik_logger"

  @doc """
  Subscribes to log entries via PubSub.

  ## Examples

      @initial_lines 50

      def mount(_, _, socket) do
        Vik.Logger.subscribe()

        lines = Vik.Logger.tail(@initial_lines)
        {:ok, stream(socket, :logs, lines)}
      end

      def handle_info({:lines, lines}, socket) do
        {:noreply, stream(socket, :logs, lines, at: 0)}
      end

  """
  @spec subscribe() :: :ok
  def subscribe do
    PubSub.subscribe(@topic)
  end

  @doc """
  Logs a simple message.
  """
  @spec info(String.t()) :: :ok
  def info(message) do
    GenServer.cast(__MODULE__, {:append, message})
  end

  @doc """
  Logs an exception.

  Excludes all stacktraces unrelated to user code.
  (Everything outside the `Vik.UserShard` namespace.)
  """
  @spec exception(Exception.t(), Exception.stacktrace()) :: :ok
  def exception(e, stacktrace \\ []) do
    message = format_exception(e, stacktrace)
    GenServer.cast(__MODULE__, {:append, message})
  end

  defp format_exception(e, stacktrace) do
    Exception.format(:error, e, clean_trace(stacktrace))
  end

  @doc """
  Returns `n` latest log entries.
  """
  @spec tail(pos_integer()) :: [String.t()]
  def tail(n) when n > 0 do
    GenServer.call(__MODULE__, {:tail, n})
  end

  @doc """
  Delete `n` oldest log entries.
  """
  @spec clear(pos_integer() | :all) :: :ok
  def clear(n \\ :all) when n > 0 or n == :all do
    GenServer.cast(__MODULE__, {:clear, n})
  end

  @doc false
  @impl true
  def init(_opts) do
    {:ok, []}
  end

  @doc false
  @impl true
  def handle_call({:tail, n}, _from, state) do
    {:reply, Enum.take(state, n), state}
  end

  @doc false
  @impl true
  def handle_cast({:append, message}, state) do
    PubSub.broadcast(@topic, {:lines, [message]})

    message
    |> decorate_message()
    |> push_notification()

    {:noreply, [message | state]}
  end

  @doc false
  @impl true
  def handle_cast({:clear, :all}, _state) do
    {:noreply, []}
  end

  @doc false
  @impl true
  def handle_cast({:clear, n}, state) do
    {:noreply, Enum.take(state, length(state) - n)}
  end

  defp push_notification(message) do
    Webhook.push("logger.message", message)
  end

  defp decorate_message(message) do
    "```\n#{message}\n```"
  end

  # This is ugly. It works tho :)

  @user_mod "Elixir.Vik.UserShard"

  defp clean_trace(stacktrace) do
    Enum.flat_map(stacktrace, fn {m, f, a, info} ->
      if m |> Atom.to_string() |> String.starts_with?(@user_mod) do
        ["Vik", "UserShard" | m] = Module.split(m)
        [{Module.concat(m), f, a, info}]
      else
        []
      end
    end)
  end
end
