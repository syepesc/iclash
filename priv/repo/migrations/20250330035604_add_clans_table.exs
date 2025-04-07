defmodule Iclash.Repo.Migrations.AddClansTable do
  use Ecto.Migration

  def change do
    create table(:clans, primary_key: false) do
      add :tag, :string, primary_key: true
      add :name, :string, null: false
      add :type, :string, null: false
      add :description, :string, null: false
      add :clan_level, :integer, null: false
      add :war_frequency, :string, null: false
      add :war_win_streak, :integer, null: false
      add :war_wins, :integer, null: false
      add :war_ties, :integer, null: false
      add :war_losses, :integer, null: false
      add :is_war_log_public, :boolean, null: false

      add :location, :map, null: false
      add :chat_language, :map, null: false

      add :member_list, :map, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:clans, [:tag])
  end
end
