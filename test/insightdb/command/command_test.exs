defmodule Insightdb.CommandTest do
  use ExUnit.Case
  import ExUnit.CaptureLog
  import Mock

  require Insightdb.Command.Constant

  alias Insightdb.Command, as: Command
  alias Insightdb.Command.Constant, as: Constant
  alias Insightdb.Command.MongoMocks, as: MongoMocks
  alias Insightdb.Command.HttpCommandMocks, as: HttpCommandMocks

  @cmd_config_1 [verb: :get, url: "http://wwww.facebook.com", body: "", headers: [], options: []]
  @server :mongo_mock

  setup do
    with {:ok, _pid} <- MongoMocks.start_link([name: @server, database: "dummy"]),
         {:ok, _pid} <- HttpCommandMocks.start_link(),
         do: :ok
  end

  test "normal http_command flow" do
    cmd_id = 123
    mock_db_key = MongoMocks.setup_mock_db(@server, cmd_id, :http_command, @cmd_config_1)
    with_mocks([MongoMocks.gen(@server, mock_db_key), HttpCommandMocks.gen()]) do
      %{Constant.field_cmd_type => cmd_type,
        Constant.field_status => Constant.status_scheduled,
        Constant.field_cmd_config => cmd_config} = Command.find_cmd(@server, cmd_id)
      Command.update_cmd_status(@server, cmd_id, Constant.status_running)
      result = Command.run_command(cmd_type, cmd_config)
      Command.update_cmd_status(@server, cmd_id, Constant.status_finished)
      Command.save_cmd_result(@server, cmd_id, result)
      Command.update_cmd_status(@server, cmd_id, Constant.status_done)

      %{Constant.field_status => "done"} = Command.find_cmd(@server, cmd_id)
      assert %{"cmd_schedule_error" => [], "cmd_schedule_result" => result} = MongoMocks.get_db(@server, mock_db_key)
      assert [%{"cmd_id" => 123,
                "result" => %{"original_response" => "hello, world", "result" => [1, 2, 3]},
                "ds" => _ds}] = result
    end
  end

  @tag capture_log: true
  test "http_command exceptions" do
    # wrong command type
    assert_raise FunctionClauseError, fn ->
      Command.run_command(:http_command1, @cmd_config_1)
    end
    # wrong http command verb
    assert_raise RuntimeError, ~r/^Do not know how to handle http verb:.+$/, fn ->
      Command.run_command(:http_command, Keyword.put(@cmd_config_1, :verb, :get1))
    end
  end

  test "mongo exceptions" do
    gen_mongo_mocks_and_replace = fn(server, mock_db_key) ->
      {m, opts, fns} = MongoMocks.gen(server, mock_db_key)
      new_fns = fns |>
        Keyword.put(:find_one, fn(_, _, _) -> nil end) |>
        Keyword.put(:insert_one!, fn(_, _coll, _doc) -> raise "oops!" end) |>
        Keyword.put(:find_one_and_update, fn(_, _, _, _) -> raise "oops!" end)
      {m, opts, new_fns}
    end
    mock_db_key = MongoMocks.setup_mock_db(@server, 123, :http_command, Keyword.put(@cmd_config_1, :verb, :get1))
    with_mocks([gen_mongo_mocks_and_replace.(@server, mock_db_key), HttpCommandMocks.gen()]) do
      assert_raise RuntimeError, ~r/^can not find cmd with id .+$/, fn ->
        Command.find_cmd(@server, 123)
      end
      assert_raise RuntimeError, "oops!", fn ->
        Command.save_cmd_result(@server, 123, %{})
      end
      fun = fn ->
        Command.update_cmd_status_and_save_error(@server, 123, "errormsg")
      end
      assert capture_log(fun) =~ "save error failed for cmd_id 123, error: errormsg, stacktrace:"
    end
  end

end
