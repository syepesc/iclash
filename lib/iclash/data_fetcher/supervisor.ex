defmodule Iclash.DataFetcher.Supervisor do
  @moduledoc false

  use Supervisor

  @rate_limit 80

  def start_link(_) do
    Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(:ok) do
    children = [
      {Registry, name: Iclash.Registry.DataFetcher, keys: :unique},
      {DynamicSupervisor,
       name: Iclash.DataFetcher, strategy: :one_for_one, max_children: @rate_limit},
      {Iclash.DataFetcher.Queue, []}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
