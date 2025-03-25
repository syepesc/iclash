defmodule Iclash.Repo.Schemas.LegendStatistic do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset
  alias Iclash.Repo.Schemas.Player

  @optional_fields [:player_tag, :inserted_at, :updated_at]
  @required_fields [:id, :rank, :trophies]

  @primary_key false
  schema "legend_statistics" do
    field :id, :string, primary_key: true
    field :rank, :integer
    field :trophies, :integer

    belongs_to :player, Player,
      foreign_key: :player_tag,
      references: :tag,
      type: :string,
      on_replace: :update,
      primary_key: true

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(%__MODULE__{} = legend_statistic, attrs \\ %{}) do
    legend_statistic
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
  end
end
