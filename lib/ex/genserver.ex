defmodule Insightdb.GenServer do

  defmacro __using__(_opts) do
     quote do
       import Insightdb.GenServer
     end
  end

  defmacro reply(the_state, do: expression) do
    quote do
      insightdb_genserver_reply_with(unquote(expression), unquote(the_state))
    end
  end

  def insightdb_genserver_reply_with({:reply, response, new_state}, _the_state) do
    {:reply, response, new_state}
  end

  def insightdb_genserver_reply_with({:error, error}, the_state) do
    {:reply, {:error, error}, the_state}
  end

  def insightdb_genserver_reply_with(value, the_state) do
    {:reply, {:error, value}, the_state}
  end

end
