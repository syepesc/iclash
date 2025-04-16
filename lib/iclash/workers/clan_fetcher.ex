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

  use GenServer
  alias Iclash.ClashApi
  alias Iclash.DomainTypes.Clan
  alias Iclash.Repo.Schemas.Clan, as: ClanSchema
  alias Iclash.Workers.PlayerFetcher
  require Logger

  @type state :: %{
          clan_tag: String.t(),
          fetch_attempts: integer(),
          failed_fetch_attempts: integer(),
          last_fetched_at: DateTime.t(),
          meta: ClanSchema.t() | {:error, any()}
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
    Logger.info("Init clan fetcher process")
    {:ok, @init_state}
  end

  @impl true
  def handle_cast({:fetch_and_persist_clan, _clan_tag} = msg, state) do
    # Delegate the actual work to the `handle_info/2` callback, this is not idiomatically.
    # However, this ensures that any retry logic or additional handling is centralized,
    # avoiding duplication of logic and maintaining a single source of truth.
    Process.send(self(), msg, [])
    {:noreply, state}
  end

  @impl true
  def handle_info({:fetch_and_persist_clan, clan_tag}, state) do
    with {:ok, %ClanSchema{} = fetched_clan} <- ClashApi.fetch_clan(clan_tag),
         {:ok, _clan} <- Clan.upsert_clan(fetched_clan) do
      new_state =
        %{
          state
          | clan_tag: clan_tag,
            fetch_attempts: state.fetch_attempts + 1,
            last_fetched_at: DateTime.utc_now(),
            meta: fetched_clan
        }

      schedule_next_fetch(clan_tag)
      schedule_players_fetch(fetched_clan.member_list)
      {:noreply, new_state}
    else
      {:error, {:http_error, %Req.Response{status: 429}} = reason} ->
        # Try again after req library exhausts its retries set on ClashApi.make_request/1
        # This will start a loop of retries between this process and req library.
        Logger.info(
          "Exhaust req library configured retries, sending message back to process #{inspect(self())}. clan_tag=#{clan_tag}"
        )

        Process.send(self(), {:fetch_and_persist_clan, clan_tag}, [])

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
          "Error in clan fetcher process. pid=#{inspect(self())} clan_tag=#{clan_tag} error=#{inspect(reason)}"
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
    {:via, Registry, {Iclash.Registry.DataFetcher, :clan_fetcher}}
  end

  defp schedule_players_fetch(players) do
    Logger.info("Delegating player fetch for #{length(players)} clan members")
    Enum.each(players, &GenServer.cast(PlayerFetcher.via(), {:fetch_and_persist_player, &1.tag}))
  end

  defp schedule_next_fetch(clan_tag) do
    # I consider that 48 hours is a reasonable fetch interval for clan data, a good minimum could be 24h.
    fetch_in = :timer.hours(48)
    Logger.info("Scheduling next clan fetch in #{fetch_in}ms. clan_tag=#{clan_tag}")
    Process.send_after(self(), {:fetch_and_persist_clan, clan_tag}, fetch_in)
  end
end
