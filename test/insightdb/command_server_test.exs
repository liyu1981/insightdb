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

  test "normal flow", %{cmd_server: cmd_server} do
    mock_db_key = MongoMocks.init_mock_db()
    HttpCommandMocks.set_lazy(1000)
    with_mocks([MongoMocks.gen(mock_db_key), HttpCommandMocks.gen()]) do
      assert {:ok, cmd_id} = CommandServer.reg(:http_command, @cmd_config_1)
      assert {:ok, "scheduled"} = CommandServer.cmd_status(cmd_id)
      assert :ok = CommandServer.run(cmd_server, cmd_id)
      # right after run cmd, server and cmd status should be `running`
      Process.sleep(100)
      assert {:ok, "running"} = CommandServer.cmd_status(cmd_id)
      Process.sleep(1000)
      assert {:ok, "done"} = CommandServer.cmd_status(cmd_id)
    end
  end

end
