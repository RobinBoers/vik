defmodule Vik.ShardNotAlive do
  @moduledoc """
  Raised when a `Vik.Shard` is being accessed via HTTP, and
  it's available in the database, but not (yet) compiled.

  This occurs when the Shard cannot compile and the app restarts,
  thereby deleting the stale module from runtime.
  """
  defexception [:slug, plug_status: 502]

  @impl true
  def exception(%Vik.Shard{} = shard) do
    %__MODULE__{slug: shard.slug}
  end

  @impl true
  def exception(slug) when is_binary(slug) do
    %__MODULE__{slug: slug}
  end

  @impl true
  def message(%__MODULE__{} = exception),
    do: "Shard '#{exception.slug}' is not alive."
end
