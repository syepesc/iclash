defmodule Iclash.DomainTypes.Clan do
  @moduledoc """
  Clan domain type.
  This module defines functionalities to interact with a Clan info.
  """

  # import Ecto.Query

  alias Iclash.ClashApi
  alias Iclash.Repo
  alias Iclash.Repo.Schemas.Clan

  @doc """
  Get a Clan by tag.
  If the clan is not found in the database, it will be fetched from the Clash API.
  """
  @spec get_clan(tag :: String.t()) :: Clan.t() | {:error, :not_found}
  def get_clan(tag) do
    result = Clan |> Repo.get(tag)

    case result do
      nil ->
        case ClashApi.fetch_clan(tag) do
          {:ok, clan} -> clan
          {:error, _} -> {:error, :not_found}
        end

      clan ->
        clan
    end
  end

  @doc """
  Upsert a clan into database.
  """
  @spec upsert_clan(clan :: Clan.t()) :: {:ok, Clan.t()} | {:error, Ecto.Changeset.t()}
  def upsert_clan(%Clan{} = clan) do
    Repo.insert(clan,
      on_conflict: {:replace_all_except, [:tag, :inserted_at]},
      conflict_target: :tag
    )
  end
end
