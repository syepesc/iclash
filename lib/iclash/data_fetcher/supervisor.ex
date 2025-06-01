defmodule Iclash.DataFetcher.Supervisor do
  @moduledoc false

  # TODO: Add start/stop functions to manually control this supervisor

  use Supervisor

  # This defines the Clash API rate limit: 40 request per second, this number is based on experimentation because their API does not provide one.
  @rate_limit 40
  @rate_limit_ms :timer.seconds(1)

  def start_link(_) do
    Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(:ok) do
    children = [
      {DynamicSupervisor, name: Iclash.DataFetcher, strategy: :one_for_one},
      {Iclash.DataFetcher.Queue, %{rate_limit: @rate_limit, rate_limit_ms: @rate_limit_ms}},
      {Iclash.DataFetcher.DbStatsFetcher, []}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
