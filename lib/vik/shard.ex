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

  # Would conflict with native Vik routers, essentially
  # making the Shard uneditable.
  @illegal_slugs ["login", "new", "shell", "log"]

  def new_changeset(attrs \\ %{}) do
    %__MODULE__{}
    |> cast(attrs, [:slug, :title])
    |> validate_required([:slug, :title])
    |> validate_exclusion(:slug, @illegal_slugs, message: "is reserved")
    |> unique_constraint(:slug)
  end

  def save_changeset(shard, attrs \\ %{}) do
    cast(shard, attrs, [:source_code])
  end
end
