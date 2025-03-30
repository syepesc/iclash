defmodule Iclash.Repo.Enums.Warfrequency do
  @moduledoc """
  Enum for a Clash of Clans Clan War frequency.
  Possible values: UNKNOWN, ALWAYS, MORE_THAN_ONCE_PER_WEEK, ONCE_PER_WEEK, LESS_THAN_ONCE_PER_WEEK, NEVER, ANY
  """

  use Ecto.Type

  @war_frequency [
    :unknown,
    :always,
    :more_than_once_per_week,
    :once_per_week,
    :less_than_once_per_week,
    :never,
    :any
  ]

  # Declare Ecto Enum
  def type, do: :string

  # Cast input values from atoms or strings to atoms
  def cast(value) when value in @war_frequency, do: {:ok, value}

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
       "Unable to parse War Frequency. Got '#{inspect(value)}' expected any of #{inspect(@war_frequency)}"}
  end

  # Load from the database (always a string)
  def load(value) when is_binary(value), do: {:ok, String.to_existing_atom(value)}

  # Dump into the database as a string
  def dump(value) when value in @war_frequency, do: {:ok, Atom.to_string(value)}

  def dump(value) do
    {:error,
     message:
       "Unexpected War Frequency in DB. Got '#{inspect(value)}' expected any of #{inspect(@war_frequency)}"}
  end

  # Helper function to access valid values
  def values, do: @war_frequency
end
