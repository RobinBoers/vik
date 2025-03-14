defmodule Vik.Repo.Migrations.AddShards do
  use Ecto.Migration

  def change do
    create table(:shards) do
      add :title, :string
      add :slug, :string
      add :source_code, :text

      timestamps()
    end

    create unique_index(:shards, [:slug])
  end
end
