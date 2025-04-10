defmodule Iclash.Repo.Migrations.AddClanWarAttacksTable do
  use Ecto.Migration

  def up do
    create table(:clan_war_attacks, primary_key: false) do
      # This are the foreign keys from clan_wars table used as part of the composite primary key.
      add :clan_tag, :string, primary_key: true
      add :opponent, :string, primary_key: true
      add :war_start_time, :utc_datetime_usec, primary_key: true

      add :attacker_tag, :string, primary_key: true
      add :defender_tag, :string, primary_key: true
      add :stars, :integer, null: false
      add :destruction_percentage, :integer, null: false
      add :order, :integer, null: false
      add :duration, :integer, null: false

      timestamps(type: :utc_datetime_usec)
    end

    execute("""
    ALTER TABLE clan_war_attacks
    ADD CONSTRAINT clan_war_attacks_fk
    FOREIGN KEY (clan_tag, opponent, war_start_time)
    REFERENCES clan_wars (clan_tag, opponent, start_time)
    ON DELETE CASCADE
    ON UPDATE CASCADE
    """)

    create unique_index(:clan_war_attacks, [
             :clan_tag,
             :opponent,
             :war_start_time,
             :attacker_tag,
             :defender_tag
           ])
  end

  def down do
    execute("ALTER TABLE clan_war_attacks DROP CONSTRAINT clan_war_attacks_fk")
    drop table(:clan_war_attacks)
  end
end
