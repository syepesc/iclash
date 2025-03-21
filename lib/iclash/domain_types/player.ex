defmodule Iclash.DomainTypes.Player do
  @moduledoc """
  Player domain type.
  This module defines functionalities to interact with a player info.
  """

  # TODO: Implement versioning on player and heroes records.

  import Ecto.Query

  alias Ecto.Multi
  alias Iclash.Repo
  alias Iclash.Repo.Schemas.Player
  alias Iclash.Repo.Schemas.Heroe

  require Logger

  @doc """
  Get a player by tag.
  If the player is not found in the database, it will fetch it from the Clash API.
  """
  @spec get_player(tag :: String.t()) :: Player.t() | {:error, :not_found}
  def get_player(tag) do
    result =
      Player
      |> Repo.get(tag)
      # This preload corresponds to the `preload_order` defined in the `Player` schema.
      |> Repo.preload(heroes: from(h in Heroe, order_by: [asc: h.updated_at]))

    case result do
      nil -> {:error, :not_found}
      player -> player
    end
  end

  @doc """
  Upsert a player.
  If the player does not exist in the database, it will be inserted.
  If the player exists, it will be updated, keeping track of changes in Player Heroes.
  """
  @spec upsert_player(player :: Player.t()) ::
          {:ok, Player.t()} | {:error, any()} | Ecto.Multi.failure()
  def upsert_player(%Player{} = player) do
    case get_player(player.tag) do
      {:error, :not_found} ->
        Repo.insert(player)

      player_from_db ->
        Multi.new()
        |> Multi.append(build_multi_for_player(player))
        |> Multi.append(build_multi_for_heroes(player.tag, player_from_db.heroes, player.heroes))
        |> Repo.transaction()
        |> case do
          {:ok, _transaction_result} ->
            Logger.info("Player upserted successfully. player_tag=#{player.tag}")
            {:ok, get_player(player.tag)}

          {:error, reason} ->
            Logger.error("Transaction error, failed to upsert player. error=#{inspect(reason)}")
            {:error, reason}
        end
    end
  end

  defp build_multi_for_player(player) do
    Multi.new()
    |> Multi.insert(
      {:upsert_player, player.tag},
      # Remove heroes to handle them sepparately.
      Map.put(player, :heroes, []),
      on_conflict: {:replace_all_except, [:tag, :inserted_at]},
      conflict_target: [:tag]
    )
  end

  defp build_multi_for_heroes(player_tag, previous_heroes, new_heroes) do
    # Update player heroes and keep track of any change in heroes.
    # If there is a hero with the same `player_tag`, `name`, and `level`.
    # Only `updated_at` will be replaced. Else, add the new hero.
    Enum.reduce(previous_heroes ++ new_heroes, Multi.new(), fn hero, acc ->
      parsed_hero_name = hero.name |> String.replace(" ", "-") |> String.upcase()
      iteration = acc |> Multi.to_list() |> length()
      operation_name = "#{player_tag}_#{parsed_hero_name}_#{hero.level}_#{iteration}"

      Multi.new()
      |> Multi.insert(
        {:upsert_heroe, operation_name},
        Map.put(hero, :player_tag, player_tag),
        on_conflict: {:replace, [:updated_at]},
        conflict_target: [:player_tag, :name, :level]
      )
      |> Multi.append(acc)
    end)
  end
end
