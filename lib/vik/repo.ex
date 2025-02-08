defmodule Vik.Repo do
  use Ecto.Repo,
    otp_app: :vik,
    adapter: Ecto.Adapters.Postgres
end
