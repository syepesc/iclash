defmodule Iclash.Supervisors.DataFetcher do
  @moduledoc """
  A Supervisor responsible for orchestrating and managing the lifecycle of data fetcher workers.

  ## Responsibilities

  - **Registry Management**: Maintains a unique registry (`Iclash.Registry.DataFetcher`) to track worker processes and ensure proper routing of messages.
  - **Init Dynamic Supervisors**: Manages multiple dynamic supervisors for different types of data fetchers:
    - `DynamicSupervisor.PlayerFetcher`: Handles workers fetching player data.
    - `DynamicSupervisor.ClanFetcher`: Handles workers fetching clan data.
    - `DynamicSupervisor.ClanWarFetcher`: Handles workers fetching clan war data.
  - **Worker Initialization**: Starts the `Iclash.Workers.DataFetcherSeeder` process, which seeds the system with initial data for fetcher workers.

  ## Design Considerations

  - The `one_for_one` strategy ensures that failures in one worker do not cascade to others, maintaining system stability.
  - Dynamic supervisors allow for flexible and scalable management of worker processes, enabling the system to handle varying workloads efficiently.
  - The registry ensures that worker processes can be uniquely identified and accessed, facilitating communication and coordination between components.

  This supervisor is a critical component of the `Iclash` application, ensuring reliable and efficient data fetching for clans, players, and wars.
  """

  use Supervisor

  def start_link(_) do
    Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(:ok) do
    children = [
      {Registry, name: Iclash.Registry.DataFetcher, keys: :unique},
      {Iclash.Workers.ClanFetcher, []},
      {Iclash.Workers.ClanWarFetcher, []},
      {Iclash.Workers.PlayerFetcher, []},
      {Iclash.Workers.DataFetcherSeeder, []}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
