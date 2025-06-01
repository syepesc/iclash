defmodule Iclash.DataFetcher.PlayerFetcher do
  @moduledoc false

  use GenServer, restart: :temporary

  alias Iclash.ClashApi
  alias Iclash.DataFetcher.Queue
  alias Iclash.DomainTypes.Player
  alias Iclash.Repo.Schemas.Player, as: PlayerSchema

  require Logger

  def start_link(player_tag) do
    GenServer.start_link(__MODULE__, player_tag, name: via(player_tag))
  end

  @impl true
  def init(player_tag) do
    Logger.info("Init player fetcher process. pid=#{inspect(self())} player_tag=#{player_tag}")
    Process.send(self(), :fetch_and_persist_player, [])
    {:ok, player_tag}
  end

  @impl true
  def handle_info(:fetch_and_persist_player, player_tag) do
    with {:ok, %PlayerSchema{} = fetched_player} <- ClashApi.fetch_player(player_tag),
         :ok <- Player.upsert_player(fetched_player) do
      schedule_next_fetch(player_tag)
      {:stop, :normal, player_tag}
    else
      {:error, {:http_error, %Req.Response{status: 404}}} ->
        # Do nothing if player not found.
        {:stop, :normal, player_tag}

      {:error, {:http_error, %Req.Response{status: 429}}} ->
        # Too many requests, send message back to queue.
        Queue.enqueue_in({:fetch_player, player_tag}, :timer.seconds(5))
        {:stop, :normal, player_tag}

      reason ->
        Logger.error(
          "Error in player fetcher process. pid=#{inspect(self())} player_tag=#{player_tag} error=#{inspect(reason)}"
        )

        {:stop, :normal, reason}
    end
  end

  defp via(player_tag) do
    {:via, Registry, {Iclash.Registry, "player_fetcher_#{player_tag}"}}
  end

  defp schedule_next_fetch(player_tag) do
    # I consider that 24 hours is a reasonable fetch interval for player data
    fetch_in = :timer.hours(24)
    Queue.enqueue_in({:fetch_player, player_tag}, fetch_in)
    Logger.info("Scheduling next player fetch in #{fetch_in}ms. player_tag=#{player_tag}")
  end
end
