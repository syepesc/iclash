defmodule Iclash.Repo.Migrations.AddTroopsTable do
  use Ecto.Migration

  def change do
    create table(:troops, primary_key: false) do
      add :player_tag,
          references(:players,
            column: :tag,
            type: :string,
            on_delete: :delete_all,
            on_update: :update_all
          ),
          primary_key: true

      add :name, :string, primary_key: true
      add :level, :integer, primary_key: true
      add :max_level, :integer, null: false
      add :village, :string, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:troops, [:player_tag, :name, :level])
  end
end
