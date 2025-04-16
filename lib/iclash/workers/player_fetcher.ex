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

  use GenServer
  alias Iclash.ClashApi
  alias Iclash.DomainTypes.Player
  alias Iclash.Repo.Schemas.Player, as: PlayerSchema
  require Logger

  @type state :: %{
          player_tag: String.t(),
          fetch_attempts: integer(),
          failed_fetch_attempts: integer(),
          last_fetched_at: DateTime.t(),
          meta: PlayerSchema.t() | {:error, any()}
        }

  @init_state %{
    player_tag: nil,
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
    Logger.info("Init player fetcher process")
    {:ok, @init_state}
  end

  @impl true
  def handle_cast({:fetch_and_persist_player, _player_tag} = msg, state) do
    # Delegate the actual work to the `handle_info/2` callback, this is not idiomatically.
    # However, this ensures that any retry logic or additional handling is centralized,
    # avoiding duplication of logic and maintaining a single source of truth.
    Process.send(self(), msg, [])
    {:noreply, state}
  end

  @impl true
  def handle_info({:fetch_and_persist_player, player_tag}, state) do
    with {:ok, %PlayerSchema{} = fetched_player} <- ClashApi.fetch_player(player_tag),
         {:ok, _player} <- Player.upsert_player(fetched_player) do
      new_state =
        %{
          state
          | player_tag: player_tag,
            fetch_attempts: state.fetch_attempts + 1,
            last_fetched_at: DateTime.utc_now(),
            meta: fetched_player
        }

      schedule_next_fetch(player_tag)
      {:noreply, new_state}
    else
      {:error, {:http_error, %Req.Response{status: 429}} = reason} ->
        # Try again after req library exhausts its retries set on ClashApi.make_request/1
        # This will start a loop of retries between this process and req library.
        Logger.info(
          "Exhaust req library configured retries, sending message back to process #{inspect(self())}. player_tag=#{player_tag}"
        )

        Process.send(self(), {:fetch_and_persist_player, player_tag}, [])

        new_state =
          %{
            state
            | player_tag: player_tag,
              failed_fetch_attempts: state.failed_fetch_attempts + 1,
              last_fetched_at: DateTime.utc_now(),
              meta: {:error, reason}
          }

        {:noreply, new_state}

      reason ->
        Logger.error(
          "Error in player fetcher process. pid=#{inspect(self())} player_tag=#{player_tag} error=#{inspect(reason)}"
        )

        new_state =
          %{
            state
            | player_tag: player_tag,
              failed_fetch_attempts: state.failed_fetch_attempts + 1,
              last_fetched_at: DateTime.utc_now(),
              meta: {:error, reason}
          }

        {:noreply, new_state}
    end
  end

  def via() do
    {:via, Registry, {Iclash.Registry.DataFetcher, :player_fetcher}}
  end

  defp schedule_next_fetch(player_tag) do
    # I consider that 24 hours is a reasonable fetch interval for player data
    fetch_in = :timer.hours(24)
    Logger.info("Scheduling next player fetch in #{fetch_in}ms. player_tag=#{player_tag}")
    Process.send_after(self(), {:fetch_and_persist_player, player_tag}, fetch_in)
  end
end
