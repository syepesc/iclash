defmodule Iclash.Utils.StructUtils do
  @moduledoc false

  @doc """
  Return a map from any nested struct.
  """
  def deep_struct_to_map(%{__struct__: _} = struct) do
    struct
    |> Map.from_struct()
    # Remove Ecto metadata
    |> Map.drop([:__meta__, :__struct__])
    |> Enum.reduce(%{}, fn {key, value}, acc -> Map.put(acc, key, deep_struct_to_map(value)) end)
  end

  # Handle lists of structs
  def deep_struct_to_map(list) when is_list(list) do
    Enum.map(list, &deep_struct_to_map/1)
  end

  # Handle preloaded associations and avoid errors with `Ecto.Association.NotLoaded`
  def deep_struct_to_map(%Ecto.Association.NotLoaded{}), do: nil

  # Base case: Return non-struct values as-is
  def deep_struct_to_map(value), do: value
end
