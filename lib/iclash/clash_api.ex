defmodule Iclash.ClashApi do
  @moduledoc """
  Clash of Clans API Behaviour
  """

  # The otp_app config key is used to lookup the implementation dynamically.
  # By default the lookup happens during runtime for the TEST env build and at
  # compile time for all other builds
  use Knigge,
    otp_app: :iclash,
    default: Iclash.ClashApi.ClientImpl

  alias Iclash.Repo.Schema.Player

  @callback get_player(player_tag :: String.t()) ::
              {:ok, Player.t()} | {:error, Req.Response.t()} | {:error, any()}
end

defmodule Iclash.ClashApi.ClientImpl do
  @moduledoc """
  Clash of Clans API Implementation
  """
  @behaviour Iclash.ClashApi

  alias Iclash.Repo.Context.Player

  require Logger

  def get_player(tag) do
    req =
      base_request()
      |> Req.merge(url: "/players/:player_tag", path_params: [player_tag: tag])

    with {:ok, body} <- make_request(req),
         {:ok, player} <- Player.from_map(body) do
      {:ok, player}
    end
  end

  defp api_token, do: Application.fetch_env!(:iclash, ClashApiConfig)[:api_token]
  defp base_url, do: Application.fetch_env!(:iclash, ClashApiConfig)[:base_url]

  defp base_request() do
    Req.new(
      retry: :transient,
      auth: {:bearer, api_token()},
      base_url: base_url(),
      decode_json: [keys: fn k -> k |> Macro.underscore() end]
    )
  end

  defp make_request(%Req.Request{} = req) do
    case Req.get(req) do
      {:ok, %Req.Response{status: 200} = response} ->
        {:ok, response.body}

      {:ok, %Req.Response{status: _} = response} ->
        Logger.error("Clash API error. request=#{inspect(req)} response=#{inspect(response)}")
        {:error, response}

      {:error, reason} ->
        Logger.error("Request error. request=#{inspect(req)} reason=#{inspect(reason)}")
        {:error, reason}
    end
  end
end
