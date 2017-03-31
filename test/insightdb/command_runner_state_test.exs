defmodule Insightdb.CommandRunnerStateTest do
  use ExUnit.Case
  import Mock

  alias Insightdb.CommandRunner, as: CommandRunner
  alias Insightdb.CommandRunnerState, as: CommandRunnerState
  alias Insightdb.CommandScheduler, as: CommandScheduler
  alias Insightdb.MongoMocks, as: MongoMocks
  alias Insightdb.Command.HttpCommandMocks, as: HttpCommandMocks

  @cmd_config_1 [verb: :get, url: "http://wwww.facebook.com", body: "", headers: [], options: []]
  @sserver :cmd_scheduler
  @rserver1 :cmd_runner1
  @rserver1_mongo_conn :cmd_runner1_mongo_conn

  setup_all do
    with {:ok, _pid} <- CommandRunnerState.start_link(),
         do: :ok
  end

  setup do
    import Supervisor.Spec, warn: false
    with {:ok, server1} <- CommandScheduler.start_link([name: @sserver]),
         {:ok, _server} <-
           Supervisor.start_link([worker(CommandRunner, [[name: @rserver1]])], [strategy: :one_for_one]),
         {:ok, _pid} <- HttpCommandMocks.start_link,
         do: {:ok, scheduler: server1}
  end

  test "come back runner", %{scheduler: scheduler} do
    mock_db_key = MongoMocks.init_mock_db(@rserver1_mongo_conn)
    mock_http_key = HttpCommandMocks.init_http_mock()
    http_mocks_gen_and_replace = fn(mock_http_key) ->
      {m, opts, fns} = HttpCommandMocks.gen(mock_http_key)
      new_fns = fns |>
        Keyword.put(:run, fn(_, _, _, _, _) ->
          Process.sleep(10)
          raise "oops!"
        end)
      {m, opts, new_fns}
    end
    with_mocks([
      MongoMocks.gen(@rserver1_mongo_conn, mock_db_key),
      http_mocks_gen_and_replace.(mock_http_key),
    ]) do
      assert {:ok, %{:inserted_id => 1}} = CommandScheduler.reg(scheduler, :http_command, @cmd_config_1)
      assert {:ok, "scheduled"} = CommandScheduler.cmd_status(scheduler, 1)
      assert :ok = CommandScheduler.run(scheduler, 1)
      # runner should be busy now, but runner will die because of http mock
      assert %{@rserver1 => %{:status => :busy}} = CommandRunnerState.get_runner_map()
      Process.sleep(100)
      # runner should be restarted and registered back
      assert %{@rserver1 => %{:status => :free}} = CommandRunnerState.get_runner_map()
    end
  end

end
