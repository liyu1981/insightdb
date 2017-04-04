defmodule Insightdb.System do
  use GenServer
  use Insightdb.GenServer

  import Insightdb.Command.Utils

  require Insightdb.Constant
  alias Insightdb.Constant, as: Constant

  # Api

  def save_cron(cron_config) do
    GenServer.call(__MODULE__, {:save_cron, cron_config})
  end

  # GenServer callbacks

  def start_link do
    with {:ok, pid} <- GenServer.start_link(__MODULE__, %{:name => __MODULE__}, []),
         true <- Process.register(pid, __MODULE__),
         do: {:ok, pid}
  end

  def init(state) do
    require Insightdb.Mongo
    mongo_start_link = Insightdb.Mongo.gen_start_link
    with conn_name <- gen_mongo_conn_name(state),
         {:ok, _mongo_pid} <- mongo_start_link.([name: conn_name, database: Constant.db]),
         do: {:ok, state}
  end

  def handle_call({:save_cron, cron_config}, _from, state) do
    reply state do
      with conn_name <- gen_mongo_conn_name(state),
           {:ok, _new_doc} <- Mongo.find_one_and_update(conn_name, Constant.coll_system,
             %{}, %{"set" => %{"cron" => cron_config}}),
           do: {:reply, :ok, state}
    end
  end

end
