defmodule Iclash.Workers.ClanWarFetcher do
  @moduledoc """
  A GenServer worker responsible for fetching and persisting clan war data at scheduled intervals.

  This module interacts with the Clash API to retrieve the current clan war information for a given clan
  and ensures that the data is stored in the system's database. It is designed to handle scheduling, error
  handling, and process lifecycle management efficiently.

  ## Responsibilities

  - **Data Fetching**: Retrieves the current clan war data for a specific clan using the provided clan tag.
  - **Data Persistence**: Upserts the fetched clan war data into the database, ensuring the information remains up-to-date.
  - **Scheduling**: Automatically schedules the next fetch operation based on the war's end time or a default interval.
  - **Error Handling**: Logs errors and gracefully terminates the process in case of failures, allowing the supervisor to restart it as needed.

  ## Design Considerations

  - **Transient Restart Strategy**: The worker uses a `:transient` restart strategy, ensuring it is only restarted if it terminates abnormally. This prevents unnecessary restarts in cases like normal process termination.
  - **Registry Integration**: Each worker is uniquely registered in the `Iclash.Registry.DataFetcher` using the clan tag, enabling efficient process lookup and management.
  - **Scalability**: The design supports concurrent workers, each handling a different clan, making it suitable for managing data for multiple clans simultaneously.
  - **Fetch Interval**: The default fetch interval is set to 24 hours, ensuring data is updated at least once per war cycle.
  - **Hibernation (Future Consideration)**: See TODO below.

  TODO: The worker could be optimized to hibernate during long idle periods to reduce memory usage. This can be achieved by using the `hibernate_after` option in `GenServer.start_link/3`.
  """

  use GenServer, restart: :transient
  alias Iclash.ClashApi
  alias Iclash.Repo.Schemas.ClanWar, as: ClanWarSchema
  alias Iclash.DomainTypes.ClanWar
  require Logger

  # I consider that 24 hours is a reasonable fetch interval for clan war data.
  # Since each clan war typically lasts 2 days, this will ensure we fetch data at least once per war.
  @fetch_timer :timer.hours(24)

  def start_link(clan_tag) do
    GenServer.start_link(__MODULE__, clan_tag, name: via("clan_war_fetcher_#{clan_tag}"))
  end

  @impl true
  def init(clan_tag) do
    Logger.info("Init clan war fetcher process for clan: #{clan_tag}")
    Process.send(self(), :fetch_and_persist_clan_war, [])
    {:ok, clan_tag}
  end

  @impl true
  def handle_info(:fetch_and_persist_clan_war, clan_tag) do
    with {:ok, %ClanWarSchema{} = fetched_clan_war} <- ClashApi.fetch_current_war(clan_tag),
         {:ok, _clan_wars} <- ClanWar.upsert_clan_war(fetched_clan_war) do
      schedule_fetch_when_war_ends(fetched_clan_war)
      {:noreply, clan_tag}
    else
      {:ok, :not_in_war} ->
        # Schedule next fetch, maybe clan will start a new war in the future
        schedule_fetch(clan_tag)
        {:noreply, clan_tag}

      {:ok, :war_log_private} ->
        {:noreply, clan_tag}

      error ->
        Logger.error(
          "Terminating Clan War Fetcher process. pid=#{inspect(self())} error=#{inspect(error)}"
        )

        # Set new state to the error so it can be identify in the observer cli process state
        {:noreply, error}
    end
  end

  def via(clan_tag) do
    {:via, Registry, {Iclash.Registry.DataFetcher, clan_tag}}
  end

  defp schedule_fetch_when_war_ends(%ClanWarSchema{} = clan_war) do
    fetch_in =
      clan_war.end_time
      |> DateTime.diff(DateTime.utc_now(), :millisecond)
      # Adding 5 minutes will include attacks made at the last second of the war.
      |> Kernel.+(:timer.minutes(5))

    Logger.info(
      "Scheduling next clan war data fetch when war ends in #{fetch_in}ms for clan: #{clan_war.clan_tag}."
    )

    Process.send_after(self(), :fetch_and_persist_clan_war, fetch_in)
  end

  defp schedule_fetch(clan_tag) do
    Logger.info("Scheduling next clan war data fetch in #{@fetch_timer}ms for clan: #{clan_tag}.")
    Process.send_after(self(), :fetch_and_persist_clan_war, @fetch_timer)
  end
end
