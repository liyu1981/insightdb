defmodule Insightdb.CommandScheduler do
  use GenServer

  require Insightdb.Constant
  import Insightdb.Command.Utils

  alias Insightdb.Constant, as: Constant
  alias Insightdb.Command, as: Command

  # Api

  def reg(server, cmd_type, cmd_config) do
    GenServer.call(server, {:reg, cmd_type, cmd_config})
  end

  def cmd_status(server, cmd_id) do
    GenServer.call(server, {:cmd_status, cmd_id})
  end

  def find(server, cmd_type, cmd_status, limit \\ 8) do
    GenServer.call(server, {:find_scheduled, cmd_type, cmd_status, limit})
  end

  def schedule_one(server, cmd_id) do
    GenServer.call(server, {:schedule, [cmd_id]})
  end

  def schedule_batch(server, cmd_id_list) do
    GenServer.call(server, {:schedule, cmd_id_list})
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
         new_state <- Map.put(state, :conn_name, conn_name),
         do: {:ok, new_state}
  end

  def handle_call({:reg, cmd_type, cmd_config}, _from, state) do
    with conn_name <- gen_mongo_conn_name(state),
         {:ok, %{inserted_id: cmd_id}} <- Mongo.insert_one(
           conn_name, Constant.coll_cmd_schedule, %{
             Constant.field_ds => DateTime.to_unix(DateTime.utc_now()),
             Constant.field_cmd_type => cmd_type,
             Constant.field_status => Constant.status_scheduled,
             Constant.field_cmd_config => cmd_config}),
         do: {:reply, {:ok, cmd_id}, state}
  end

  def handle_call({:cmd_status, cmd_id}, _from, state) do
    with conn_name <- gen_mongo_conn_name(state),
         doc <- Command.find_cmd(conn_name, cmd_id),
         true <- Map.has_key?(doc, Constant.field_status),
         do: {:reply, {:ok, doc[Constant.field_status]}, state}
  end

  def handle_call({:find_scheduled, cmd_type, cmd_status, limit}, _from, state) do
    opts = [sort: %{Constant.field_ds => 1}, batch_size: limit, limit: limit]
    with conn_name <- gen_mongo_conn_name(state),
         cursor <- Mongo.find(conn_name, Constant.coll_cmd_schedule, %{
             Constant.field_status => cmd_status,
             Constant.field_cmd_type => cmd_type,
           }, opts),
         list <- Enum.to_list(cursor),
         do: {:reply, {:ok, list}, state}
  end

  def handle_call({:schedule, cmd_id_list}, _from, state) do
    with conn_name <- gen_mongo_conn_name(state),
         updated_cmd_id_list <- schedule_cmd(conn_name, cmd_id_list),
         do: {:reply, {:ok, %{updated_ids: updated_cmd_id_list}}, state}
  end

  # Private

  defp schedule_cmd(conn_name, [cmd_id | tl]) do
    with {:ok, doc} <- Command.update_cmd_status(conn_name, cmd_id, Constant.status_scheduled),
         list <- schedule_cmd(conn_name, tl),
         do: [Map.get(doc, Constant.field__id)] ++ list
  end

  defp schedule_cmd(_conn_name, []) do
    []
  end

end
