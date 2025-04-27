defmodule Vik.Shard do
  @moduledoc """
  Shards are the building blocks of `Vik`. They are standalone
  snippets of code that are compiled into Elixir modules.

  They can define compile-time dependencies on other shards.
  """
  use Ecto.Schema

  import Ecto.Changeset

  schema "shards" do
    field :slug, :string
    field :title, :string
    field :source_code, :string

    timestamps()
  end

  @type t :: %__MODULE__{
          slug: String.t(),
          title: String.t(),
          source_code: String.t()
        }

  def new_changeset(attrs \\ %{}) do
    %__MODULE__{}
    |> cast(attrs, [:slug, :title])
    |> validate_required([:slug, :title])
    |> unique_constraint(:slug)
  end

  def save_changeset(shard, attrs \\ %{}) do
    cast(shard, attrs, [:source_code])
  end
end
