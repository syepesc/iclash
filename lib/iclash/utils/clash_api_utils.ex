defmodule Iclash.Utils.ClashApiUtils do
  def format_date_string(date_string) do
    String.replace(
      date_string,
      ~r/(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})/,
      "\\1-\\2-\\3T\\4:\\5:\\6"
    )
  end
end
