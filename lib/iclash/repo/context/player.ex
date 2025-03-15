defmodule Iclash.Repo.Context.Player do
  @moduledoc false

  import Ecto.Changeset
  alias Iclash.Repo.Schema.Player

  require Logger

  @type errors_map :: %{atom() => String.t()}

  @doc """
  Returns a Player struct from a map.
  """
  @spec from_map(player :: map()) :: {:ok, Player.t()} | {:error, errors_map()}
  def from_map(%{} = player) do
    changeset = Player.changeset(%Player{}, player)

    case changeset.valid? do
      true ->
        {:ok, apply_changes(changeset)}

      false ->
        errors = traverse_errors(changeset, &changeset_errors_to_map/1)
        Logger.error("Error parsing player to struct. errors=#{inspect(errors)}")
        {:error, errors}
    end
  end

  defp changeset_errors_to_map({msg, opts} = _errors) do
    Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
      opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
    end)
  end
end
