defmodule Vik.Authority do
  @moduledoc """
  Acts as the central authority for active `@codemirror/collab`
  sessions. Holds the authoritative master copy of every shard.

  This enables real-time collaborative editing across multiple
  browser windows or computers.
  """
  use GenServer
  use TypedStruct

  alias Vik.PubSub

  typedstruct module: Session do
    @moduledoc false

    field :doc, term()
    field :updated, [term()]
  end

  @type suid :: binary()
  @opaque state :: %{suid() => Session.t()}

  @doc """
  Starts the authority.
  """
  @spec start_link([]) :: :ok
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Joins a collaboration session.
  """
  @spec join(suid()) :: :ok
  def join(suid) do
    PubSub.subscribe(suid)
    ensure_session!(suid)

    :ok
  end

  defp ensure_session!(suid) do
    GenServer.cast(__MODULE__, {:ensure_session, suid})
  end

  @doc false
  @impl true
  def init(_opts) do
    {:ok, %{}}
  end
end