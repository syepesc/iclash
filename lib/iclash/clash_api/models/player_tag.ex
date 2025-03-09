defmodule Iclash.ClashApi.Models.PlayerTag do
  @moduledoc false

  use TypedStruct

  @typedoc "A Clash of Clans Player tag"
  typedstruct do
    field :tag, String.t(), enforce: true
  end

  @doc """
  Returns a player tag struct or raises an error if tag is invalid. A tag is valid when:
  - Starts with "#".
  - Contains 9 characters, including the "#".
  """
  @spec new(player_tag :: String.t()) :: __MODULE__.t()
  def new(player_tag) do
    if not String.starts_with?(player_tag, "#") do
      raise("Player tag must start with '#'. e.i. '#ABCD1234'.")
    end

    if String.length(player_tag) != 9 do
      raise("Player tag must contain 9 characters including '#'. e.i. '#ABCD1234'.")
    end

    # Player tags start with hash character '#' and that needs to be URL-encoded properly
    # to work in URL, so for example player tag '#2ABC' would become '%232ABC' in the URL.
    tag = String.replace(player_tag, "#", "%23")
    %__MODULE__{tag: tag}
  end
end
