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
      {:ok, inserted_clan} = Clan.upsert_clan(clan)
      clan_form_db = Clan.get_clan(clan.tag)
      assert inserted_clan == clan_form_db
    end

    test "do not fetch clan's data from clash api if clan is found in db", %{clan: clan} do
      MockClashApi |> expect(:fetch_clan, 0, fn _ -> {:ok, clan} end)
      {:ok, inserted_clan} = Clan.upsert_clan(clan)
      clan_form_db = Clan.get_clan(clan.tag)
      assert inserted_clan == clan_form_db
    end

    test "fetch clan's data from clash api if not found in db", %{clan: clan} do
      MockClashApi |> expect(:fetch_clan, fn _ -> {:ok, clan} end)
      assert clan == Clan.get_clan(clan.tag)
    end

    test "return error tuple if not found in db and clash api", %{clan: clan} do
      MockClashApi |> expect(:fetch_clan, fn _ -> {:error, {:http_error, %Req.Response{}}} end)
      assert {:error, :not_found} == Clan.get_clan(clan.tag)
    end
  end

  describe "upsert_clan/1" do
    test "creates a clan", %{clan: clan} do
      {:ok, clan_form_db} = Clan.upsert_clan(clan)
      assert clan_form_db == Clan.get_clan(clan.tag)
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

      {:ok, _clan_from_db} = Clan.upsert_clan(clan)
      {:ok, updated_clan} = Clan.upsert_clan(updated_clan)

      assert clan != updated_clan
      assert ClanSchema.to_map(updated_clan).member_list == new_member_list
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

      {:ok, clan_from_db} = Clan.upsert_clan(clan)
      {:ok, updated_clan} = Clan.upsert_clan(updated_clan)

      assert clan_from_db.updated_at != updated_clan.updated_at
      assert clan_from_db.inserted_at == updated_clan.inserted_at
    end
  end
end
