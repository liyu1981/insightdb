defmodule Insightdb.RequestTest do
  use ExUnit.Case
  import Mock
  import Insightdb.Constant

  alias Insightdb.Constant, as: Constant
  alias Insightdb.MongoMocks, as: MongoMocks
  alias Insightdb.Request, as: Request

  @mongo_server :mongo_mock_server

  setup do
    with {:ok, _pid} <- MongoMocks.start_link([name: @mongo_server, database: "dummy"]),
         do: :ok
  end

  test "normal flow" do
    mock_db_key = MongoMocks.init_mock_db(@mongo_server)
    with_mocks([MongoMocks.gen(@mongo_server, mock_db_key)]) do
      assert {:ok, type, config} = Request.validate(@correct_request_config)
      assert {:ok, rid} = Request.save(@mongo_server, type, config)
      assert :ok = Request.reap(@mongo_server, rid)
    end
  end

  test "validate error" do
    assert {:error, error} = Request.validate(@wrong_request_config)
  end

  test "mongo errors" do
    mock_db_key = MongoMocks.init_mock_db(@mongo_server)
    with_mocks([MongoMocks.gen(@mongo_server, mock_db_key)]) do
      assert {:ok, type, config} = Request.validate(@correct_request_config)
      assert {:ok, rid} = Request.save(@mongo_server, type, config)
    end

    gen_mongo_mocks_and_replace = fn(server, mock_db_key) ->
      {m, opts, fns} = MongoMocks.gen(server, mock_db_key)
      new_fns = fns |>
        Keyword.put(:find_one, fn(_, _, _) -> nil end) |>
        Keyword.put(:insert_one!, fn(_, _coll, _doc) -> raise "oops!" end) |>
        Keyword.put(:find_one_and_update, fn(_, _, _, _) -> raise "oops!" end)
      {m, opts, new_fns}
    end
    with_mocks([gen_mongo_mocks_and_replace.(@mongo_server, mock_db_key)]) do
      assert {:ok, type, config} = Request.validate(@correct_request_config)
      assert {:error, error} = Request.save(@mongo_server, type, config)
      assert {:error, error} = Request.reap(@mongo_server, rid)
    end
  end

end
