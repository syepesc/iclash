defmodule Iclash.Repo.Schemas.Player do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias Iclash.Repo.Enums.{ClanRole, WarPreference}
  alias Iclash.Repo.Schemas.Player.Heroe

  @type t :: %__MODULE__{}

  @starts_with_hash ~r/^#/
  @letters_and_numbers ~r/^#[A-Za-z0-9]+$/

  @requiered_fields [:tag, :name, :role, :war_preference]
  @optional_fields []

  schema "players" do
    field :tag, :string
    field :name, :string
    field :role, ClanRole
    field :war_preference, WarPreference
    embeds_many :heroes, Heroe
    timestamps()
  end

  def changeset(player, attrs) do
    player
    |> cast(attrs, @requiered_fields ++ @optional_fields)
    |> cast_embed(:heroes, on_replace: :delete)
    |> validate_required(@requiered_fields)
    |> validate_format(:tag, @starts_with_hash, message: "Tag must start with '#'.")
    |> validate_format(:tag, @letters_and_numbers, message: "Tag must be an alphanumeric string.")
  end
end

defmodule Iclash.Repo.Schemas.Player.Heroe do
  @moduledoc false

  use Ecto.Schema
  alias Iclash.Repo.Enums.Village
  alias Iclash.Repo.Schemas.Player.Heroe.Equipment

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

defmodule Iclash.Repo.Schemas.Player.Heroe.Equipment do
  @moduledoc false

  use Ecto.Schema
  alias Iclash.Repo.Enums.Village

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
