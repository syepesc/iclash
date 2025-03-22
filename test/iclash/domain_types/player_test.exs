defmodule Iclash.DomainTypes.PlayerTest do
  use Iclash.DataCase, async: true

  alias Iclash.DomainTypes.Player, as: Player
  alias Iclash.Repo.Schemas.Player, as: PlayerSchema

  setup do
    now = ~U[2025-08-08 12:00:00.000000Z]

    heroes_map = [
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

    {:ok, player} =
      %{
        tag: "#P1",
        name: "PLAYER 1",
        trophies: 100,
        town_hall_level: 17,
        best_trophies: 100,
        attack_wins: 10,
        defense_wins: 10,
        role: "admin",
        war_preference: "in",
        heroes: heroes_map,
        inserted_at: now,
        updated_at: now
      }
      |> PlayerSchema.to_struct()

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
      {:ok, updated_player_from_db} = Player.upsert_player(updated_player)

      assert updated_player_from_db.name == new_name
    end

    test "updates a player, change updated_at and keeps inserted_at", %{player: player} do
      new_name = "NEW NAME"
      # Instead of keeping the fixed timestamps from the player passed through the setup function,
      # the timestamps should be set to nil to let Ecto handle them internally.
      updated_player =
        player
        |> Map.put(:name, new_name)
        |> Map.put(:updated_at, nil)
        |> Map.put(:insterted_at, nil)

      {:ok, player_from_db} = Player.upsert_player(player)
      {:ok, updated_player_from_db} = Player.upsert_player(updated_player)

      assert player_from_db.updated_at != updated_player_from_db.updated_at
      assert player_from_db.inserted_at == updated_player_from_db.inserted_at
    end

    test "updates player associated heroes", %{player: player} do
      new_hero_name = "NEW NAME"
      updated_heroe = Map.put(hd(player.heroes), :name, new_hero_name)
      updated_player = Map.put(player, :heroes, [updated_heroe])

      {:ok, player_from_db} = Player.upsert_player(player)
      {:ok, updated_player_from_db} = Player.upsert_player(updated_player)

      assert Enum.any?(updated_player_from_db.heroes, fn h -> h.name == new_hero_name end)

      assert Map.drop(hd(player_from_db.heroes), [:name]) ==
               Map.drop(hd(updated_player_from_db.heroes), [:name])
    end

    test "updates player associated heroes updated_at and keeps inserted_at", %{
      player: player
    } do
      new_hero_name = "NEW NAME"
      # Instead of keeping the fixed timestamps from the player passed through the setup function,
      # the timestamps should be set to nil to let Ecto handle them internally.
      updated_heroe =
        player.heroes
        |> hd()
        |> Map.put(:name, new_hero_name)
        |> Map.put(:updated_at, nil)
        |> Map.put(:insterted_at, nil)

      updated_player = Map.put(player, :heroes, [updated_heroe])

      {:ok, player_from_db} = Player.upsert_player(player)
      {:ok, updated_player_from_db} = Player.upsert_player(updated_player)

      assert hd(player_from_db.heroes).updated_at != hd(updated_player_from_db.heroes).updated_at

      assert hd(player_from_db.heroes).inserted_at ==
               hd(updated_player_from_db.heroes).inserted_at
    end

    test "keeps track of changes in player heroes", %{now: now, player: player} do
      new_heroes = [
        # New hero, now database shuold have 3 heroes.
        %{
          player_tag: "#P1",
          name: "HERO 3",
          level: 100,
          max_level: 100,
          village: "home",
          inserted_at: DateTime.add(now, 8, :minute),
          updated_at: DateTime.add(now, 8, :minute)
        },
        # Update existing hero level, now database shuold have 4 heroes counting the previous record for this hero.
        %{
          player_tag: "#P1",
          name: "HERO 2",
          level: 100,
          max_level: 100,
          village: "home",
          inserted_at: DateTime.add(now, 8, :minute),
          updated_at: DateTime.add(now, 8, :minute)
        }
      ]

      {:ok, new_player} =
        player
        |> PlayerSchema.to_map()
        |> Map.put(:heroes, new_heroes)
        |> PlayerSchema.to_struct()

      {:ok, player_from_db} = Player.upsert_player(player)
      {:ok, updated_player_from_db} = Player.upsert_player(new_player)

      # There should be 2 heroes after inserting the player.
      assert length(player_from_db.heroes) == 2
      # There should be 4 after updating. 2 existing heroes, 1 new hero and 1 updated hero.
      assert length(updated_player_from_db.heroes) == 4
    end
  end
end
