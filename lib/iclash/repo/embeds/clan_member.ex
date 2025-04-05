defmodule Iclash.Repo.Embeds.ClanMember do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset
  alias Iclash.Repo.Enums.ClanRole

  @required_fields [:tag, :name]
  @optional_fields [
    :role,
    :donations,
    :donations_received,
    :trophies,
    :clan_rank
  ]

  @primary_key false
  embedded_schema do
    field :tag, :string
    field :name, :string
    field :role, ClanRole
    field :donations, :integer
    field :donations_received, :integer
    field :trophies, :integer
    field :clan_rank, :integer
  end

  def changeset(%__MODULE__{} = clan_member, attrs \\ %{}) do
    clan_member
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
  end
end
