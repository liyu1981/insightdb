defmodule Insightdb.HttpCommand.MergeStrategy do

  def fb(%{body: %{"data" => data}}, accumulator) do
    {:ok, accumulator ++ data}
  end

  def fb(response, _) do
    {:error, "can not understand data #{inspect response}"}
  end

end
