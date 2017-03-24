defmodule Insightdb.Command.HttpCommandMocks do
  use GenServer
  use Bangify

  @server_name :http_command_mock_server

  @sample_result %{"result" => [1,2,3], "original_response" => "hello, world"}

  def init_http_mock do
    GenServer.call(@server_name, {:init})
  end

  def set_lazy(mock_key, lazyness) when is_integer(lazyness) do
    GenServer.call(@server_name, {:set_lazy, mock_key, lazyness})
  end

  def gen(mock_key \\ "0") do
    {Insightdb.Command.HttpCommand, [], [
      run: fn(_, _, _, _, _) ->
        GenServer.call(@server_name, {:request, mock_key})
      end,
      run!: fn(_, _, _, _, _) ->
        bangify(GenServer.call(@server_name, {:request, mock_key}))
      end
    ]}
  end

  # GenServer

  def start_link do
    with {:ok, pid} <- GenServer.start_link(__MODULE__, :ok, []),
         true <- Process.register(pid, @server_name),
         do: {:ok, pid}
  end

  def init(:ok) do
    {:ok, %{lazy: %{"0" => 0}}}
  end

  def handle_call({:init}, _from, state) do
    mock_key = SecureRandom.base64(8)
    new_lazy_map = Map.get(state, :lazy, %{}) |> Map.put_new(mock_key, 0)
    {:reply, mock_key, Map.put(state, :lazy, new_lazy_map)}
  end


  def handle_call({:set_lazy, mock_key, lazyness}, _from, state) do
    new_lazy_map = Map.get(state, :lazy, %{}) |> Map.put(mock_key, lazyness)
    {:reply, :ok, Map.put(state, :lazy, new_lazy_map)}
  end

  def handle_call({:request, mock_key}, _from, state) do
    with %{lazy: lazy_map} <- state,
         lazy <- Map.get(lazy_map, mock_key, 0),
         _ <- Process.sleep(lazy),
         do: {:reply, {:ok, @sample_result}, state}
  end

end
