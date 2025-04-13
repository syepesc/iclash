defmodule Iclash.Workers.ClanFetcher do
  @moduledoc """
  A GenServer worker responsible for periodically fetching and updating clan data.

  This module is designed to handle the retrieval of clan information from an external API
  and ensure that the data is persisted in the system.

  It operates on a scheduled basis, fetching data at regular intervals, and is capable of handling
  failures gracefully through a transient restart strategy.

  ## Responsibilities

  - **Clan Data Fetching**: Retrieves clan information from the external Clash API using the provided clan tag.
  - **Data Persistence**: Ensures that the fetched clan data is upserted into the system's database, keeping the information up-to-date.
  - **Scheduling**: Automatically schedules the next fetch operation after completing the current one, ensuring continuous updates.
  - **Error Handling**: Logs errors and terminates the process gracefully in case of failures, allowing the supervisor to restart it as needed.
  - **Player Data Delegation**: After fetching clan data, delegates the task of fetching player data for all clan members to other workers.

  ## Design Considerations

  - **Transient Restart Strategy**: The worker uses a `:transient` restart strategy, meaning it will only be restarted if it terminates abnormally. This prevents infinite restart loops in case of persistent errors.
  - **Registry Integration**: Each worker is registered with a unique identifier (clan tag) in the `Iclash.Registry.DataFetcher`, enabling efficient process lookup and communication.
  - **Scalability**: The design allows for multiple `ClanFetcher` workers to run concurrently, each handling a different clan, making the system scalable for large numbers of clans.
  - **Hibernation (Future Consideration)**: See TODO below.

  TODO: The worker could be enhanced to hibernate during long idle periods to reduce memory usage. GenServer.start_link(..., hibernate_after: 5_000)
  """

  use GenServer, restart: :transient
  alias Iclash.ClashApi
  alias Iclash.DomainTypes.Clan
  alias Iclash.Repo.Schemas.Clan, as: ClanSchema
  alias Iclash.Workers.PlayerFetcher
  require Logger

  # I consider that 48 hours is a reasonable fetch interval for clan data, a good minimum could be 24h.
  @fetch_timer :timer.hours(48)

  def start_link(clan_tag) do
    GenServer.start_link(__MODULE__, clan_tag, name: via("clan_fetcher_#{clan_tag}"))
  end

  @impl true
  def init(clan_tag) do
    Logger.info("Init clan fetcher process for clan: #{clan_tag}")
    Process.send(self(), :fetch_and_persist_clan, [])
    {:ok, clan_tag}
  end

  @impl true
  def handle_info(:fetch_and_persist_clan, clan_tag) do
    with {:ok, %ClanSchema{} = fetched_clan} <- ClashApi.fetch_clan(clan_tag),
         {:ok, _clan} <- Clan.upsert_clan(fetched_clan) do
      schedule_fetch(clan_tag)
      schedule_players_fetch(fetched_clan.member_list)
      {:noreply, clan_tag}
    else
      error ->
        Logger.error(
          "Terminating clan fetcher process. pid=#{inspect(self())} error=#{inspect(error)}"
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

  defp schedule_players_fetch(players) do
    Logger.info("Delegating Player data fetching for #{length(players)} clan members.")

    # To avoid overwhelming the Clash API with a large number of concurrent requests when fetching player data for all clan members,
    # we introduce a staggered delay. Each player's data fetch is scheduled with a slight delay, spreading out the requests over time.
    # This approach ensures a more controlled and gradual load on the API.
    players
    |> Enum.with_index(1)
    |> Enum.each(fn {player, i} ->
      Process.send_after(self(), {:fetch_and_persist_player, player.tag}, :timer.seconds(i))
    end)
  end

  defp schedule_fetch(clan_tag) do
    Logger.info("Scheduling next data fetch in #{@fetch_timer}ms for clan: #{clan_tag}.")
    Process.send_after(self(), :fetch_and_persist_clan, @fetch_timer)
  end
end
