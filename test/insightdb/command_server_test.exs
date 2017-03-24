defmodule Insightdb.CommandServerTest do
  use ExUnit.Case
  import Mock

  alias Insightdb.CommandServer, as: CommandServer
  alias Insightdb.Command.MongoMocks, as: MongoMocks
  alias Insightdb.Command.HttpCommandMocks, as: HttpCommandMocks

  @cmd_config_1 [verb: :get, url: "http://wwww.facebook.com", body: "", headers: [], options: []]

  setup do
    with {:ok, server} <- CommandServer.start_link,
         {:ok, _pid} <- MongoMocks.start_link,
         {:ok, _pid} <- HttpCommandMocks.start_link,
         do: {:ok, cmd_server: server}
  end

  test "normal http_command flow", %{cmd_server: cmd_server} do
    mock_db_key = MongoMocks.init_mock_db()
    mock_http_key = HttpCommandMocks.init_http_mock()
    HttpCommandMocks.set_lazy(mock_http_key, 1000)
    with_mocks([MongoMocks.gen(mock_db_key), HttpCommandMocks.gen(mock_http_key)]) do
      assert {:ok, cmd_id} = CommandServer.reg(:http_command, @cmd_config_1)
      assert {:ok, "scheduled"} = CommandServer.cmd_status(cmd_id)
      assert :ok = CommandServer.run(cmd_server, cmd_id)
      # right after run cmd, server and cmd status should be `running`
      Process.sleep(10)
      assert {:ok, "running"} = CommandServer.cmd_status(cmd_id)
      Process.sleep(1000)
      assert {:ok, "done"} = CommandServer.cmd_status(cmd_id)
    end
  end

  @tag capture_log: true
  test "http_command exception", %{cmd_server: cmd_server} do
    mock_db_key = MongoMocks.init_mock_db()
    with_mocks([MongoMocks.gen(mock_db_key)]) do
      assert {:ok, 1} = CommandServer.reg(:http_command1, @cmd_config_1)
      assert :ok = CommandServer.run(cmd_server, 1)
      Process.sleep(10)
      mock_db = MongoMocks.get_db(mock_db_key)
      assert %{"cmd_schedule" => [%{"status" => "failed"}]} = mock_db
      assert %{"cmd_schedule_result" => []} = mock_db
      assert %{"cmd_schedule_error" => [%{"cmd_id" => 1, "error" => error}]} = mock_db
      assert error =~ "no function clause matching in"

      assert {:ok, 2} = CommandServer.reg(:http_command, Keyword.put(@cmd_config_1, :verb, :get1))
      assert :ok = CommandServer.run(cmd_server, 2)
      Process.sleep(10)
      mock_db = MongoMocks.get_db(mock_db_key)
      assert %{"cmd_schedule" => [_, %{"_id" => 2, "status" => "failed"}]} = mock_db
      assert %{"cmd_schedule_result" => []} = mock_db
      assert %{"cmd_schedule_error" => [_, %{"cmd_id" => 2, "error" => error}]} = mock_db
      assert error =~ "Do not know how to handle http verb: get1"
    end
  end

  test "http_command mongo exceptions", %{cmd_server: cmd_server} do
    gen_mongo_mocks_and_replace = fn(mock_db_key) ->
      {m, opts, fns} = MongoMocks.gen(mock_db_key)
      new_fns = Keyword.put(fns, :find_one, fn(_, _, _) -> nil end)
      {m, opts, new_fns}
    end
    mock_db_key = MongoMocks.init_mock_db()
    with_mocks([gen_mongo_mocks_and_replace.(mock_db_key), HttpCommandMocks.gen()]) do
      assert {:ok, 1} = CommandServer.reg(:http_command, @cmd_config_1)
      assert :ok = CommandServer.run(cmd_server, 1)
      Process.sleep(10)
      mock_db = MongoMocks.get_db(mock_db_key)
      assert %{"cmd_schedule" => [%{"_id" => 1, "status" => "failed"}]} = mock_db
      assert %{"cmd_schedule_result" => []} = mock_db
      assert %{"cmd_schedule_error" => [%{"cmd_id" => 1, "error" => error}]} = mock_db
      assert error =~ "can not find cmd with id 1"
    end
  end

end
