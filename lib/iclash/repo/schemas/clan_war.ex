defmodule Iclash.Repo.Schemas.ClanWar do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset

  alias Iclash.Repo.Enums.WarState
  alias Iclash.Repo.Enums.WarType
  alias Iclash.Repo.Schemas.ClanWarAttack
  alias Iclash.Utils.{StructUtils, ChagesetUtils, ClashApiUtils}

  require Logger

  @type t :: %__MODULE__{}
  @type errors_map :: %{atom() => String.t()}

  @starts_with_hash ~r/^#/
  @letters_and_numbers ~r/^#[A-Za-z0-9]+$/

  # Adding timestamps as optionnal fields comes handy when testing with a fixed time.
  @optional_fields [:inserted_at, :updated_at]
  @requiered_fields [
    :clan_tag,
    :opponent,
    :state,
    :start_time,
    :end_time,
    :war_type
  ]

  @primary_key false
  schema "clan_wars" do
    field :clan_tag, :string, primary_key: true
    field :opponent, :string, primary_key: true
    field :state, WarState, default: nil
    field :start_time, :utc_datetime_usec, primary_key: true
    field :end_time, :utc_datetime_usec
    field :war_type, WarType

    has_many :attacks, ClanWarAttack,
      foreign_key: :war_start_time,
      references: :start_time,
      on_replace: :delete_if_exists,
      # This preload order is used in the `Player.get_player()` function.
      preload_order: [asc: :order]

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(%__MODULE__{} = clan_war, attrs \\ %{}) do
    clan_war
    |> cast(attrs, @requiered_fields ++ @optional_fields)
    |> cast_assoc(:attacks, with: &ClanWarAttack.changeset/2)
    |> validate_required(@requiered_fields)
    |> unique_constraint([:clan_tag, :opponent, :start_time], message: "Clan War must be unique.")
    |> validate_format(:clan_tag, @starts_with_hash, message: "Tag must start with '#'.")
    |> validate_format(:clan_tag, @letters_and_numbers,
      message: "Tag must be an alphanumeric string."
    )
    |> validate_format(:opponent, @starts_with_hash, message: "Tag must start with '#'.")
    |> validate_format(:opponent, @letters_and_numbers,
      message: "Tag must be an alphanumeric string."
    )
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

        Logger.error(
          "Error parsing clan war to struct. errors=#{inspect(errors)} clan_war=#{inspect(clan_war)}"
        )

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

  @spec from_clash_api(response_body :: map()) :: {:ok, __MODULE__.t()} | {:error, any()}
  def from_clash_api(response_body) when is_map(response_body) do
    response_body
    # Since we are also transforming the opponent field, extracting attacks should go first than extracting opponent tag.
    |> extract_clan_war_attacks()
    |> extract_clan_tag()
    |> extract_opponent_tag()
    |> transform_date_into_datetime_struct()
    # Added war_type manually here to identify between clan_war and clan_war_league wars. This is a required field for the ClanWar schema.
    |> from_map()
  end

  defp extract_clan_war_attacks(body) do
    # As defined in the ClanWar schema, the `attacks` field is a list of attacks.
    # The Clash API provides a map containing the list of clan members for both the attacking and defending clans.
    # Each member in this list includes an `attacks` field, which represents the attacks performed by that member during the war.
    #
    # So:
    # 1) We need to extract the attacks from both `clan` and `opponent`.
    # 2) Append foreign keys from Clan War to each attack: `clan_tag`, `opponent`, `war_start_time`.
    # 3) Append the attacks into the body of the response.

    # Extract attacks from each clan member, we use Map.get() because there might be members that haven't attack yet.
    clan_attacks =
      body["clan"]["members"]
      |> Enum.map(fn member -> Map.get(member, "attacks", []) end)
      |> List.flatten()

    opponent_attacks =
      body["opponent"]["members"]
      |> Enum.map(fn member -> Map.get(member, "attacks", []) end)
      |> List.flatten()

    attacks =
      (clan_attacks ++ opponent_attacks)
      |> Enum.map(fn attack ->
        attack
        |> Map.put("clan_tag", body["clan"]["tag"])
        |> Map.put("opponent", body["opponent"]["tag"])
        |> Map.put("war_start_time", ClashApiUtils.format_date_string(body["start_time"]))
      end)

    Map.put(body, "attacks", attacks)
  end

  defp extract_clan_tag(body) do
    # As defined in the ClanWar schema, the `clan_tag` field is a string.
    # However, Clash API return a map with the clan info.
    #
    # So:
    # 1) We need to extract the clan tag.
    # 2) Append the tag into the body of the response.
    clan_tag = body["clan"]["tag"]
    Map.put(body, "clan_tag", clan_tag)
  end

  defp extract_opponent_tag(body) do
    # As defined in the ClanWar schema, the `opponent` field is a string.
    # However, Clash API return a map with the opponent clan info.
    #
    # So:
    # 1) We need to extract the oppoent clan tag.
    # 2) Append the tag into the body of the response.
    opponent_tag = body["opponent"]["tag"]
    Map.put(body, "opponent", opponent_tag)
  end

  defp transform_date_into_datetime_struct(body) do
    # As defined in the ClanWar schema, the `start_time` and `end_time` are `utc_datetime_usec`.
    # However, Clash API return a string with the following format representing a date: "20250330T105010.000Z"
    #
    # So:
    # 1) We need to transform the date string into Elixir DateTime.
    # 2) Append the transform date into the body of the response.
    body
    |> Map.put("start_time", ClashApiUtils.format_date_string(body["start_time"]))
    |> Map.put("end_time", ClashApiUtils.format_date_string(body["end_time"]))
  end
end
