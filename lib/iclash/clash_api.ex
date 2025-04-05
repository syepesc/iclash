defmodule Iclash.ClashApi do
  @moduledoc """
  Clash of Clans API Behaviour
  """

  # TODO: Implemented re authentication logic when api_token expires (http403).
  # Needs to be confirmed if ClashAPI offers refresh token or not.

  # The otp_app config key is used to lookup the implementation dynamically.
  # By default the lookup happens during runtime for the TEST env build and at
  # compile time for all other builds
  use Knigge,
    otp_app: :iclash,
    default: Iclash.ClashApi.ClientImpl

  alias Iclash.Repo.Schemas.{Player, Clan, ClanWar}

  @type http_error :: {:error, {:http_error, Mint.HTTPError.t()}}
  @type network_error :: {:error, {:network_error, Mint.TransportError.t()}}

  @callback get_player(player_tag :: String.t()) ::
              {:ok, Player.t()} | http_error() | network_error()

  @callback get_clan(clan_tag :: String.t()) ::
              {:ok, Clan.t()} | http_error() | network_error()

  @callback get_current_war(clan_tag :: String.t()) ::
              {:ok, ClanWar.t()} | http_error() | network_error()
end

defmodule Iclash.ClashApi.ClientImpl do
  @moduledoc """
  Clash of Clans API Implementation
  """
  @behaviour Iclash.ClashApi

  alias Iclash.Repo.Schemas.{Player, Clan, ClanWar}

  require Logger

  def get_player(player_tag) do
    {:ok, body} =
      base_request()
      |> Req.merge(url: "/players/:player_tag", path_params: [player_tag: player_tag])
      |> make_request()

    body
    |> transform_legend_statistics()
    |> Player.from_map()
  end

  def get_clan(clan_tag) do
    {:ok, body} =
      base_request()
      |> Req.merge(url: "/clans/:clan_tag", path_params: [clan_tag: clan_tag])
      |> make_request()

    body
    # wars are populated separately in Clan DomainType bacuase Clash API does not return wars in the clan endpoint.
    |> Map.put("wars", [])
    |> Clan.from_map()
  end

  def get_current_war(clan_tag) do
    {:ok, body} =
      base_request()
      |> Req.merge(url: "/clans/:clan_tag/currentwar", path_params: [clan_tag: clan_tag])
      |> make_request()

    ClanWar.from_map(body)
  end

  defp api_token, do: Application.fetch_env!(:iclash, ClashApiConfig)[:api_token]
  defp base_url, do: Application.fetch_env!(:iclash, ClashApiConfig)[:base_url]

  defp base_request() do
    Req.new(
      retry: :transient,
      auth: {:bearer, api_token()},
      base_url: base_url(),
      # Transform keys from camelCase to snake_case.
      decode_json: [keys: fn k -> k |> Macro.underscore() end]
    )
  end

  defp make_request(%Req.Request{} = req) do
    Logger.info("Clash API request attempt")

    case Req.get(req) do
      {:ok, %Req.Response{status: 200} = response} ->
        {:ok, response.body}

      {:ok, %Req.Response{status: _} = reason} ->
        Logger.error("HTTP request error. error=#{inspect(reason)} request=#{inspect(req)}")
        {:error, {:http_error, reason}}

      {:error, reason} ->
        Logger.error("Network error. error=#{inspect(reason)} request=#{inspect(req)}")
        {:error, {:network_error, reason}}
    end
  end

  defp transform_legend_statistics(body) do
    # As defined in the Player schema, the legend_statistics is a one-to-many relationship.
    # The intend is to store multiple legend_statistic results for each player.
    # Now, Clash API return a map of:
    #
    # %{
    #   "legend_statictics" => %{
    #     "current_season" => %{...},
    #     "previous_season" => %{...},
    #     ...
    #   }
    # }
    #
    # So:
    # 1) We need to transform this map into a list of legend_statistic.
    #    Caring only about `current_season` and `previous_season`.
    #
    # 2) We need to generate `current_season` id because Clash API does not include it,
    #    following season id pattern "<year>-<month>".
    #
    # Note: The logic to keep track of historical data is implemented in the Player DomainType.
    current_year = Date.utc_today().year
    current_month = Date.utc_today().month |> Integer.to_string() |> String.pad_leading(2, "0")

    current_season =
      body
      |> Map.fetch!("legend_statistics")
      |> Map.fetch!("current_season")
      |> Map.put("id", "#{current_year}-#{current_month}")

    previous_season =
      body
      |> Map.fetch!("legend_statistics")
      |> Map.fetch!("previous_season")

    Map.put(body, "legend_statistics", [current_season, previous_season])
  end
end
