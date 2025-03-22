defmodule Iclash.Repo.Migrations.AddPlayersTable do
  use Ecto.Migration

  defmodule Iclash.Repo.Migrations.CreatePlayers do
    use Ecto.Migration

    def change do
      create table(:players, primary_key: false) do
        add :tag, :string, primary_key: true
        add :name, :string, null: false
        add :trophies, :integer, null: false
        add :town_hall_level, :integer, null: false
        add :best_trophies, :integer, null: false
        add :war_stars, :integer, null: false
        add :attack_wins, :integer, null: false
        add :defense_wins, :integer, null: false
        add :exp_level, :integer, null: false
        add :role, :string, null: false
        add :war_preference, :string, null: false

        timestamps(type: :utc_datetime_usec)
      end

      create unique_index(:players, [:tag])
    end
  end
end
