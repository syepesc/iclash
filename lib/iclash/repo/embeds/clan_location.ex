defmodule Iclash.Repo.Embeds.ClanLocation do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :id, :integer, primary_key: true
    field :name, :string
  end

  def changeset(%__MODULE__{} = country, attrs \\ %{}) do
    country
    |> cast(attrs, [:id, :name])
    |> validate_required([:id, :name])
  end
end
