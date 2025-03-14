defmodule VikWeb.ShardController do
  @moduledoc false
  use VikWeb, :controller

  alias Vik.Store
  alias Vik.Compiled

  import Structo

  def execute(conn, %{"slug" => slug}) do
    case Store.fetch(slug) do
      :error ->
        send_resp(conn, 404, "Shard not found.")

      {:ok, ~m{:Compiled, module}} ->
        if function_exported?(module, :call, 2) do
          module.call(conn, [])
        else
          send_resp(conn, 404, "Shard does not expose a Plug.")
        end
    end
  end
end