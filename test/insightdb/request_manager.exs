defmodule Insightdb.RequestManagerTest do
  use ExUnit.Case
  import Mock

  alias Insightdb.RequestManager, as: RequestManager
  alias Insightdb.MongoMocks, as: MongoMocks

  @sample_request_config_1 %{
    "type" => "http",
    "schedule" => "repeat",
    "repeat" => "* * * * *",
    "payload" => %{},
  }
  @sample_request_config_2 %{
    "type" => "http",
    "schedule" => "once",
    "payload" => %{},
  }
  @s :request_manager
  @s_mongo :request_manager_mongo_conn

  setup do
    with {:ok, server} <- RequestManager.start_link([name: @s]),
         do: {:ok, reqmgr: server}
  end

  test "normal flow", %{reqmgr: reqmgr} do
    mock_db_key = MongoMocks.init_mock_db(@s_mongo)
    with_mocks([MongoMocks.gen(@s_mongo, mock_db_key)]) do
      assert {:ok, rid1} = RequestManager.new(reqmgr, @sample_request_config_1)
      assert {:ok, rid2} = RequestManager.new(reqmgr, @sample_request_config_2)
      assert {:ok, reaped_rids} = RequestManager.reap(reqmgr)
    end
  end

end
