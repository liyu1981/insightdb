defmodule Insightdb.Command.MongoMocks do
  use GenServer
  require Stash

  @stash_mock_db_key "mockdb"
  @stash_domain :mongo_mock_server

  @init_mock_db %{
    "cmd_schedule" => [],
    "cmd_schedule_error" => [],
    "cmd_schedule_result" => [],
  }

  def init_mock_db(server) do
    GenServer.call(server, {:init_mock_db})
  end

  def setup_mock_db(server, cmd_id, cmd_type, cmd_config) do
    mock_db_key = init_mock_db(server)
    GenServer.call(server, {:insert_doc, mock_db_key, "cmd_schedule",
      %{"_id" => cmd_id, "cmd_type" => cmd_type, "status" => "scheduled", "cmd_config" => cmd_config}})
    mock_db_key
  end

  def find_doc(server, mock_db_key, coll, findfn) do
    GenServer.call(server, {:find_doc, mock_db_key, coll, findfn})
  end

  def update_doc(server, mock_db_key, coll, doc) do
    GenServer.call(server, {:update_doc, mock_db_key, coll, doc})
  end

  def insert_doc(server, mock_db_key, coll, doc) do
    GenServer.call(server, {:insert_doc, mock_db_key, coll, doc})
  end

  def gen(server, mock_db_key) do
    {Mongo, [], [
      find_one: fn(_, _, %{"_id" => cmd_id}) ->
        find_doc(server, mock_db_key, "cmd_schedule", fn(x) -> x["_id"] == cmd_id end)
      end,
      find_one_and_update: fn(_, _, %{"_id" => cmd_id}, %{"set" => %{"status" => status}}) ->
        doc = find_doc(server, mock_db_key, "cmd_schedule", fn(x) -> x["_id"] == cmd_id end)
        new_doc = Map.put(doc, "status", status)
        with {:ok, _} <- update_doc(server, mock_db_key, "cmd_schedule", new_doc),
             do: {:ok, new_doc}
      end,
      insert_one: fn(_, coll, doc) ->
        insert_doc(server, mock_db_key, coll, doc)
      end,
      insert_one!: fn(_, coll, doc) ->
        insert_doc(server, mock_db_key, coll, doc)
      end,
    ]}
  end

  def get_db(server, mock_db_key) do
    GenServer.call(server, {:get_db, mock_db_key})
  end

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

  def handle_call({:find_doc, mock_db_key, coll, findfn}, _from, state) do
    mock_db = Stash.get(@stash_domain, mock_db_key)
    doc = Enum.find(Map.get(mock_db, coll), fn(x) -> findfn.(x) end)
    {:reply, doc, state}
  end

  def handle_call({:insert_doc, mock_db_key, coll, doc}, _from, state) do
    mock_db = Stash.get(@stash_domain, mock_db_key)
    coll_list = Map.get(mock_db, coll)
    size = Enum.count(coll_list) + 1
    Stash.set(@stash_domain, mock_db_key, Map.put(mock_db, coll, coll_list ++ [Map.put_new(doc, "_id", size)]))
    {:reply, {:ok, %{inserted_id: size}}, state}
  end

  def handle_call({:update_doc, mock_db_key, coll, doc}, _from, state) do
    mock_db = Stash.get(@stash_domain, mock_db_key)
    coll_list = Map.get(mock_db, coll)
    with pos <- Enum.find_index(coll_list, fn(x) -> x["_id"] == doc["_id"] end),
         new_coll_list <- (List.delete_at(coll_list, pos) ++ [doc]),
         do:
           Stash.set(@stash_domain, mock_db_key, Map.put(mock_db, coll, new_coll_list))
           {:reply, {:ok, %{matched_count: 1, modified_count: 1}}, state}
  end

end