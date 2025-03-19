defmodule Iclash.DomainTypes.PlayerTest do
  use Iclash.DataCase, async: true

  alias Iclash.DomainTypes.Player, as: Player
  alias Iclash.Repo.Schemas.Player, as: PlayerSchema

  setup do
    now = ~U[2025-08-08 12:00:00.000000Z]

    heroes_map = [
      %{
        # "player_id" => "#P1",
        "name" => "HERO 1",
        "level" => 100,
        "max_level" => 100,
        "village" => "home",
        "inserted_at" => now,
        "updated_at" => now
      }
    ]

    player_map =
      %{
        "tag" => "#P1",
        "name" => "PLAYER 1",
        "trophies" => 100,
        "town_hall_level" => 17,
        "best_trophies" => 100,
        "attack_wins" => 10,
        "defense_wins" => 10,
        "role" => "admin",
        "war_preference" => "in",
        "heroes" => heroes_map,
        "inserted_at" => now,
        "updated_at" => now
      }

    %{player: player_map}
  end

  describe "get_player/1" do
    test "Gets a player from database return player struct", %{player: player} do
      %PlayerSchema{}
      |> PlayerSchema.changeset(player)
      |> IO.inspect(label: "CS -->")
      |> Repo.insert()

      {:ok, inserted_player} = Player.upsert_player(player)
      player_form_db = Player.get_player(player["tag"])
      assert player_form_db == inserted_player
    end

    test "Gets a player from databse return error tuple if not found", %{player: player} do
      result = Player.get_player(player["tag"])
      assert result == {:error, :not_found}
    end
  end

  # describe "upsert_player/1" do
  #   test "Creates a player", %{player: player} do
  #     {:ok, player_form_db} = Player.upsert_player(player)
  #     assert player_form_db == Player.get_player(player.tag)
  #   end

  #   test "Updates a player", %{player: player} do
  #     new_name = "NEW NAME"
  #     updated_player = Map.put(player, :name, new_name)

  #     {:ok, player_from_db} = Player.upsert_player(player)
  #     {:ok, updated_player_from_db} = Player.upsert_player(updated_player)

  #     assert updated_player_from_db.name == new_name
  #     assert Map.drop(player_from_db, [:name]) == Map.drop(updated_player_from_db, [:name])
  #   end

  #   test "Updates a player,  change updated_at and keeps inserted_at", %{player: player} do
  #     new_name = "NEW NAME"
  #     # Instead of keeping the fixed timestamps from the player passed through the setup function,
  #     # the timestamps should be set to nil to let Ecto handle them internally.
  #     updated_player =
  #       player
  #       |> Map.put(:name, new_name)
  #       |> Map.put(:updated_at, nil)
  #       |> Map.put(:insterted_at, nil)

  #     {:ok, player_from_db} = Player.upsert_player(player)
  #     {:ok, updated_player_from_db} = Player.upsert_player(updated_player)

  #     assert player_from_db.updated_at != updated_player_from_db.updated_at
  #     assert player_from_db.inserted_at == updated_player_from_db.inserted_at
  #   end

  #   # test "Updates a player heroes association", %{player: player} do
  #   #   new_hero_name = "NEW NAME"
  #   #   updated_heroe = Map.put(hd(player.heroes), :name, new_hero_name)
  #   #   updated_player = Map.put(player, :heroes, [updated_heroe])

  #   #   {:ok, player_from_db} = Player.upsert_player(player)
  #   #   {:ok, updated_player_from_db} = Player.upsert_player(updated_player)

  #   #   assert hd(updated_player_from_db.heroes).name == new_hero_name

  #   #   assert Map.drop(hd(player_from_db.heroes), [:name]) ==
  #   #            Map.drop(hd(updated_player_from_db.heroes), [:name])
  #   # end

  #   # test "Updating a player heroes association change updated_at and keeps inserted_at", %{
  #   #   player: player
  #   # } do
  #   #   new_hero_name = "NEW NAME"
  #   #   # Instead of keeping the fixed timestamps from the player passed through the setup function,
  #   #   # the timestamps should be set to nil to let Ecto handle them internally.
  #   #   updated_heroe =
  #   #     player.heroes
  #   #     |> hd()
  #   #     |> Map.put(:name, new_hero_name)
  #   #     |> Map.put(:updated_at, nil)
  #   #     |> Map.put(:insterted_at, nil)

  #   #   updated_player = Map.put(player, :heroes, [updated_heroe])

  #   #   {:ok, player_from_db} = Player.upsert_player(player)
  #   #   {:ok, updated_player_from_db} = Player.upsert_player(updated_player)

  #   #   assert hd(player_from_db.heroes).updated_at != hd(updated_player_from_db.heroes).updated_at

  #   #   assert hd(player_from_db.heroes).inserted_at ==
  #   #            hd(updated_player_from_db.heroes).inserted_at
  #   # end
  # end
end
