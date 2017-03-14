defmodule Insightdb.HttpCommandTest do
  use ExUnit.Case

  alias Insightdb.HttpCommand, as: HttpCommand

  setup do
    use Insightdb.HttpCommand
  end

  test "html 200" do
    assert {:ok, response} = HttpCommand.run(:get, "http://www.qq.com")
    assert is_binary(response.body)
  end

  test "html 301" do
    assert {:ok, response} = HttpCommand.run(:get, "https://www.google.com")
    assert is_binary(response.body)
  end

  test "json 200" do
    assert {:ok, response} = HttpCommand.run(:get, "http://ip.jsontest.com")
    assert is_map(response.body)
    assert byte_size(response.body["ip"]) > 0
  end

  test "wrong verb" do
    try do
      HttpCommand.run(:get!, "http://www.qq.com")
    catch
      :exit, _ ->
        :ok
    end
  end

  test "fb paging normal" do
    alias Insightdb.HttpCommand.PagingStrategy, as: PagingStrategy
    url = "https://graph.facebook.com/v2.8/act_1638830686366258/campaigns?limit=4" <>
          "&access_token=EAAWwAGS9W2EBADWMwKBFLw5W1rWQ5lVQW4vaEQ6ejEcRp9C27nAbrXyjDXJUmz53fI3od4BhWQdn0emCE1YNBvkQzF" <>
          "vhAF0nF9WQAY0eQtSkWEs7f4KVZC0jVc80Fqix7DbLZCNONz2nBGkViyfZCCU3jW4dyTXZAKicXkdUUeAAiOzbZBaNpmWSZAvnFHVP8ZD"
    assert {:ok, response} = HttpCommand.run(:get, url, "", [], paging_strategy: &PagingStrategy.fb/1)
    assert is_list(response)
    assert length(response) > 1
  end

end
