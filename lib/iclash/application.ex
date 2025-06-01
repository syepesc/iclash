defmodule Iclash.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {IclashWeb.Telemetry, []},
      {Iclash.Repo, []},
      {Registry, name: Iclash.Registry, keys: :unique},
      {DNSCluster, query: Application.get_env(:iclash, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Iclash.PubSub},
      {Finch, name: Iclash.Finch},
      {Iclash.DataFetcher.Supervisor, [auto_start: false]},
      # Start to serve requests, typically the child
      IclashWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Iclash.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    IclashWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
