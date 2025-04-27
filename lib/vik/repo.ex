defmodule Vik.Repo do
  use Ecto.Repo,
    otp_app: :vik,
    adapter: Ecto.Adapters.Postgres

  @doc """
  Deletes a struct using an arbitrary query.

  See `get_by!/2` and `delete!/2`.
  """
  @spec delete_by!(Ecto.Queryable.t(), Keyword.t() | map()) :: Ecto.Schema.t()
  def delete_by!(queryable, clauses) do
    queryable
    |> get_by!(clauses)
    |> delete!()
  end
end
