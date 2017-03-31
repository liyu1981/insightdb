defmodule Insightdb.MongoMocksTest do
  use ExUnit.Case
  import Mock

  alias Insightdb.MongoMocks, as: MongoMocks

  @cmd_config_1 [verb: :get, url: "http://wwww.facebook.com", body: "", headers: [], options: []]
  @server :test123

  setup do
    with {:ok, _pid} <- MongoMocks.start_link([name: @server, database: "test123"]),
         do: :ok
  end

  test "interfaces" do
    mock_db_key = MongoMocks.init_mock_db(@server)
    assert %{"cmd_schedule" => [], "cmd_schedule_error" => [], "cmd_schedule_result" => []} =
      MongoMocks.get_db(@server, mock_db_key)
    assert {:ok, %{inserted_id: 1}} = MongoMocks.insert_doc(@server, mock_db_key, "cmd_schedule",
      %{"cmd_type" => :http_command, "status" => "scheduled", "cmd_config" => @cmd_config_1})
    assert [doc] = MongoMocks.find_doc(@server, mock_db_key, "cmd_schedule", fn(x) -> x["_id"] == 1 end)
    assert %{"_id" => 1} = doc
    new_doc = Map.put(doc, "status", "finished")
    assert {:ok, %{matched_count: 1, modified_count: 1}} =
      MongoMocks.update_doc(@server, mock_db_key, "cmd_schedule", new_doc)
    assert [doc2] = MongoMocks.find_doc(@server, mock_db_key, "cmd_schedule", fn(x) -> x["_id"] == 1 end)
    assert %{"status" => "finished"} = doc2
  end

  test "gen" do
    mock_db_key = MongoMocks.setup_mock_db(@server, 123, :http_command, @cmd_config_1)
    with_mocks([MongoMocks.gen(@server, mock_db_key)]) do
      doc = Mongo.find_one(mock_db_key, "cmd_schedule", %{"_id" => 123})
      assert %{"_id" => 123} = doc
      assert {:ok, doc2} =
        Mongo.find_one_and_update(mock_db_key, "cmd_schedule", %{"_id" => 123}, %{"set" => %{"status" => "done"}})
      assert %{"status" => "done"} = doc2
      assert {:ok, %{inserted_id: 2}} =
        Mongo.insert_one(mock_db_key, "cmd_schedule", %{"status" => "scheduled"})
      doc3 = Mongo.find_one(mock_db_key, "cmd_schedule", %{"_id" => 2})
      assert %{"_id" => 2, "status" => "scheduled"} = doc3
    end
  end

end
