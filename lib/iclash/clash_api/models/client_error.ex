defmodule Iclash.ClashApi.Models.ClientError do
  @moduledoc false

  use TypedStruct

  @typedoc "A Clash of Clans API client error"
  typedstruct do
    field :message, String.t()
    field :reason, String.t()
  end

  @spec new(map()) :: __MODULE__.t()
  def new(%{} = client_error) do
    %__MODULE__{
      message: client_error["message"],
      reason: client_error["reason"]
    }
  end
end
