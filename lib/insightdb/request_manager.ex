defmodule Insightdb.RequestManager do
  use GenServer
  use Insightdb.GenServer

  require Insightdb.Constant
  import Insightdb.Command.Utils

  alias Insightdb.Constant, as: Constant
  alias Insightdb.Request, as: Request

  # Api

  def new(server, request_config) do
    GenServer.call(server, {:new, request_config})
  end

  def reap(server) do
    GenServer.call(server, {:reap})
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
         {:ok, _pid} <- mongo_start_link.([name: conn_name, database: Constant.db]),
         do: {:ok, state}
  end

  def handle_call({:new, request_config}, _from, state) do
    reply state do
      with conn_name <- gen_mongo_conn_name(state),
           {:ok, formal_request_config} <- Request.validate(request_config),
           {:ok, id} <- Request.save(conn_name, formal_request_config),
           do: {:reply, {:ok, id}, state}
    end
  end

  def handle_call({:reap}, _from, state) do
    opts = [projection: %{Constant.field__id => 1}]
    reply state do
      with conn_name <- gen_mongo_conn_name(state),
           request_list <- Enum.to_list(Mongo.find(conn_name, Constant.coll_request, %{}, opts)),
           {:ok, reaped_ids, archived_ids, cronjob_config_list} <- reap_request_list(conn_name, request_list),
           :ok <- Insightdb.install_cronjob(cronjob_config_list),
           do: {:reply, {:ok, %{reaped_ids: reaped_ids, archived_ids: archived_ids}}, state}
    end
  end

  # private

  defp reap_request_list(conn_name, [request_id | tl]) do
    with doc <- Request.find(conn_name, request_id),
         {:ok, archived_list} <- Request.try_archive(doc),
         {:ok, reaped_list, cronjob_config_list} <- Request.reap(doc),
         {:ok, reaped_ids, archived_ids, cronjob_configs} <- reap_request_list(conn_name, tl),
         do: {:ok,
              reaped_list ++ reaped_ids,
              archived_list ++ archived_ids,
              cronjob_config_list ++ cronjob_configs}
  end

  defp reap_request_list(_conn_name, []) do
    {:ok, [], [], []}
  end

end
