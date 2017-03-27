defmodule Insightdb.CommandSchedulerTest do
  use ExUnit.Case
  import Mock

  alias Insightdb.CommandScheduler, as: CommandScheduler
  alias Insightdb.Command.MongoMocks, as: MongoMocks
  alias Insightdb.Command, as: Command

  @cmd_config_1 [verb: :get, url: "http://wwww.facebook.com", body: "", headers: [], options: []]
  @s :cmd_scheduler
  @s_mongo :cmd_scheduler_mongo_conn

  setup do
    with {:ok, server} <- CommandScheduler.start_link([name: @s]),
         do: {:ok, scheduler: server}
  end

  test "normal reg & cmd_status", %{scheduler: scheduler} do
    mock_db_key = MongoMocks.init_mock_db(@s_mongo)
    with_mocks([MongoMocks.gen(@s_mongo, mock_db_key)]) do
      assert {:ok, 1} = CommandScheduler.reg(scheduler, :http_command, @cmd_config_1)
      assert {:ok, "scheduled"} = CommandScheduler.cmd_status(scheduler, 1)
    end
  end

  test "normal find & schedule", %{scheduler: scheduler} do
    mock_db_key = MongoMocks.init_mock_db(@s_mongo)
    with_mocks([MongoMocks.gen(@s_mongo, mock_db_key)]) do
      assert {:ok, 1} = CommandScheduler.reg(scheduler, :http_command, @cmd_config_1)
      assert {:ok, 2} = CommandScheduler.reg(scheduler, :http_command, @cmd_config_1)
      assert {:ok, 3} = CommandScheduler.reg(scheduler, :http_command, @cmd_config_1)
      assert {:ok, list} = CommandScheduler.find(scheduler, :http_command, "scheduled", 10)
      assert [%{"_id" => 1}, %{"_id" => 2}, %{"_id" => 3}] = list

      Command.update_cmd_status(@s_mongo, 2, "failed")
      Command.update_cmd_status(@s_mongo, 3, "done")
      assert {:ok, list2} = CommandScheduler.find(scheduler, :http_command, "scheduled", 10)
      assert [%{"_id" => 1}] = list2
      assert {:ok, [%{"_id" => 2}]} = CommandScheduler.find(scheduler, :http_command, "failed", 10)
      assert {:ok, [%{"_id" => 3}]} = CommandScheduler.find(scheduler, :http_command, "done", 10)
      assert {:ok, %{updated_ids: [2, 3]}} = CommandScheduler.schedule_batch(scheduler, [2, 3])
      assert {:ok, list3} = CommandScheduler.find(scheduler, :http_command, "scheduled", 10)
      assert [%{"_id" => 1}, %{"_id" => 2}, %{"_id" => 3}] = list3
    end
  end

end
