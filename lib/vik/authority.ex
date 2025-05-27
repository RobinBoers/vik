defmodule Vik.Authority do
  @moduledoc """
  Acts as the central authority for active `@codemirror/collab`
  sessions. Holds the authoritative master copy of every shard.

  This enables real-time collaborative editing across multiple
  browser windows or devices.
  """
  use GenServer
  use TypedStruct

  alias Vik.PubSub
  alias Vik.Shard
  alias Vik.Repo

  import Structo

  @type version :: non_neg_integer()

  typedstruct module: Session do
    @moduledoc false
    @derive {Jason.Encoder, only: [:version, :updates, :doc]}

    field :participants, pos_integer(), default: 1
    field :version, integer(), default: 0
    field :updates, [Update.t()], default: []
    field :doc, String.t()
  end

  typedstruct module: Update do
    @moduledoc """
    JSON payload consisting of changes to a CodeMirror document. 
    The contents of these updates is seen as irrelevant to the 
    authority.

    The `Vik.Authority` simply passes them along to the 
    concerning CodeMirror instances for further processing.
    """

    field :client_id, String.t()
    field :changes, [term()]

    defimpl Jason.Encoder do
      def encode(%{client_id: cid, changes: changes}, opts) do
        Jason.Encode.map(%{"clientID" => cid, "changes" => changes}, opts)
      end
    end
  end

  @typedoc """
  Session identifiers uniquely identify a collaborative
  session.

  For convience, Shard slugs double as valid session 
  identifiers as well.
  """
  @type suid :: Vik.slug()
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
  @spec join(suid()) :: :ok | {:error, term()}
  def join(suid) do
    with :ok <- subscribe(suid) do
      GenServer.cast(__MODULE__, {:join, suid})
    end
  end

  @doc """
  Leaves a collaboration session.

  When empty, the collaboration session will
  automatically close.
  """
  @spec leave(suid()) :: :ok
  def leave(suid) do
    GenServer.cast(__MODULE__, {:leave, suid})
  end

  @doc """
  Pulls any changes made since `version`.
  """
  @spec fetch_changes(suid(), version()) :: [Update.t()]
  def fetch_changes(suid, version) do
    GenServer.call(__MODULE__, {:fetch_changes, suid, version})
  end

  @doc """
  Pushes new changes starting from `version`.
  """
  @spec push_changes(suid(), version(), [Update.t()]) :: :ok | :rejected
  def push_changes(suid, version, updates) do
    GenServer.call(__MODULE__, {:push_changes, suid, version, updates})
  end

  @doc """
  Returns the session with all relevant data for
  constructing the current CodeMirror document.
  """
  @spec get_document(suid()) :: Session.t()
  def get_document(suid) do
    GenServer.call(__MODULE__, {:get_document, suid})
  end

  @doc false
  @impl true
  def init(_opts) do
    {:ok, Map.new()}
  end

  @doc false
  @impl true
  def handle_cast({:join, suid}, state) do
    %Shard{} = shard = Repo.get_by!(Shard, slug: suid)
    %Session{} = new_session = initialise_session(shard)

    {:noreply, Map.update(state, suid, new_session, &join_session/1)}
  end

  @doc false
  @impl true
  def handle_cast({:leave, suid}, state) do
    %Session{} = session = Map.fetch!(state, suid)

    case leave_session(session) do
      %Session{} = s when s.participants <= 0 ->
        {:noreply, Map.delete(state, suid)}

      %Session{} = updated_session ->
        {:noreply, Map.put(state, suid, updated_session)}
    end
  end

  @doc false
  @impl true
  def handle_call({:get_document, suid}, _from, state) do
    %Session{} = session = Map.fetch!(state, suid)
    {:reply, session, state}
  end

  @doc false
  @impl true
  def handle_call({:fetch_changes, suid, version}, _from, state) do
    %Session{} = session = Map.fetch!(state, suid)
    behind = session.version - version

    {:reply, pending_changes(session, behind), state}
  end

  @doc false
  @impl true
  def handle_call({:push_changes, suid, version, updates}, _from, state) do
    %Session{} = session = Map.fetch!(state, suid)
    
    if version != session.version do
      {:reply, :rejected, state}
    else
      session = append_changes(session, updates)
      state = Map.put(state, suid, session)

      # Notify other clients of the new updates.
      broadcast(suid, {:collab, updates})
  
      {:reply, :ok, state}
    end
  end

  defp initialise_session(shard) do
    %Session{doc: shard.source_code}
  end
  defp join_session(session) do
    Map.update!(session, :participants, &(&1 + 1))
  end
  defp leave_session(session) do
    Map.update!(session, :participants, &(&1 - 1))
  end

  defp pending_changes(_session, x) when x < 0, do: []
  defp pending_changes(session, behind) do
    session.updates |> Enum.take(behind) |> Enum.reverse()
  end

  defp append_changes(session, new) do
    version = session.version + Enum.count(new)
    updates = Enum.reverse(new) ++ session.updates

    ~m{:Session, version, updates}
  end

  # PubSub helpers

  @topic "@collab/"

  defp subscribe(suid) when is_binary(suid) do
    PubSub.subscribe(@topic <> suid)
  end

  defp broadcast(suid, message) when is_binary(suid) do
    PubSub.broadcast(@topic <> suid, message)
  end
end