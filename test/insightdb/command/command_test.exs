defmodule Insightdb.CommandTest do
  use ExUnit.Case
  import ExUnit.CaptureLog
  import Mock

  alias Insightdb.Command, as: Command

  @stash_mock_db_key "mockdb"
  @sample_result %{"result" => [1,2,3], "original_response": "hello, world"}
  @cmd_config_1 [verb: :get, url: "http://wwww.facebook.com", body: "", headers: [], options: []]

  @init_mock_db %{
    "cmd_schedule" => [],
    "cmd_schedule_error" => [],
    "cmd_schedule_result" => [],
  }

  defp init_mock_db(mock_db) do
    mock_db_key = @stash_mock_db_key <> SecureRandom.base64(8)
    Stash.set(:unitest, mock_db_key, mock_db)
    mock_db_key
  end

  defp setup_mock_db(cmd_id, cmd_type, cmd_config) do
    mock_db = Map.put(@init_mock_db, "cmd_schedule", [%{
      "_id" => cmd_id,
      "cmd_type" => cmd_type,
      "status" => "scheduled",
      "cmd_config" => cmd_config
    }])
    init_mock_db(mock_db)
  end

  defp find_cmd_schedule(mock_db_key, cmd_id) do
    mock_db = Stash.get(:unitest, mock_db_key)
    Enum.find(mock_db["cmd_schedule"], fn(x) -> x["_id"] == cmd_id end)
  end

  defp change_cmd_schedule_status(mock_db_key, cmd_id, status) do
    mock_db = Stash.get(:unitest, mock_db_key)
    index = Enum.find_index(mock_db["cmd_schedule"], fn(x) -> x["_id"] == cmd_id end)
    cmd_doc = Enum.find(mock_db["cmd_schedule"], fn(x) -> x["_id"] == cmd_id end)
    new_doc = Map.put(cmd_doc, "status", status)
    Stash.set(:unitest, mock_db_key, Map.put(mock_db, "cmd_schedule",
      List.replace_at(mock_db["cmd_schedule"], index, new_doc)))
  end

  defp insert_doc(mock_db_key, coll, doc) do
    mock_db = Stash.get(:unitest, mock_db_key)
    coll_list = Map.get(mock_db, coll)
    Stash.set(:unitest, mock_db_key, Map.put(mock_db, coll,
      coll_list ++ [doc]))
  end

  defp gen_mongo_mocks(mock_db_key) do
    {Mongo, [], [
      find_one: fn(_, _, %{"_id" => cmd_id}) ->
        find_cmd_schedule(mock_db_key, cmd_id)
      end,
      find_one_and_update: fn(_, _, %{"_id" => cmd_id}, %{"set" => %{"status" => status}}) ->
        change_cmd_schedule_status(mock_db_key, cmd_id, status)
      end,
      insert_one!: fn(_, coll, doc) ->
        case coll do
          "cmd_schedule_error" ->
            insert_doc(mock_db_key, "cmd_schedule_error", doc)
          "cmd_schedule_result" ->
            insert_doc(mock_db_key, "cmd_schedule_result", doc)
        end
      end,
    ]}
  end

  defp gen_and_replace({m, opts, fns}, key, new_fn) do
    new_fns = if Keyword.has_key?(fns, key) do
      Keyword.put(fns, key, new_fn)
    else
      Keyword.put_new(fns, key, new_fn)
    end
    {m, opts, new_fns}
  end

  defp gen_httpcommand_mocks() do
    {Insightdb.Command.HttpCommand, [], [
      run: fn(_, _, _, _, _) -> {:ok, @sample_result} end,
    ]}
  end

  setup do
    Logger.disable(self())
  end

  test "normal reg command" do
    mock_db_key = init_mock_db(@init_mock_db)
    gen_mongo_mocks_and_replace = fn(mock_db_key) ->
      gen_and_replace(gen_mongo_mocks(mock_db_key),
        :insert_one, fn(_, coll, doc) ->
          new_doc = Map.put(doc, "_id", 456)
          insert_doc(mock_db_key, coll, new_doc)
          {:ok, 456}
        end)
    end
    with_mocks([gen_mongo_mocks_and_replace.(mock_db_key)]) do
      assert {:ok, 456} = Command.reg(:http_command, @cmd_config_1)
      assert %{"_id" => 456, "status" => "planned"} = find_cmd_schedule(mock_db_key, 456)
    end
  end

  test "normal status command" do
    cmd_id = 123
    mock_db_key = setup_mock_db(cmd_id, "http_command", @cmd_config_1)
    with_mocks([gen_mongo_mocks(mock_db_key)]) do
      assert {:ok, "scheduled"} = Command.status(cmd_id)
    end
  end

  test "normal http_command" do
    cmd_id = 123
    mock_db_key = setup_mock_db(cmd_id, "http_command", @cmd_config_1)
    with_mocks([gen_mongo_mocks(mock_db_key), gen_httpcommand_mocks()]) do
      assert Command.run(cmd_id)
      mock_db = Stash.get(:unitest, mock_db_key)
      assert %{"cmd_schedule" => [%{"status" => "done"}]} = mock_db
    end
  end

  test "not http_command" do
    cmd_id = 123
    mock_db_key = setup_mock_db(cmd_id, "http_command1", @cmd_config_1)
    with_mocks([gen_mongo_mocks(mock_db_key), gen_httpcommand_mocks()]) do
      assert Command.run(cmd_id)
      mock_db = Stash.get(:unitest, mock_db_key)
      assert %{"cmd_schedule" => [%{"status" => "failed"}]} = mock_db
      assert %{"cmd_schedule_result" => []} = mock_db
      assert %{"cmd_schedule_error" => [%{"cmd_id" => 123, "error" => _error}]} = mock_db
      #IO.puts "cmd_id is #{cmd_id}, error is #{error}"
    end
  end

  test "http_command wrong config" do
    cmd_id = 123
    mock_db_key = setup_mock_db(cmd_id, "http_command", Keyword.put(@cmd_config_1, :verb, :get1))
    with_mocks([gen_mongo_mocks(mock_db_key)]) do
      assert Command.run(cmd_id)
      mock_db = Stash.get(:unitest, mock_db_key)
      assert %{"cmd_schedule" => [%{"status" => "failed"}]} = mock_db
      assert %{"cmd_schedule_result" => []} = mock_db
      assert %{"cmd_schedule_error" => [%{"cmd_id" => 123, "error" => _error}]} = mock_db
      #IO.puts "cmd_id is #{cmd_id}, error is #{error}"
    end
  end

  test "http_command mongo exception in find" do
    gen_mongo_mocks_and_replace = fn(mock_db_key) ->
      {m, opts, fns} = gen_mongo_mocks(mock_db_key)
      new_fns = Keyword.put(fns, :find_one, fn(_, _, _) -> nil end)
      {m, opts, new_fns}
    end

    cmd_id = 123
    mock_db_key = setup_mock_db(cmd_id, "http_command", Keyword.put(@cmd_config_1, :verb, :get1))
    with_mocks([gen_mongo_mocks_and_replace.(mock_db_key), gen_httpcommand_mocks()]) do
      assert Command.run(cmd_id)
      mock_db = Stash.get(:unitest, mock_db_key)
      assert %{"cmd_schedule" => [%{"status" => "failed"}]} = mock_db
      assert %{"cmd_schedule_result" => []} = mock_db
      assert %{"cmd_schedule_error" => [%{"cmd_id" => 123, "error" => _error}]} = mock_db
      #IO.puts "cmd_id is #{cmd_id}, error is #{error}"
    end
  end

  test "http_command mongo exception in insert_one!" do
    gen_mongo_mocks_and_replace = fn(mock_db_key) ->
      gen_and_replace(gen_mongo_mocks(mock_db_key),
        :insert_one!, fn(_, coll, doc) ->
          case coll do
            "cmd_schedule_error" -> insert_doc(mock_db_key, "cmd_schedule_error", doc)
            "cmd_schedule_result" -> raise "oops!"
          end
        end
      )
    end

    cmd_id = 123
    mock_db_key = setup_mock_db(cmd_id, "http_command", Keyword.put(@cmd_config_1, :verb, :get1))
    with_mocks([gen_mongo_mocks_and_replace.(mock_db_key), gen_httpcommand_mocks()]) do
      assert Command.run(cmd_id)
      mock_db = Stash.get(:unitest, mock_db_key)
      assert %{"cmd_schedule" => [%{"status" => "failed"}]} = mock_db
      assert %{"cmd_schedule_result" => []} = mock_db
      assert %{"cmd_schedule_error" => [%{"cmd_id" => 123, "error" => _error}]} = mock_db
      #IO.puts "cmd_id is #{cmd_id}, error is #{error}"
    end
  end

  test "http_command mongo exception in saving error" do
    gen_mongo_mocks_and_replace = fn(mock_db_key) ->
      gen_and_replace(gen_mongo_mocks(mock_db_key),
        :find_one_and_update, fn(_, _, _, _) -> raise "oops!" end)
    end

    cmd_id = 123
    mock_db_key = setup_mock_db(cmd_id, "http_command", Keyword.put(@cmd_config_1, :verb, :get1))
    fun = fn ->
      with_mocks([gen_mongo_mocks_and_replace.(mock_db_key), gen_httpcommand_mocks()]) do
        assert Command.run(cmd_id)
        mock_db = Stash.get(:unitest, mock_db_key)
        assert %{"cmd_schedule" => [%{"status" => "scheduled"}]} = mock_db
        #assert called Logger.error
        #IO.puts "cmd_id is #{cmd_id}, error is #{error}"
      end
    end
    capture_log(fun) =~ "save error failed for cmd_id"
  end

end
