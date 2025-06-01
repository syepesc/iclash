defmodule Iclash.DomainTypes.ClanTest do
  use Iclash.DataCase, async: true

  import Mox

  alias Iclash.DomainTypes.Clan, as: Clan
  alias Iclash.Repo.Schemas.Clan, as: ClanSchema

  setup do
    now = ~U[2025-08-08 12:00:00.000000Z]

    location = %{
      id: 1,
      name: "INTERNATIONAL"
    }

    chat_language = %{
      id: 1,
      name: "ENGLISH"
    }

    member_list = [
      %{
        tag: "#P1",
        name: "PLAYER 1",
        role: :leader,
        donations: 100,
        donations_received: 200,
        trophies: 1000,
        clan_rank: 1
      }
    ]

    {:ok, clan} =
      %{
        name: "CLAN NAME",
        tag: "#C1",
        type: :open,
        description: "CLAN DESCRIPTION",
        clan_level: 10,
        war_frequency: :always,
        war_win_streak: 10,
        war_wins: 10,
        war_ties: 10,
        war_losses: 10,
        is_war_log_public: true,
        location: location,
        chat_language: chat_language,
        member_list: member_list,
        inserted_at: now,
        updated_at: now
      }
      |> ClanSchema.from_map()

    %{now: now, clan: clan}
  end

  describe "get_clan/1" do
    test "gets a clan and return clan struct", %{clan: clan} do
      :ok = Clan.upsert_clan(clan)
      clan_from_db = Clan.get_clan(clan.tag)
      assert %ClanSchema{} = clan_from_db
    end

    test "return error tuple if not found in database", %{clan: clan} do
      assert {:error, :not_found} == Clan.get_clan(clan.tag)
    end
  end

  describe "upsert_clan/1" do
    test "creates a clan", %{clan: clan} do
      :ok = Clan.upsert_clan(clan)
      clan_from_db = Clan.get_clan(clan.tag)
      assert clan_from_db.tag == clan.tag
    end

    test "updates a clan", %{clan: clan} do
      # TODO: try a parametrized test with different fields
      new_member_list = [
        %{
          tag: "#P1",
          name: "PLAYER 1",
          role: :leader,
          donations: 100,
          donations_received: 200,
          trophies: 1000,
          clan_rank: 1
        },
        %{
          tag: "#P2",
          name: "PLAYER 2",
          role: :co_leader,
          donations: 100,
          donations_received: 200,
          trophies: 1000,
          clan_rank: 2
        }
      ]

      updated_clan = Map.put(clan, :member_list, new_member_list)

      :ok = Clan.upsert_clan(clan)
      {:ok, clan_from_db} = Clan.get_clan(clan.tag)

      :ok = Clan.upsert_clan(updated_clan)
      {:ok, updated_clan_from_db} = Clan.get_clan(updated_clan.tag)

      assert clan_from_db != updated_clan_from_db
      assert ClanSchema.to_map(updated_clan_from_db).member_list == new_member_list
    end

    test "updates a clan updated_at and keeps inserted_at", %{clan: clan} do
      new_name = "NEW NAME"
      # Instead of keeping the fixed timestamps from the clan passed through the setup function,
      # the timestamps should be set to nil to let Ecto handle them internally.
      updated_clan =
        clan
        |> Map.put(:name, new_name)
        |> Map.put(:updated_at, nil)
        |> Map.put(:insterted_at, nil)

      :ok = Clan.upsert_clan(clan)
      {:ok, clan_from_db} = Clan.get_clan(clan.tag)

      :ok = Clan.upsert_clan(updated_clan)
      {:ok, updated_clan_from_db} = Clan.get_clan(updated_clan.tag)

      assert clan_from_db.updated_at != updated_clan_from_db.updated_at
      assert clan_from_db.inserted_at == updated_clan_from_db.inserted_at
    end
  end
end
