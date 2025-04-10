defmodule Iclash.Repo.Migrations.AddLegendStatisticsTable do
  use Ecto.Migration

  def change do
    create table(:legend_statistics, primary_key: false) do
      add :player_tag,
          references(:players,
            column: :tag,
            type: :string,
            on_delete: :delete_all,
            on_update: :update_all
          ),
          primary_key: true

      add :id, :string, primary_key: true
      add :rank, :integer
      add :trophies, :integer

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:legend_statistics, [:player_tag, :id])
  end
end
