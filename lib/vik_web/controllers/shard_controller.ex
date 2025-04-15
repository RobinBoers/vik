defmodule VikWeb.ShardController do
  @moduledoc false
  use VikWeb, :controller

  alias Vik.Repo
  alias Vik.Store
  alias Vik.Shard
  alias Vik.Compiled
  alias Vik.PubSub

  import Structo

  plug :put_content_type

  def execute(conn, params) do
    {slug, params} = extract_slug(params)

    case Repo.get_by(Shard, slug: slug) do
      %Shard{} = shard -> try_execute(conn, params, shard)
      nil -> raise Vik.ShardNotFound, slug
    end
  end

  defp extract_slug(%{"path" => path} = params) do
    {slug, path} = extract_slug(path)
    {slug, %{params | "path" => path}}
  end

  defp extract_slug(path) when is_binary(path) do
    case String.split(path, "/", parts: 2) do
      [slug] -> {slug, "/"}
      [slug, path] -> {slug, path}
    end
  end

  defp try_execute(conn, params, shard) do
    case find_callable(shard) do
      {mod, [{f, 2}]} -> apply(mod, f, [conn, []])
      {mod, [{f, 3}]} -> apply(mod, f, [conn, params, []])
      nil -> raise Vik.ShardNotExposed, shard
    end
  rescue
    e ->
      Vik.Logger.exception(e, __STACKTRACE__)
      PubSub.broadcast(shard.slug, {:exception, e})

      reraise e, __STACKTRACE__
  end

  defp find_callable(~m{:Shard, slug}) do
    case Store.fetch(slug) do
      {:ok, data} -> extract_spec(data)
      :error -> raise Vik.ShardNotAlive, slug
    end
  end

  defp extract_spec(~m{:Compiled, module}) do
    if function_exported?(module, :__call__, 0) do
      {module, module.__call__()}
    end
  end

  # The shard can of course override this, but we need
  # to make sure we at least set the header. Otherwise,
  # the browser will assume application/ocet-stream, which
  # is almost never desired behaviour. JSON is a sane default.

  defp put_content_type(conn, _opts) do
    put_resp_content_type(conn, "application/json")
  end
end
