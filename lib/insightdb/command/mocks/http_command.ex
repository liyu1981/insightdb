defmodule Insightdb.Command.HttpCommandMocks do
  use GenServer

  @server_name :http_command_mock_server

  @sample_result %{"result" => [1,2,3], "original_response": "hello, world"}

  def set_lazy(lazyness) when is_integer(lazyness) do
    GenServer.call(@server_name, {:set_lazy, lazyness})
  end

  def gen() do
    {Insightdb.Command.HttpCommand, [], [
      run: fn(_, _, _, _, _) ->
        GenServer.call(@server_name, {:request})
      end,
    ]}
  end

  # GenServer

  def start_link do
    with {:ok, pid} <- GenServer.start_link(__MODULE__, :ok, []),
         true <- Process.register(pid, @server_name),
         do: {:ok, pid}
  end

  def init(:ok) do
    {:ok, %{lazy: 0}}
  end

  def handle_call({:set_lazy, lazyness}, _from, state) do
    {:reply, :ok, Map.put(state, :lazy, lazyness)}
  end

  def handle_call({:request}, _from, state) do
    with %{lazy: lazy} <- state,
         _ <- Process.sleep(lazy),
         do: {:reply, {:ok, @sample_result}, state}
  end

end
