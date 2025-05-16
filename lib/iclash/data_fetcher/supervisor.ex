defmodule Iclash.DataFetcher.Supervisor do
  @moduledoc false

  use Supervisor

  # This defines the Clash API rate limit: 50 request per second.
  @rate_limit 50
  @rate_limit_ms :timer.seconds(1)

  def start_link(_) do
    Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(:ok) do
    children = [
      {Registry, name: Iclash.Registry.DataFetcher, keys: :unique},
      {DynamicSupervisor,
       name: Iclash.DataFetcher, strategy: :one_for_one, max_children: @rate_limit},
      {Iclash.DataFetcher.Queue, %{rate_limit: @rate_limit, rate_limit_ms: @rate_limit_ms}}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
