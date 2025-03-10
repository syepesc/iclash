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

  alias Iclash.Repo.Schemas.ClientError
  alias Iclash.Repo.Schemas.PlayerTag
  alias Iclash.Repo.Schemas.Player

  @callback get_player(player_tag :: PlayerTag.t()) ::
              {:ok, Player.t()} | {:error, ClientError.t()} | {:error, any()}
end

defmodule Iclash.ClashApi.ClientImpl do
  @moduledoc """
  Clash of Clans API Implementation
  """
  @behaviour Iclash.ClashApi

  alias Iclash.Repo.Schemas.ClientError
  alias Iclash.Repo.Schemas.PlayerTag
  alias Iclash.Repo.Schemas.Player

  require Logger

  def get_player(%PlayerTag{tag: tag}) do
    response = Req.get(base_request(), url: "/players/#{tag}")

    case response do
      {:ok, %Req.Response{status: 200} = response} ->
        {:ok, Player.new(response.body)}

      {:ok, %Req.Response{status: _} = response} ->
        Logger.error("Clash API error. response=#{inspect(response)}")
        {:error, ClientError.new(response.body)}

      {:error, reason} ->
        Logger.error("Req library error. reason=#{inspect(reason)}")
        {:error, reason}
    end
  end

  defp api_token, do: Application.fetch_env!(:iclash, ClashApiConfig)[:api_token]
  defp base_url, do: Application.fetch_env!(:iclash, ClashApiConfig)[:base_url]

  defp base_request() do
    Req.new(
      retry: :transient,
      auth: {:bearer, api_token()},
      base_url: base_url()
    )
  end
end
