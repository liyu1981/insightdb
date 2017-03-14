defmodule Insightdb.HttpCommand.PagingStrategy do

  def fb(%{body: %{"data" => data, "paging" => %{"next" => next_url}}}) do
    if length(data) > 0 and byte_size(next_url) > 0 do
      {:ok, next_url}
    else
      {:no, ""}
    end
  end

  def fb(_) do
    {:no, ""}
  end

end
