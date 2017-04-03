defmodule Insightdb.CommandRunner do
  @moduledoc """
  Command's life cycle:
    1. update command's data to Mongo doc with cmd_id (status: scheduled)
    2. run command (update status: running)
    3. after finish command, depends on the result, update status: finished or failed
    4. save result/error to new doc in Mongo with ref cmd id to cmd_id, after saving, update
       command's data in Mongo with status: done
  """

  use GenServer
  use Insightdb.GenServer

  require Insightdb.Constant
  import Insightdb.Command.Utils

  alias Insightdb.Constant, as: Constant
  alias Insightdb.Command, as: Command
  alias Insightdb.CommandRunnerState, as: CommandRunnerState

  # API

  def reg(server, cmd_type, cmd_config, request_id) do
    GenServer.call(server, {:reg, cmd_type, cmd_config, request_id})
  end

  def run(server, cmd_id) do
    GenServer.cast(server, {:run, cmd_id})
  end

  # GenServer Callbacks

  def start_link([name: server_name]) do
    with {:ok, pid} <- GenServer.start_link(__MODULE__, %{:name => server_name}, []),
         true <- Process.register(pid, server_name),
         do: {:ok, pid}
  end

  def init(state) do
    require Insightdb.Mongo
    mongo_start_link = Insightdb.Mongo.gen_start_link
    with conn_name <- gen_mongo_conn_name(state),
         {:ok, _mongo_pid} <- mongo_start_link.([name: conn_name, database: Constant.db]),
         CommandRunnerState.add_new_runner(Map.get(state, :name)),
         do: {:ok, state}
  end

  def handle_call({:reg, cmd_type, cmd_config, ref_request_id}, _from, state) do
    reply state do
      with conn_name <- gen_mongo_conn_name(state),
           {:ok, response} <- Mongo.insert_one(
             conn_name, Constant.coll_cmd_schedule, %{
               Constant.field_ds => DateTime.to_unix(DateTime.utc_now()),
               Constant.field_cmd_type => cmd_type,
               Constant.field_status => Constant.status_scheduled,
               Constant.field_ref_request_id => ref_request_id,
               Constant.field_cmd_config => cmd_config}),
           do: {:reply, {:ok, response}, state}
    end
  end

  def handle_cast({:run, cmd_id}, state) do
    CommandRunnerState.update_runner_status(Map.get(state, :name), :busy)
    conn_name = gen_mongo_conn_name(state)
    try do
      %{Constant.field_cmd_type => cmd_type,
        Constant.field_status => Constant.status_scheduled,
        Constant.field_cmd_config => cmd_config} = Command.find_cmd(conn_name, cmd_id)
      Command.update_cmd_status(conn_name, cmd_id, Constant.status_running)
      result = Command.run_command(cmd_type, cmd_config)
      Command.update_cmd_status(conn_name, cmd_id, Constant.status_finished)
      Command.save_cmd_result(conn_name, cmd_id, result)
      Command.update_cmd_status(conn_name, cmd_id, Constant.status_done)
    rescue
      e ->
        Command.update_cmd_status_and_save_error(conn_name, cmd_id, Exception.message(e))
    catch
      :exit, reason ->
        Command.update_cmd_status_and_save_error(conn_name, cmd_id, Exception.format_exit(reason))
    end
    CommandRunnerState.update_runner_status(Map.get(state, :name), :free)
    {:noreply, state}
  end

end
