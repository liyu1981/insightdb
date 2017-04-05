defmodule Insightdb.CommandRunnerStateTest do
  use ExUnit.Case
  use Insightdb.Test
  import Mock

  alias Insightdb.CommandRunner, as: CommandRunner
  alias Insightdb.CommandRunnerState, as: CommandRunnerState
  alias Insightdb.CommandScheduler, as: CommandScheduler
  alias Insightdb.MongoMocks, as: MongoMocks
  alias Insightdb.HttpCommandMocks, as: HttpCommandMocks

  @cmd_config_1 [verb: :get, url: "http://wwww.facebook.com", body: "", headers: [], options: []]
  @rserver1 :cmd_runner1
  @rserver1_mongo_conn :cmd_runner1_mongo_conn

  setup_all do
    with {:ok, pid1} <- CommandRunnerState.start_link,
         {:ok, pid2} <- CommandScheduler.start_link,
         {:ok, pid3} <- HttpCommandMocks.start_link,
         _ <- kill_all_on_exit([pid1, pid2, pid3]),
         do: :ok
  end

  setup do
    import Supervisor.Spec, warn: false
    with {:ok, _server} <-
           Supervisor.start_link([worker(CommandRunner, [[name: @rserver1]])], [strategy: :one_for_one]),
         do: :ok
  end

  test "come back runner" do
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
      assert {:ok, %{:inserted_id => 1}} = CommandScheduler.reg(:http_command, @cmd_config_1)
      assert {:ok, "scheduled"} = CommandScheduler.cmd_status(1)
      assert :ok = CommandScheduler.run(1)
      # runner should be busy now, but runner will die because of http mock
      assert %{@rserver1 => %{:status => :busy}} = CommandRunnerState.get_runner_map()
      Process.sleep(400)
      # runner should be restarted and registered back
      assert %{@rserver1 => %{:status => :free}} = CommandRunnerState.get_runner_map()
    end
  end

end
