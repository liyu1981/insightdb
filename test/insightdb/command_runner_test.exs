defmodule Insightdb.CommandRunnerTest do
  use ExUnit.Case
  import Mock

  alias Insightdb.CommandRunner, as: CommandRunner

  @stash_mock_db_key "mockdb"
  @sample_result %{"result" => [1,2,3], "original_response": "hello, world"}
  @cmd_config_1 [verb: :get, url: "http://wwww.facebook.com", body: "", headers: [], options: []]

  @init_mock_db %{
    "cmd_schedule" => [],
    "cmd_schedule_error" => [],
    "cmd_schedule_result" => [],
  }

  defp setup_mock_db(cmd_id, cmd_type, cmd_config) do
    mock_db = Map.put(@init_mock_db, "cmd_schedule", [%{
      "_id" => cmd_id,
      "cmd_type" => cmd_type,
      "status" => "scheduled",
      "cmd_config" => cmd_config
    }])
    mock_db_key = @stash_mock_db_key <> SecureRandom.base64(8)
    Stash.set(:unitest, mock_db_key, mock_db)
    mock_db_key
  end

  defp find_cmd_schedule(mock_db_key) do
    mock_db = Stash.get(:unitest, mock_db_key)
    mock_db["cmd_schedule"] |> hd
  end

  defp change_cmd_schedule_status(mock_db_key, status) do
    mock_db = Stash.get(:unitest, mock_db_key)
    cmd_doc = mock_db["cmd_schedule"] |> hd
    new_doc = Map.put(cmd_doc, "status", status)
    Stash.set(:unitest, mock_db_key, Map.put(mock_db, "cmd_schedule", [new_doc]))
  end

  defp insert_doc(mock_db_key, coll, doc) do
    mock_db = Stash.get(:unitest, mock_db_key)
    Stash.set(:unitest, mock_db_key, Map.put(mock_db, coll, [doc]))
  end

  defp gen_mongo_mocks(mock_db_key) do
    {Mongo, [], [
      find: fn(_, _, _) -> find_cmd_schedule(mock_db_key) end,
      find_one_and_update: fn(_, _, _, %{"set" => %{"status" => status}}) ->
        change_cmd_schedule_status(mock_db_key, status)
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

  defp gen_httpcommand_mocks() do
    {Insightdb.HttpCommand, [], [
      run: fn(_, _, _, _, _) -> {:ok, @sample_result} end,
    ]}
  end

  setup do
    Logger.disable(self())
  end

  test "normal http_command" do
    cmd_id = "123"
    mock_db_key = setup_mock_db(cmd_id, "http_command", @cmd_config_1)
    with_mocks([gen_mongo_mocks(mock_db_key), gen_httpcommand_mocks()]) do
      assert CommandRunner.run(cmd_id)
      mock_db = Stash.get(:unitest, mock_db_key)
      assert %{"cmd_schedule" => [%{"status" => "done"}]} = mock_db
    end
  end

  test "not http_command" do
    cmd_id = "123"
    mock_db_key = setup_mock_db(cmd_id, "http_command1", @cmd_config_1)
    with_mocks([gen_mongo_mocks(mock_db_key), gen_httpcommand_mocks()]) do
      assert CommandRunner.run(cmd_id)
      mock_db = Stash.get(:unitest, mock_db_key)
      assert %{"cmd_schedule" => [%{"status" => "failed"}]} = mock_db
      assert %{"cmd_schedule_result" => []} = mock_db
      assert %{"cmd_schedule_error" => [%{"cmd_id" => "123", "error" => _error}]} = mock_db
      #IO.puts "cmd_id is #{cmd_id}, error is #{error}"
    end
  end

  test "http_command wrong config" do
    cmd_id = "123"
    mock_db_key = setup_mock_db(cmd_id, "http_command", Keyword.put(@cmd_config_1, :verb, :get1))
    with_mocks([gen_mongo_mocks(mock_db_key)]) do
      assert CommandRunner.run(cmd_id)
      mock_db = Stash.get(:unitest, mock_db_key)
      assert %{"cmd_schedule" => [%{"status" => "failed"}]} = mock_db
      assert %{"cmd_schedule_result" => []} = mock_db
      assert %{"cmd_schedule_error" => [%{"cmd_id" => "123", "error" => _error}]} = mock_db
      #IO.puts "cmd_id is #{cmd_id}, error is #{error}"
    end
  end

end
