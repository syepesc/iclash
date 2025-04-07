defmodule Iclash.ClashApi do
  @moduledoc """
  Clash of Clans API Behaviour
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
end

defmodule Iclash.ClashApi.ClientImpl do
  @moduledoc """
  Clash of Clans API Implementation
  """
  @behaviour Iclash.ClashApi

  alias Iclash.Repo.Schemas.{Player, Clan, ClanWar}

  require Logger

  def fetch_player(player_tag) do
    {:ok, body} =
      base_request()
      |> Req.merge(url: "/players/:player_tag", path_params: [player_tag: player_tag])
      |> make_request()

    body
    |> transform_legend_statistics()
    |> Player.from_map()
  end

  def fetch_clan(clan_tag) do
    {:ok, body} =
      base_request()
      |> Req.merge(url: "/clans/:clan_tag", path_params: [clan_tag: clan_tag])
      |> make_request()

    Clan.from_map(body)
  end

  def fetch_current_war(clan_tag) do
    req =
      base_request()
      |> Req.merge(url: "/clans/:clan_tag/currentwar", path_params: [clan_tag: clan_tag])
      |> make_request()

    case req do
      {:ok, body} ->
        if body["state"] in ["inWar", "warEnded"] do
          body
          |> extract_clan_war_attacks()
          |> extract_opponent_tag_from_clan_war_body()
          |> transform_string_date_into_datetime_struct()
          |> ClanWar.from_map()
        else
          Logger.info("Skipping, no current war found for clan with tag #{clan_tag}.")
          {:ok, :not_in_war}
        end

      # Specific error handling when clans have their WarLog Private.
      {:error, {:http_error, %Req.Response{status: 403}}} ->
        Logger.info("Clan tag #{clan_tag} has Private War Log.")
        {:ok, :war_log_private}

      _ ->
        req
    end
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
    # Note: we use Map.get() because there are players that do not have `legend_statistics` at all, this prevents from crashing the application.
    current_year = Date.utc_today().year
    current_month = Date.utc_today().month |> Integer.to_string() |> String.pad_leading(2, "0")

    current_season =
      body
      |> Map.get("legend_statistics", %{})
      |> Map.get("current_season", %{})
      |> Map.put("id", "#{current_year}-#{current_month}")

    previous_season =
      body
      |> Map.get("legend_statistics", %{})
      |> Map.get("previous_season", %{})

    Map.put(body, "legend_statistics", [current_season, previous_season])
  end

  defp transform_string_date_into_datetime_struct(body) do
    # As defined in the ClanWar schema, the `start_time` and `end_time` are `utc_datetime_usec`.
    # However, Clash API return a string with the following format representing a date: "20250330T105010.000Z"
    #
    # So:
    # 1) We need to transform the date string into Elixir DateTime.
    # 2) Append the transform date into the body of the response.
    body
    |> Map.put("start_time", format_date_string(body["start_time"]))
    |> Map.put("end_time", format_date_string(body["end_time"]))
  end

  defp extract_opponent_tag_from_clan_war_body(body) do
    # As defined in the ClanWar schema, the `opponent` field is a string.
    # However, Clash API return a map with the opponent clan info.
    #
    # So:
    # 1) We need to extract the oppoent clan tag.
    # 2) Append the tag into the body of the response.
    opponent_tag = body["opponent"]["tag"]
    Map.put(body, "opponent", opponent_tag)
  end

  defp extract_clan_war_attacks(body) do
    # As defined in the ClanWar schema, the `attacks` field is a list of attacks.
    # The Clash API provides a map containing the list of clan members for both the attacking and defending clans.
    # Each member in this list includes an `attacks` field, which represents the attacks performed by that member during the war.
    #
    # So:
    # 1) We need to extract the attacks from both `clan` and `opponent`.
    # 2) Append the attacks into the body of the response.

    # Extract attacks from each clan member, we use Map.get() because there might be members that haven't attack yet.
    clan_attacks =
      body["clan"]["members"]
      |> Enum.map(fn member -> Map.get(member, "attacks", []) end)
      |> List.flatten()

    opponent_attacks =
      body["opponent"]["members"]
      |> Enum.map(fn member -> Map.get(member, "attacks", []) end)
      |> List.flatten()

    Map.put(body, "attacks", clan_attacks ++ opponent_attacks)
  end

  defp format_date_string(date_string) do
    String.replace(
      date_string,
      ~r/(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})/,
      "\\1-\\2-\\3T\\4:\\5:\\6"
    )
  end
end
