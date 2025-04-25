defmodule Iclash.DomainTypes.Player do
  @moduledoc """
  Player domain type.
  This module defines functionalities to interact with a player info.
  """

  import Ecto.Query

  alias Ecto.Multi
  alias Iclash.ClashApi
  alias Iclash.Repo
  alias Iclash.Repo.Schemas.{Player, Heroe, Troop, Spell, HeroEquipment, LegendStatistic}

  require Logger

  @doc """
  Gets a player by tag, with all its preloads (heroes, troops, spells, hero_equipment, and legend_statistics).
  If the player is not found in the database, the function will attempt to fetch the player's data from the ClashAPI.
  """
  @spec get_player(tag :: String.t()) :: Player.t() | {:error, :not_found}
  def get_player(tag) do
    result =
      Player
      |> Repo.get(tag)
      |> Repo.preload(
        heroes: from(h in Heroe, order_by: [asc: h.updated_at]),
        troops: from(t in Troop, order_by: [asc: t.updated_at]),
        spells: from(s in Spell, order_by: [asc: s.updated_at]),
        hero_equipment: from(he in HeroEquipment, order_by: [asc: he.updated_at]),
        legend_statistics: from(lsr in LegendStatistic, order_by: [asc: lsr.updated_at])
      )

    case result do
      nil ->
        case ClashApi.fetch_player(tag) do
          {:ok, player} -> player
          {:error, _} -> {:error, :not_found}
        end

      player ->
        player
    end
  end

  @doc """
  Upsert a player.
  If the player does not exist in the database, it will be inserted.
  If the player exists, it will be updated, keeping track of changes in Player fields.
  """
  @spec upsert_player(player :: Player.t()) :: :ok | {:error, any()} | Ecto.Multi.failure()
  def upsert_player(%Player{} = player) do
    Multi.new()
    |> Multi.append(insert_query_for_player(player))
    |> Multi.append(insert_queries_for_heroes(player.tag, player.heroes))
    |> Multi.append(insert_queries_for_troops(player.tag, player.troops))
    |> Multi.append(insert_queries_for_spells(player.tag, player.spells))
    |> Multi.append(insert_queries_for_hero_equipment(player.tag, player.hero_equipment))
    |> Multi.append(insert_queries_for_legend_statistics(player.tag, player.legend_statistics))
    |> Repo.transaction()
    |> case do
      {:ok, _transaction_result} ->
        Logger.info("Player upserted successfully. player_tag=#{player.tag}")
        :ok

      {:error, reason} ->
        Logger.error(
          "Transaction failed to upsert player. error=#{inspect(reason)} player_tag=#{player.tag}"
        )

        {:error, reason}
    end
  end

  defp insert_query_for_player(player) do
    Multi.new()
    |> Multi.insert(
      {:upsert_player, player.tag},
      # Remove heroes, troops, spells, hero equipment, and
      # legend_statistics to handle them sepparately.
      player
      |> Map.put(:heroes, [])
      |> Map.put(:troops, [])
      |> Map.put(:spells, [])
      |> Map.put(:hero_equipment, [])
      |> Map.put(:legend_statistics, []),
      on_conflict: {:replace_all_except, [:tag, :inserted_at]},
      conflict_target: [:tag]
    )
  end

  defp insert_queries_for_heroes(player_tag, new_heroes) do
    # Update player heroes and keep track of any change.
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
        on_conflict: {:replace_all_except, [:player_tag, :name, :level, :inserted_at]},
        conflict_target: [:player_tag, :name, :level]
      )
      |> Multi.append(acc)
    end)
  end

  defp insert_queries_for_troops(player_tag, new_troops) do
    # Update player troops and keep track of any change.
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
        on_conflict: {:replace_all_except, [:player_tag, :name, :level, :inserted_at]},
        conflict_target: [:player_tag, :name, :level]
      )
      |> Multi.append(acc)
    end)
  end

  defp insert_queries_for_spells(player_tag, new_spells) do
    # Update player spells and keep track of any change.
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
        on_conflict: {:replace_all_except, [:player_tag, :name, :level, :inserted_at]},
        conflict_target: [:player_tag, :name, :level]
      )
      |> Multi.append(acc)
    end)
  end

  defp insert_queries_for_hero_equipment(player_tag, new_hero_equipment) do
    # Update player hero equipment and keep track of any change.
    # If there is a hero equipment with the same `player_tag`, `name`, and `level`.
    # Only `updated_at` will be replaced. Else, add the new hero equipment.
    Enum.reduce(new_hero_equipment, Multi.new(), fn he, acc ->
      parsed_he_name = he.name |> String.replace(" ", "-") |> String.upcase()
      iteration = acc |> Multi.to_list() |> length()
      operation_name = "#{player_tag}_#{parsed_he_name}_#{he.level}_#{iteration}"

      Multi.new()
      |> Multi.insert(
        {:upsert_hero_equipment, operation_name},
        Map.put(he, :player_tag, player_tag),
        on_conflict: {:replace_all_except, [:player_tag, :name, :level, :inserted_at]},
        conflict_target: [:player_tag, :name, :level]
      )
      |> Multi.append(acc)
    end)
  end

  defp insert_queries_for_legend_statistics(player_tag, new_legend_statistics) do
    # Update player legend statistics and keep track of any change.
    # If there is a hero equipment with the same `player_tag`, `name`, and `level`.
    # Only `updated_at` will be replaced. Else, add the new hero equipment.
    Enum.reduce(new_legend_statistics, Multi.new(), fn ls, acc ->
      iteration = acc |> Multi.to_list() |> length()
      operation_name = "#{player_tag}_#{ls.id}_#{iteration}"

      Multi.new()
      |> Multi.insert(
        {:upsert_legend_statistic, operation_name},
        Map.put(ls, :player_tag, player_tag),
        on_conflict: {:replace_all_except, [:player_tag, :id, :inserted_at]},
        conflict_target: [:player_tag, :id]
      )
      |> Multi.append(acc)
    end)
  end
end
