defmodule IclashWeb.Telemetry do
  use Supervisor
  import Telemetry.Metrics

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(_arg) do
    children = [
      # Telemetry poller will execute the given period measurements
      # every 10_000ms. Learn more here: https://hexdocs.pm/telemetry_metrics
      {:telemetry_poller, measurements: periodic_measurements(), period: 10_000}
      # Add reporters as children of your supervision tree.
      # {Telemetry.Metrics.ConsoleReporter, metrics: metrics()}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def metrics do
    [
      # Phoenix Metrics
      summary("phoenix.endpoint.start.system_time",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.endpoint.stop.duration",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.start.system_time",
        tags: [:route],
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.exception.duration",
        tags: [:route],
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.stop.duration",
        tags: [:route],
        unit: {:native, :millisecond}
      ),
      summary("phoenix.socket_connected.duration",
        unit: {:native, :millisecond}
      ),
      sum("phoenix.socket_drain.count"),
      summary("phoenix.channel_joined.duration",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.channel_handled_in.duration",
        tags: [:event],
        unit: {:native, :millisecond}
      ),

      # Database Metrics
      # Read more -> https://hexdocs.pm/ecto/Ecto.Repo.html#module-telemetry-events
      summary("iclash.repo.query.total_time",
        unit: {:native, :millisecond},
        description: "The sum of the other measurements",
        tags: [:action],
        tag_values: &set_query_action/1
      ),
      summary("iclash.repo.query.decode_time",
        unit: {:native, :millisecond},
        tags: [:action],
        tag_values: &set_query_action/1,
        description: "The time spent decoding the data received from the database"
      ),
      summary("iclash.repo.query.query_time",
        unit: {:native, :millisecond},
        tags: [:action],
        tag_values: &set_query_action/1,
        description: "The time spent executing the query"
      ),
      summary("iclash.repo.query.queue_time",
        unit: {:native, :millisecond},
        tags: [:action],
        tag_values: &set_query_action/1,
        description: "The time spent waiting for a database connection"
      ),
      summary("iclash.repo.query.idle_time",
        unit: {:native, :millisecond},
        tags: [:action],
        tag_values: &set_query_action/1,
        description:
          "The time the connection spent waiting before being checked out for the query"
      ),
      # This is sum instead of counter because the insert_all queries should be added instead of counted
      sum("iclash.repo.query.count", tags: [:action]),

      # VM Metrics
      summary("vm.memory.total", unit: {:byte, :megabyte}),
      summary("vm.total_run_queue_lengths.total"),
      summary("vm.total_run_queue_lengths.cpu"),
      summary("vm.total_run_queue_lengths.io"),

      # Clash API Metrics
      summary("iclash.http.clash_api.duration", unit: {:native, :microsecond}, tags: [:endpoint]),
      counter("iclash.http.clash_api.count", tags: [:endpoint])
    ]
  end

  defp periodic_measurements do
    [
      # A module, function and arguments to be invoked periodically.
      # This function must call :telemetry.execute/3 and a metric must be added above.
      # {IclashWeb, :count_users, []}
    ]
  end

  # To understand how this work read the example in -> https://hexdocs.pm/phoenix/telemetry.html#extracting-tag-values-from-plug-conn
  defp set_query_action(metadata) do
    # The :action value come from the option :telemetry_options in Repo.insert()/insert_all()/etc.
    action = metadata[:options][:action]

    if action == nil do
      metadata
    else
      Map.put(metadata, :action, action)
    end
  end
end
