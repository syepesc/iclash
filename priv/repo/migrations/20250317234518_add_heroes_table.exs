defmodule Iclash.Repo.Migrations.AddHeroesTable do
  use Ecto.Migration

  def change do
    create table(:heroes) do
      add :tag, references(:players, column: :tag, type: :string, on_delete: :delete_all),
        null: false

      add :name, :string, null: false
      add :level, :integer, null: false
      add :max_level, :integer, null: false
      add :village, :string, null: false
      timestamps(type: :utc_datetime_usec)
    end
  end
end
