defmodule Vik.Store do
  @moduledoc """
  The Store is a key-value store that holds the compile
  results (`Vik.Result`) by slug.
  """

  alias Vik.Shard
  alias Vik.Result

  @type state :: %{Vik.slug() => Result.t()}
  @type status :: :up | :down | :stale

  alias __MODULE__.Server

  @spec all() :: %{Vik.slug() => Result.t()}
  def all do
    GenServer.call(Server, :all)
  end

  @spec fetch(Shard.t()) :: {:ok, Result.t()} | {:error, term()}
  @spec fetch(Vik.slug()) :: {:ok, Result.t()} | {:error, term()}
  def fetch(%Shard{} = shard), do: fetch(shard.slug)

  def fetch(slug) do
    GenServer.call(Server, {:fetch, slug})
  end

  @spec fetch!(Shard.t()) :: Result.t()
  @spec fetch!(Vik.slug()) :: Result.t()
  def fetch!(%Shard{} = shard), do: fetch!(shard.slug)

  def fetch!(slug) do
    case fetch(slug) do
      {:ok, compiled} -> compiled
      :error -> raise KeyError, key: slug
    end
  end

  @spec get(Shard.t()) :: Result.t() | nil
  @spec get(Vik.slug()) :: Result.t() | nil
  def get(%Shard{} = shard), do: get(shard.slug)

  def get(slug) do
    case fetch(slug) do
      {:ok, compiled} -> compiled
      :error -> nil
    end
  end

  @spec put(Shard.t(), Result.t()) :: :ok
  @spec put(Vik.slug(), Result.t()) :: :ok
  def put(%Shard{} = shard, data), do: put(shard.slug, data)

  def put(slug, data) do
    GenServer.cast(Server, {:put, slug, data})
  end

  @spec mark_stale(Shard.t()) :: :ok
  @spec mark_stale(Vik.slug()) :: :ok
  def mark_stale(%Shard{} = shard), do: mark_stale(shard.slug)

  def mark_stale(slug) do
    GenServer.cast(Server, {:mark_stale, slug})
  end

  @spec status(Shard.t()) :: status()
  @spec status(Vik.slug()) :: status()
  def status(%Shard{} = shard), do: status(shard.slug)

  def status(slug) do
    GenServer.call(Server, {:status, slug})
  end

  @doc false
  @spec child_spec(Enum.t()) :: Supervisor.child_spec()
  defdelegate child_spec(state), to: Server

  defmodule Server do
    @moduledoc false
    use GenServer

    @spec start_link(Enum.t()) :: :ok
    def start_link(opts) do
      GenServer.start_link(__MODULE__, opts, name: __MODULE__)
    end

    @impl true
    def init(opts) do
      {:ok, Map.new(opts)}
    end

    @impl true
    def handle_call(:all, _from, state) do
      {:reply, state, state}
    end

    @impl true
    def handle_call({:fetch, slug}, _from, state) do
      {:reply, Map.fetch(state, slug), state}
    end

    @impl true
    def handle_call({:status, slug}, _from, state) do
      {:reply, resolve_status(state, slug), state}
    end

    @impl true
    def handle_cast({:mark_stale, slug}, state) do
      if data = Map.get(state, slug) do
        {:noreply, Map.put(state, slug, Result.put_stale(data))}
      else
        {:noreply, state}
      end
    end

    @impl true
    def handle_cast({:put, slug, data}, state) do
      {:noreply, Map.put(state, slug, data)}
    end

    def resolve_status(state, slug) do
      case Map.get(state, slug) do
        %Result{stale?: true} -> :stale
        %Result{stale?: false} -> :up
        nil -> :down
      end
    end
  end
end
