defmodule Insightdb.RequestManager do
  use GenServer

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
    with conn_name <- gen_mongo_conn_name(state),
         {:ok, request_type, request_config2} <- Request.validate(request_config),
         {:ok, id} <- Request.save(conn_name, request_type, request_config2),
         do: {:reply, {:ok, id}, state}
  end

  def handle_call({:reap}, _from, state) do
    opts = [projection: %{Constant.field__id => 1}]
    with conn_name <- gen_mongo_conn_name(state),
         request_list <- Enum.to_list(Mongo.find(conn_name, Constant.coll_request, %{}, opts)),
         {:ok, reaped_ids, archived_ids, cron_job_list} <- reap_request_list(conn_name, request_list),
         :ok <- install_new_crontab(cron_job_list),
         do: {:reply, {:ok, %{reaped_ids: reaped_ids, archived_ids: archived_ids}}}
  end

  # private

  defp reap_request_list([request_id | tl], conn_name) do
    # with {:ok, reaped_ids1, archived_ids1, cron_job_list1} <- Request.reap(request_id, conn_name),
    #      {:ok, reaped_ids2, archived_ids2, cron_job_list2} <- reap_request_list(tl, conn_name),
    #      do: {:ok,
    #           request_id1 ++ reaped_ids2,
    #           archived_ids1 ++ archived_ids2,
    #           cron_job_list1 ++ cron_job_list2}
  end

  defp reap_request_list([], _conn_name) do
    {:ok, [], [], []}
  end

  defp install_new_crontab(cron_job_list) do
    :ok
  end

end
