defmodule Iclash.Repo.Schemas.ClanWar do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset
  alias Iclash.Utils.{StructUtils, ChagesetUtils}
  require Logger

  @type t :: %__MODULE__{}
  @type errors_map :: %{atom() => String.t()}

  # Adding timestamps as optionnal fields comes handy when testing with a fixed time.
  @optional_fields [:inserted_at, :updated_at]
  @requiered_fields [
    :state,
    :start_time,
    :preparation_start_time,
    :end_time
  ]

  # @primary_key false
  schema "clan_wars" do
    # field :clan_tag_1, :string, primary_key: true
    # field :clan_tag_2, :string, primary_key: true
    field :state, :string, virtual: true, default: nil
    field :start_time, :string
    field :preparation_start_time, :string
    field :end_time, :string

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(%__MODULE__{} = clan_war, attrs \\ %{}) do
    clan_war
    |> cast(attrs, @requiered_fields ++ @optional_fields)
    |> validate_required(@requiered_fields)
  end

  @doc """
  Returns a ClanWar struct from a map.
  """
  @spec from_map(clan_war :: map()) :: {:ok, __MODULE__.t()} | {:error, errors_map()}
  def from_map(%{} = clan_war) do
    changeset = changeset(%__MODULE__{}, clan_war)

    case changeset.valid? do
      true ->
        {:ok, apply_changes(changeset)}

      false ->
        errors = ChagesetUtils.errors_on(changeset)
        Logger.error("Error parsing clan_war to struct. errors=#{inspect(errors)}")
        {:error, errors}
    end
  end

  @doc """
  Returns a map from a ClanWar struct.
  """
  @spec to_map(clan_war :: __MODULE__.t()) :: map()
  def to_map(%__MODULE__{} = clan_war) do
    StructUtils.deep_struct_to_map(clan_war)
  end
end
