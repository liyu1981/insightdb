defmodule Insightdb.CommandServer do
  use GenServer
  alias Insightdb.Command, as: Command

  def start_link do
    GenServer.start_link(__MODULE__, :ok, [])
  end

  # API

  def status(server) do
    GenServer.call(server, :status)
  end

  def run(server, cmd_id) do
    GenServer.cast(server, {:run, cmd_id})
  end

  # GenServer Callbacks

  def init(:ok) do
    {:ok, %{:status => :free}}
  end

  def handle_call(:status, _from, server_state) do
    {:reply, Map.fetch(server_state, :status), server_state}
  end

  def handle_call({:set_status, new_status}, _from, server_state) do
    {:reply, :ok, Map.put(server_state, :status, new_status)}
  end

  def handle_cast({:run, cmd_id}, server_state) do
    GenServer.call(__MODULE__, {:set_status, :running})
    Command.run(cmd_id)
    {:noreply, Map.put(server_state, :status, :free) }
  end

end
