defmodule Iclash.DomainTypes.ClanWar do
  @moduledoc """
  ClanWar domain type.
  This module defines functionalities to interact with a ClanWar data struct.
  """

  import Ecto.Query

  alias Iclash.Repo.Schemas.ClanWarAttack
  alias Ecto.Multi
  alias Iclash.ClashApi
  alias Iclash.Repo
  alias Iclash.Repo.Schemas.ClanWar

  require Logger

  @doc """
  Get all clan wars by clan tag.
  If the clan war is not found in the database, it will be fetched from the Clash API.
  """
  @spec get_clan_wars(tag :: String.t()) :: [ClanWar.t()] | {:error, :not_found}
  def get_clan_wars(tag) do
    attacks_query = from cwa in ClanWarAttack, order_by: [asc: cwa.order]

    result =
      from(cw in ClanWar, where: cw.clan_tag == ^tag, preload: [attacks: ^attacks_query])
      |> Repo.all()

    case result do
      [] ->
        case ClashApi.fetch_current_war(tag) do
          {:ok, :not_in_war} -> {:error, :not_found}
          {:ok, :war_log_private} -> {:error, :not_found}
          {:ok, clan_war} -> clan_war
          {:error, _} -> {:error, :not_found}
        end

      clan_war ->
        clan_war
    end
  end

  @doc """
  Upsert a clan war into database.
  """
  @spec upsert_clan_war(clan_war :: ClanWar.t()) :: :ok | {:error, any()} | Ecto.Multi.failure()
  def upsert_clan_war(%ClanWar{} = clan_war) do
    Multi.new()
    |> Multi.append(insert_query_for_clan_war(clan_war))
    |> Multi.append(insert_queries_for_attacks(clan_war))
    |> Repo.transaction()
    |> case do
      {:ok, _transaction_result} ->
        Logger.info("Clan war upserted successfully. clan_tag=#{clan_war.clan_tag}")
        :ok

      {:error, reason} ->
        Logger.error(
          "Transaction failed to upsert clan war. error=#{inspect(reason)} clan_tag=#{clan_war.clan_tag}"
        )

        {:error, reason}
    end
  end

  # TODO: get clan wars by player tag

  defp insert_query_for_clan_war(clan_war) do
    operation_name = "#{clan_war.clan_tag}_#{clan_war.opponent}_#{clan_war.start_time}"

    Multi.new()
    |> Multi.insert(
      {:upsert_clan_war, operation_name},
      # Remove attacks to handle them sepparately.
      clan_war
      |> Map.put(:attacks, []),
      on_conflict: {:replace_all_except, [:clan_tag, :opponent, :start_time, :inserted_at]},
      conflict_target: [:clan_tag, :opponent, :start_time]
    )
  end

  defp insert_queries_for_attacks(clan_war) do
    # Update clan_war attacks and keep track of any change.

    Enum.reduce(clan_war.attacks, Multi.new(), fn attack, acc ->
      iteration = acc |> Multi.to_list() |> length()
      operation_name = "#{attack.attacker_tag}_#{attack.defender_tag}_#{iteration}"

      Multi.new()
      |> Multi.insert(
        {:upsert_attack, operation_name},
        attack
        |> Map.put(:clan_tag, clan_war.clan_tag)
        |> Map.put(:opponent, clan_war.opponent)
        |> Map.put(:war_start_time, clan_war.start_time),
        on_conflict: {:replace, [:updated_at]},
        conflict_target: [:clan_tag, :opponent, :war_start_time, :attacker_tag, :defender_tag]
      )
      |> Multi.append(acc)
    end)
  end
end
