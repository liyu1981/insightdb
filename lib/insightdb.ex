defmodule Insightdb do
  @moduledoc false

  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false
    children = for _ <- 1..4 do
      {name, id} = gen_command_server_name()
      worker(Insightdb.CommandServer, [[name: name]], [id: id])
    end
    opts = [strategy: :one_for_one, name: Insightdb.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp gen_command_server_name() do
    id = SecureRandom.base64(8)
    name = String.to_atom("insightdb_command_server_" <> id)
    {name, id}
  end

end
