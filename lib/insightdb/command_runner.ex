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
  require Insightdb.Command.Constant
  import Insightdb.Command.Utils

  alias Insightdb.Command.Constant, as: Constant
  alias Insightdb.Command, as: Command

  # API

  def run(server, cmd_id) do
    GenServer.cast(server, {:run, cmd_id})
  end

  # GenServer Callbacks

  def start_link([name: server_name]) do
    with {:ok, pid} <- GenServer.start_link(__MODULE__, %{name: server_name}, []),
         true <- Process.register(pid, server_name),
         do: {:ok, pid}
  end

  def init(state) do
    require Insightdb.Mongo
    mongo_start_link = Insightdb.Mongo.gen_start_link
    with conn_name <- gen_mongo_conn_name(state),
         {:ok, _mongo_pid} <- mongo_start_link.([name: conn_name, database: "insightdb"]),
         do: {:ok, state}
  end

  def handle_cast({:run, cmd_id}, state) do
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
    {:noreply, state}
  end

end
