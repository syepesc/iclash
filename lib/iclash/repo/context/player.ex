defmodule Iclash.Repo.Context.Player do
  @moduledoc false

  alias Iclash.ClashApi
  alias Iclash.Repo
  alias Iclash.Repo.Schema.Player

  require Logger

  @spec create_player!(Player.t()) :: Player.t()
  def create_player!(%Player{} = player), do: Repo.insert!(player)

  @spec update_player!(Player.t() | Ecto.Changeset.t()) :: Player.t()
  def update_player!(player), do: Repo.update!(player)

  @spec get_player(tag :: String.t()) :: Player.t() | {:error, :not_found}
  def get_player(tag) when is_binary(tag) do
    case Repo.get(Player, tag) do
      nil ->
        Logger.info("Player not found in DB, fetching info from Clash API.")

        case ClashApi.get_player(tag) do
          {:ok, player} ->
            Logger.info("Player fetched from Clash API.")
            create_player!(player)

          {:error, _reason} ->
            Logger.error("Failed to fetch Player from Clash API.")
            {:error, :not_found}
        end

      %Player{} = player ->
        now = DateTime.utc_now()
        refresh_record? = DateTime.compare(player.ttr, now) in [:lt, :eq]

        # Refresh and return record if ttr is in the past, else, return previous record.
        if refresh_record? do
          case ClashApi.get_player(tag) do
            {:ok, refreshed_player} ->
              Logger.info("Player fetched from Clash API.")
              refreshed_player_map = Player.to_map(refreshed_player)

              player
              |> Player.changeset(refreshed_player_map)
              |> update_player!()

            {:error, _reason} ->
              Logger.error("Failed to fetch Player from Clash API, returning previous record.")
              player
          end
        else
          Logger.info("Player found in DB.")
          player
        end
    end
  end
end
