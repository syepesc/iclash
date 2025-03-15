defmodule Iclash.Repo.Enums.Village do
  @moduledoc """
  Enum for a Clash of Clans Heroe, Troop, Spell, or Equipment Village.
  Possible values: [:home, :builder_base, :clan_capital]
  """

  use Ecto.Type

  @villages [:home, :builder_base, :clan_capital]

  # Declare Ecto Enum
  def type, do: :string

  # Cast input values from atoms or strings to atoms
  def cast(value) when value in @villages, do: {:ok, value}

  def cast(value) when is_binary(value) do
    # Camel case to snake case
    value
    |> Macro.underscore()
    |> String.to_existing_atom()
    |> cast()
  end

  def cast(value) do
    {:error,
     message:
       "Unable to parse Village. Got '#{inspect(value)}' expected any of #{inspect(@villages)}"}
  end

  # Load from the database (always a string)
  def load(value) when is_binary(value), do: {:ok, String.to_existing_atom(value)}

  # Dump into the database as a string
  def dump(value) when value in @villages, do: {:ok, Atom.to_string(value)}

  def dump(value) do
    {:error,
     message:
       "Unexpected Village in DB. Got '#{inspect(value)}' expected any of #{inspect(@villages)}"}
  end

  # Helper function to access valid values
  def values, do: @villages
end
