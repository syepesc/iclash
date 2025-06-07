defmodule Iclash.DomainTypes.Player do
  @moduledoc """
  Player domain type.
  This module defines functionalities to interact with a player info.
  """

  import Ecto.Query

  alias Iclash.Repo
  alias Iclash.Repo.Schemas.{Player, Heroe, Troop, Spell, HeroEquipment, LegendStatistic}

  require Logger

  @type player_tag :: String.t()

  @doc """
  Gets a player by tag, with all its preloads (heroes, troops, spells, hero_equipment, and legend_statistics).
  If the player is not found in the database, the function will attempt to fetch the player's data from the ClashAPI.
  """
  @spec get_player(tag :: player_tag()) :: Player.t() | {:error, :not_found}
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
      nil -> {:error, :not_found}
      player -> player
    end
  end

  @doc """
  Upsert a player.
  If the player does not exist in the database, it will be inserted.
  If the player exists, it will be updated, keeping track of changes in Player fields.
  """
  @spec upsert_player(player :: Player.t()) ::
          :ok | {:error, Ecto.Changeset.t()} | {:error, [Ecto.Changeset.t()]}
  def upsert_player(%Player{} = player) do
    with {:ok, _} <- insert_player(player),
         {:ok, _} <- insert_heroes(player.tag, player.heroes),
         {:ok, _} <- insert_troops(player.tag, player.troops),
         {:ok, _} <- insert_spells(player.tag, player.spells),
         {:ok, _} <- insert_hero_equipments(player.tag, player.hero_equipment),
         {:ok, _} <- insert_legend_statistics(player.tag, player.legend_statistics) do
      Logger.info("Player upserted successfully. player_tag=#{player.tag}")
      :ok
    else
      {:error, reason} ->
        Logger.error(
          "Failed to upsert some Player info. error=#{inspect(reason)} player_tag=#{player.tag}"
        )

        {:error, reason}
    end
  end

  # TODO: get all player tags from db

  defp insert_player(player) do
    :telemetry.execute([:iclash, :repo, :query], %{count: 1}, %{action: "insert_player"})

    Repo.insert(
      # Remove heroes, troops, spells, hero equipment, and
      # legend_statistics to handle them separately.
      player
      |> Map.put(:heroes, [])
      |> Map.put(:troops, [])
      |> Map.put(:spells, [])
      |> Map.put(:hero_equipment, [])
      |> Map.put(:legend_statistics, []),
      on_conflict: {:replace_all_except, [:tag, :inserted_at]},
      conflict_target: [:tag],
      telemetry_options: [action: "insert_player"]
    )
  end

  defp insert_heroes(player_tag, new_heroes) do
    # Update player heroes and keep track of any change.
    # If there is a hero with the same `player_tag`, `name`, and `level`.
    # Only `updated_at` will be replaced. Else, add the new hero.
    results =
      Enum.map(new_heroes, fn hero ->
        :telemetry.execute([:iclash, :repo, :query], %{count: 1}, %{action: "insert_hero"})

        Repo.insert(
          Map.put(hero, :player_tag, player_tag),
          on_conflict: {:replace_all_except, [:player_tag, :name, :level, :inserted_at]},
          conflict_target: [:player_tag, :name, :level],
          telemetry_options: [action: "insert_hero"]
        )
      end)

    errors = results |> Enum.filter(fn r -> elem(r, 0) == :error end)

    if Enum.empty?(errors) do
      {:ok, results}
    else
      {:error, errors}
    end
  end

  defp insert_troops(player_tag, new_troops) do
    # Update player troops and keep track of any change.
    # If there is a troop with the same `player_tag`, `name`, and `level`.
    # Only `updated_at` will be replaced. Else, add the new troop.

    results =
      Enum.map(new_troops, fn troop ->
        :telemetry.execute([:iclash, :repo, :query], %{count: 1}, %{action: "insert_troop"})

        Repo.insert(
          Map.put(troop, :player_tag, player_tag),
          on_conflict: {:replace_all_except, [:player_tag, :name, :level, :inserted_at]},
          conflict_target: [:player_tag, :name, :level],
          telemetry_options: [action: "insert_troop"]
        )
      end)

    errors = results |> Enum.filter(fn r -> elem(r, 0) == :error end)

    if Enum.empty?(errors) do
      {:ok, results}
    else
      {:error, errors}
    end
  end

  defp insert_spells(player_tag, new_spells) do
    # Update player spells and keep track of any change.
    # If there is a spell with the same `player_tag`, `name`, and `level`.
    # Only `updated_at` will be replaced. Else, add the new spell.

    results =
      Enum.map(new_spells, fn spell ->
        :telemetry.execute([:iclash, :repo, :query], %{count: 1}, %{action: "insert_spell"})

        Repo.insert(
          Map.put(spell, :player_tag, player_tag),
          on_conflict: {:replace_all_except, [:player_tag, :name, :level, :inserted_at]},
          conflict_target: [:player_tag, :name, :level],
          telemetry_options: [action: "insert_spell"]
        )
      end)

    errors = results |> Enum.filter(fn r -> elem(r, 0) == :error end)

    if Enum.empty?(errors) do
      {:ok, results}
    else
      {:error, errors}
    end
  end

  defp insert_hero_equipments(player_tag, new_hero_equipment) do
    # Update player hero equipment and keep track of any change.
    # If there is a hero equipment with the same `player_tag`, `name`, and `level`.
    # Only `updated_at` will be replaced. Else, add the new hero equipment.

    results =
      Enum.map(new_hero_equipment, fn he ->
        :telemetry.execute([:iclash, :repo, :query], %{count: 1}, %{
          action: "insert_hero_equipment"
        })

        Repo.insert(
          Map.put(he, :player_tag, player_tag),
          on_conflict: {:replace_all_except, [:player_tag, :name, :level, :inserted_at]},
          conflict_target: [:player_tag, :name, :level],
          telemetry_options: [action: "insert_hero_equipment"]
        )
      end)

    errors = results |> Enum.filter(fn r -> elem(r, 0) == :error end)

    if Enum.empty?(errors) do
      {:ok, results}
    else
      {:error, errors}
    end
  end

  defp insert_legend_statistics(player_tag, new_legend_statistics) do
    # Update player legend statistics and keep track of any change.
    # If there is a hero equipment with the same `player_tag`, `name`, and `level`.
    # Only `updated_at` will be replaced. Else, add the new hero equipment.

    results =
      Enum.map(new_legend_statistics, fn ls ->
        :telemetry.execute([:iclash, :repo, :query], %{count: 1}, %{
          action: "insert_legend_statistic"
        })

        Repo.insert(
          Map.put(ls, :player_tag, player_tag),
          on_conflict: {:replace_all_except, [:player_tag, :id, :inserted_at]},
          conflict_target: [:player_tag, :id],
          telemetry_options: [action: "insert_legend_statistic"]
        )
      end)

    errors = results |> Enum.filter(fn r -> elem(r, 0) == :error end)

    if Enum.empty?(errors) do
      {:ok, results}
    else
      {:error, errors}
    end
  end
end
