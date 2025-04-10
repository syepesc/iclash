defmodule Iclash.Repo.Schemas.ClanWar do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset

  alias Iclash.Repo.Enums.WarState
  alias Iclash.Repo.Schemas.ClanWarAttack
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
    :state,
    :start_time,
    :end_time
  ]

  @primary_key false
  schema "clan_wars" do
    field :clan_tag, :string, primary_key: true
    field :opponent, :string, primary_key: true
    field :state, WarState, default: nil
    field :start_time, :utc_datetime_usec, primary_key: true
    field :end_time, :utc_datetime_usec

    has_many :attacks, ClanWarAttack,
      foreign_key: :war_start_time,
      references: :start_time,
      on_replace: :delete_if_exists,
      # This preload order is used in the `Player.get_player()` function.
      preload_order: [asc: :order]

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(%__MODULE__{} = clan_war, attrs \\ %{}) do
    clan_war
    |> cast(attrs, @requiered_fields ++ @optional_fields)
    |> cast_assoc(:attacks, with: &ClanWarAttack.changeset/2)
    |> validate_required(@requiered_fields)
    |> unique_constraint([:clan_tag, :opponent, :start_time], message: "Clan War must be unique.")
    |> validate_format(:clan_tag, @starts_with_hash, message: "Tag must start with '#'.")
    |> validate_format(:clan_tag, @letters_and_numbers,
      message: "Tag must be an alphanumeric string."
    )
    |> validate_format(:opponent, @starts_with_hash, message: "Tag must start with '#'.")
    |> validate_format(:opponent, @letters_and_numbers,
      message: "Tag must be an alphanumeric string."
    )
  end

  @doc """
  Returns a ClanWar struct from a map.
  """
  @spec from_map(clan_war :: map()) :: {:ok, __MODULE__.t()} | {:error, errors_map()}
  def from_map(%{} = clan_war) do
    changeset = changeset(%__MODULE__{}, clan_war)

    case changeset.valid? do
      true ->
        {:ok, apply_changes(changeset)}

      false ->
        errors = ChagesetUtils.errors_on(changeset)
        Logger.error("Error parsing Clan War to struct. errors=#{inspect(errors)}")
        {:error, errors}
    end
  end

  @doc """
  Returns a map from a ClanWar struct.
  """
  @spec to_map(clan_war :: __MODULE__.t()) :: map()
  def to_map(%__MODULE__{} = clan_war) do
    StructUtils.deep_struct_to_map(clan_war)
  end
end
