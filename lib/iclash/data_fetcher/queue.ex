defmodule Iclash.DataFetcher.Queue do
  @moduledoc false

  # TODO: Implement request steps (GenStage). Init by triggering @rate_limit requests, wait 1 second. Then, trigger next @rate_limit requests.
  # TODO: Avoid queuing already queued clans, clan wars, and player.

  use GenServer
  alias Iclash.ClashApi
  alias Iclash.DataFetcher.ClanFetcher
  alias Iclash.DataFetcher.ClanWarFetcher
  alias Iclash.DataFetcher.PlayerFetcher
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

  # ###########################################################################
  # Public API
  # ###########################################################################

  @spec enqueue_player_fetch(clan_tag :: String.t(), fetch_in_ms :: pos_integer()) :: :ok
  def enqueue_clan_fetch(clan_tag, fetch_in_ms \\ 0) do
    GenServer.cast(via(), {:fetch_clan_in, clan_tag, fetch_in_ms})
  end

  @spec enqueue_player_fetch(clan_tag :: String.t(), fetch_in_ms :: pos_integer()) :: :ok
  def enqueue_clan_war_fetch(clan_tag, fetch_in_ms \\ 0) do
    GenServer.cast(via(), {:fetch_clan_war_in, clan_tag, fetch_in_ms})
  end

  @spec enqueue_player_fetch(player_tag :: String.t(), fetch_in_ms :: pos_integer()) :: :ok
  def enqueue_player_fetch(player_tag, fetch_in_ms \\ 0) do
    GenServer.cast(via(), {:fetch_player_in, player_tag, fetch_in_ms})
  end

  # ###########################################################################
  # GenServer callbacks
  # ###########################################################################
  def start_link(_args) do
    GenServer.start_link(__MODULE__, :ok, name: via())
  end

  def init(:ok) do
    Logger.info("Starting data fetcher queue process. pid=#{inspect(self())}")
    clan_tags_seed() |> Enum.each(&Process.send(self(), {:fetch_clan, &1}, []))
    @known_players |> Enum.each(&Process.send(self(), {:fetch_player, &1}, []))
    {:ok, %{}}
  end

  def handle_info({:fetch_clan, clan_tag}, state) do
    case DynamicSupervisor.start_child(Iclash.DataFetcher, {ClanFetcher, clan_tag}) do
      {:error, :max_children} ->
        # Re-enqueue clan fetch for later
        enqueue_clan_fetch(clan_tag)
        {:noreply, state}

      _ ->
        {:noreply, state}
    end
  end

  def handle_info({:fetch_clan_war, clan_tag}, state) do
    case DynamicSupervisor.start_child(Iclash.DataFetcher, {ClanWarFetcher, clan_tag}) do
      {:error, :max_children} ->
        # Re-enqueue clan war fetch for later
        enqueue_clan_war_fetch(clan_tag)
        {:noreply, state}

      _ ->
        {:noreply, state}
    end
  end

  def handle_info({:fetch_player, player_tag}, state) do
    case DynamicSupervisor.start_child(Iclash.DataFetcher, {PlayerFetcher, player_tag}) do
      {:error, :max_children} ->
        # Re-enqueue player fetch for later
        enqueue_player_fetch(player_tag)
        {:noreply, state}

      _ ->
        {:noreply, state}
    end
  end

  def handle_cast({:fetch_clan_in, clan_tag, fetch_in}, state) do
    Process.send_after(self(), {:fetch_clan, clan_tag}, fetch_in)
    {:noreply, state}
  end

  def handle_cast({:fetch_clan_war_in, clan_tag, fetch_in}, state) do
    Process.send_after(self(), {:fetch_clan_war, clan_tag}, fetch_in)
    {:noreply, state}
  end

  def handle_cast({:fetch_player_in, player_tag, fetch_in}, state) do
    Process.send_after(self(), {:fetch_player, player_tag}, fetch_in)
    {:noreply, state}
  end

  defp via() do
    {:via, Registry, {Iclash.Registry.DataFetcher, :data_fetcher_queue}}
  end

  defp clan_tags_seed() do
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
end
