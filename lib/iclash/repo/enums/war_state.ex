defmodule Iclash.Repo.Enums.WarState do
  @moduledoc """
  Enum for a Clash of Clans Heroe, Troop, Spell, or Equipment War State.
  Possible values: [:in_war, :war_ended] we do not care for other possible values return by ClashAPI.

  `in_war`: Indicates that the clan is currently in a war, can be use to update current war State in DB.
  `war_ended`:  This function determines whether a war has concluded.
                  It is particularly useful for retrieving the final results of a war
                  in scenarios where a player launches an attack at the very last moment,
                  and the periodic end-time update process fails to account for this
                  last-second change, similar to how Clash of Clans ensures accurate war
                  statistics by capturing late-stage attacks.
  """

  use Ecto.Type

  @war_state [:in_war, :war_ended]

  # Declare Ecto Enum
  def type, do: :string

  # Cast input values from atoms or strings to atoms
  def cast(value) when value in @war_state, do: {:ok, value}

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
       "Unable to parse War State. Got '#{inspect(value)}' expected any of #{inspect(@war_state)}"}
  end

  # Load from the database (always a string)
  def load(value) when is_binary(value), do: {:ok, String.to_existing_atom(value)}

  # Dump into the database as a string
  def dump(value) when value in @war_state, do: {:ok, Atom.to_string(value)}

  def dump(value) do
    {:error,
     message:
       "Unexpected War State in DB. Got '#{inspect(value)}' expected any of #{inspect(@war_state)}"}
  end

  # Helper function to access valid values
  def values, do: @war_state
end
