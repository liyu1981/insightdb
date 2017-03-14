defmodule Insightdb.HttpCommand.MergeStrategyTest do
  use ExUnit.Case

  alias Insightdb.HttpCommand.MergeStrategy, as: MergeStrategy

  test "normal merge" do
    resp = %HTTPoison.Response{
      body: %{
        "data" => [4, 5, 6],
      },
      headers: [],
      status_code: 200,
    }
    assert {:ok, [1, 2, 3, 4, 5, 6]} = MergeStrategy.fb(resp, [1, 2, 3])
  end

  test "error" do
    resp = %HTTPoison.Response{
      body: %{},
      headers: [],
      status_code: 200,
    }
    assert {:error, _} = MergeStrategy.fb(resp, [])
  end

end
