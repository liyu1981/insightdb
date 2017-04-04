defmodule Insightdb.Request do

  require Insightdb.Constant

  alias Insightdb.Constant, as: Constant
  alias Insightdb.CommandScheduler, as: CommandScheduler

  def validate(request_config) do
    # TODO: fix validation
    {:ok, request_config}
  end

  def save(mongo_conn, request_config) do
    new_request_config = Map.put(request_config, Constant.field_ds, DateTime.to_unix(DateTime.utc_now()))
    Mongo.insert_one(mongo_conn, Constant.coll_request, new_request_config, [])
  end

  def find(mongo_conn, request_id) do
    Mongo.find_one(mongo_conn, Constant.coll_request, %{Constant.field__id => request_id}, [])
  end

  def try_archive(doc) do
    case Map.get(doc, Constant.request_field_type) do
      Constant.request_type_repeat -> {:ok, []}
      Constant.request_type_once -> {:ok, [Map.get(doc, Constant.field__id)]}
    end
  end

  def reap(doc) do
    {rid, datetime, cron_fun, cmd_type, cmd_config} = gen_cronjob_cmd(doc)
    with {:ok, %{inserted_id: cmd_id}} <- CommandScheduler.reg(cmd_type, cmd_config, rid),
      do: {:ok, [rid], [{datetime, cron_fun, cmd_id}]}
  end

  # private

  defp gen_cronjob_cmd(doc) do
    case Map.get(doc, Constant.request_field_type) do
      Constant.request_type_once ->
        gen_cronjob_cmd_once(doc)
      Constant.request_type_repeat ->
        gen_cronjob_cmd_repeat(doc)
    end
  end

  defp gen_cronjob_cmd_once(doc) do
    with payload <- Map.get(doc, Constant.request_field_payload),
         rid <- Map.get(doc, Constant.field__id),
         cmd_type <- Map.get(payload, Constant.field_cmd_type),
         cmd_config <- Map.get(payload, Constant.field_cmd_config),
         do: {rid, :once, &CommandScheduler.run/1, cmd_type, cmd_config}
  end

  defp gen_cronjob_cmd_repeat(doc) do
    # TODO: repeat validation
    with payload <- Map.get(doc, Constant.request_field_payload),
         datetime <- Map.get(doc, Constant.request_type_repeat),
         rid <- Map.get(doc, Constant.field__id),
         cmd_type <- Map.get(payload, Constant.field_cmd_type),
         cmd_config <- Map.get(payload, Constant.field_cmd_config),
         do: {rid, datetime, &CommandScheduler.run/1, cmd_type, cmd_config}
  end

  # defp gen_archieve_doc(doc) do
  #   %{Constant.field__id => orig_request_id} = doc
  #   doc |> Map.delete(Constant.field__id) |> Map.put(Constant.request_field_req_id, orig_request_id)
  # end
  #
  # defp try_archive_request(true, mongo_conn, request_id, doc) do
  #   with archieve_doc <- gen_archieve_doc(doc),
  #        {:ok, %{inserted_id: _new_id}} <- Mongo.insert_one(mongo_conn, Constant.coll_request_archive,
  #                                                           archieve_doc),
  #        {:ok, %{deleted_id: _id}} <- Mongo.delete_one(mongo_conn, Constant.coll_request,
  #                                                      %{Constant.field__id => request_id}),
  #        do: {:ok, [request_id]}
  # end
  # defp try_archive_request(_archive?, _mongo_conn, _request_id, _doc) do
  #   {:ok, []}
  # end

end
