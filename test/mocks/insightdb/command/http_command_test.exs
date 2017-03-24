defmodule Insightdb.Command.HttpCommandMocksTest do
  use ExUnit.Case
  import Mock

  alias Insightdb.Command.HttpCommand, as: HttpCommand
  alias Insightdb.Command.HttpCommandMocks, as: HttpCommandMocks

  setup do
    with {:ok, _pid} <- HttpCommandMocks.start_link(),
         do: :ok
  end

  test "normal flow" do
    with_mocks([HttpCommandMocks.gen()]) do
      assert {:ok, _} = HttpCommand.run(:get, "http://www.facebook.com", "", [], [])
    end
  end

end
