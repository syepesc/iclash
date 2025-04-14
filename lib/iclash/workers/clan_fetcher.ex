defmodule Iclash.Workers.ClanFetcher do
  @moduledoc """
  A GenServer worker responsible for fetching and updating clan data periodically.

  This module retrieves clan information from an external API, persists it in the database, and schedules future updates.
  It also delegates tasks like fetching player and clan war data to other workers.

  ## Key Features

  - **Clan Data Fetching**: Fetches clan details using the provided clan tag.
  - **Data Persistence**: Ensures fetched data is upserted into the database.
  - **Task Delegation**: Delegates fetching of player and clan war data to specialized workers.
  - **Scheduling**: Automatically schedules periodic updates for continuous data freshness.
  - **Error Handling**: Logs errors and terminates gracefully, leveraging a transient restart strategy for recovery.

  ## Design Highlights

  - **Transient Restart**: Restarts only on abnormal termination to avoid infinite loops.
  - **Registry Integration**: Uses `Iclash.Registry.DataFetcher` for unique worker identification and process lookup.
  - **API Load Management**: Introduces staggered delays when scheduling player data fetches to prevent API overload.

  TODO: The worker could be enhanced to hibernate during long idle periods to reduce memory usage. GenServer.start_link(..., hibernate_after: 5_000)
  """

  use GenServer, restart: :transient
  alias Iclash.ClashApi
  alias Iclash.DomainTypes.Clan
  alias Iclash.Repo.Schemas.Clan, as: ClanSchema
  alias Iclash.Workers.ClanWarFetcher
  alias Iclash.Workers.PlayerFetcher
  require Logger

  # I consider that 48 hours is a reasonable fetch interval for clan data, a good minimum could be 24h.
  @fetch_timer :timer.hours(48)

  def start_link(clan_tag) do
    GenServer.start_link(__MODULE__, clan_tag, name: via("clan_fetcher_#{clan_tag}"))
  end

  @impl true
  def init(clan_tag) do
    Logger.info("Init clan fetcher process. clan_tag=#{clan_tag}")
    Process.send(self(), :fetch_and_persist_clan, [])
    {:ok, clan_tag}
  end

  @impl true
  def handle_info(:fetch_and_persist_clan, clan_tag) do
    with {:ok, %ClanSchema{} = fetched_clan} <- ClashApi.fetch_clan(clan_tag),
         {:ok, _clan} <- Clan.upsert_clan(fetched_clan) do
      schedule_next_fetch(clan_tag)
      schedule_clan_war_fetch(clan_tag)
      schedule_players_fetch(fetched_clan.member_list)
      {:noreply, clan_tag}
    else
      error ->
        Logger.error(
          "Terminating clan fetcher process. pid=#{inspect(self())} clan_tag=#{clan_tag} error=#{inspect(error)}"
        )

        # Set new state to the error so it can be identify in the observer cli process state
        {:noreply, error}
    end
  end

  @impl true
  def handle_info({:fetch_and_persist_player, player_tag}, clan_tag) do
    case DynamicSupervisor.start_child(
           DynamicSupervisor.PlayerFetcher,
           {PlayerFetcher, player_tag}
         ) do
      {:ok, _} -> {:noreply, clan_tag}
      # Catches already started child, this should not generate any errors for the clan fetcher.
      # Errors in the player fetcher should be handle there.
      {:error, _} -> {:noreply, clan_tag}
    end
  end

  def via(clan_tag) do
    {:via, Registry, {Iclash.Registry.DataFetcher, clan_tag}}
  end

  defp schedule_clan_war_fetch(clan_tag) do
    Logger.info("Delegating clan war fetch. clan_tag=#{clan_tag}")

    case DynamicSupervisor.start_child(
           DynamicSupervisor.ClanWarFetcher,
           {ClanWarFetcher, clan_tag}
         ) do
      {:ok, _} -> {:noreply, clan_tag}
      # Catches already started child, this should not generate any errors for the clan fetcher.
      # Errors in the clan war fetcher should be handle there.
      {:error, _} -> {:noreply, clan_tag}
    end
  end

  defp schedule_players_fetch(players) do
    Logger.info("Delegating player fetch for #{length(players)} clan members")

    # To avoid overwhelming the Clash API with a large number of concurrent requests when fetching player data for all clan members,
    # we introduce a staggered delay. Each player's data fetch is scheduled with a slight delay, spreading out the requests over time.
    # This approach ensures a more controlled and gradual load on the API.
    players
    |> Enum.with_index(1)
    |> Enum.each(fn {player, i} ->
      Process.send_after(self(), {:fetch_and_persist_player, player.tag}, :timer.seconds(i))
    end)
  end

  defp schedule_next_fetch(clan_tag) do
    Logger.info("Scheduling next clan fetch in #{@fetch_timer}ms. clan_tag=#{clan_tag}")
    Process.send_after(self(), :fetch_and_persist_clan, @fetch_timer)
  end
end
