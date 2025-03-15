defmodule Iclash.Repo.Enums.ClanRole do
  @moduledoc """
  Enum for a Clash of Clans Player Clan Role.
  Possible values: [:not_member, :member, :leader, :admin, :coleader]
  """

  use Ecto.Type

  @clan_roles [:not_member, :member, :leader, :admin, :coleader]

  # Declare Ecto Enum
  def type, do: :string

  # Cast input values from atoms or strings to atoms
  def cast(value) when value in @clan_roles, do: {:ok, value}

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
       "Unable to parse Clan Role. Got '#{inspect(value)}' expected any of #{inspect(@clan_roles)}"}
  end

  # Load from the database (always a string)
  def load(value) when is_binary(value), do: {:ok, String.to_existing_atom(value)}

  # Dump into the database as a string
  def dump(value) when value in @clan_roles, do: {:ok, Atom.to_string(value)}

  def dump(value) do
    {:error,
     message:
       "Unexpected Clan Role in DB. Got '#{inspect(value)}' expected any of #{inspect(@clan_roles)}"}
  end

  # Helper function to access valid values
  def values, do: @clan_roles
end
