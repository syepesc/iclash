defmodule Iclash.DomainTypes.Clan do
  @moduledoc """
  Clan domain type.
  This module defines functionalities to interact with a Clan info.
  """

  # import Ecto.Query

  alias Iclash.Repo
  alias Iclash.Repo.Schemas.Clan

  @doc """
  Get a Clan by tag.
  """
  @spec get_clan(clan_tag :: String.t()) :: Clan.t() | {:error, :not_found}
  def get_clan(clan_tag) do
    result = Clan |> Repo.get(clan_tag)

    case result do
      nil -> {:error, :not_found}
      player -> player
    end
  end
end
