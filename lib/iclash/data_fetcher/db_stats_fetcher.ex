defmodule Iclash.DataFetcher.DbStatsFetcher do
  @moduledoc """
  This module is designed to collect and report the row count and storage size of each table in the database.

  The purpose is to provide an initial snapshot of how the database grows over time as data is fetched and stored.
  Before a full user interface is built for the app,there will be a single LiveView page that acts as a welcome screen
  and displays this historical storage data to help monitor ingestion progress and system health.
  """

  use GenServer
  alias Iclash.Repo
  alias Iclash.Repo.Schemas.DbStat
  require Logger

  # ###########################################################################
  # Public API
  # ###########################################################################

  @spec start() :: :ok
  def start() do
    GenServer.cast(via(), :start)
  end

  # ###########################################################################
  # GenServer callbacks
  # ###########################################################################

  def start_link(_args) do
    GenServer.start_link(__MODULE__, :ok, name: via())
  end

  @impl true
  def init(:ok) do
    Logger.info("Init database stats fetcher process. pid=#{inspect(self())}")
    {:ok, %{}}
  end

  @impl true
  def handle_cast(:start, state) do
    Process.send(self(), :fetch_and_persist_db_stats, [])
    {:noreply, state}
  end

  @impl true
  def handle_info(:fetch_and_persist_db_stats, _state) do
    query = """
    SELECT
      s.relname AS table_name,
      s.n_live_tup AS row_count,
      pg_total_relation_size(s.relid) AS total_size_mb,
      pg_relation_size(s.relid) AS table_size_mb,
      pg_total_relation_size(s.relid) - pg_relation_size(s.relid) AS index_size_mb
    FROM
      pg_stat_user_tables s
    JOIN
      pg_statio_user_tables i ON s.relid = i.relid
    ORDER BY
      pg_total_relation_size(s.relid) DESC;
    """

    {:ok, result} = Ecto.Adapters.SQL.query(Repo, query, [])

    now = DateTime.utc_now()

    Enum.each(result.rows, fn [table_name, row_count, _total_size, table_size, index_size] ->
      attrs = %{
        table_name: table_name,
        row_count: row_count,
        table_size_mb: table_size,
        index_size_mb: index_size,
        collected_at: now
      }

      %DbStat{}
      |> DbStat.changeset(attrs)
      |> Repo.insert()
    end)

    schedule_next_fetch()
    {:noreply, %{}}
  end

  defp via() do
    {:via, Registry, {Iclash.Registry.DataFetcher, :db_stats_fetcher}}
  end

  defp schedule_next_fetch() do
    fetch_in = :timer.minutes(1)
    Process.send_after(self(), :fetch_and_persist_db_stats, fetch_in)
    Logger.info("Scheduling next database stats fetch in #{fetch_in}ms")
  end
end
