defmodule Insightdb.CommandScheduler do
  use GenServer
  use Insightdb.GenServer

  require Insightdb.Constant
  import Insightdb.Command.Utils

  alias Insightdb.Constant, as: Constant
  alias Insightdb.Command, as: Command
  alias Insightdb.CommandRunner, as: CommandRunner

  # Api

  def get() do
    __MODULE__
  end

  def reg(cmd_type, cmd_config, ref_request_id \\ 0) do
    GenServer.call(__MODULE__, {:reg, cmd_type, cmd_config, ref_request_id})
  end

  def run(cmd_id) do
    GenServer.call(__MODULE__, {:run, cmd_id})
  end

  def cmd_status(cmd_id) do
    GenServer.call(__MODULE__, {:cmd_status, cmd_id})
  end

  def find(cmd_type, cmd_status, limit \\ 8) do
    GenServer.call(__MODULE__, {:find, cmd_type, cmd_status, limit})
  end

  # GenServer Callbacks

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

  def handle_call({:reg, cmd_type, cmd_config, ref_request_id}, _from, state) do
    reply state do
      with {:ok, free_runner} <- Insightdb.find_free_command_runner(),
           {:ok, response} <- CommandRunner.reg(free_runner, cmd_type, cmd_config, ref_request_id),
           do: {:reply, {:ok, response}, state}
    end
  end

  def handle_call({:run, cmd_id}, _from, state) do
    reply state do
      with {:ok, free_runner} <- Insightdb.find_free_command_runner(),
           :ok <- CommandRunner.run(free_runner, cmd_id),
           do: {:reply, :ok, state}
    end
  end

  def handle_call({:cmd_status, cmd_id}, _from, state) do
    reply state do
      with conn_name <- gen_mongo_conn_name(state),
           doc <- Command.find_cmd(conn_name, cmd_id),
           true <- Map.has_key?(doc, Constant.field_status),
           do: {:reply, {:ok, doc[Constant.field_status]}, state}
    end
  end

  def handle_call({:find, cmd_type, cmd_status, limit}, _from, state) do
    opts = [sort: %{Constant.field_ds => 1}, batch_size: limit, limit: limit]
    reply state do
      with conn_name <- gen_mongo_conn_name(state),
           cursor <- Mongo.find(conn_name, Constant.coll_cmd_schedule, %{
               Constant.field_status => cmd_status,
               Constant.field_cmd_type => cmd_type,
             }, opts),
           list <- Enum.to_list(cursor),
           do: {:reply, {:ok, list}, state}
    end
  end

  # Private

end
