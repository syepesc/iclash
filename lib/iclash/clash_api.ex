defmodule Iclash.ClashApi do
  @moduledoc """
  Clash of Clans API Behaviour

  TODO: Create struct for functions that returns `{:ok, any()}`.
  """

  use Knigge,
    otp_app: :iclash,
    default: Iclash.ClashApi.ClientImpl

  alias Iclash.Repo.Schemas.{Player, Clan, ClanWar}

  @type http_error :: {:error, {:http_error, Mint.HTTPError.t()}}
  @type network_error :: {:error, {:network_error, Mint.TransportError.t()}}

  @callback fetch_player(player_tag :: String.t()) ::
              {:ok, Player.t()} | http_error() | network_error()

  @callback fetch_clan(clan_tag :: String.t()) ::
              {:ok, Clan.t()} | http_error() | network_error()

  @callback fetch_current_war(clan_tag :: String.t()) ::
              {:ok, ClanWar.t()}
              | {:ok, :not_in_war}
              | {:ok, :war_log_private}
              | http_error()
              | network_error()

  @callback fetch_locations() ::
              {:ok, any()} | http_error() | network_error()

  @callback fetch_clan_ranking_by_location(location_id :: integer(), limit :: integer()) ::
              {:ok, any()} | http_error() | network_error()

  @callback fetch_player_ranking_by_location(location_id :: integer(), limit :: integer()) ::
              {:ok, any()} | http_error() | network_error()
end

defmodule Iclash.ClashApi.ClientImpl do
  @moduledoc """
  Clash of Clans API Implementation
  """
  @behaviour Iclash.ClashApi

  alias Iclash.Repo.Schemas.{Player, Clan, ClanWar}

  require Logger

  def fetch_player(player_tag) do
    base_request()
    |> Req.merge(url: "/players/:player_tag", path_params: [player_tag: player_tag])
    |> make_request()
    |> case do
      {:ok, body} -> Player.from_clash_api(body)
      # This bubbles-up the returns from make_request/1.
      error -> error
    end
  end

  def fetch_clan(clan_tag) do
    base_request()
    |> Req.merge(url: "/clans/:clan_tag", path_params: [clan_tag: clan_tag])
    |> make_request()
    |> case do
      {:ok, body} -> Clan.from_map(body)
      # This bubbles-up the returns from make_request/1.
      error -> error
    end
  end

  def fetch_current_war(clan_tag) do
    base_request()
    |> Req.merge(url: "/clans/:clan_tag/currentwar", path_params: [clan_tag: clan_tag])
    |> make_request()
    |> case do
      {:ok, body} ->
        if body["state"] in ["inWar", "warEnded"] do
          ClanWar.from_clash_api(body)
        else
          # We don't care when clan war is in other states. e.i. like "preparation" or "notInWar".
          Logger.info("Skipping, clan is not currently in war. clan_tag=#{clan_tag}")
          {:ok, :not_in_war}
        end

      # Specific error handling when clans have their war log private.
      # This error handling came from previous experiences querying the ClashAPI - not confirmed with the official docs yet.
      {:error, {:http_error, %Req.Response{status: 403}}} ->
        Logger.info("Skipping, clan war log is private. clan_tag=#{clan_tag}")
        {:ok, :war_log_private}

      error ->
        # This bubbles-up the returns from make_request/1.
        error
    end
  end

  def fetch_locations() do
    {:ok, body} =
      base_request()
      |> Req.merge(
        url: "/locations",
        params: [limit: 500]
      )
      |> make_request()

    {:ok, body}
  end

  def fetch_clan_ranking_by_location(location_id, limit) do
    {:ok, body} =
      base_request()
      |> Req.merge(
        url: "/locations/:location_id/rankings/clans",
        path_params: [location_id: location_id],
        params: [limit: limit]
      )
      |> make_request()

    {:ok, body}
  end

  def fetch_player_ranking_by_location(location_id, limit) do
    {:ok, body} =
      base_request()
      |> Req.merge(
        url: "/locations/:location_id/rankings/players",
        path_params: [location_id: location_id],
        params: [limit: limit]
      )
      |> make_request()

    {:ok, body}
  end

  defp api_token, do: Application.fetch_env!(:iclash, ClashApiConfig)[:api_token]
  defp base_url, do: Application.fetch_env!(:iclash, ClashApiConfig)[:base_url]

  defp base_request() do
    Req.new(
      retry: :safe_transient,
      max_retries: 5,
      auth: {:bearer, api_token()},
      base_url: base_url(),
      # Transform keys from CamelCase/camelCase to snake_case.
      decode_json: [keys: fn k -> k |> Macro.underscore() end]
    )
  end

  defp make_request(%Req.Request{} = req) do
    Logger.info(
      "Clash api request attempt. url=#{req.url} params=#{inspect(Map.get(req.options, :params))} path_params=#{inspect(Map.get(req.options, :path_params))}"
    )

    case Req.get(req) do
      {:ok, %Req.Response{status: 200} = response} ->
        {:ok, response.body}

      {:ok, %Req.Response{status: _} = reason} ->
        Logger.warning("Http error. error=#{inspect(reason)} request=#{inspect(req)}")
        {:error, {:http_error, reason}}

      {:error, reason} ->
        Logger.warning("Network error. error=#{inspect(reason)} request=#{inspect(req)}")
        {:error, {:network_error, reason}}
    end
  end
end
