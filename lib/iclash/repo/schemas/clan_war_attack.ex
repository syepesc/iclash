defmodule Iclash.Repo.Schemas.ClanWarAttack do
  @moduledoc """
  Represents an Attack in a Clan War.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Iclash.Utils.{StructUtils, ChagesetUtils}

  require Logger

  @type t :: %__MODULE__{}
  @type errors_map :: %{atom() => String.t()}

  @starts_with_hash ~r/^#/
  @letters_and_numbers ~r/^#[A-Za-z0-9]+$/

  # Adding timestamps as optionnal fields comes handy when testing with a fixed time.
  @optional_fields [:inserted_at, :updated_at]
  @requiered_fields [
    :clan_tag,
    :opponent,
    :war_start_time,
    :attacker_tag,
    :defender_tag,
    :stars,
    :destruction_percentage,
    :order,
    :duration
  ]

  @primary_key false
  schema "clan_war_attacks" do
    # This are the foreign keys from clan_wars table used as part of the composite primary key.
    field :clan_tag, :string, primary_key: true
    field :opponent, :string, primary_key: true
    field :war_start_time, :utc_datetime_usec, primary_key: true

    field :attacker_tag, :string, primary_key: true
    field :defender_tag, :string, primary_key: true
    field :stars, :integer
    field :destruction_percentage, :integer
    field :order, :integer
    field :duration, :integer

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(%__MODULE__{} = clan_war_attack, attrs \\ %{}) do
    clan_war_attack
    |> cast(attrs, @requiered_fields ++ @optional_fields)
    |> validate_required(@requiered_fields)
    |> unique_constraint([:clan_tag, :opponent, :war_start_time, :attacker_tag, :defender_tag],
      message: "Clan War Attack must be unique."
    )
    |> validate_format(:attacker_tag, @starts_with_hash,
      message: "Player Tag must start with '#'."
    )
    |> validate_format(:attacker_tag, @letters_and_numbers,
      message: "Player Tag must be an alphanumeric string."
    )
    |> validate_format(:defender_tag, @starts_with_hash,
      message: "Player Tag must start with '#'."
    )
    |> validate_format(:defender_tag, @letters_and_numbers,
      message: "Player Tag must be an alphanumeric string."
    )
  end

  @doc """
  Returns a ClanWarAttack struct from a map.
  """
  @spec from_map(clan_war_attack :: map()) :: {:ok, __MODULE__.t()} | {:error, errors_map()}
  def from_map(%{} = clan_war_attack) do
    changeset = changeset(%__MODULE__{}, clan_war_attack)

    case changeset.valid? do
      true ->
        {:ok, apply_changes(changeset)}

      false ->
        errors = ChagesetUtils.errors_on(changeset)

        Logger.error(
          "Error parsing clan war attack to struct. errors=#{inspect(errors)} clan_war_attack=#{inspect(clan_war_attack)}"
        )

        {:error, errors}
    end
  end

  @doc """
  Returns a map from a ClanWarAttack struct.
  """
  @spec to_map(clan_war_attack :: __MODULE__.t()) :: map()
  def to_map(%__MODULE__{} = clan_war_attack) do
    StructUtils.deep_struct_to_map(clan_war_attack)
  end
end
