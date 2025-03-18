defmodule Iclash.DomainType.Player do
  @moduledoc false

  alias Iclash.Repo
  alias Iclash.Repo.Schemas.Player

  require Logger

  @spec get_player(tag :: String.t()) :: Player.t() | {:error, :not_found}
  def get_player(tag) do
    case Repo.get(Player, tag) do
      nil -> {:error, :not_found}
      player -> player
    end
  end
end
