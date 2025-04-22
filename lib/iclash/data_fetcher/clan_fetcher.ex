defmodule Iclash.DataFetcher.ClanFetcher do
  @moduledoc false

  use GenServer, restart: :temporary

  alias Iclash.ClashApi
  alias Iclash.DataFetcher.Queue
  alias Iclash.DomainTypes.Clan
  alias Iclash.Repo.Schemas.Clan, as: ClanSchema

  require Logger

  def start_link(clan_tag) do
    GenServer.start_link(__MODULE__, clan_tag, name: via(clan_tag))
  end

  @impl true
  def init(clan_tag) do
    Logger.info("Init clan fetcher process. pid=#{inspect(self())} clan_tag=#{clan_tag}")
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
      {:stop, :normal, clan_tag}
    else
      {:error, {:http_error, %Req.Response{status: 404}}} ->
        # Do nothing if clan not found.
        {:stop, :normal, clan_tag}

      {:error, {:http_error, %Req.Response{status: 429}}} ->
        # Try again after req library exhausts its retries set on ClashApi.make_request/1
        # This will start a loop of retries between this process and req library.
        Logger.info(
          "Exhaust req library configured retries, sending message back to queue #{inspect(self())}. clan_tag=#{clan_tag}"
        )

        Queue.enqueue_clan_fetch(clan_tag, 5_000)
        {:stop, :normal, clan_tag}

      reason ->
        Logger.error(
          "Error in clan fetcher process. pid=#{inspect(self())} clan_tag=#{clan_tag} error=#{inspect(reason)}"
        )

        {:stop, :normal, reason}
    end
  end

  defp via(clan_tag) do
    {:via, Registry, {Iclash.Registry.DataFetcher, "clan_fetcher_#{clan_tag}"}}
  end

  defp schedule_clan_war_fetch(clan_tag) do
    Queue.enqueue_clan_war_fetch(clan_tag)
  end

  defp schedule_players_fetch(players) do
    Logger.info("Delegating player fetch for #{length(players)} clan members")
    Enum.each(players, &Queue.enqueue_player_fetch(&1.tag))
  end

  defp schedule_next_fetch(clan_tag) do
    # I consider that 48 hours is a reasonable fetch interval for clan data, a good minimum could be 24h.
    fetch_in = :timer.hours(48)
    Logger.info("Scheduling next clan fetch in #{fetch_in}ms. clan_tag=#{clan_tag}")
    Queue.enqueue_clan_fetch(clan_tag, fetch_in)
  end
end
