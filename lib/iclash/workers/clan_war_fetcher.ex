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

  use GenServer
  alias Iclash.ClashApi
  alias Iclash.DomainTypes.ClanWar
  alias Iclash.Repo.Schemas.ClanWar, as: ClanWarSchema
  require Logger

  @type state :: %{
          clan_tag: String.t(),
          fetch_attempts: integer(),
          failed_fetch_attempts: integer(),
          last_fetched_at: DateTime.t(),
          meta: ClanWarSchema.t() | {:error, any()}
        }

  @init_state %{
    clan_tag: nil,
    fetch_attempts: 0,
    failed_fetch_attempts: 0,
    last_fetched_at: nil,
    meta: nil
  }

  def start_link(_args) do
    GenServer.start_link(__MODULE__, :ok, name: via())
  end

  @impl true
  def init(:ok) do
    Logger.info("Init clan war fetcher process")
    {:ok, @init_state}
  end

  @impl true
  def handle_cast({:fetch_and_persist_clan_war, _clan_tag} = msg, state) do
    # Delegate the actual work to the `handle_info/2` callback, this is not idiomatically.
    # However, this ensures that any retry logic or additional handling is centralized,
    # avoiding duplication of logic and maintaining a single source of truth.
    Process.send(self(), msg, [])
    {:noreply, state}
  end

  @impl true
  def handle_info({:fetch_and_persist_clan_war, clan_tag}, state) do
    with {:ok, %ClanWarSchema{} = fetched_clan_war} <- ClashApi.fetch_current_war(clan_tag),
         {:ok, _clan_wars} <- ClanWar.upsert_clan_war(fetched_clan_war) do
      new_state =
        %{
          state
          | clan_tag: clan_tag,
            fetch_attempts: state.fetch_attempts + 1,
            last_fetched_at: DateTime.utc_now(),
            meta: fetched_clan_war
        }

      schedule_fetch_when_war_ends(fetched_clan_war)
      {:noreply, new_state}
    else
      {:ok, :not_in_war} ->
        # Schedule next fetch, maybe clan will start a new war in the future
        schedule_next_fetch(clan_tag)

        new_state =
          %{
            state
            | clan_tag: clan_tag,
              fetch_attempts: state.fetch_attempts + 1,
              last_fetched_at: DateTime.utc_now()
          }

        {:noreply, new_state}

      {:ok, :war_log_private} ->
        # Schedule next fetch, maybe clan will public their war log in the future
        schedule_next_fetch(clan_tag)

        new_state =
          %{
            state
            | clan_tag: clan_tag,
              fetch_attempts: state.fetch_attempts + 1,
              last_fetched_at: DateTime.utc_now()
          }

        {:noreply, new_state}

      {:error, {:http_error, %Req.Response{status: 429}} = reason} ->
        # Try again after req library exhausts its retries set on ClashApi.make_request/1
        # This will start a loop of retries between this process and req library.
        # This behaviour is specifically for 429 returns.
        Logger.error(
          "Terminating clan war fetcher process. pid=#{inspect(self())} clan_tag=#{clan_tag} error=#{inspect(reason)}"
        )

        Process.send(self(), {:fetch_and_persist_clan_war, clan_tag}, [])

        new_state =
          %{
            state
            | clan_tag: clan_tag,
              failed_fetch_attempts: state.failed_fetch_attempts + 1,
              last_fetched_at: DateTime.utc_now(),
              meta: {:error, reason}
          }

        {:noreply, new_state}

      reason ->
        Logger.error(
          "Error in clan war fetcher process. pid=#{inspect(self())} clan_tag=#{clan_tag} error=#{inspect(reason)}"
        )

        new_state =
          %{
            state
            | clan_tag: clan_tag,
              failed_fetch_attempts: state.failed_fetch_attempts + 1,
              last_fetched_at: DateTime.utc_now(),
              meta: {:error, reason}
          }

        {:noreply, new_state}
    end
  end

  def via() do
    {:via, Registry, {Iclash.Registry.DataFetcher, :clan_war_fetcher}}
  end

  defp schedule_fetch_when_war_ends(%ClanWarSchema{} = clan_war) do
    war_end_time_from_now = DateTime.diff(clan_war.end_time, DateTime.utc_now(), :millisecond)

    if war_end_time_from_now <= 0 do
      # War already ended, fetch again in the next iteration
      schedule_next_fetch(clan_war.clan_tag)
    else
      # War is ongoing, fetch when it ends and add 5 minutes to include attacks made at the last second of the war
      fetch_in = war_end_time_from_now + :timer.minutes(5)

      Logger.info(
        "Scheduling next clan war fetch when war ends in #{fetch_in}ms. clan_tag=#{clan_war.clan_tag}"
      )

      Process.send_after(self(), {:fetch_and_persist_clan_war, clan_war.clan_tag}, fetch_in)
    end
  end

  defp schedule_next_fetch(clan_tag) do
    # I consider that 24 hours is a reasonable fetch interval for clan war data.
    # Since each clan war typically lasts 2 days, this will ensure we fetch data at least once per war.
    fetch_in = :timer.hours(24)
    Logger.info("Scheduling next clan war fetch in #{fetch_in}ms. clan_tag=#{clan_tag}")
    Process.send_after(self(), {:fetch_and_persist_clan_war, clan_tag}, fetch_in)
  end
end
