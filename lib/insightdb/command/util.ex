defmodule Insightdb.Command.Utils do

  def format_mongo_conn_name(server_name) do
    to_string(server_name) <> "_mongo_conn" |> String.to_atom
  end

  def gen_mongo_conn_name(server_state) do
    with server_name <- Map.get(server_state, :name),
         do: format_mongo_conn_name(server_name)
  end

end
