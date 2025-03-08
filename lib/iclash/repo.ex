defmodule Iclash.Repo do
  use Ecto.Repo,
    otp_app: :iclash,
    adapter: Ecto.Adapters.Postgres
end
