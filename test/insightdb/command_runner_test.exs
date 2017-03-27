defmodule Insightdb.CommandRunnerTest do
  use ExUnit.Case
  import Mock

  alias Insightdb.CommandRunner, as: CommandRunner
  alias Insightdb.CommandScheduler, as: CommandScheduler
  alias Insightdb.Command.MongoMocks, as: MongoMocks
  alias Insightdb.Command.HttpCommandMocks, as: HttpCommandMocks

  @cmd_config_1 [verb: :get, url: "http://wwww.facebook.com", body: "", headers: [], options: []]
  @sserver :cmd_scheduler
  @rserver :cmd_runner
  @rserver_mongo_conn :cmd_runner_mongo_conn

  setup do
    with {:ok, server1} <- CommandScheduler.start_link([name: @sserver]),
         {:ok, server2} <- CommandRunner.start_link([name: @rserver]),
         {:ok, _pid} <- HttpCommandMocks.start_link,
         do: {:ok, scheduler: server1, runner: server2}
  end

  test "normal http_command flow", %{scheduler: scheduler, runner: runner} do
    mock_db_key = MongoMocks.init_mock_db(@rserver_mongo_conn)
    mock_http_key = HttpCommandMocks.init_http_mock()
    HttpCommandMocks.set_lazy(mock_http_key, 1000)
    with_mocks([MongoMocks.gen(@rserver_mongo_conn, mock_db_key), HttpCommandMocks.gen(mock_http_key)]) do
      assert {:ok, cmd_id} = CommandScheduler.reg(scheduler, :http_command, @cmd_config_1)
      assert {:ok, "scheduled"} = CommandScheduler.cmd_status(scheduler, cmd_id)
      assert :ok = CommandRunner.run(runner, cmd_id)
      # right after run cmd, server and cmd status should be `running`
      Process.sleep(10)
      assert {:ok, "running"} = CommandScheduler.cmd_status(scheduler, cmd_id)
      Process.sleep(1000)
      assert {:ok, "done"} = CommandScheduler.cmd_status(scheduler, cmd_id)
    end
  end

  @tag capture_log: true
  test "http_command exception", %{scheduler: scheduler, runner: runner} do
    mock_db_key = MongoMocks.init_mock_db(@rserver_mongo_conn)
    with_mocks([MongoMocks.gen(@rserver_mongo_conn, mock_db_key)]) do
      assert {:ok, 1} = CommandScheduler.reg(scheduler, :http_command1, @cmd_config_1)
      assert :ok = CommandRunner.run(runner, 1)
      Process.sleep(10)
      mock_db = MongoMocks.get_db(@rserver_mongo_conn, mock_db_key)
      assert %{"cmd_schedule" => [%{"status" => "failed"}]} = mock_db
      assert %{"cmd_schedule_result" => []} = mock_db
      assert %{"cmd_schedule_error" => [%{"cmd_id" => 1, "error" => error}]} = mock_db
      assert error =~ "no function clause matching in"

      assert {:ok, 2} = CommandScheduler.reg(scheduler, :http_command, Keyword.put(@cmd_config_1, :verb, :get1))
      assert :ok = CommandRunner.run(runner, 2)
      Process.sleep(10)
      mock_db = MongoMocks.get_db(@rserver_mongo_conn, mock_db_key)
      assert %{"cmd_schedule" => [_, %{"_id" => 2, "status" => "failed"}]} = mock_db
      assert %{"cmd_schedule_result" => []} = mock_db
      assert %{"cmd_schedule_error" => [_, %{"cmd_id" => 2, "error" => error, "ds" => _ds}]} = mock_db
      assert error =~ "Do not know how to handle http verb: get1"
    end
  end

  test "http_command mongo exceptions", %{scheduler: scheduler, runner: runner} do
    gen_mongo_mocks_and_replace = fn(server, mock_db_key) ->
      {m, opts, fns} = MongoMocks.gen(server, mock_db_key)
      new_fns = Keyword.put(fns, :find_one, fn(_, _, _) -> nil end)
      {m, opts, new_fns}
    end
    mock_db_key = MongoMocks.init_mock_db(@rserver_mongo_conn)
    with_mocks([gen_mongo_mocks_and_replace.(@rserver_mongo_conn, mock_db_key), HttpCommandMocks.gen()]) do
      assert {:ok, 1} = CommandScheduler.reg(scheduler, :http_command, @cmd_config_1)
      assert :ok = CommandRunner.run(runner, 1)
      Process.sleep(10)
      mock_db = MongoMocks.get_db(@rserver_mongo_conn, mock_db_key)
      assert %{"cmd_schedule" => [%{"_id" => 1, "status" => "failed"}]} = mock_db
      assert %{"cmd_schedule_result" => []} = mock_db
      assert %{"cmd_schedule_error" => [%{"cmd_id" => 1, "error" => error, "ds" => _ds}]} = mock_db
      assert error =~ "can not find cmd with id 1"
    end
  end

end
