defmodule KV do
  @moduledoc """
  A modulear key-value store for arbitrary, 
  disk-persisted term storage based on `:dets`.

  ## Usage

  Add `KV` to your supervision tree:

      {KV, root: "/tmp"}

  """
  use TypedStruct
  use GenServer

  @type table :: atom()
  @type key :: atom()
  @type value :: term()

  typedstruct module: State do
    field :root, String.t(), required: true
    field :tables, map(), default: %{}
  end

  @doc """
  Starts the store.
  """
  def start_link(opts) do
    state = %State{root: Keyword.get(opts, :root) || "/tmp"}
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  @doc """
  Puts the given `value` in `table` under `key`.

  If the table does not exist yet, it is created
  on-demand.

  ## Examples

        iex> KV.put(:users, 1, %User{id: 1, name: "Robin", age: 18})
        iex> KV.put(:users, 2, %User{id: 2, name: "Gijs", age: 15})
        :ok

  """
  @spec put(table(), key(), value()) :: :ok | :error
  def put(table, key, value) do
    GenServer.call(__MODULE__, {:put, table, key, value})
  end

  @doc """
  Gets the value for the given `key` from `table`.

  ## Examples

      iex> KV.get(:users, 1)
      {:ok, %User{id: 1, name: "Robin", age: 18}}

      iex> KV.get(:users, 3)
      :error

      iex> KV.get(:non_existant, 3)
      :error

  """
  @spec fetch(table(), key()) :: {:ok, value()} | :error
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
  @spec get(table(), key()) :: value() | nil
  def get(table, key) do
    case fetch(table, key) do
      {:ok, value} -> value
      :error -> nil
    end
  end

  @doc """
  Lists all values in the given `table`.
  """
  @spec list(table()) :: [value()]
  def list(table) do
    GenServer.call(__MODULE__, {:list, table})
  end

  @doc false
  @impl true
  def init(state) do
    {:ok, state}
  end

  @doc false
  @impl true
  def handle_call({:put, table, key, value}, _from, state) do
    state = ensure_table!(state, table)

    :dets.insert(table, {key, value})
    {:reply, :ok, state}
  end

  @doc false
  @impl true
  def handle_call({:fetch, table, key}, _from, state) do
    state = ensure_table!(state, table)

    case :dets.lookup(table, key) do
      [{^key, value}] -> {:reply, {:ok, value}, state}
      [] -> {:reply, :error, state}
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
  def terminate(_reason, state) do
    state 
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