defmodule Iclash.DataFetcher.Queue do
  @moduledoc false

  use GenServer
  alias Iclash.ClashApi
  alias Iclash.DataFetcher.ClanFetcher
  alias Iclash.DataFetcher.ClanWarFetcher
  alias Iclash.DataFetcher.PlayerFetcher
  require Logger

  @type clan_tag :: String.t()
  @type player_tag :: String.t()

  @known_clans [
    # ATLIENS
    "#2Y9PLYGP9",
    # ATLIENS 2.0
    "#2QL9PRCPQ",
    # 51/50
    "#2QV00JJJG"
  ]

  @known_players [
    # SYEPESC:
    "#QPPJLQUU",
    # SYEPESC III:
    "#P9LR2LY02",
    # ANGELO,
    "#2YGCUJYY",
    # TOPO,
    "#Q02RU2UY",
    # DOMINATOR
    "#2LGQRYPV",
    # TIG28
    "#8YYCVV20C"
  ]

  # ###########################################################################
  # Public API
  # ###########################################################################

  @spec enqueue_in(
          instruction ::
            {:fetch_clan, clan_tag()}
            | {:fetch_player, player_tag()}
            | {:fetch_clan_war, clan_tag()},
          delay_in_ms :: non_neg_integer()
        ) :: :ok
  def enqueue_in(instruction, delay_in_ms) do
    GenServer.cast(via(), {:enqueue_in, instruction, delay_in_ms})
  end

  @spec seed() :: :ok
  def seed() do
    GenServer.cast(via(), :seed)
  end

  # ###########################################################################
  # GenServer callbacks
  # ###########################################################################

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: via())
  end

  @impl true
  def init(args) do
    rate_limit = Map.fetch!(args, :rate_limit)
    rate_limit_ms = Map.fetch!(args, :rate_limit_ms)

    Logger.info(
      "Init data fetcher queue process. pid=#{inspect(self())}, rate_limit=#{rate_limit}, rate_limit_ms=#{rate_limit_ms}"
    )

    state = %{
      rate_limit: rate_limit,
      rate_limit_ms: rate_limit_ms,
      queue: []
    }

    {:ok, state}
  end

  @impl true
  def handle_info(:process_instructions, state) do
    # 1. Process as many instructions as the rate limit allow.
    {to_process, rest} = Enum.split(state.queue, state.rate_limit)

    # 2. Delegate instructions.
    :ok = Enum.each(to_process, fn i -> handle_instruction(i) end)

    # 3. Process instructions again according to rate limit timer.
    Process.send_after(self(), :process_instructions, state.rate_limit_ms)

    # 4. Return new state.
    {:noreply, %{state | queue: rest}}
  end

  @impl true
  def handle_info({:enqueue, instruction}, state) do
    if Enum.member?(state.queue, instruction) do
      # If exists, do nothing.
      {:noreply, state}
    else
      # Else, add instruction to the queue.
      {:noreply, %{state | queue: [instruction | state.queue]}}
    end
  end

  @impl true
  def handle_cast({:enqueue_in, instruction, delay_in_ms}, state) do
    Process.send_after(self(), {:enqueue, instruction}, delay_in_ms)
    {:noreply, state}
  end

  @impl true
  def handle_cast(:seed, state) do
    seed_queue = seed_queue()
    Process.send_after(self(), :process_instructions, :timer.seconds(10))
    {:noreply, %{state | queue: seed_queue}}
  end

  defp seed_queue() do
    # TODO: Abstract this into an Agent that hold its state and refreshes periodically.
    # TODO: Include tags from players and clans that are in the database.
    # TODO: Implement black listing of clan/player tags that are not found (404) or have any weird behaviour like querying more than usual.

    {:ok, locations} = ClashApi.fetch_locations()

    international_id =
      locations["items"]
      |> Enum.find(fn location -> location["name"] == "International" end)
      |> Map.get("id")

    {:ok, int_rankings_response} = ClashApi.fetch_clan_ranking_by_location(international_id, 200)

    seed_clans =
      locations["items"]
      |> Enum.filter(& &1["is_country"])
      |> Enum.map(& &1["id"])
      |> Enum.map(fn l_id -> ClashApi.fetch_clan_ranking_by_location(l_id, 50) end)
      |> Enum.flat_map(fn {:ok, response} -> Map.get(response, "items", []) end)
      |> Enum.concat(int_rankings_response["items"])
      |> Enum.map(& &1["tag"])
      |> Enum.concat(@known_clans)
      |> Enum.uniq()
      |> Enum.map(fn ct -> {:fetch_clan, ct} end)

    seed_players = Enum.map(@known_players, fn pt -> {:fetch_player, pt} end)

    seed_clans ++ seed_players
  end

  defp handle_instruction(instruction) do
    case instruction do
      {:fetch_clan, _clan_tag} ->
        start_fetcher(ClanFetcher, instruction)

      {:fetch_player, _player_tag} ->
        start_fetcher(PlayerFetcher, instruction)

      {:fetch_clan_war, _clan_tag} ->
        start_fetcher(ClanWarFetcher, instruction)

      unexpected ->
        Logger.error("Unexpected instruction received. instruction=#{inspect(unexpected)}")
        :error
    end
  end

  defp start_fetcher(fetcher, {_, tag} = instruction) do
    case DynamicSupervisor.start_child(Iclash.DataFetcher, {fetcher, tag}) do
      {:error, :max_children} -> Process.send(self(), {:enqueue, instruction}, [])
      _ -> :ok
    end
  end

  defp via() do
    {:via, Registry, {Iclash.Registry, :data_fetcher_queue}}
  end
end
