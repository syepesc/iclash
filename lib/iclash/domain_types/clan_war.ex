defmodule Iclash.DomainTypes.ClanWar do
  @moduledoc """
  ClanWar domain type.
  This module defines functionalities to interact with a ClanWar data struct.
  """

  import Ecto.Query

  alias Iclash.Repo.Schemas.ClanWarAttack
  alias Iclash.Repo
  alias Iclash.Repo.Schemas.ClanWar

  require Logger

  @type clan_tag :: String.t()

  @doc """
  Get all clan wars by clan tag.
  If the clan war is not found in the database, it will be fetched from the Clash API.
  """
  @spec get_clan_wars(tag :: clan_tag()) :: [ClanWar.t()] | {:error, :not_found}
  def get_clan_wars(tag) do
    attacks_query = from cwa in ClanWarAttack, order_by: [asc: cwa.order]

    result =
      from(cw in ClanWar, where: cw.clan_tag == ^tag, preload: [attacks: ^attacks_query])
      |> Repo.all()

    case result do
      [] -> {:error, :not_found}
      clan_wars -> clan_wars
    end
  end

  @doc """
  Upsert a clan war into database.
  """
  @spec upsert_clan_war(clan_war :: ClanWar.t()) :: :ok | {:error, any()} | Ecto.Multi.failure()
  def upsert_clan_war(%ClanWar{} = clan_war) do
    with {:ok, _} <- insert_query_for_clan_war(clan_war),
         {:ok, _} <- insert_queries_for_attacks(clan_war) do
      Logger.info("Clan War upserted successfully. clan_tag=#{clan_war.clan_tag}")
      :ok
    else
      {:error, reason} ->
        Logger.error(
          "Failed to upsert some Clan War info. error=#{inspect(reason)} clan_tag=#{clan_war.clan_tag}"
        )

        {:error, reason}
    end
  end

  # TODO: get clan wars by player tag

  defp insert_query_for_clan_war(clan_war) do
    Repo.insert(
      # Remove attacks to handle them separately.
      clan_war
      |> Map.put(:attacks, []),
      on_conflict: {:replace_all_except, [:clan_tag, :opponent, :start_time, :inserted_at]},
      conflict_target: [:clan_tag, :opponent, :start_time]
    )
  end

  defp insert_queries_for_attacks(clan_war) do
    results =
      Enum.map(clan_war.attacks, fn attack ->
        Repo.insert(
          attack
          |> Map.put(:clan_tag, clan_war.clan_tag)
          |> Map.put(:opponent, clan_war.opponent)
          |> Map.put(:war_start_time, clan_war.start_time),
          on_conflict: {:replace, [:updated_at]},
          conflict_target: [:clan_tag, :opponent, :war_start_time, :attacker_tag, :defender_tag]
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
