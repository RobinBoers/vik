defmodule Vik.ShardNotExposed do
  @moduledoc """
  Raised when a Shard is being accessed via its HTTP, but
  it does not provide a top-level `call/2` function.
  """
  defexception [:slug, plug_status: 403]

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
    do: "Shard '#{exception.slug}' does not expose a Plug."
end
