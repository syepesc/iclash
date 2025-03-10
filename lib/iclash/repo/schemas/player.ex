defmodule Iclash.Repo.Schemas.Player do
  @moduledoc false

  use TypedStruct

  @typedoc "A Clash of Clans Player info"
  typedstruct do
    field :tag, String.t(), enforce: true
    field :name, String.t()
  end

  @spec new(map()) :: __MODULE__.t() | no_return()
  def new(%{} = player) do
    tag = Map.fetch!(player, "tag")
    name = Map.fetch!(player, "name")

    %__MODULE__{
      tag: tag,
      name: name
    }
  end
end
