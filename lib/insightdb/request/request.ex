defmodule Insightdb.Request do

  import Insightdb.Constant

  alias Insightdb.Constant, as: Constant
  alias Insightdb.CommandScheduler, as: CommandScheduler
  alias Insightdb.CommandRunner, as: CommandRunner

  def validate(request_config) do
    with type <- Map.get(request_config, Constant.request_field_type),
         config <- normalize_request_config(Map.delete(request_config, Constant.request_field_type)),
         do: {:ok, type, config}
  end

  def save(mongo_conn, request_type, request_config) do
    with {:ok, %{inserted_id: id}} = Mongo.insert_one(mongo_conn, Constant.coll_request,
           %{Constant.field_ds => DateTime.to_unix(DateTime.utc_now()),
           Constant.request_field_type => request_type,
           Constant.request_field_config => request_config},
         []),
         do: {:ok, id}
  end

  @spec reap(term, integer) :: {:ok, list, list, list} | {:error, String.t}
  def reap(mongo_conn, request_id) do
    with doc <- Mongo.find_one(mongo_conn, Constant.coll_request, %{Constant.field__id => request_id}),
         {:ok, archive?, cron_job} <- gen_cron_job(doc),
         {:ok, archived_ids} <- try_archive_request(archive?, mongo_conn, request_id, doc),
         do: {:ok, [request_id], archived_ids, [cron_job]}
  end

  # private

  defp normalize_request_config(request_config) do
    request_config
  end

  defp gen_cron_job(doc) do
    %{Constant.field__id => request_id} = doc
    request_id
  end

  defp gen_archieve_doc(doc) do
    %{Constant.field__id => orig_request_id} = doc
    doc |> Map.delete(Constant.field__id) |> Map.put(Constant.request_field_req_id, orig_request_id)
  end

  defp try_archive_request(true, mongo_conn, request_id, doc) do
    with archieve_doc <- gen_archieve_doc(doc),
         {:ok, %{inserted_id: _new_id}} <- Mongo.insert_one(mongo_conn, Constant.coll_request_archive,
                                                            archieve_doc),
         {:ok, %{deleted_id: _id}} <- Mongo.delete_one(mongo_conn, Constant.coll_request,
                                                       %{Constant.field__id => request_id}),
         do: {:ok, [request_id]}
  end

  defp try_archive_request(_archive?, _mongo_conn, _request_id, _doc) do
    {:ok, []}
  end

end
