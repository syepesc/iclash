defmodule Iclash.Utils.ClashApiUtils do
  @doc """
  Formats a date string from a compact format to a more readable ISO 8601 format.

  ## Parameters
    - date_string: A string representing a date in the format `YYYYMMDDTHHMMSS`.

  ## Returns
    - A string formatted as `YYYY-MM-DDTHH:MM:SS`.

  ## Examples

      iex> format_date_string("20230516T123456")
      "2023-05-16T12:34:56"

      iex> format_date_string("19991231T235959")
      "1999-12-31T23:59:59"

      iex> format_date_string("20220101T000000")
      "2022-01-01T00:00:00"
  """
  @spec format_date_string(date_string :: String.t()) :: String.t()
  def format_date_string(date_string) do
    String.replace(
      date_string,
      ~r/(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})/,
      "\\1-\\2-\\3T\\4:\\5:\\6"
    )
  end
end
