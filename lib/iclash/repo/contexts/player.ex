defmodule Iclash.Repo.Contexts.Player do
  @moduledoc false

  import Ecto.Changeset
  alias Iclash.Repo.Schemas.Player

  @type errors_map :: %{atom() => String.t()}

  @doc """
  Returns a Player struct from a map.
  """
  @spec from_map(player :: map()) :: {:ok, Player.t()} | {:error, errors_map()}
  def from_map(%{} = player) do
    changeset = Player.changeset(%Player{}, player)

    case changeset.valid? do
      true -> {:ok, apply_changes(changeset)}
      false -> {:error, traverse_errors(changeset, &changeset_errors_to_map/1)}
    end
  end

  defp changeset_errors_to_map({msg, opts} = _errors) do
    Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
      opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
    end)
  end
end
