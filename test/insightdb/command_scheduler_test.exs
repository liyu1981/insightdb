defmodule Insightdb.CommandSchedulerTest do
  use ExUnit.Case
  import Mock

  alias Insightdb.CommandRunner, as: CommandRunner
  alias Insightdb.CommandRunnerState, as: CommandRunnerState
  alias Insightdb.CommandScheduler, as: CommandScheduler
  alias Insightdb.MongoMocks, as: MongoMocks

  @cmd_config_1 [verb: :get, url: "http://wwww.facebook.com", body: "", headers: [], options: []]
  @r :cmd_runner
  @s :cmd_scheduler
  @s_mongo :cmd_scheduler_mongo_conn

  setup_all do
    with {:ok, _pid} <- CommandRunnerState.start_link,
         do: :ok
  end

  setup do
    with {:ok, _server1} <- CommandRunner.start_link([name: @r]),
         {:ok, server2} <- CommandScheduler.start_link([name: @s]),
         {:ok, _pid} <- HttpCommandMocks.start_link,
         do: {:ok, scheduler: server2}
  end

  test "normal reg & cmd_status", %{scheduler: scheduler} do
    mock_db_key = MongoMocks.init_mock_db(@s_mongo)
    with_mocks([MongoMocks.gen(@s_mongo, mock_db_key)]) do
      assert {:ok, %{:inserted_id => 1}} = CommandScheduler.reg(scheduler, :http_command, @cmd_config_1)
      assert {:ok, "scheduled"} = CommandScheduler.cmd_status(scheduler, 1)
    end
  end

end
