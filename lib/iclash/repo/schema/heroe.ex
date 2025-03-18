defmodule Iclash.Repo.Schema.Heroe do
  @moduledoc false

  use Ecto.Schema
  alias Iclash.Repo.Enum.Village
  alias Iclash.Repo.Schema.Player

  @required_fields [:name, :level, :max_level, :village]

  schema "heroes" do
    field :name, :string
    field :level, :integer
    field :max_level, :integer
    field :village, Village

    belongs_to :player, Player, type: :string, foreign_key: :tag, on_replace: :delete
    timestamps(type: :utc_datetime_usec)

    def changeset(heroe, attrs) do
      heroe
      |> Ecto.Changeset.cast(attrs, @required_fields)
      |> Ecto.Changeset.validate_required(@required_fields)
    end
  end
end
