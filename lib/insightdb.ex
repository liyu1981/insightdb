defmodule Insightdb do
  @moduledoc false

  use Application

  # Apis

  def list_worker(fun \\ fn(x) -> to_string(x) =~ "insightdb" end) do
    Process.registered |> Enum.filter(fun)
  end

  def find_free_command_runner() do
    Insightdb.CommandRunnerState.find_free_runner
  end

  def get_command_scheduler() do
    Insightdb.CommandScheduler.get
  end

  def install_cronjob(cronjob_config_list) do
    with :ok <- Insightdb.System.save_cron(cronjob_config_list),
         do: Insightdb.Quantum.install_cronjob(cronjob_config_list)
  end

  # Application callbacks

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    system = [worker(Insightdb.System, [])]

    cmd_runner_state = [worker(Insightdb.CommandRunnerState, [])]

    cmd_runner_nameids = for _ <- 1..4, do: gen_command_runner_name()
    cmd_runners = Enum.map(cmd_runner_nameids, fn({name, id}) ->
      worker(Insightdb.CommandRunner, [[name: name]], [id: id])
    end)

    cmd_scheduler = [worker(Insightdb.CommandScheduler, [])]

    children = system ++ cmd_runner_state ++ cmd_runners ++ cmd_scheduler

    opts = [strategy: :one_for_one, name: Insightdb.Supervisor]

    if Mix.env == :test do
      Supervisor.start_link([], opts)
    else
      Supervisor.start_link(children, opts)
    end
  end

  # Private

  defp gen_command_runner_name() do
    id = SecureRandom.base64(8)
    name = String.to_atom("insightdb_command_runner_" <> id)
    {name, id}
  end

end
