require DBConnection
require Mongo

defmodule Insightdb.Supervisor do
  use Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, :ok)
  end

  def init(:ok) do
    children = [
      # TODO: use Poolboy?
      worker(Mongo, [[name: :insightdb_mongo_conn, database: "insightdb"]]), #, pool: DBConnection.Poolboy]])
    ]

    supervise(children, strategy: :one_for_one)
  end

end
