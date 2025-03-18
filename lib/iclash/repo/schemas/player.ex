defmodule Iclash.Repo.Schemas.Player do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias Iclash.Repo.Enums.{ClanRole, WarPreference}
  alias Iclash.Repo.Schemas.Heroe
  alias Iclash.Utils.StructUtils

  require Logger

  @type t :: %__MODULE__{}
  @type errors_map :: %{atom() => String.t()}

  @starts_with_hash ~r/^#/
  @letters_and_numbers ~r/^#[A-Za-z0-9]+$/

  @optional_fields []
  @requiered_fields [
    :tag,
    :name,
    :trophies,
    :town_hall_level,
    :best_trophies,
    :attack_wins,
    :defense_wins,
    :role,
    :war_preference
  ]

  @primary_key {:tag, :string, []}
  schema "players" do
    field :name, :string
    field :trophies, :integer
    field :town_hall_level, :integer
    field :best_trophies, :integer
    field :attack_wins, :integer
    field :defense_wins, :integer
    field :role, ClanRole
    field :war_preference, WarPreference

    # The on_delete behaviour MUST be defined in the assoc migration using: references().
    has_many :heroes, Heroe, foreign_key: :tag, on_delete: :delete_all
    timestamps(type: :utc_datetime_usec)
  end

  def changeset(player, attrs) do
    player
    |> cast(attrs, @requiered_fields ++ @optional_fields)
    |> cast_assoc(:heroes, with: &Heroe.changeset/2)
    |> unique_constraint([:tag], name: :players_unique_tag_index, message: "Tag must be unique.")
    |> validate_required(@requiered_fields)
    |> validate_format(:tag, @starts_with_hash, message: "Tag must start with '#'.")
    |> validate_format(:tag, @letters_and_numbers, message: "Tag must be an alphanumeric string.")
  end

  @doc """
  Returns a Player struct from a map.
  """
  @spec to_struct(player :: map()) :: {:ok, __MODULE__.t()} | {:error, errors_map()}
  def to_struct(%{} = player) do
    changeset = changeset(%__MODULE__{}, player)

    case changeset.valid? do
      true ->
        {:ok, apply_changes(changeset)}

      false ->
        errors = changeset_errors_to_map(changeset)
        Logger.error("Error parsing player to struct. errors=#{inspect(errors)}")
        {:error, errors}
    end
  end

  @doc """
  Returns a map from a Player struct.
  """
  @spec to_map(player :: __MODULE__.t()) :: map()
  def to_map(%__MODULE__{} = player) do
    StructUtils.deep_struct_to_map(player)
  end

  defp changeset_errors_to_map(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
