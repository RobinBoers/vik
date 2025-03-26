defmodule Vik.IOHandler do
  @moduledoc false

  alias Vik.PubSub

  @io "io"

  # Public API

  def subscribe do
    PubSub.subscribe(@io)
  end

  def write(iodata) do
    lines =
      iodata
      |> to_string()
      |> String.split("\n", trim: true)

    PubSub.broadcast(@io, {:lines, lines})
  end

  def attach do
    :ok = :io.setopts(:standard_io, device: __MODULE__)
    :ok = :io.setopts(:standard_error, device: __MODULE__)

    Process.group_leader(self(), self())
  end

  # Implementation of IO handler

  def put_chars(_, chars), do: write(chars)
  def put_chars(_, _encoding, chars), do: write(chars)
  def get_line(_, _), do: {:error, :enotsup}
  def get_chars(_, _, _), do: {:error, :enotsup}
  def setopts(_, _), do: :ok
  def getopts(_), do: []
  def flush(_), do: :ok

  # Supervisor API

  def start_link do
    Task.start_link(fn -> __MODULE__.attach() end)
  end

  def child_spec(_) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, []},
      type: :worker,
      restart: :temporary,
      shutdown: 5000
    }
  end
end
