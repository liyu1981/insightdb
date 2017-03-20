defmodule Insightdb.Command.HttpCommand.PagingStrategyTest do
  use ExUnit.Case

  alias Insightdb.Command.HttpCommand.PagingStrategy, as: PagingStrategy

  test "normal" do
    resp = %HTTPoison.Response{
      body: %{
        "data" => [1,2,3],
        "paging" => %{"next" => "https://www.facebook.com/next"},
      },
      headers: [],
      status_code: 200,
    }
    assert {:ok, _} = PagingStrategy.fb(resp)
  end

  test "empty" do
    assert {:no, _} = PagingStrategy.fb(%{})
  end

  test "data is empty" do
    resp = %HTTPoison.Response{
      body: %{
        "data" => [],
        "paging" => %{"next": "https://www.facebook.com/next"},
      },
      headers: [],
      status_code: 200,
    }
    assert {:no, _} = PagingStrategy.fb(resp)
  end

  test "general no case 1" do
    resp = %HTTPoison.Response{
      body: %{
        "data" => [1,2,3],
        "paging" => %{},
      },
      headers: [],
      status_code: 200,
    }
    assert {:no, _} = PagingStrategy.fb(resp)
  end

  test "general no case 2" do
    resp = %HTTPoison.Response{
      body: %{
        "data" => [1,2,3],
        "paging" => %{"next": ""},
      },
      headers: [],
      status_code: 200,
    }
    assert {:no, _} = PagingStrategy.fb(resp)
  end

end
