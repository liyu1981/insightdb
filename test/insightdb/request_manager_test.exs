defmodule Insightdb.RequestManagerTest do
  use ExUnit.Case
  import Mock

  alias Insightdb.CommandRunner, as: CommandRunner
  alias Insightdb.CommandRunnerState, as: CommandRunnerState
  alias Insightdb.CommandScheduler, as: CommandScheduler
  alias Insightdb.RequestManager, as: RequestManager
  alias Insightdb.MongoMocks, as: MongoMocks
  alias Insightdb.HttpCommandMocks, as: HttpCommandMocks

  @sample_request_config_1 %{
    "type" => "repeat",
    "repeat" => "* * * * *",
    "payload" => %{
      "cmd_type" => :http_command,
      "cmd_config" => %{
        :verb => :get,
        :url => "http://wwww.facebook.com"
      }
    },
  }
  @sample_request_config_2 %{
    "type" => "once",
    "payload" => %{
      "cmd_type" => :http_command,
      "cmd_config" => %{
        :verb => :get,
        :url => "http://wwww.facebook.com"
      }
    },
  }
  @cr1 :cmd_runner1
  @cr2 :cmd_runner2
  @s :request_manager
  @s_mongo :request_manager_mongo_conn

  setup_all do
    with {:ok, pid} <- CommandRunnerState.start_link,
         _ <- on_exit(fn-> Process.exit(pid, :kill) end),
         do: :ok
  end

  setup do
    with {:ok, _pid} <- CommandRunner.start_link([name: @cr1]),
         {:ok, _pid} <- CommandRunner.start_link([name: @cr2]),
         {:ok, _pid} <- CommandScheduler.start_link,
         {:ok, server} <- RequestManager.start_link([name: @s]),
         {:ok, _pid} <- HttpCommandMocks.start_link,
         do: {:ok, reqmgr: server}
  end

  test "normal flow", %{reqmgr: reqmgr} do
    mock_db_key = MongoMocks.init_mock_db(@s_mongo)
    http_mock_key = HttpCommandMocks.init_http_mock()
    with_mocks([MongoMocks.gen(@s_mongo, mock_db_key), HttpCommandMocks.gen(http_mock_key)]) do
      assert {:ok, %{inserted_id: 1}} = RequestManager.new(reqmgr, @sample_request_config_1)
      assert {:ok, %{inserted_id: 2}} = RequestManager.new(reqmgr, @sample_request_config_2)
      assert {:ok, %{reaped_ids: [1, 2], archived_ids: [2]}} = RequestManager.reap(reqmgr)
    end
  end

end
