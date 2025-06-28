defmodule Vik.ShardNotFound do
  @moduledoc """
  Raised when a `Vik.Shard` cannot be found in the database.
  """
  defexception [:slug, plug_status: 404]

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
    do: "Shard '#{exception.slug}' was not found."
end
