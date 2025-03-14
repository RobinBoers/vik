defmodule Vik.Store do
  @moduledoc """
  The Store is a key-value store that holds the compile
  results (`Vik.Compiled`) by shard slug.
  """
  
  alias Vik.Repo
  alias Vik.Shard
  alias Vik.Compiled
  alias __MODULE__.Server

  @spec fetch(Vik.slug()) :: {:ok, Compiled.t()} | {:error, term()}
  def fetch(slug) do
    GenServer.call(Server, {:fetch, slug})
  end

  @spec fetch!(Vik.slug()) :: Compiled.t()
  def fetch!(slug) do
    case fetch(slug) do
      {:ok, compiled} -> compiled
      :error -> raise KeyError, key: slug
    end
  end

  @spec status(Vik.slug()) :: :up | :down | :stale
  def status(slug) do
    GenServer.call(Server, {:status, slug})
  end

  @spec ensure_compiled!(Vik.slug()) :: Compiled.t()
  def ensure_compiled!(slug) do
    GenServer.call(Server, {:ensure_compiled, slug}, :infinity)
  end

  @spec mark_stale(Vik.slug()) :: :ok
  def mark_stale(slug) do
    GenServer.cast(Server, {:mark_stale, slug})
  end

  @spec compile!(Vik.slug()) :: :ok
  def compile!(slug) do
    GenServer.cast(Server, {:compile, slug})
  end

  @spec recompile!(Vik.slug()) :: :ok
  def recompile!(slug) do
    GenServer.cast(Server, {:recompile, slug})
  end

  @doc false
  defdelegate child_spec(opts), to: Server

  defmodule Server do
    @moduledoc false
    use GenServer

    require Logger

    def start_link(opts) when is_list(opts) do
      GenServer.start_link(__MODULE__, opts, name: __MODULE__)
    end

    @impl true
    def init(opts) do
      {:ok, build_initial_state(opts)}
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
    def handle_call({:ensure_compiled, slug}, _from, state) do
      %Shard{} = shard = Repo.get_by(Shard, slug: slug)
      state = maybe_compile_and_insert(state, shard)

      {:reply, Map.fetch!(state, slug), state}
    end

    @impl true
    def handle_cast({:mark_stale, slug}, state) do
      if data = Map.get(state, slug) do
        {:noreply, Map.put(state, slug, Compiled.put_stale(data))}
      else
        {:noreply, state}
      end
    end

    @impl true
    def handle_cast({:compile, slug}, state) do
      %Shard{} = shard = Repo.get_by(Shard, slug: slug)
      {:noreply, maybe_compile_and_insert(state, shard)}
    end

    @impl true
    def handle_cast({:recompile, slug}, state) do
      %Shard{} = shard = Repo.get_by(Shard, slug: slug)
      {:noreply, compile_and_insert(state, shard)}
    end

    defp build_initial_state(_) do
      for %Shard{} = shard <- Repo.all(Shard), reduce: %{} do
        state -> maybe_compile_and_insert(state, shard)
      end
    end

    def resolve_status(state, slug) do
      case Map.get(state, slug) do
        %Compiled{stale?: true} -> :stale
        %Compiled{stale?: false} -> :up
        nil -> :down
      end
    end

    defp maybe_compile_and_insert(state, shard) do
      if Map.has_key?(state, shard.slug) do
        state
      else
        compile_and_insert(state, shard)
      end
    end

    defp compile_and_insert(state, shard) do
      case Vik.Compiler.compile(shard) do
        {:ok, result, exports} ->
          Map.put(state, shard.slug, Compiled.new(result, exports))

        {:error, exception} ->
          Logger.warning("Compiling shard #{shard.slug} failed, got: #{inspect(exception)}")
          
          if data = Map.get(state, shard.slug) do
            Map.put(state, shard.slug, Compiled.put_stale(data))
          else
            state
          end
      end
    end
  end
end