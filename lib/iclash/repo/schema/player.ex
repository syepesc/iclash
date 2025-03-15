defmodule Iclash.Repo.Schema.Player do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias Iclash.Repo.Enum.{ClanRole, WarPreference}
  alias Iclash.Repo.Schema.Player.{Heroe, Troop, Spell}
  alias Iclash.Repo.Schema.Player.Heroe.Equipment

  @type t :: %__MODULE__{}

  @ttr_in_milliseconds :timer.hours(24)
  @starts_with_hash ~r/^#/
  @letters_and_numbers ~r/^#[A-Za-z0-9]+$/

  # `ttr`: Time To Refresh in milliseconds.
  # If current time is grater than `ttr`. Then, query api and refresh record.
  @optional_fields [:ttr]
  @requiered_fields [
    :tag,
    :name,
    :trophies,
    :town_hall_level,
    :best_trophies,
    :attack_wins,
    :defense_wins
  ]

  @primary_key {:tag, :string, []}
  schema "players" do
    field :ttr, :utc_datetime
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

    timestamps()
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
    |> calculate_ttr()
  end

  defp calculate_ttr(changeset) do
    ttr = fetch_field!(changeset, :ttr)
    updated_at = fetch_field!(changeset, :updated_at)

    if is_nil(ttr) or is_nil(updated_at) do
      ttr = DateTime.add(DateTime.utc_now(), @ttr_in_milliseconds, :millisecond)
      put_change(changeset, :ttr, ttr)
    else
      ttr = DateTime.add(updated_at, @ttr_in_milliseconds, :millisecond)
      put_change(changeset, :ttr, ttr)
    end
  end
end

defmodule Iclash.Repo.Schema.Player.Heroe do
  @moduledoc false

  use Ecto.Schema
  alias Iclash.Repo.Enum.Village
  alias Iclash.Repo.Schema.Player.Heroe.Equipment

  @required_fields [:name, :level, :max_level, :village]

  @primary_key false
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

  @primary_key false
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

  @primary_key false
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

  @primary_key false
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
