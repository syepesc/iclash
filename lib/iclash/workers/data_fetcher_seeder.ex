defmodule Iclash.Workers.DataFetcherSeeder do
  @moduledoc """
  This module is responsible for the core functionality of data ingestion in the Iclash project.

  The current approach involves fetching the top 200 international clan tags by querying the rankings endpoint (200 clans is the max number returned by the API).
  These clan tags serve as the starting point for gathering data.

  Once the clan tags are retrieved, the system spawns worker processes to handle the following tasks:
  - Fetch detailed data about each clan, and their clan wars.
  - The clan fetcher workers will, in turn, spawn additional player fetcher workers to gather data about individual clan members (players).

  Note: Some clans and players are hardcoded into the system because their inclusion in the top 200 clans is uncertain.

  TODO: To expand the database further, consider querying the top 200 clans from various countries instead of limiting the scope to international clans.
  TODO: The current implementation statically queries only the top 200 clans and their associated players during the application's initialization.
        To enhance the data ingestion process, consider implementing a periodic update mechanism.
        This mechanism should not only re-fetch the top 200 clans but also include any additional clans and players already stored in the database.
        Remember to handle potential children duplicates in the DynamicSupervisor when a process is already alive.
  """

  use GenServer
  alias Iclash.ClashApi
  alias Iclash.Workers.ClanFetcher
  alias Iclash.Workers.ClanWarFetcher
  alias Iclash.Workers.PlayerFetcher
  require Logger

  @known_clans [
    # ATLIENS
    "#2Y9PLYGP9",
    # ATLIENS 2.0
    "#2QL9PRCPQ",
    # 51/50
    "#2QVOOJJJG"
  ]

  @known_players [
    # SYEPESC:
    "#QPPJLQUU",
    # SYEPESC III:
    "#P9LR2LY02",
    # ANGELO,
    "#2YGCUJYY",
    # TOPO,
    "#QO2RU2UY",
    # DOMINATOR
    "#2LGQRYPV",
    # TIG28
    "#8YYCVV2OC"
  ]

  def start_link(_args) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(:ok) do
    {:ok, locations} = ClashApi.fetch_locations()

    international_id =
      locations["items"]
      |> Enum.find(fn location -> location["name"] == "International" end)
      |> Map.get("id")

    {:ok, rankings} = international_id |> ClashApi.fetch_ranking_for_location()

    clan_tags =
      rankings["items"]
      |> Enum.map(& &1["tag"])
      |> Enum.concat(@known_clans)
      |> Enum.uniq()

    init_clan_fetcher_workers(clan_tags)
    init_clan_war_fetcher_workers(clan_tags)
    # We only fill known players, the rest are fetched by the clan fetcher process
    init_player_fetcher_workers(@known_players)
    {:ok, %{}}
  end

  defp init_clan_fetcher_workers(clan_tags) do
    Enum.each(clan_tags, fn clan_tag ->
      DynamicSupervisor.start_child(DynamicSupervisor.ClanFetcher, {ClanFetcher, clan_tag})
    end)
  end

  defp init_clan_war_fetcher_workers(clan_tags) do
    Enum.each(clan_tags, fn clan_tag ->
      DynamicSupervisor.start_child(DynamicSupervisor.ClanWarFetcher, {ClanWarFetcher, clan_tag})
    end)
  end

  defp init_player_fetcher_workers(player_tags) do
    Enum.each(player_tags, fn player_tag ->
      DynamicSupervisor.start_child(DynamicSupervisor.PlayerFetcher, {PlayerFetcher, player_tag})
    end)
  end
end
