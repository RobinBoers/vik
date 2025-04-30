defmodule KV do
  @moduledoc """
  A modular key-value store for arbitrary, 
  disk-persisted term storage based on `:dets`.

  ## Usage

  Add `KV` to your supervision tree:

      {KV, root: "/tmp"}

  """
  use TypedStruct
  use GenServer

  @type table :: atom()
  @type key :: atom()
  @type object :: term()

  typedstruct module: State do
    @moduledoc false

    field :root, String.t(), required: true
    field :tables, map(), default: %{}
  end

  @type start_opts :: [
          root: Path.t()
        ]

  @doc """
  Starts the store.
  """
  @spec start_link(start_opts()) :: :ok
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Puts the given `object` in `table`.

  If the table does not exist yet, it is created on-demand.

  ## Examples

      iex> KV.put(:users, 1, %User{id: 1, name: "Robin", age: 18})
      iex> KV.put(:users, 2, %User{id: 2, name: "Gijs", age: 15})
      :ok

  """
  @spec put(table(), key(), object()) :: :ok | :error
  def put(table, key, object) do
    GenServer.call(__MODULE__, {:put, table, key, object})
  end

  @doc """
  Gets the object for the given `key` from `table`.

  ## Examples

      iex> KV.get(:users, 1)
      {:ok, %User{id: 1, name: "Robin", age: 18}}

      iex> KV.get(:users, 3)
      :error

      iex> KV.get(:non_existant, 3)
      :error

  """
  @spec fetch(table(), key()) :: {:ok, object()} | :error
  def fetch(table, key) do
    GenServer.call(__MODULE__, {:fetch, table, key})
  end

  @doc """
  Same as `fetch/2`, but returns `nil` if the given table 
  or key cannot be found.

  ## Examples

      iex> KV.get(:users, 1)
      %User{id: 1, name: "Robin", age: 18}

      iex> KV.get(:users, 3)
      nil

      iex> KV.get(:non_existant, 3)
      nil

  """
  @spec get(table(), key()) :: object() | nil
  def get(table, key) do
    case fetch(table, key) do
      {:ok, object} -> object
      :error -> nil
    end
  end

  @doc """
  Deletes the object for the given `key` from `table`.

  ## Examples

      iex> KV.put(:users, 1, %User{id: 1, name: "Robin", age: 18})
      iex> KV.get(:users, 1)
      %User{id: 1, name: "Robin", age: 18}

      iex> KV.delete(:users, 1)
      iex> KV.get(:users, 1)
      nil

  """
  @spec delete(table(), key()) :: :ok | :error
  def delete(table, key) do
    GenServer.call(__MODULE__, {:delete, table, key})
  end

  @doc """
  Lists all objects in the given `table`.

  ## Examples

      iex> KV.list(:users)
      [%User{id: 1, name: "Robin", age: 18}, %User{id: 2, name: "Gijs", age: 15}]

  """
  @spec list(table()) :: [object()]
  def list(table) do
    GenServer.call(__MODULE__, {:list, table})
  end

  @doc """
  Deletes all objects from the given `table`, effectively
  emptying it.

  ## Examples

      iex> KV.list(:users)
      [%User{id: 1, name: "Robin", age: 18}, %User{id: 2, name: "Gijs", age: 15}]

      iex> KV.clear(:users)
      iex> KV.list(:users)
      []

  """
  @spec clear(table()) :: :ok | :error
  def clear(table) do
    GenServer.call(__MODULE__, {:clear, table})
  end

  @doc false
  @impl true
  def init(opts) do
    {:ok, %State{root: Keyword.get(opts, :root) || "/tmp"}}
  end

  @doc false
  @impl true
  def handle_call({:put, table, key, object}, _from, state) do
    state = ensure_table!(state, table)

    :dets.insert(table, {key, object})
    {:reply, :ok, state}
  end

  @doc false
  @impl true
  def handle_call({:fetch, table, key}, _from, state) do
    state = ensure_table!(state, table)

    case :dets.lookup(table, key) do
      [{^key, object}] -> {:reply, {:ok, object}, state}
      [] -> {:reply, :error, state}
      {:error, _} -> {:reply, :error, state}
    end
  end

  @doc false
  @impl true
  def handle_call({:delete, table, key}, _from, state) do
    state = ensure_table!(state, table)

    case :dets.delete(table, key) do
      :ok -> {:reply, :ok, state}
      {:error, _} -> {:reply, :error, state}
    end
  end

  @doc false
  @impl true
  def handle_call({:list, table}, _from, state) do
    state = ensure_table!(state, table)
    records = :dets.foldl(fn {_, v}, acc -> [v | acc] end, [], table)

    {:reply, records, state}
  end

  @doc false
  @impl true
  def handle_call({:clear, table}, _from, state) do
    state = ensure_table!(state, table)

    case :dets.delete_all_objects(table) do
      :ok -> {:reply, :ok, state}
      {:error, _} -> {:reply, :error, state}
    end
  end

  @doc false
  @impl true
  def terminate(_reason, state) do
    state.tables
    |> Map.keys()
    |> Enum.each(&:dets.close/1)
  end

  defp ensure_table!(state, table)
    when is_map_key(state.tables, table), do: state

  defp ensure_table!(state, table) when is_atom(table) do
    path = construct_path(state.root, table)

    case :dets.open_file(table, file: path, type: :set) do
      {:ok, ^table} ->
        %State{state | tables: Map.put(state, table, true)}

      {:error, {:already_exists, ^table}} ->
        %State{state | tables: Map.put(state, table, true)}

      {:error, reason} ->
        raise "Failed to open table #{inspect(table)}: #{inspect(reason)}"
    end
  end

  defp construct_path(root, table) do
    root |> Path.join(to_string(table)) |> to_charlist()
  end
end
