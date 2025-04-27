defmodule Vik.Thread do
  @moduledoc """
  Manages compilation and side-effects.

  - Communicates with the LiveViews over PubSub to
    report on compiler logs, stale Shards etc.

  - Ensures the Store is properly populated with the
    results produced by the Compiler.

  """

  alias Vik.Shard
  alias Vik.Repo
  alias Vik.Compiled
  alias Vik.Compiler
  alias Vik.PubSub
  alias Vik.Store
  alias Vik.IO

  require Logger

  @spec ensure_compiled!(Shard.t()) :: Compiled.t()
  def ensure_compiled!(slug) when is_binary(slug) do
    Shard |> Repo.get_by!(slug: slug) |> ensure_compiled!()
  end

  def ensure_compiled!(%Shard{} = shard) do
    case Store.fetch(shard) do
      {:ok, %Compiled{} = c} -> c
      :error -> eval!(shard)
    end
  end

  @spec eval(Shard.t()) :: {:ok, Compiled.t()} | {:error, Exception.t()}
  def eval(%Shard{} = shard) do
    case evaluate_captured(shard) do
      {:ok, result, exports, includes} ->
        %Compiled{} = compiled =
          Compiled.new(result, exports, includes)

        Store.put(shard, compiled)
        PubSub.broadcast(shard.slug, {:status, :up})

        PubSub.broadcast(shard.slug, {:stdout, """
        Generated #{shard.slug} shard
        """})

        {:ok, compiled}

      {:error, exception} ->
        Logger.warning("Compilation of '#{shard.slug}' failed with: #{inspect(exception)}")

        Store.mark_stale(shard)
        PubSub.broadcast(shard.slug, {:exception, exception})
        PubSub.broadcast(shard.slug, {:status, :stale})

        {:failed, exception}
    end
  end

  @spec eval!(Shard.t()) :: Compiled.t()
  def eval!(%Shard{} = shard) do
    {result, exports, includes} = Compiler.eval!(shard)

    %Compiled{} = compiled =
      Compiled.new(result, exports, includes)

    Store.put(shard, compiled)
    PubSub.broadcast(shard.slug, {:status, :up})

    compiled
  end

  @spec mark_stale(Shard.t()) :: :ok
  def mark_stale(%Shard{} = shard) do
    if Store.status(shard) == :up do
      Store.mark_stale(shard.slug)
      PubSub.broadcast(shard.slug, {:status, :stale})
    end

    :ok
  end

  defp evaluate_captured(%Shard{} = shard) do
    PubSub.broadcast(shard.slug, {:stdout, """
    => Compiling #{shard.slug}
    """})

    {result, stdout, stderr} =
      IO.capture(fn -> Compiler.eval(shard) end)

    PubSub.broadcast(shard.slug, {:stdout, stdout})
    PubSub.broadcast(shard.slug, {:stderr, stderr})

    result
  end

  @spec provision() :: :ok
  def provision do
    for %Shard{} = shard <- Repo.all(Shard) do
      eval(shard)
    end
  end

  @doc false
  def child_spec(_) do
    %{
      id: Task,
      restart: :temporary,
      start: {Task, :start_link, [&provision/0]}
    }
  end
end
