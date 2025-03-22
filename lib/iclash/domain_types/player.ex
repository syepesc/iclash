defmodule Iclash.DomainTypes.Player do
  @moduledoc """
  Player domain type.
  This module defines functionalities to interact with a player info.
  """

  # TODO: Implement versioning on player and heroes records.

  import Ecto.Query

  alias Ecto.Multi
  alias Iclash.Repo
  alias Iclash.Repo.Schemas.{Player, Heroe, Troop, Spell}

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
      |> Repo.preload(
        heroes: from(h in Heroe, order_by: [asc: h.updated_at]),
        troops: from(t in Troop, order_by: [asc: t.updated_at]),
        spells: from(s in Spell, order_by: [asc: s.updated_at])
      )

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
    Multi.new()
    |> Multi.append(insert_query_for_player(player))
    |> Multi.append(insert_queries_for_heroes(player.tag, player.heroes))
    |> Multi.append(insert_queries_for_troops(player.tag, player.troops))
    |> Multi.append(insert_queries_for_spells(player.tag, player.spells))
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

  defp insert_query_for_player(player) do
    Multi.new()
    |> Multi.insert(
      {:upsert_player, player.tag},
      # Remove heroes, troops, and spells to handle them sepparately.
      player
      |> Map.put(:heroes, [])
      |> Map.put(:troops, [])
      |> Map.put(:spells, []),
      on_conflict: {:replace_all_except, [:tag, :inserted_at]},
      conflict_target: [:tag]
    )
  end

  defp insert_queries_for_heroes(player_tag, new_heroes) do
    # Update player heroes and keep track of any change in heroes.
    # If there is a hero with the same `player_tag`, `name`, and `level`.
    # Only `updated_at` will be replaced. Else, add the new hero.
    Enum.reduce(new_heroes, Multi.new(), fn hero, acc ->
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

  defp insert_queries_for_troops(player_tag, new_troops) do
    # Update player troops and keep track of any change in troops.
    # If there is a troop with the same `player_tag`, `name`, and `level`.
    # Only `updated_at` will be replaced. Else, add the new troop.
    Enum.reduce(new_troops, Multi.new(), fn troop, acc ->
      parsed_spell_name = troop.name |> String.replace(" ", "-") |> String.upcase()
      iteration = acc |> Multi.to_list() |> length()
      operation_name = "#{player_tag}_#{parsed_spell_name}_#{troop.level}_#{iteration}"

      Multi.new()
      |> Multi.insert(
        {:upsert_troop, operation_name},
        Map.put(troop, :player_tag, player_tag),
        on_conflict: {:replace, [:updated_at]},
        conflict_target: [:player_tag, :name, :level]
      )
      |> Multi.append(acc)
    end)
  end

  defp insert_queries_for_spells(player_tag, new_spells) do
    # Update player spells and keep track of any change in spells.
    # If there is a spell with the same `player_tag`, `name`, and `level`.
    # Only `updated_at` will be replaced. Else, add the new spell.
    Enum.reduce(new_spells, Multi.new(), fn spell, acc ->
      parsed_spell_name = spell.name |> String.replace(" ", "-") |> String.upcase()
      iteration = acc |> Multi.to_list() |> length()
      operation_name = "#{player_tag}_#{parsed_spell_name}_#{spell.level}_#{iteration}"

      Multi.new()
      |> Multi.insert(
        {:upsert_spell, operation_name},
        Map.put(spell, :player_tag, player_tag),
        on_conflict: {:replace, [:updated_at]},
        conflict_target: [:player_tag, :name, :level]
      )
      |> Multi.append(acc)
    end)
  end
end
