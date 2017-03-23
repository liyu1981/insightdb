defmodule Insightdb.CommandServer do
  require Logger
  use GenServer
  alias Insightdb.Command, as: Command

  def start_link do
    GenServer.start_link(__MODULE__, :ok, [])
  end

  # API

  def status(server) do
    GenServer.call(server, :status)
  end

  def reg(cmd_type, cmd_config) do
    Command.reg(cmd_type, cmd_config)
  end

  def cmd_status(cmd_id) do
    Command.status(cmd_id)
  end

  def run(server, cmd_id) do
    GenServer.cast(server, {:run, cmd_id})
  end

  # GenServer Callbacks

  def init(:ok) do
    {:ok, %{:status => :free}}
  end

  def handle_cast({:run, cmd_id}, state) do
    Command.run(cmd_id)
    {:noreply, state}
  end

end
