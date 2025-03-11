defmodule Iclash.Repo.Schemas.Player do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @starts_with_hash ~r/^#/
  @letters_and_numbers ~r/^#[A-Za-z0-9]+$/

  schema "players" do
    field :tag, :string
    field :name, :string
    timestamps()
  end

  def changeset(player, attrs) do
    player
    |> cast(attrs, [:tag, :name])
    |> validate_required([:tag])
    |> validate_format(:tag, @starts_with_hash, message: "Tag must start with '#'.")
    |> validate_format(:tag, @letters_and_numbers, message: "Tag must be an alphanumeric string.")
  end
end
