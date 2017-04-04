defmodule Insightdb.MongoMocks do
  use GenServer
  require Stash

  @stash_mock_db_key "mockdb"
  @stash_domain :mongo_mock_server

  @typedoc "The GenServer name"
  @type name :: atom | {:global, term} | {:via, module, term}

  @typedoc "The server reference"
  @type server :: pid | name | {atom, node}

  @init_mock_db %{
    "cmd_schedule" => [],
    "cmd_schedule_error" => [],
    "cmd_schedule_result" => [],
  }

  @spec init_mock_db(server) :: term
  def init_mock_db(server) do
    GenServer.call(server, {:init_mock_db})
  end

  @spec setup_mock_db(server, integer, term, map) :: term
  def setup_mock_db(server, cmd_id, cmd_type, cmd_config) do
    mock_db_key = init_mock_db(server)
    GenServer.call(server, {:insert_doc, mock_db_key, "cmd_schedule",
      %{"_id" => cmd_id, "cmd_type" => cmd_type, "status" => "scheduled", "cmd_config" => cmd_config}})
    mock_db_key
  end

  @spec find_doc(server, String.t, String.t, fun) :: term
  def find_doc(server, mock_db_key, coll, findfn, default \\ [%{}]) do
    GenServer.call(server, {:find_doc, mock_db_key, coll, findfn, default})
  end

  @spec update_doc(server, String.t, String.t, map) :: term
  def update_doc(server, mock_db_key, coll, doc) do
    GenServer.call(server, {:update_doc, mock_db_key, coll, doc})
  end

  @spec insert_doc(server, String.t, String.t, map) :: term
  def insert_doc(server, mock_db_key, coll, doc) do
    GenServer.call(server, {:insert_doc, mock_db_key, coll, doc})
  end

  @spec gen(server, String.t) :: {module, list, list}
  def gen(server, mock_db_key) do
    {Mongo, [], [
      find: fn(_, "cmd_schedule", %{"cmd_type" => :http_command, "status" => status},
              [sort: _sort, batch_size: _batch_size, limit: _limit]) ->
        find_doc(server, mock_db_key, "cmd_schedule",
          fn(x) -> x["cmd_type"] == :http_command and x["status"] == status end)
      end,
      find: fn(_, coll, %{}, [projection: %{"_id" => 1}]) ->
        find_doc(server, mock_db_key, coll, fn(_x) -> true end) |> Enum.map(fn(item) -> Map.get(item, "_id") end)
      end,

      find_one: fn(_, coll, %{"_id" => id}) ->
        find_doc(server, mock_db_key, coll, fn(x) -> x["_id"] == id end) |> hd
      end,
      find_one: fn(_, coll, %{"_id" => id}, _) ->
        find_doc(server, mock_db_key, coll, fn(x) -> x["_id"] == id end) |> hd
      end,

      find_one_and_update: fn(_, coll, %{"_id" => cmd_id}, %{"set" => set_config}) ->
        doc = find_doc(server, mock_db_key, coll, fn(x) -> x["_id"] == cmd_id end) |> hd
        new_doc = Enum.reduce(set_config, doc, fn({key, value}, acc) -> Map.put(acc, key, value) end)
        with {:ok, _} <- update_doc(server, mock_db_key, coll, new_doc),
             do: {:ok, new_doc}
      end,
      find_one_and_update: fn(_, coll, %{}, %{"set" => set_config}) ->
        doc = find_doc(server, mock_db_key, coll, fn(_x) -> true end) |> hd
        new_doc = Enum.reduce(set_config, doc, fn({key, value}, acc) -> Map.put(acc, key, value) end)
        with {:ok, _} <- update_doc(server, mock_db_key, coll, new_doc),
             do: {:ok, new_doc}
      end,

      insert_one: fn(_, coll, doc, _) ->
        insert_doc(server, mock_db_key, coll, doc)
      end,
      insert_one: fn(_, coll, doc) ->
        insert_doc(server, mock_db_key, coll, doc)
      end,

      insert_one!: fn(_, coll, doc, _) ->
        insert_doc(server, mock_db_key, coll, doc)
      end,
      insert_one!: fn(_, coll, doc) ->
        insert_doc(server, mock_db_key, coll, doc)
      end,
    ]}
  end

  @spec get_db(server, String.t) :: term
  def get_db(server, mock_db_key) do
    GenServer.call(server, {:get_db, mock_db_key})
  end

  @spec gen_start_link() :: {module, list, list}
  def gen_start_link() do
    {Mongo, [], [
      start_link: fn(params) -> start_link(params) end,
    ]}
  end

  # GenServer

  def start_link([name: conn_name, database: _database]) do
    with {:ok, pid} <- GenServer.start_link(__MODULE__, :ok, []),
         true <- Process.register(pid, conn_name),
         do: {:ok, pid}
  end

  def init(:ok) do
    {:ok, %{}}
  end

  def handle_call({:init_mock_db}, _from, state) do
    mock_db_key = @stash_mock_db_key <> SecureRandom.base64(8)
    Stash.set(@stash_domain, mock_db_key, @init_mock_db)
    {:reply, mock_db_key, state}
  end

  def handle_call({:get_db, mock_db_key}, _from, state) do
    {:reply, Stash.get(@stash_domain, mock_db_key), state}
  end

  def handle_call({:find_doc, mock_db_key, coll, findfn, default}, _from, state) do
    mock_db = Stash.get(@stash_domain, mock_db_key)
    case Map.get(mock_db, coll) do
      nil -> {:reply, default, state}
      coll_list -> {:reply, Enum.filter(coll_list, fn(x) -> findfn.(x) end), state}
    end
  end

  def handle_call({:insert_doc, mock_db_key, coll, doc}, _from, state) do
    mock_db = Stash.get(@stash_domain, mock_db_key)
    coll_list = Map.get(mock_db, coll, [])
    size = Enum.count(coll_list) + 1
    Stash.set(@stash_domain, mock_db_key, Map.put(mock_db, coll, coll_list ++ [Map.put_new(doc, "_id", size)]))
    {:reply, {:ok, %{inserted_id: size}}, state}
  end

  def handle_call({:update_doc, mock_db_key, coll, doc}, _from, state) do
    mock_db = Stash.get(@stash_domain, mock_db_key)
    coll_list = Map.get(mock_db, coll)
    if coll_list == nil do
      Stash.set(@stash_domain, mock_db_key, Map.put(mock_db, coll, [doc]))
      {:reply, {:ok, %{matched_count: 0, modified_count: 1}}, state}
    else
      with pos <- Enum.find_index(coll_list, fn(x) -> x["_id"] == doc["_id"] end),
           new_coll_list <- (List.delete_at(coll_list, pos) ++ [doc]),
           do:
             Stash.set(@stash_domain, mock_db_key, Map.put(mock_db, coll, new_coll_list))
             {:reply, {:ok, %{matched_count: 1, modified_count: 1}}, state}
    end
  end

end
