defmodule Insightdb do
  @moduledoc false

  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    cmd_runners = for _ <- 1..4 do
      {name, id} = gen_command_runner_name()
      worker(Insightdb.CommandRunner, [[name: name]], [id: id])
    end

    {name, id} = gen_command_scheduler_name()
    cmd_scheduler = [worker(Insightdb.CommandScheduler, [[name: name]], [id: id])]

    children = cmd_runners ++ cmd_scheduler

    opts = [strategy: :one_for_one, name: Insightdb.Supervisor]
    Supervisor.start_link(children, opts)
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
