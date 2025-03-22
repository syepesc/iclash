defmodule Iclash.Repo.Schemas.Spell do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias Iclash.Repo.Enums.Village
  alias Iclash.Repo.Schemas.Player

  # `:player_tag` is optional because after applying the changeset for new players this field is nil.
  # So, it will raise an error if it is required, instead of optional.
  # However, in the DB this field is required since is part of the composite key.
  # Adding timestamps as optionnal fields comes handy when testing with a fixed time.
  @optional_fields [:player_tag, :inserted_at, :updated_at]
  @required_fields [:name, :level, :max_level, :village]

  # To define a composite-key we need to add `primary_key: true` to
  # the fields that forms the primary key. Finally add it to the migration.
  @primary_key false
  schema "spells" do
    field :name, :string, primary_key: true
    field :level, :integer, primary_key: true
    field :max_level, :integer
    field :village, Village

    belongs_to :player, Player,
      foreign_key: :player_tag,
      primary_key: true,
      type: :string,
      references: :tag,
      on_replace: :update

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(%__MODULE__{} = spell, attrs \\ %{}) do
    spell
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
  end
end
