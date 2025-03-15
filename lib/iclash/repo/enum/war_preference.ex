defmodule Iclash.Repo.Enum.WarPreference do
  @moduledoc """
  Enum for a Clash of Clans Player War Preference.
  Possible values: [:in, :out]
  """

  use Ecto.Type

  @war_preferences [:in, :out]

  # Declare Ecto Enum
  def type, do: :string

  # Cast input values from atoms or strings to atoms
  def cast(value) when value in @war_preferences, do: {:ok, value}

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
       "Unable to parse War Preference. Got '#{inspect(value)}' expected any of #{inspect(@war_preferences)}"}
  end

  # Load from the database (always a string)
  def load(value) when is_binary(value), do: {:ok, String.to_existing_atom(value)}

  # Dump into the database as a string
  def dump(value) when value in @war_preferences, do: {:ok, Atom.to_string(value)}

  def dump(value) do
    {:error,
     message:
       "Unexpected War Preference in DB. Got '#{inspect(value)}' expected any of #{inspect(@war_preferences)}"}
  end

  # Helper function to access valid values
  def values, do: @war_preferences
end
