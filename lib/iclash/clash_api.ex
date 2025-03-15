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

  alias Iclash.ClashApi.ClientError
  alias Iclash.Repo.Schema.Player

  @callback get_player(player_tag :: String.t()) ::
              {:ok, Player.t()} | {:error, ClientError.t()} | {:error, any()}
end

defmodule Iclash.ClashApi.ClientImpl do
  @moduledoc """
  Clash of Clans API Implementation
  """
  @behaviour Iclash.ClashApi

  alias Iclash.ClashApi.ClientError
  alias Iclash.Repo.Context.Player

  require Logger

  def get_player(tag) do
    req =
      base_request()
      |> Req.merge(
        url: "/players/:player_tag",
        path_params: [player_tag: tag]
      )

    case Req.get(req) do
      {:ok, %Req.Response{status: 200} = response} ->
        case Player.from_map(response.body) do
          {:ok, player} -> {:ok, player}
          {:error, errors} -> Logger.warning("Error parsing player to struct. errors=#{errors}")
        end

      {:ok, %Req.Response{status: _} = response} ->
        Logger.error("Clash API error. request=#{inspect(req)} response=#{inspect(response)}")
        {:error, ClientError.new(response)}

      {:error, reason} ->
        Logger.error("Req library error. request=#{inspect(req)} reason=#{inspect(reason)}")
        {:error, reason}
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
end

defmodule Iclash.ClashApi.ClientError do
  @moduledoc """
  A Clash of Clans API Client Error.
  This is a utility module to parse into a struct any errors from the API.
  """
  use TypedStruct

  typedstruct do
    field :status, integer()
    field :message, String.t()
    field :reason, String.t()
  end

  @spec new(response :: Req.Response.t()) :: __MODULE__.t()
  def new(%Req.Response{body: ""} = response) do
    %__MODULE__{
      status: response.status,
      message: nil,
      reason: nil
    }
  end

  def new(%Req.Response{} = response) do
    %__MODULE__{
      status: response.status,
      message: response.body["message"],
      reason: response.body["reason"]
    }
  end
end
