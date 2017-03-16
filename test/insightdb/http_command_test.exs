defmodule Insightdb.HttpCommandTest do
  use ExUnit.Case
  import Mock

  alias Insightdb.HttpCommand, as: HttpCommand
  alias Insightdb.HttpCommand.PagingStrategy, as: PagingStrategy
  alias Insightdb.HttpCommand.MergeStrategy, as: MergeStrategy

  @mock_response_200 %HTTPoison.Response{body: "this is test", status_code: 200, headers: []}
  @mock_response_302 %HTTPoison.Response{body: "", status_code: 302, headers: [{"Location", "http://301.to.somewhere"}]}
  @mock_response_json_200 %HTTPoison.Response{
    body: "{\"ip\": \"192.168.100.1\"}", status_code: 200, headers: [{"Content-Type", "application/json"}]
  }
  @mock_response_fb_paging_1 %HTTPoison.Response{
    body: ~s({"data":[{"id":"1"},{"id":"2"}],"paging":{"next":"https://graph.facebook.com/v2.8/act_1638830686366258/campaigns?access_token=EAAB&after=1"}}),
    status_code: 200, headers: [{"Content-Type", "application/json"}]
  }
  @mock_response_fb_paging_2 %HTTPoison.Response{
    body: ~s({"data":[{"id":"3"},{"id":"4"}],"paging":{"next":"https://graph.facebook.com/v2.8/act_1638830686366258/campaigns?access_token=EAAB&after=2"}}),
    status_code: 200, headers: [{"Content-Type", "application/json"}]
  }
  @mock_response_fb_paging_3 %HTTPoison.Response{
    body: ~s({"data":[],"paging":{}}),
    status_code: 200, headers: [{"Content-Type", "application/json"}]
  }

  setup do
    use Insightdb.HttpCommand
  end

  test "html 200" do
    with_mock HTTPoison, [get: fn(_, _, _) -> {:ok, @mock_response_200} end ] do
      assert {:ok, %{"result" => result, "original_response" => original_response}} =
        HttpCommand.run(:get, "http://www.qq.com")
      assert is_binary(result)
      assert original_response
    end
  end

  test "html 302" do
    with_mock HTTPoison, [
      get: fn(url, _, _) ->
        case url do
          "http://301.to" <> _ -> {:ok, @mock_response_200}
          _ -> {:ok, @mock_response_302}
        end
      end
    ] do
      assert {:ok, %{"result" => result, "original_response" => original_response}} =
        HttpCommand.run(:get, "https://www.google.com")
      assert is_binary(result)
      assert original_response
    end
  end

  test "json 200" do
    with_mock HTTPoison, [get: fn(_, _, _) -> {:ok, @mock_response_json_200} end ] do
      assert {:ok, %{"result" => result, "original_response" => original_response}} =
        HttpCommand.run(:get, "http://ip.jsontest.com")
      assert is_map(result)
      assert original_response
      assert byte_size(result["ip"]) > 0
    end
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
    with_mock HTTPoison, [
      get: fn(url, _, _) ->
        case String.reverse(url) do
          "2=retfa" <> _ -> {:ok, @mock_response_fb_paging_3}
          "1=retfa" <> _ -> {:ok, @mock_response_fb_paging_2}
          _ -> {:ok, @mock_response_fb_paging_1}
        end
      end
    ] do
      url = "https://graph.facebook.com/v2.8/act_1638830686366258/campaigns?access_token=EAAW"
      assert {:ok, %{"result" => result, "original_response" => original_response}} =
        HttpCommand.run(:get, url, "", [], [paging_strategy: &PagingStrategy.fb/1, merge_strategy: &MergeStrategy.fb/2])
      assert is_list(result)
      assert original_response
      assert length(result) > 1
    end
  end

  test "fb paing empty" do
    with_mock HTTPoison, [ get: fn(url, _, _) -> {:ok, @mock_response_fb_paging_3} end ] do
      url = "https://graph.facebook.com/v2.8/act_1638830686366258/campaigns?access_token=EAAW"
      assert {:ok, %{"result" => result, "original_response" => original_response}} =
        HttpCommand.run(:get, url, "", [], [paging_strategy: &PagingStrategy.fb/1, merge_strategy: &MergeStrategy.fb/2])
      assert is_list(result)
      assert original_response
      assert length(result) == 0
    end
  end

end
