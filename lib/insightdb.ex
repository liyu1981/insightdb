defmodule Insightdb do
  @moduledoc false

  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false
    children = [
      worker(Insightdb.CommandServer, [[name: gen_command_server_name()]]),
    ]
    opts = [strategy: :one_for_one, name: Insightdb.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp gen_command_server_name() do
    "insightdb_command_server_" <> SecureRandom.base64(8) |> String.to_atom
  end

end
