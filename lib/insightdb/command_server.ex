defmodule Insightdb.CommandServer do
  @moduledoc """
  Command's life cycle:
    1. update command's data to Mongo doc with cmd_id (status: scheduled)
    2. run command (update status: running)
    3. after finish command, depends on the result, update status: finished or failed
    4. save result/error to new doc in Mongo with ref cmd id to cmd_id, after saving, update
       command's data in Mongo with status: done
  """

  use GenServer
  require Logger
  require Insightdb.Command.Constant
  alias Insightdb.Command.Constant, as: Constant
  alias Insightdb.Command, as: Command

  # API

  def reg(server, cmd_type, cmd_config) do
    with  conn_name <- format_conn_name(server),
          {:ok, %{inserted_id: cmd_id}} <- Mongo.insert_one(
           conn_name, Constant.coll_cmd_schedule, %{
             Constant.field_cmd_type => cmd_type,
             Constant.field_status => Constant.status_scheduled,
             Constant.field_cmd_config => cmd_config
           }),
         do: {:ok, cmd_id}
  end

  def cmd_status(server, cmd_id) do
    with conn_name <- format_conn_name(server),
         doc <- Command.find_cmd(conn_name, cmd_id),
         false <- is_nil(doc),
         true <- Map.has_key?(doc, Constant.field_status),
         do: {:ok, doc[Constant.field_status]}
  end

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
    with server_name = Map.get(state, :name),
         conn_name = format_conn_name(server_name),
         {:ok, _mongo_pid} <- mongo_start_link.([name: conn_name, database: "insightdb"]),
         new_state <- Map.put(state, :conn_name, conn_name),
         do: {:ok, new_state}
  end

  def handle_cast({:run, cmd_id}, state) do
    conn_name = Map.get(state, :conn_name)
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

  # Private

  defp format_conn_name(server_name) do
    to_string(server_name) <> "_mongo_conn" |> String.to_atom
  end

end
