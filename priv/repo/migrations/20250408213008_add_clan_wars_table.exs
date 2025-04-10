defmodule Iclash.Repo.Migrations.AddClanWarsTable do
  use Ecto.Migration

  def change do
    create table(:clan_wars, primary_key: false) do
      add :clan_tag, :string, primary_key: true
      add :opponent, :string, primary_key: true
      add :state, :string, null: false
      add :start_time, :utc_datetime_usec, primary_key: true
      add :end_time, :utc_datetime_usec, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:clan_wars, [:clan_tag, :opponent, :start_time])
  end
end
