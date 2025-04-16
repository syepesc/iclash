defmodule Iclash.Workers.DataFetcherSeeder do
  @moduledoc """
  This module is responsible for the core functionality of data ingestion in the Iclash project.

  The current approach involves fetching the top 200 international clan tags and the first 50 clans of each country
  by querying the rankings endpoint (200 clans is the max number returned by the API).
  These clan tags serve as the starting point for gathering data.

  Once the clan tags are retrieved, the system spawns worker processes to handle the following tasks:
  - Fetch detailed data about each clan, and their clan wars.
  - The clan fetcher workers will, in turn, spawn additional player and clan war fetcher workers to gather additional data.

  Note: Some clans and players are hardcoded into the system because their inclusion in the top 200/50 clans is uncertain.

  TODO: To expand the database further, consider querying the top 200 clans from various countries instead of just 50 (this will probably blowup clash api, lol).
  TODO: The current implementation statically queries only the top 200/50 clans and their associated players during the application's initialization.
        To enhance the data ingestion process, consider implementing a periodic update mechanism.
        This mechanism should not only re-fetch the top 200/50 clans but also include any additional clans and players already stored in the database.
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
    "#2QV00JJJG"
  ]

  @known_players [
    # SYEPESC:
    "#QPPJLQUU",
    # SYEPESC III:
    "#P9LR2LY02",
    # ANGELO,
    "#2YGCUJYY",
    # TOPO,
    "#Q02RU2UY",
    # DOMINATOR
    "#2LGQRYPV",
    # TIG28
    "#8YYCVV20C"
  ]

  def start_link(_args) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(:ok) do
    clan_tags = data_seed()
    init_clan_fetcher_workers(clan_tags)
    init_clan_war_fetcher_workers(clan_tags)
    # Here we only fetch known players, because the top clans might not include them.
    # The rest of players data-fetch is delegated by the clan fetcher process.
    init_player_fetcher_workers(@known_players)
    {:ok, %{}}
  end

  def data_seed() do
    {:ok, locations} = ClashApi.fetch_locations()

    international_id =
      locations["items"]
      |> Enum.find(fn location -> location["name"] == "International" end)
      |> Map.get("id")

    {:ok, int_rankings_response} = ClashApi.fetch_clan_ranking_by_location(international_id, 200)

    locations["items"]
    |> Enum.filter(& &1["is_country"])
    |> Enum.map(& &1["id"])
    |> Enum.map(fn l_id -> ClashApi.fetch_clan_ranking_by_location(l_id, 50) end)
    |> Enum.flat_map(fn {:ok, response} -> Map.get(response, "items", []) end)
    |> Enum.concat(int_rankings_response["items"])
    |> Enum.map(& &1["tag"])
    |> Enum.concat(@known_clans)
    |> Enum.uniq()
  end

  defp init_clan_fetcher_workers(clan_tags) do
    Enum.each(clan_tags, &GenServer.cast(ClanFetcher.via(), {:fetch_and_persist_clan, &1}))
  end

  defp init_clan_war_fetcher_workers(clan_tags) do
    Enum.each(clan_tags, &GenServer.cast(ClanWarFetcher.via(), {:fetch_and_persist_clan_war, &1}))
  end

  defp init_player_fetcher_workers(player_tags) do
    Enum.each(player_tags, &GenServer.cast(PlayerFetcher.via(), {:fetch_and_persist_player, &1}))
  end
end
