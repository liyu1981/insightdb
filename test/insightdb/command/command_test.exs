defmodule Insightdb.CommandTest do
  use ExUnit.Case
  import ExUnit.CaptureLog
  import Mock
  import Insightdb.Mock

  alias Insightdb.Command, as: Command
  alias Insightdb.Command.MongoMocks, as: MongoMocks
  alias Insightdb.Command.HttpCommandMocks, as: HttpCommandMocks

  @cmd_config_1 [verb: :get, url: "http://wwww.facebook.com", body: "", headers: [], options: []]

  setup do
    Logger.disable(self())
    with {:ok, _pid} <- MongoMocks.start_link(),
         {:ok, _pid} <- HttpCommandMocks.start_link(),
         do: :ok
  end

  test "reg & status" do
    cmd_id = 123
    mock_db_key = MongoMocks.setup_mock_db(cmd_id, :http_command, @cmd_config_1)
    with_mocks([MongoMocks.gen(mock_db_key)]) do
      assert {:ok, 2} = Command.reg(:http_command, @cmd_config_1)
      assert %{"_id" => 2, "status" => "scheduled"} = Mongo.find_one(:dummy_conn, "cmd_schedule", %{"_id" => 2})
      assert {:ok, "scheduled"} = Command.status(cmd_id)
    end
  end

  test "normal http_command" do
    cmd_id = 123
    mock_db_key = MongoMocks.setup_mock_db(cmd_id, :http_command, @cmd_config_1)
    with_mocks([MongoMocks.gen(mock_db_key), HttpCommandMocks.gen()]) do
      assert Command.run(cmd_id)
      assert %{"cmd_schedule" => [%{"status" => "done"}]} = MongoMocks.get_db(mock_db_key)
    end
  end

  test "not http_command" do
    cmd_id = 123
    mock_db_key = MongoMocks.setup_mock_db(cmd_id, :http_command1, @cmd_config_1)
    with_mocks([MongoMocks.gen(mock_db_key), HttpCommandMocks.gen()]) do
      assert Command.run(cmd_id)
      mock_db = MongoMocks.get_db(mock_db_key)
      assert %{"cmd_schedule" => [%{"status" => "failed"}]} = mock_db
      assert %{"cmd_schedule_result" => []} = mock_db
      assert %{"cmd_schedule_error" => [%{"cmd_id" => 123, "error" => _error}]} = mock_db
    end
  end

  test "http_command wrong config" do
    cmd_id = 123
    mock_db_key = MongoMocks.setup_mock_db(cmd_id, :http_command, Keyword.put(@cmd_config_1, :verb, :get1))
    with_mocks([MongoMocks.gen(mock_db_key)]) do
      assert Command.run(cmd_id)
      mock_db = MongoMocks.get_db(mock_db_key)
      assert %{"cmd_schedule" => [%{"status" => "failed"}]} = mock_db
      assert %{"cmd_schedule_result" => []} = mock_db
      assert %{"cmd_schedule_error" => [%{"cmd_id" => 123, "error" => _error}]} = mock_db
    end
  end

  test "http_command mongo exception in find" do
    gen_mongo_mocks_and_replace = fn(mock_db_key) ->
      {m, opts, fns} = MongoMocks.gen(mock_db_key)
      new_fns = Keyword.put(fns, :find_one, fn(_, _, _) -> nil end)
      {m, opts, new_fns}
    end

    cmd_id = 123
    mock_db_key = MongoMocks.setup_mock_db(cmd_id, :http_command, Keyword.put(@cmd_config_1, :verb, :get1))
    with_mocks([gen_mongo_mocks_and_replace.(mock_db_key), HttpCommandMocks.gen()]) do
      assert Command.run(cmd_id)
      mock_db = MongoMocks.get_db(mock_db_key)
      assert %{"cmd_schedule" => [%{"status" => "failed"}]} = mock_db
      assert %{"cmd_schedule_result" => []} = mock_db
      assert %{"cmd_schedule_error" => [%{"cmd_id" => 123, "error" => _error}]} = mock_db
    end
  end

  test "http_command mongo exception in insert_one!" do
    gen_mongo_mocks_and_replace = fn(mock_db_key) ->
      gen_and_replace(MongoMocks.gen(mock_db_key),
        :insert_one!, fn(_, coll, doc) ->
          case coll do
            "cmd_schedule_error" -> MongoMocks.insert_doc(mock_db_key, "cmd_schedule_error", doc)
            "cmd_schedule_result" -> raise "oops!"
          end
        end
      )
    end

    cmd_id = 123
    mock_db_key = MongoMocks.setup_mock_db(cmd_id, :http_command, Keyword.put(@cmd_config_1, :verb, :get1))
    with_mocks([gen_mongo_mocks_and_replace.(mock_db_key), HttpCommandMocks.gen()]) do
      assert Command.run(cmd_id)
      mock_db = MongoMocks.get_db(mock_db_key)
      assert %{"cmd_schedule" => [%{"status" => "failed"}]} = mock_db
      assert %{"cmd_schedule_result" => []} = mock_db
      assert %{"cmd_schedule_error" => [%{"cmd_id" => 123, "error" => _error}]} = mock_db
    end
  end

  test "http_command mongo exception in saving error" do
    gen_mongo_mocks_and_replace = fn(mock_db_key) ->
      gen_and_replace(MongoMocks.gen(mock_db_key),
        :find_one_and_update, fn(_, _, _, _) -> raise "oops!" end)
    end

    cmd_id = 123
    mock_db_key = MongoMocks.setup_mock_db(cmd_id, :http_command, Keyword.put(@cmd_config_1, :verb, :get1))
    fun = fn ->
      with_mocks([gen_mongo_mocks_and_replace.(mock_db_key), HttpCommandMocks.gen()]) do
        assert Command.run(cmd_id)
        mock_db = MongoMocks.get_db(mock_db_key)
        assert %{"cmd_schedule" => [%{"status" => "scheduled"}]} = mock_db
      end
    end
    capture_log(fun) =~ "save error failed for cmd_id"
  end

end
