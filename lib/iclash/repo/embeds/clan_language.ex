defmodule Iclash.Repo.Embeds.ClanLanguage do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :id, :integer, primary_key: true
    field :name, :string
  end

  def changeset(%__MODULE__{} = language, attrs \\ %{}) do
    language
    |> cast(attrs, [:id, :name])
    |> validate_required([:id, :name])
  end
end
