defmodule Insightdb.CommandServer do
  @moduledoc """
  Command's life cycle:
    1. update command's data to Mongo doc with cmd_id (status: scheduled)
    2. run command (update status: running)
    3. after finish command, depends on the result, update status: finished or failed
    4. save result/error to new doc in Mongo with ref cmd id to cmd_id, after saving, update
       command's data in Mongo with status: done
  """

  require Logger
  require Insightdb.Command.Constant
  use GenServer
  alias Insightdb.Command.Constant, as: Constant
  alias Insightdb.Command, as: Command

  # API

  def reg(cmd_type, cmd_config) do
    with {:ok, %{inserted_id: cmd_id}} <- Mongo.insert_one(
           Constant.conn_name, Constant.coll_cmd_schedule, %{
             Constant.field_cmd_type => cmd_type,
             Constant.field_status => Constant.status_scheduled,
             Constant.field_cmd_config => cmd_config
           }),
         do: {:ok, cmd_id}
  end

  def cmd_status(cmd_id) do
    with doc <- Command.find_cmd(cmd_id),
         false <- is_nil(doc),
         true <- Map.has_key?(doc, Constant.field_status),
         do: {:ok, doc[Constant.field_status]}
  end

  def run(server, cmd_id) do
    GenServer.cast(server, {:run, cmd_id})
  end

  # GenServer Callbacks

  def start_link do
    GenServer.start_link(__MODULE__, :ok, [])
  end

  def handle_cast({:run, cmd_id}, state) do
    try do
      %{Constant.field_cmd_type => cmd_type,
        Constant.field_status => Constant.status_scheduled,
        Constant.field_cmd_config => cmd_config} = Command.find_cmd(cmd_id)
      Command.update_cmd_status(cmd_id, Constant.status_running)
      result = Command.run_command(cmd_type, cmd_config)
      Command.update_cmd_status(cmd_id, Constant.status_finished)
      Command.save_cmd_result(cmd_id, result)
      Command.update_cmd_status(cmd_id, Constant.status_done)
    rescue
      e ->
        Command.update_cmd_status_and_save_error(cmd_id, Exception.message(e))
    catch
      :exit, reason ->
        Command.update_cmd_status_and_save_error(cmd_id, Exception.format_exit(reason))
    end
    {:noreply, state}
  end

end
