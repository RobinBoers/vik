defmodule VikWeb.ShardController do
  @moduledoc false
  use VikWeb, :controller

  alias Vik.Repo
  alias Vik.Store
  alias Vik.Shard
  alias Vik.Compiled

  import Structo

  def execute(conn, %{"slug" => slug}) do
    case Repo.get_by(Shard, slug: slug) do
      %Shard{} = shard -> try_execute(conn, shard)
      nil -> raise Vik.ShardNotFound, slug
    end
  end

  defp try_execute(conn, shard) do
    if module = find_callable(shard) do
      module.call(conn, [])
    else
      raise Vik.ShardNotExposed, shard
    end
  end

  defp find_callable(~m{:Shard, slug}) do
    case Store.fetch(slug) do
      {:ok, data} -> check_callable(data)
      :error -> raise Vik.ShardNotAlive, slug
    end
  end

  defp check_callable(~m{:Compiled, module}) do
    if function_exported?(module, :call, 2), do: module
  end
end