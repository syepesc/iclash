defmodule Iclash.DomainTypes.Clan do
  @moduledoc """
  Clan domain type.
  This module defines functionalities to interact with a Clan info.
  """

  alias Iclash.Repo
  alias Iclash.Repo.Schemas.Clan

  @type clan_tag :: String.t()

  @doc """
  Get a Clan by tag.
  If the clan is not found in the database, it will be fetched from the Clash API.
  """
  @spec get_clan(tag :: clan_tag()) :: Clan.t() | {:error, :not_found}
  def get_clan(tag) do
    result = Clan |> Repo.get(tag)

    case result do
      nil -> {:error, :not_found}
      clan -> clan
    end
  end

  @doc """
  Upsert a clan into database.
  """
  @spec upsert_clan(clan :: Clan.t()) :: :ok | {:error, Ecto.Changeset.t()}
  def upsert_clan(%Clan{} = clan) do
    case Repo.insert(clan,
           on_conflict: {:replace_all_except, [:tag, :inserted_at]},
           conflict_target: :tag
         ) do
      {:ok, _clan} -> :ok
      {:error, changeset} -> {:error, changeset}
    end
  end
end
