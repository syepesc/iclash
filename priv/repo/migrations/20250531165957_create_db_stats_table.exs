defmodule Iclash.Repo.Migrations.CreateDbStatsTable do
  use Ecto.Migration

  def change do
    create table(:db_stats) do
      add :table_name, :string
      add :row_count, :bigint
      add :table_size_mb, :bigint
      add :index_size_mb, :bigint
      add :collected_at, :utc_datetime_usec
    end
  end
end
