defmodule Iclash.Repo.Schema.Player do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias Iclash.Repo.Enum.{ClanRole, WarPreference}
  alias Iclash.Repo.Schema.Player.{Heroe, Troop, Spell}
  alias Iclash.Repo.Schema.Player.Heroe.Equipment
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

    embeds_many :heroes, Heroe
    embeds_many :hero_equipment, Equipment
    embeds_many :troops, Troop
    embeds_many :spells, Spell

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(player, attrs) do
    player
    |> cast(attrs, @requiered_fields ++ @optional_fields)
    |> cast_embed(:heroes, on_replace: :delete)
    |> cast_embed(:hero_equipment, on_replace: :delete)
    |> cast_embed(:troops, on_replace: :delete)
    |> cast_embed(:spells, on_replace: :delete)
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
        errors = traverse_errors(changeset, &changeset_errors_to_map/1)
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

  defp changeset_errors_to_map({msg, opts} = _errors) do
    Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
      opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
    end)
  end
end

defmodule Iclash.Repo.Schema.Player.Heroe do
  @moduledoc false

  use Ecto.Schema
  alias Iclash.Repo.Enum.Village
  alias Iclash.Repo.Schema.Player.Heroe.Equipment

  @required_fields [:name, :level, :max_level, :village]

  embedded_schema do
    field :name, :string
    field :level, :integer
    field :max_level, :integer
    field :village, Village
    embeds_many :equipment, Equipment

    def changeset(heroe, attrs) do
      heroe
      |> Ecto.Changeset.cast(attrs, @required_fields)
      |> Ecto.Changeset.cast_embed(:equipment, on_replace: :delete)
      |> Ecto.Changeset.validate_required(@required_fields)
    end
  end
end

defmodule Iclash.Repo.Schema.Player.Heroe.Equipment do
  @moduledoc false

  use Ecto.Schema
  alias Iclash.Repo.Enum.Village

  @required_fields [:name, :level, :max_level, :village]

  embedded_schema do
    field :name, :string
    field :level, :integer
    field :max_level, :integer
    field :village, Village
  end

  def changeset(equipment, attrs) do
    equipment
    |> Ecto.Changeset.cast(attrs, @required_fields)
    |> Ecto.Changeset.validate_required(@required_fields)
  end
end

defmodule Iclash.Repo.Schema.Player.Spell do
  @moduledoc false

  use Ecto.Schema
  alias Iclash.Repo.Enum.Village

  @required_fields [:name, :level, :max_level, :village]

  embedded_schema do
    field :name, :string
    field :level, :integer
    field :max_level, :integer
    field :village, Village
  end

  def changeset(equipment, attrs) do
    equipment
    |> Ecto.Changeset.cast(attrs, @required_fields)
    |> Ecto.Changeset.validate_required(@required_fields)
  end
end

defmodule Iclash.Repo.Schema.Player.Troop do
  @moduledoc false

  use Ecto.Schema
  alias Iclash.Repo.Enum.Village

  @required_fields [:name, :level, :max_level, :village]

  embedded_schema do
    field :name, :string
    field :level, :integer
    field :max_level, :integer
    field :village, Village
  end

  def changeset(equipment, attrs) do
    equipment
    |> Ecto.Changeset.cast(attrs, @required_fields)
    |> Ecto.Changeset.validate_required(@required_fields)
  end
end
