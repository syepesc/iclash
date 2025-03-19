defmodule Iclash.DomainTypes.Player do
  @moduledoc false

  alias Iclash.Repo
  alias Iclash.Repo.Schemas.Player

  require Logger

  @spec get_player(tag :: String.t()) :: Player.t() | {:error, :not_found}
  def get_player(tag) do
    result =
      Player
      |> Repo.get_by(tag: tag)
      |> Repo.preload(:heroes)

    case result do
      nil -> {:error, :not_found}
      player -> player
    end
  end

  @spec upsert_player(player :: map()) :: {:ok, Player.t()} | {:error, Ecto.Changeset}
  def upsert_player(player \\ %{}) do
    case get_player(player["tag"]) do
      {:error, :not_found} ->
        %Player{}
        |> Player.changeset(player)
        |> Repo.insert(
          on_conflict: {:replace_all_except, [:tag, :inserted_at]},
          conflict_target: [:tag]
        )

      player_from_db ->
        player_from_db
        |> Player.changeset(player)
        |> Repo.insert(
          on_conflict: {:replace_all_except, [:tag, :inserted_at]},
          conflict_target: [:tag]
        )
    end
  end
end
