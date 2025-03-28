defmodule Iclash.DomainTypes.PlayerTest do
  use Iclash.DataCase, async: true

  alias Iclash.DomainTypes.Player, as: Player
  alias Iclash.Repo.Schemas.Player, as: PlayerSchema

  setup do
    now = ~U[2025-08-08 12:00:00.000000Z]

    heroes = [
      %{
        player_tag: "#P1",
        name: "HERO 1",
        level: 50,
        max_level: 100,
        village: "home",
        inserted_at: now,
        updated_at: now
      },
      %{
        player_tag: "#P1",
        name: "HERO 2",
        level: 80,
        max_level: 100,
        village: "home",
        inserted_at: now,
        updated_at: now
      }
    ]

    hero_equipment = [
      %{
        player_tag: "#P1",
        name: "HERO EQUIPMENT 1",
        level: 50,
        max_level: 100,
        village: "home",
        inserted_at: now,
        updated_at: now
      }
    ]

    troops = [
      %{
        player_tag: "#P1",
        name: "TROOP 1",
        level: 50,
        max_level: 100,
        village: "home",
        inserted_at: now,
        updated_at: now
      }
    ]

    spells = [
      %{
        player_tag: "#P1",
        name: "SPELL 1",
        level: 50,
        max_level: 100,
        village: "home",
        inserted_at: now,
        updated_at: now
      }
    ]

    legend_statistics = [
      %{
        id: "2025-01",
        rank: 10,
        trophies: 100,
        inserted_at: now,
        updated_at: now
      }
    ]

    {:ok, player} =
      %{
        tag: "#P1",
        name: "PLAYER 1",
        trophies: 100,
        town_hall_level: 17,
        best_trophies: 100,
        war_stars: 10,
        attack_wins: 10,
        defense_wins: 10,
        exp_level: 100,
        role: "admin",
        war_preference: "in",
        heroes: heroes,
        hero_equipment: hero_equipment,
        troops: troops,
        spells: spells,
        legend_statistics: legend_statistics,
        inserted_at: now,
        updated_at: now
      }
      |> PlayerSchema.from_map()

    %{now: now, player: player}
  end

  describe "get_player/1" do
    test "gets a player and return player struct", %{player: player} do
      {:ok, inserted_player} = Player.upsert_player(player)
      player_form_db = Player.get_player(player.tag)
      assert inserted_player == player_form_db
    end

    test "gets a player and return error tuple if not found", %{player: player} do
      result = Player.get_player(player.tag)
      assert result == {:error, :not_found}
    end
  end

  describe "upsert_player/1" do
    test "creates a player", %{player: player} do
      {:ok, player_form_db} = Player.upsert_player(player)
      assert player_form_db == Player.get_player(player.tag)
    end

    test "updates a player", %{player: player} do
      new_name = "NEW NAME"
      updated_player = Map.put(player, :name, new_name)

      {:ok, _player_from_db} = Player.upsert_player(player)
      {:ok, updated_player} = Player.upsert_player(updated_player)

      assert updated_player.name == new_name
    end

    test "updates a player updated_at and keeps inserted_at", %{player: player} do
      new_name = "NEW NAME"
      # Instead of keeping the fixed timestamps from the player passed through the setup function,
      # the timestamps should be set to nil to let Ecto handle them internally.
      updated_player =
        player
        |> Map.put(:name, new_name)
        |> Map.put(:updated_at, nil)
        |> Map.put(:insterted_at, nil)

      {:ok, player_from_db} = Player.upsert_player(player)
      {:ok, updated_player} = Player.upsert_player(updated_player)

      assert player_from_db.updated_at != updated_player.updated_at
      assert player_from_db.inserted_at == updated_player.inserted_at
    end

    test "keeps track of changes in player associated heroes", %{now: now, player: player} do
      eigth_minutes_later = DateTime.add(now, 8, :minute)
      new_hero_name = "NEW HERO"

      heroes_to_update = [
        # New hero, now database should have 3 heroes.
        %{
          player_tag: "#P1",
          name: new_hero_name,
          level: 100,
          max_level: 100,
          village: "home",
          inserted_at: eigth_minutes_later,
          updated_at: eigth_minutes_later
        },
        # Update existing hero level, now database should have 4 heroes.
        # Keeping the previous record for this hero and persisting the updated one.
        %{
          player_tag: "#P1",
          name: "HERO 1",
          level: 100,
          max_level: 100,
          village: "home",
          inserted_at: eigth_minutes_later,
          updated_at: eigth_minutes_later
        }
      ]

      # Workaround to append new heroes into the player struct (defined in setup).
      {:ok, player_to_update} =
        player
        |> PlayerSchema.to_map()
        |> Map.put(:heroes, heroes_to_update)
        |> PlayerSchema.from_map()

      {:ok, player_from_db} = Player.upsert_player(player)
      {:ok, updated_player} = Player.upsert_player(player_to_update)

      # Assert 2 heroes after initial player insertion.
      assert length(player_from_db.heroes) == 2
      # Assert 4 records in DB. 2 existing heroes, 1 new hero and 1 updated hero.
      assert length(updated_player.heroes) == 4
      assert Enum.any?(updated_player.heroes, fn hero -> hero.name == new_hero_name end)
    end

    test "updates associated player heroes updated_at and keeps inserted_at", %{
      now: now,
      player: player
    } do
      eigth_minutes_later = DateTime.add(now, 8, :minute)

      heroes_to_update = [
        # When a data refresh is performed but, the heroes data is the same.
        # The record should be updated with the new timestamp.
        # This record must be the same as the one in the setup (except for the timestamps).
        %{
          player_tag: "#P1",
          name: "HERO 1",
          level: 50,
          max_level: 100,
          village: "home",
          inserted_at: eigth_minutes_later,
          updated_at: eigth_minutes_later
        }
      ]

      # Workaround to append new heroes into the player struct (defined in setup).
      {:ok, player_to_update} =
        player
        |> PlayerSchema.to_map()
        |> Map.put(:heroes, heroes_to_update)
        |> PlayerSchema.from_map()

      {:ok, player_from_db} = Player.upsert_player(player)
      {:ok, updated_player} = Player.upsert_player(player_to_update)

      hero_1 = Enum.find(player_from_db.heroes, fn hero -> hero.name == "HERO 1" end)
      updated_hero_1 = Enum.find(updated_player.heroes, fn hero -> hero.name == "HERO 1" end)

      assert hero_1.updated_at != updated_hero_1.updated_at
      assert hero_1.inserted_at == updated_hero_1.inserted_at
    end

    test "keeps track of changes in player associated troops", %{now: now, player: player} do
      eigth_minutes_later = DateTime.add(now, 8, :minute)
      new_troop_name = "NEW TROOP"

      troops_to_update = [
        # New troop, now database should have 2 troops.
        %{
          player_tag: "#P1",
          name: new_troop_name,
          level: 100,
          max_level: 100,
          village: "home",
          inserted_at: eigth_minutes_later,
          updated_at: eigth_minutes_later
        },
        # Update existing troop level, now database should have 3 troops.
        # Keeping the previous record for this troop and persisting the updated one.
        %{
          player_tag: "#P1",
          name: "TROOP 1",
          level: 100,
          max_level: 100,
          village: "home",
          inserted_at: eigth_minutes_later,
          updated_at: eigth_minutes_later
        }
      ]

      # Workaround to append new troops into the player struct (defined in setup).
      {:ok, player_to_update} =
        player
        |> PlayerSchema.to_map()
        |> Map.put(:troops, troops_to_update)
        |> PlayerSchema.from_map()

      {:ok, player_from_db} = Player.upsert_player(player)
      {:ok, updated_player} = Player.upsert_player(player_to_update)

      # Assert 1 troop after initial player insertion.
      assert length(player_from_db.troops) == 1
      # Assert 3 records in DB. 1 existing troop, 1 new troop and 1 updated troop.
      assert length(updated_player.troops) == 3
      assert Enum.any?(updated_player.troops, fn troop -> troop.name == new_troop_name end)
    end

    test "updates associated player troops updated_at and keeps inserted_at", %{
      now: now,
      player: player
    } do
      eigth_minutes_later = DateTime.add(now, 8, :minute)

      troops_to_update = [
        # When a data refresh is performed but, the troop data is the same.
        # The record should be updated with the new timestamp.
        # This record must be the same as the one in the setup (except for the timestamps).
        %{
          player_tag: "#P1",
          name: "TROOP 1",
          level: 50,
          max_level: 100,
          village: "home",
          inserted_at: eigth_minutes_later,
          updated_at: eigth_minutes_later
        }
      ]

      # Workaround to append new troops into the player struct (defined in setup).
      {:ok, player_to_update} =
        player
        |> PlayerSchema.to_map()
        |> Map.put(:troops, troops_to_update)
        |> PlayerSchema.from_map()

      {:ok, player_from_db} = Player.upsert_player(player)

      {:ok, updated_player} =
        Player.upsert_player(player_to_update)

      troop_1 = Enum.find(player_from_db.troops, fn troop -> troop.name == "TROOP 1" end)
      updated_troop_1 = Enum.find(updated_player.troops, fn troop -> troop.name == "TROOP 1" end)

      assert troop_1.updated_at != updated_troop_1.updated_at
      assert troop_1.inserted_at == updated_troop_1.inserted_at
    end

    test "keeps track of changes in player associated spells", %{now: now, player: player} do
      eigth_minutes_later = DateTime.add(now, 8, :minute)
      new_spell_name = "NEW SPELL"

      spells_to_update = [
        # New spell, now database should have 2 spells.
        %{
          player_tag: "#P1",
          name: new_spell_name,
          level: 100,
          max_level: 100,
          village: "home",
          inserted_at: eigth_minutes_later,
          updated_at: eigth_minutes_later
        },
        # Update existing spell level, now database should have 3 spells.
        # Keeping the previous record for this spell and persisting the updated one.
        %{
          player_tag: "#P1",
          name: "SPELL 1",
          level: 100,
          max_level: 100,
          village: "home",
          inserted_at: eigth_minutes_later,
          updated_at: eigth_minutes_later
        }
      ]

      # Workaround to append new spells into the player struct (defined in setup).
      {:ok, player_to_update} =
        player
        |> PlayerSchema.to_map()
        |> Map.put(:spells, spells_to_update)
        |> PlayerSchema.from_map()

      {:ok, player_from_db} = Player.upsert_player(player)
      {:ok, updated_player} = Player.upsert_player(player_to_update)

      # Assert 1 spell after initial player insertion.
      assert length(player_from_db.spells) == 1
      # Assert 3 records in DB. 1 existing spell, 1 new spell and 1 updated spell.
      assert length(updated_player.spells) == 3
      assert Enum.any?(updated_player.spells, fn spell -> spell.name == new_spell_name end)
    end

    test "updates associated player spells updated_at and keeps inserted_at", %{
      now: now,
      player: player
    } do
      eigth_minutes_later = DateTime.add(now, 8, :minute)

      spells_to_update = [
        # When a data refresh is performed but, the spell data is the same.
        # The record should be updated with the new timestamp.
        # This record must be the same as the one in the setup (except for the timestamps).
        %{
          player_tag: "#P1",
          name: "SPELL 1",
          level: 50,
          max_level: 100,
          village: "home",
          inserted_at: eigth_minutes_later,
          updated_at: eigth_minutes_later
        }
      ]

      # Workaround to append new spells into the player struct (defined in setup).
      {:ok, player_to_update} =
        player
        |> PlayerSchema.to_map()
        |> Map.put(:spells, spells_to_update)
        |> PlayerSchema.from_map()

      {:ok, player_from_db} = Player.upsert_player(player)
      {:ok, updated_player} = Player.upsert_player(player_to_update)

      spell_1 = Enum.find(player_from_db.spells, fn spell -> spell.name == "SPELL 1" end)
      updated_spell_1 = Enum.find(updated_player.spells, fn spell -> spell.name == "SPELL 1" end)

      assert spell_1.updated_at != updated_spell_1.updated_at
      assert spell_1.inserted_at == updated_spell_1.inserted_at
    end
  end

  test "keeps track of changes in player associated hero equipment", %{now: now, player: player} do
    eigth_minutes_later = DateTime.add(now, 8, :minute)
    new_he_name = "NEW HERO EQUIPMENT"

    he_to_update = [
      # New HE, now database should have 2 HE.
      %{
        player_tag: "#P1",
        name: new_he_name,
        level: 100,
        max_level: 100,
        village: "home",
        inserted_at: eigth_minutes_later,
        updated_at: eigth_minutes_later
      },
      # Update existing HE level, now database should have 3 HE.
      # Keeping the previous record for this HE and persisting the updated one.
      %{
        player_tag: "#P1",
        name: "HERO EQUIPMENT 1",
        level: 100,
        max_level: 100,
        village: "home",
        inserted_at: eigth_minutes_later,
        updated_at: eigth_minutes_later
      }
    ]

    # Workaround to append new HE into the player struct (defined in setup).
    {:ok, player_to_update} =
      player
      |> PlayerSchema.to_map()
      |> Map.put(:hero_equipment, he_to_update)
      |> PlayerSchema.from_map()

    {:ok, player_from_db} = Player.upsert_player(player)
    {:ok, updated_player} = Player.upsert_player(player_to_update)

    # Assert 1 HE after initial player insertion.
    assert length(player_from_db.hero_equipment) == 1
    # Assert 3 records in DB. 1 existing HE, 1 new HE and 1 updated HE.
    assert length(updated_player.hero_equipment) == 3
    assert Enum.any?(updated_player.hero_equipment, fn he -> he.name == new_he_name end)
  end

  test "updates associated player hero equipment updated_at and keeps inserted_at", %{
    now: now,
    player: player
  } do
    eigth_minutes_later = DateTime.add(now, 8, :minute)

    he_to_update = [
      # When a data refresh is performed but, the HE data is the same.
      # The record should be updated with the new timestamp.
      # This record must be the same as the one in the setup (except for the timestamps).
      %{
        player_tag: "#P1",
        name: "HERO EQUIPMENT 1",
        level: 50,
        max_level: 100,
        village: "home",
        inserted_at: eigth_minutes_later,
        updated_at: eigth_minutes_later
      }
    ]

    # Workaround to append new he into the player struct (defined in setup).
    {:ok, player_to_update} =
      player
      |> PlayerSchema.to_map()
      |> Map.put(:hero_equipment, he_to_update)
      |> PlayerSchema.from_map()

    {:ok, player_from_db} = Player.upsert_player(player)
    {:ok, updated_player} = Player.upsert_player(player_to_update)

    he_1 = Enum.find(player_from_db.hero_equipment, fn he -> he.name == "HERO EQUIPMENT 1" end)

    updated_he_1 =
      Enum.find(updated_player.hero_equipment, fn he -> he.name == "HERO EQUIPMENT 1" end)

    assert he_1.updated_at != updated_he_1.updated_at
    assert he_1.inserted_at == updated_he_1.inserted_at
  end

  test "keeps track of changes in player associated legend statistics", %{
    now: now,
    player: player
  } do
    eigth_minutes_later = DateTime.add(now, 8, :minute)
    new_trophies = 150

    ls_to_update = [
      # New LS, now database should have 2 LS.
      %{
        id: "2025-02",
        rank: 10,
        trophies: 100,
        inserted_at: eigth_minutes_later,
        updated_at: eigth_minutes_later
      },
      # Update existing LS, now database should have 2 LS.
      %{
        id: "2025-01",
        rank: 10,
        trophies: new_trophies,
        inserted_at: eigth_minutes_later,
        updated_at: eigth_minutes_later
      }
    ]

    # Workaround to append new LS into the player struct (defined in setup).
    {:ok, player_to_update} =
      player
      |> PlayerSchema.to_map()
      |> Map.put(:legend_statistics, ls_to_update)
      |> PlayerSchema.from_map()

    {:ok, player_from_db} = Player.upsert_player(player)
    {:ok, updated_player} = Player.upsert_player(player_to_update)

    # Assert 1 HE after initial player insertion.
    assert length(player_from_db.legend_statistics) == 1
    # Assert 3 records in DB. 1 existing HE, and 1 updated HE.
    assert length(updated_player.legend_statistics) == 2
    assert Enum.any?(updated_player.legend_statistics, fn ls -> ls.trophies == new_trophies end)
  end

  test "updates associated player legend statistics updated_at and keeps inserted_at", %{
    now: now,
    player: player
  } do
    eigth_minutes_later = DateTime.add(now, 8, :minute)
    new_trophies = 150

    ls_to_update = [
      # When a data refresh is performed but, the LS data is the same.
      # The record should be updated with the new timestamp.
      %{
        id: "2025-01",
        rank: 10,
        trophies: new_trophies,
        inserted_at: eigth_minutes_later,
        updated_at: eigth_minutes_later
      }
    ]

    # Workaround to append new LS into the player struct (defined in setup).
    {:ok, player_to_update} =
      player
      |> PlayerSchema.to_map()
      |> Map.put(:legend_statistics, ls_to_update)
      |> PlayerSchema.from_map()

    {:ok, player_from_db} = Player.upsert_player(player)
    {:ok, updated_player} = Player.upsert_player(player_to_update)

    he_1 = Enum.find(player_from_db.legend_statistics, fn ls -> ls.trophies == 100 end)
    updated_he_1 = Enum.find(updated_player.legend_statistics, fn he -> he.trophies == 150 end)

    assert he_1.updated_at != updated_he_1.updated_at
    assert he_1.inserted_at == updated_he_1.inserted_at
  end
end
