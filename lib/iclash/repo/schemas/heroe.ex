defmodule Iclash.Repo.Schemas.Heroe do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias Iclash.Repo.Enums.Village
  alias Iclash.Repo.Schemas.Player

  # Adding timestamps as optionnal fields comes handy when testing with a fixed time.
  @optional_fields [:player_id, :inserted_at, :updated_at]
  @required_fields [:name, :level, :max_level, :village]

  # To define a composite-key we need to add `primary_key: true` to
  # both fields that forms the primary key. Finally add it to the migration.
  @primary_key false
  schema "heroes" do
    field :name, :string, primary_key: true
    field :level, :integer
    field :max_level, :integer
    field :village, Village

    belongs_to :player, Player,
      foreign_key: :player_id,
      primary_key: true,
      type: :string,
      references: :tag,
      on_replace: :update

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(heroe, attrs) do
    heroe
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
  end
end
