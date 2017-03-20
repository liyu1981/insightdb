defmodule Insightdb.CommandServerTest do
  use ExUnit.Case

  alias Insightdb.CommandServer, as: CommandServer

  setup do
    {:ok, server} = CommandServer.start_link()
    {:ok, cr_server: server}
  end

  test "get status", %{cr_server: cr_server} do
    assert {:ok, :free} = CommandServer.status(cr_server)
  end

end
