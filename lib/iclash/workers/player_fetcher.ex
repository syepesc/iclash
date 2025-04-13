defmodule Iclash.Workers.PlayerFetcher do
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
  alias Iclash.Repo.Schemas.Player, as: PlayerSchema
  alias Iclash.DomainTypes.Player
  require Logger

  # I consider that 24 hours is a reasonable fetch interval for player data
  @fetch_timer :timer.hours(24)

  def start_link(player_tag) do
    GenServer.start_link(__MODULE__, player_tag, name: via("player_fetcher_#{player_tag}"))
  end

  @impl true
  def init(player_tag) do
    Logger.info("Init player fetcher process for player: #{player_tag}")
    Process.send(self(), :fetch_and_persist_player, [])
    {:ok, player_tag}
  end

  @impl true
  def handle_info(:fetch_and_persist_player, player_tag) do
    with {:ok, %PlayerSchema{} = fetched_player} <- ClashApi.fetch_player(player_tag),
         {:ok, _player} <- Player.upsert_player(fetched_player) do
      schedule_fetch(player_tag)
      {:noreply, player_tag}
    else
      error ->
        Logger.error(
          "Terminating player fetcher process. pid=#{inspect(self())} error=#{inspect(error)}"
        )

        # Set new state to the error so it can be identify in the observer cli process state
        {:noreply, error}
    end
  end

  def via(player_tag) do
    {:via, Registry, {Iclash.Registry.DataFetcher, player_tag}}
  end

  defp schedule_fetch(player_tag) do
    Logger.info("Scheduling next data fetch in #{@fetch_timer}ms for player: #{player_tag}.")
    Process.send_after(self(), :fetch_and_persist_player, @fetch_timer)
  end
end
