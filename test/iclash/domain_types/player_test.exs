defmodule Iclash.DomainTypes.PlayerTest do
  use Iclash.DataCase, async: true

  alias Iclash.DomainTypes.Player, as: Player
  alias Iclash.Repo.Schemas.Player, as: PlayerSchema

  setup do
    heroes_map = [
      %{
        name: "HERO 1",
        level: 100,
        max_level: 100,
        village: "home"
      }
    ]

    player_map =
      %{
        tag: "#ABC123",
        name: "PLAYER 1",
        trophies: 100,
        town_hall_level: 17,
        best_trophies: 100,
        attack_wins: 10,
        defense_wins: 10,
        role: "admin",
        war_preference: "in",
        heroes: heroes_map
      }

    {:ok, player} = PlayerSchema.to_struct(player_map) |> IO.inspect(label: "struct --->")

    %{player: player}
  end

  describe "get_player/1" do
    test "Get a player from database", %{player: player} do
      Repo.insert(player) |> IO.inspect(label: "ADDED PLAYER")
      Repo.get(PlayerSchema, player.tag) |> IO.inspect(label: "QUERIED PLAYER")
      # Player.upsert_player(player)
      # assert player_form_db == Player.get_player(player.tag)
    end

    test "Get a player from databse return error tuple if not found", %{player: player} do
      result = Player.get_player(player.tag)
      assert result == {:error, :not_found}
    end
  end

  # describe "upsert_player/1" do
  #   test "Creates a player", %{player: player} do
  #     {:ok, player_form_db} = Player.create_player(player)
  #     assert player_form_db == Player.get_player(player.tag)
  #   end

  #   test "Updates a player", %{player: player} do
  #     new_name = "NEW PLAYER NAME"
  #     updated_player = Map.put(player, :name, new_name)

  #     {:ok, player_from_db} = Player.create_player(player)
  #     {:ok, updated_player_from_db} = Player.update_player(updated_player)

  #     assert updated_player_from_db.name == new_name
  #   end

  #   test "Updating a player change updated_at and keeps inserted_at", %{player: player} do
  #     new_name = "NEW PLAYER NAME"
  #     updated_player = Map.put(player, :name, new_name)

  #     {:ok, player_from_db} = Player.create_player(player)
  #     {:ok, updated_player_from_db} = Player.update_player(updated_player)

  #     assert player_from_db.updated_at != updated_player_from_db.updated_at
  #     assert player_from_db.inserted_at == updated_player_from_db.inserted_at
  #   end
  # end
end
