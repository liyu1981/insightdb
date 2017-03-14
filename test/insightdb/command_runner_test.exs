defmodule Insightdb.CommandRunnerTest do
  use ExUnit.Case
  alias Insightdb.CommandRunner, as: CommandRunner
  alias Insightdb.HttpCommand.PagingStrategy, as: PagingStrategy
  alias Insightdb.HttpCommand.MergeStrategy, as: MergeStrategy

  test "paging requests" do
    url = "https://graph.facebook.com/v2.8/act_1638830686366258/campaigns?limit=4" <>
          "&access_token=EAAWwAGS9W2EBADWMwKBFLw5W1rWQ5lVQW4vaEQ6ejEcRp9C27nAbrXyjDXJUmz53fI3od4BhWQdn0emCE1YNBvkQzF" <>
          "vhAF0nF9WQAY0eQtSkWEs7f4KVZC0jVc80Fqix7DbLZCNONz2nBGkViyfZCCU3jW4dyTXZAKicXkdUUeAAiOzbZBaNpmWSZAvnFHVP8ZD"
    assert {:ok, response} = CommandRunner.run(
      :http_command, :get, url, "", [],
      [paging_strategy: &PagingStrategy.fb/1, merge_strategy: &MergeStrategy.fb/2]
    )
    assert is_map(response)
  end

  test "normal request" do
    url = "https://www.google.com"
    assert {:ok, response} = CommandRunner.run :http_command, :get, url
    assert is_map(response)
  end

end
