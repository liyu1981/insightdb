defmodule Insightdb.RequestTest do
  use ExUnit.Case
  use Insightdb.Test
  import Mock
  #import Insightdb.Constant

  #alias Insightdb.Constant, as: Constant
  alias Insightdb.CommandRunnerState, as: CommandRunnerState
  alias Insightdb.CommandScheduler, as: CommandScheduler
  alias Insightdb.MongoMocks, as: MongoMocks
  alias Insightdb.Request, as: Request

  @mongo_server :mongo_mock_server
  @rserver :cmd_runner

  @correct_request_config %{
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
  #@wrong_request_config ""

  setup_all do
    with {:ok, pid1} <- CommandRunnerState.start_link,
         {:ok, pid2} <- CommandScheduler.start_link,
         _ <- kill_all_on_exit([pid1, pid2]),
         do: :ok
  end

  setup do
    with {:ok, _pid} <- Insightdb.CommandRunner.start_link([name: @rserver]),
         {:ok, _pid} <- MongoMocks.start_link([name: @mongo_server, database: "dummy"]),
         do: :ok
  end

  test "normal flow" do
    mock_db_key = MongoMocks.init_mock_db(@mongo_server)
    with_mocks([MongoMocks.gen(@mongo_server, mock_db_key)]) do
      assert {:ok, config} = Request.validate(@correct_request_config)
      assert {:ok, %{:inserted_id => 1}} = Request.save(@mongo_server, config)
      doc = Request.find(@mongo_server, 1)
      assert doc != nil 
      assert {:ok, [1], [{"* * * * *", fun, 1}]} = Request.reap(doc)
      assert fun == &Insightdb.CommandScheduler.run/1
      assert {:ok, "scheduled"} = CommandScheduler.cmd_status(1)
    end
  end

  # test "validate error" do
  #   assert {:error, error} = Request.validate(@wrong_request_config)
  #   IO.puts "#{inspect error}"
  # end
  #
  # test "mongo errors" do
  #   mock_db_key = MongoMocks.init_mock_db(@mongo_server)
  #   with_mocks([MongoMocks.gen(@mongo_server, mock_db_key)]) do
  #     assert {:ok, type, config} = Request.validate(@correct_request_config)
  #     assert {:ok, rid} = Request.save(@mongo_server, type, config)
  #   end
  #
  #   gen_mongo_mocks_and_replace = fn(server, mock_db_key) ->
  #     {m, opts, fns} = MongoMocks.gen(server, mock_db_key)
  #     new_fns = fns |>
  #       Keyword.put(:find_one, fn(_, _, _) -> nil end) |>
  #       Keyword.put(:insert_one!, fn(_, _coll, _doc) -> raise "oops!" end) |>
  #       Keyword.put(:find_one_and_update, fn(_, _, _, _) -> raise "oops!" end)
  #     {m, opts, new_fns}
  #   end
  #   with_mocks([gen_mongo_mocks_and_replace.(@mongo_server, mock_db_key)]) do
  #     assert {:ok, type, config} = Request.validate(@correct_request_config)
  #     assert {:error, error} = Request.save(@mongo_server, type, config)
  #     assert {:error, error} = Request.reap(@mongo_server, rid)
  #   end
  # end

end
