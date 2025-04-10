defmodule Iclash.DomainTypes.ClanWarTest do
  use Iclash.DataCase, async: true

  import Mox

  alias Iclash.DomainTypes.ClanWar, as: ClanWar
  alias Iclash.Repo.Schemas.ClanWar, as: ClanWarSchema

  setup do
    now = ~U[2025-08-08 12:00:00.000000Z]
    tomorrow = ~U[2025-08-09 12:00:00.000000Z]

    attacks = [
      %{
        clan_tag: "C1",
        opponent: "C2",
        war_start_time: now,
        attacker_tag: "#P1",
        defender_tag: "#P2",
        stars: 3,
        destruction_percentage: 100,
        order: 1,
        duration: 100,
        inserted_at: now,
        updated_at: now
      }
    ]

    {:ok, clan_war} =
      %{
        clan_tag: "#C1",
        opponent: "#C2",
        state: :in_war,
        start_time: now,
        end_time: tomorrow,
        attacks: attacks,
        inserted_at: now,
        updated_at: now
      }
      |> ClanWarSchema.from_map()

    %{now: now, end_time: tomorrow, clan_war: clan_war}
  end

  describe "get_clan_wars/1" do
    test "returns a list of clan wars", %{clan_war: clan_war} do
      {:ok, _} = ClanWar.upsert_clan_war(clan_war)
      clan_wars_form_db = ClanWar.get_clan_wars(clan_war.clan_tag)
      assert is_list(clan_wars_form_db)
    end

    test "returns multiple clan wars", %{clan_war: clan_war} do
      {:ok, _} = ClanWar.upsert_clan_war(clan_war)
      {:ok, _} = ClanWar.upsert_clan_war(Map.put(clan_war, :opponent, "#C3"))
      clan_wars_form_db = ClanWar.get_clan_wars(clan_war.clan_tag)
      assert length(clan_wars_form_db) == 2
    end

    test "gets clan wars and return ClanWar structs", %{clan_war: clan_war} do
      {:ok, inserted_clan_war} = ClanWar.upsert_clan_war(clan_war)
      clan_wars_form_db = ClanWar.get_clan_wars(clan_war.clan_tag)
      assert inserted_clan_war == clan_wars_form_db
    end

    test "do not fetch clan_war's data from clash api if clan_war is found in db", %{
      clan_war: clan_war
    } do
      MockClashApi |> expect(:fetch_current_war, 0, fn _ -> {:ok, clan_war} end)
      {:ok, inserted_clan_war} = ClanWar.upsert_clan_war(clan_war)
      clan_wars_form_db = ClanWar.get_clan_wars(clan_war.clan_tag)
      assert inserted_clan_war == clan_wars_form_db
    end

    test "fetch clan_war's data from clash api if not found in db", %{clan_war: clan_war} do
      MockClashApi |> expect(:fetch_current_war, fn _ -> {:ok, clan_war} end)
      assert clan_war == ClanWar.get_clan_wars(clan_war.clan_tag)
    end

    test "return error tuple if not found in db and clash api", %{clan_war: clan_war} do
      mock_response = {:error, {:http_error, %Req.Response{}}}
      MockClashApi |> expect(:fetch_current_war, fn _ -> mock_response end)
      assert {:error, :not_found} == ClanWar.get_clan_wars(clan_war.clan_tag)
    end
  end

  describe "upsert_clan_war/1" do
    test "creates a clan war", %{clan_war: clan_war} do
      {:ok, clan_wars_form_db} = ClanWar.upsert_clan_war(clan_war)
      assert clan_wars_form_db == ClanWar.get_clan_wars(clan_war.clan_tag)
    end

    test "updates a clan war updated_at and keeps inserted_at", %{clan_war: clan_war} do
      new_name = "NEW NAME"

      # Instead of keeping the fixed timestamps from the clan_war passed through the setup function,
      # the timestamps should be set to nil to let Ecto handle them internally.
      updated_clan_war =
        clan_war
        |> Map.put(:name, new_name)
        |> Map.put(:updated_at, nil)
        |> Map.put(:insterted_at, nil)

      {:ok, [clan_war_from_db]} = ClanWar.upsert_clan_war(clan_war)
      {:ok, [updated_clan_war]} = ClanWar.upsert_clan_war(updated_clan_war)

      assert clan_war_from_db.updated_at != updated_clan_war.updated_at
      assert clan_war_from_db.inserted_at == updated_clan_war.inserted_at
    end

    test "updates clan war attacks", %{clan_war: clan_war, now: now} do
      # TODO: try a parametrized test with different fields
      new_attacks = [
        %{
          clan_tag: "#C1",
          opponent: "#C2",
          war_start_time: now,
          attacker_tag: "#P1",
          defender_tag: "#P2",
          stars: 3,
          destruction_percentage: 100,
          order: 1,
          duration: 100,
          inserted_at: now,
          updated_at: now
        },
        %{
          clan_tag: "#C1",
          opponent: "#C2",
          war_start_time: now,
          attacker_tag: "#P1",
          defender_tag: "#P3",
          stars: 3,
          destruction_percentage: 100,
          order: 2,
          duration: 100,
          inserted_at: now,
          updated_at: now
        }
      ]

      {:ok, updated_clan_war} =
        clan_war
        |> ClanWarSchema.to_map()
        |> Map.put(:attacks, new_attacks)
        |> ClanWarSchema.from_map()

      {:ok, _clan_war_from_db} = ClanWar.upsert_clan_war(clan_war)
      {:ok, [updated_clan_wars]} = ClanWar.upsert_clan_war(updated_clan_war)
      assert clan_war != updated_clan_wars
      assert length(updated_clan_wars.attacks) == 2

      assert ClanWarSchema.to_map(updated_clan_wars).attacks ==
               ClanWarSchema.to_map(updated_clan_war).attacks
    end

    test "updates a clan war attack updated_at and keeps inserted_at", %{
      clan_war: clan_war,
      now: now
    } do
      new_attacks = [
        %{
          clan_tag: "#C1",
          opponent: "#C2",
          war_start_time: now,
          attacker_tag: "#P1",
          defender_tag: "#P2",
          stars: 3,
          destruction_percentage: 100,
          order: 1,
          duration: 100,
          inserted_at: nil,
          updated_at: nil
        }
      ]

      {:ok, updated_clan_war} =
        clan_war
        |> ClanWarSchema.to_map()
        |> Map.put(:attacks, new_attacks)
        |> ClanWarSchema.from_map()

      {:ok, _clan_war_from_db} = ClanWar.upsert_clan_war(clan_war)
      {:ok, [updated_clan_wars]} = ClanWar.upsert_clan_war(updated_clan_war)

      assert hd(updated_clan_wars.attacks).updated_at != updated_clan_wars.inserted_at
      assert hd(updated_clan_wars.attacks).inserted_at == updated_clan_wars.inserted_at
    end
  end
end
