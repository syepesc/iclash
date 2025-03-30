defmodule Iclash.Repo.Enums.ClanType do
  @moduledoc """
  Enum for a Clash of Clans Clan Type.
  Possible values: OPEN, INVITE_ONLY, CLOSED
  """

  use Ecto.Type

  @clan_types [:open, :invite_only, :closed]

  # Declare Ecto Enum
  def type, do: :string

  # Cast input values from atoms or strings to atoms
  def cast(value) when value in @clan_types, do: {:ok, value}

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
       "Unable to parse Clan Type. Got '#{inspect(value)}' expected any of #{inspect(@clan_types)}"}
  end

  # Load from the database (always a string)
  def load(value) when is_binary(value), do: {:ok, String.to_existing_atom(value)}

  # Dump into the database as a string
  def dump(value) when value in @clan_types, do: {:ok, Atom.to_string(value)}

  def dump(value) do
    {:error,
     message:
       "Unexpected Clan Type in DB. Got '#{inspect(value)}' expected any of #{inspect(@clan_types)}"}
  end

  # Helper function to access valid values
  def values, do: @clan_types
end
