defmodule Insightdb do
  @moduledoc false

  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    cmd_runner_state = [worker(Insightdb.CommandRunnerState, [])]

    cmd_runner_nameids = for _ <- 1..4, do: gen_command_runner_name()
    cmd_runners = Enum.map(cmd_runner_nameids, fn({name, id}) ->
      worker(Insightdb.CommandRunner, [[name: name]], [id: id])
    end)

    {name, id} = gen_command_scheduler_name()
    cmd_runner_names = Enum.map(cmd_runner_nameids, fn({name, _id}) -> name end)
    cmd_scheduler = [worker(Insightdb.CommandScheduler, [[name: name, runner_names: cmd_runner_names]], [id: id])]

    children = cmd_runner_state ++ cmd_runners ++ cmd_scheduler

    opts = [strategy: :one_for_one, name: Insightdb.Supervisor]

    if Mix.env == :test do
      Supervisor.start_link([], opts)
    else
      Supervisor.start_link(children, opts)
    end
  end

  def list_worker(fun \\ fn(x) -> to_string(x) =~ "insightdb" end) do
    Process.registered |> Enum.filter(fun)
  end

  defp gen_command_runner_name() do
    id = SecureRandom.base64(8)
    name = String.to_atom("insightdb_command_runner_" <> id)
    {name, id}
  end

  defp gen_command_scheduler_name() do
    name = String.to_atom("insightdb_command_scheduler")
    {name, name}
  end

end
