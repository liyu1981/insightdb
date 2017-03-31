defmodule Insightdb.CommandRunnerState do
  use GenServer

  def start_link do
    Agent.start(fn -> Map.new end, name: __MODULE__)
  end

  def add_new_runner(name) do
    Agent.update(__MODULE__, fn(map) -> Map.put(map, name, %{:status => :free}) end)
  end

  def update_runner_status(name, status) do
    Agent.update(__MODULE__, fn(map) ->
        if Map.has_key?(map, name) do
          runner_state = Map.get(map, name)
          new_runner_state = Map.put(runner_state, :status, status)
          Map.put(map, name, new_runner_state)
        else
          add_new_runner(name)
          update_runner_status(name, status)
        end
      end)
  end

  def get_runner_map() do
    Agent.get(__MODULE__, fn(map) -> map end)
  end

  def find_free_runner() do
    Agent.get(__MODULE__, fn(map) ->
        case Enum.find(map, fn({_name, state}) -> Map.get(state, :status) == :free end) do
          {name, _state} -> {:ok, name}
          _ -> {:error, "Can not find free runner"}
        end
      end)
  end

end
