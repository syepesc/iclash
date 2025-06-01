defmodule Iclash.Repo.Schemas.DbStat do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  @optional_fields []
  @required_fields [:table_name, :row_count, :table_size_mb, :index_size_mb, :collected_at]

  schema "db_stats" do
    field :table_name, :string
    field :row_count, :integer
    field :table_size_mb, :integer
    field :index_size_mb, :integer
    field :collected_at, :utc_datetime_usec
  end

  def changeset(stat, attrs \\ %{}) do
    stat
    |> cast(attrs, @optional_fields ++ @required_fields)
    |> validate_required(@required_fields)
  end
end
