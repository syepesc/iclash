defmodule Iclash.DataFetcher.ClanWarFetcher do
  @moduledoc false

  use GenServer, restart: :temporary

  alias Iclash.ClashApi
  alias Iclash.DataFetcher.Queue
  alias Iclash.DomainTypes.ClanWar
  alias Iclash.Repo.Schemas.ClanWar, as: ClanWarSchema

  require Logger

  def start_link(clan_tag) do
    GenServer.start_link(__MODULE__, clan_tag, name: via(clan_tag))
  end

  @impl true

  def init(clan_tag) do
    Logger.info("Init clan war fetcher process. pid=#{inspect(self())} clan_tag=#{clan_tag}")
    Process.send(self(), :fetch_and_persist_clan_war, [])
    {:ok, clan_tag}
  end

  @impl true
  def handle_info(:fetch_and_persist_clan_war, clan_tag) do
    with {:ok, %ClanWarSchema{} = fetched_clan_war} <- ClashApi.fetch_current_war(clan_tag),
         :ok <- ClanWar.upsert_clan_war(fetched_clan_war) do
      schedule_fetch_when_war_ends(fetched_clan_war)
      {:stop, :normal, clan_tag}
    else
      {:ok, :not_in_war} ->
        # Schedule next fetch, maybe clan will start a new war in the future
        schedule_next_fetch(clan_tag)
        {:stop, :normal, clan_tag}

      {:ok, :war_log_private} ->
        # Schedule next fetch, maybe clan will public their war log in the future
        schedule_next_fetch(clan_tag)
        {:stop, :normal, clan_tag}

      {:error, {:http_error, %Req.Response{status: 404}}} ->
        # Do nothing if clan war not found.
        {:stop, :normal, clan_tag}

      {:error, {:http_error, %Req.Response{status: 429}}} ->
        # Try again after req library exhausts its retries set on ClashApi.make_request/1
        # This will start a loop of retries between this process and req library.
        Logger.info(
          "Exhaust req library configured retries, sending message back to queue #{inspect(self())}. clan_tag=#{clan_tag}"
        )

        Queue.enqueue_clan_war_fetch(clan_tag, 5_000)
        {:stop, :normal, clan_tag}

      reason ->
        Logger.error(
          "Error in clan war fetcher process. pid=#{inspect(self())} clan_tag=#{clan_tag} error=#{inspect(reason)}"
        )

        {:stop, :normal, reason}
    end
  end

  defp via(clan_tag) do
    {:via, Registry, {Iclash.Registry.DataFetcher, "clan_war_fetcher_#{clan_tag}"}}
  end

  defp schedule_fetch_when_war_ends(%ClanWarSchema{} = clan_war) do
    war_end_time_from_now = DateTime.diff(clan_war.end_time, DateTime.utc_now(), :millisecond)

    if war_end_time_from_now <= 0 do
      # War already ended, fetch again in the next iteration
      schedule_next_fetch(clan_war.clan_tag)
    else
      # War is ongoing, fetch when it ends and add 5 minutes to include attacks made at the last second of the war
      fetch_in = war_end_time_from_now + :timer.minutes(5)
      Queue.enqueue_clan_war_fetch(clan_war.clan_tag, fetch_in)

      Logger.info(
        "Scheduling next clan war fetch when war ends in #{fetch_in}ms. clan_tag=#{clan_war.clan_tag}"
      )
    end
  end

  defp schedule_next_fetch(clan_tag) do
    # I consider that 24 hours is a reasonable fetch interval for clan war data.
    # Since each clan war typically lasts 2 days, this will ensure we fetch data at least once per war.
    fetch_in = :timer.hours(24)
    Queue.enqueue_clan_war_fetch(clan_tag, fetch_in)
    Logger.info("Scheduling next clan war fetch in #{fetch_in}ms. clan_tag=#{clan_tag}")
  end
end
