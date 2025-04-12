defmodule Iclash.Repo.Schemas.Clan do
  @moduledoc false

  # TODO: Extend clan schema with Clan Wars.
  # TODO: Extend clan schema with Clan War League Statistics.
  # TODO: Extend clan schema with Clan War Log, take into count the `is_war_log_public` variable.

  use Ecto.Schema
  import Ecto.Changeset

  alias Iclash.Repo.Enums.{Warfrequency, ClanType}
  alias Iclash.Repo.Embeds.{ClanLocation, ClanLanguage, ClanMember}
  alias Iclash.Utils.{StructUtils, ChagesetUtils}

  require Logger

  # this will return the ecto schema as a type
  @type t :: %__MODULE__{}
  @type errors_map :: %{atom() => String.t()}

  @starts_with_hash ~r/^#/
  @letters_and_numbers ~r/^#[A-Za-z0-9]+$/

  # Adding timestamps as optional fields comes handy when testing with a fixed time.
  @optional_fields [:inserted_at, :updated_at, :description, :war_frequency]
  @requiered_fields [
    :tag,
    :name,
    :type,
    :clan_level,
    :war_win_streak,
    :war_wins,
    :war_ties,
    :war_losses,
    :is_war_log_public
  ]

  @primary_key {:tag, :string, []}
  schema "clans" do
    field :name, :string
    field :type, ClanType
    field :description, :string
    field :clan_level, :integer
    field :war_frequency, Warfrequency
    field :war_win_streak, :integer, default: 0
    field :war_wins, :integer, default: 0
    field :war_ties, :integer, default: 0
    field :war_losses, :integer, default: 0
    field :is_war_log_public, :boolean

    embeds_one :location, ClanLocation, on_replace: :update, defaults_to_struct: true
    embeds_one :chat_language, ClanLanguage, on_replace: :update, defaults_to_struct: true

    embeds_many :member_list, ClanMember, on_replace: :delete

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(%__MODULE__{} = clan, attrs \\ %{}) do
    clan
    |> cast(attrs, @requiered_fields ++ @optional_fields)
    |> cast_embed(:location, with: &ClanLocation.changeset/2)
    |> cast_embed(:chat_language, with: &ClanLanguage.changeset/2)
    |> cast_embed(:member_list, with: &ClanMember.changeset/2)
    |> validate_required(@requiered_fields)
    |> unique_constraint([:tag], message: "Clan Tag must be unique.")
    |> validate_format(:tag, @starts_with_hash, message: "Tag must start with '#'.")
    |> validate_format(:tag, @letters_and_numbers, message: "Tag must be an alphanumeric string.")
  end

  @doc """
  Returns a Clan struct from a map.
  """
  @spec from_map(clan :: map()) :: {:ok, __MODULE__.t()} | {:error, errors_map()}
  def from_map(%{} = clan) do
    changeset = changeset(%__MODULE__{}, clan)

    case changeset.valid? do
      true ->
        {:ok, apply_changes(changeset)}

      false ->
        errors = ChagesetUtils.errors_on(changeset)
        Logger.error("Error parsing Clan to struct. errors=#{inspect(errors)}")
        {:error, errors}
    end
  end

  @doc """
  Returns a map from a Clan struct.
  """
  @spec to_map(clan :: __MODULE__.t()) :: map()
  def to_map(%__MODULE__{} = clan) do
    StructUtils.deep_struct_to_map(clan)
  end
end
