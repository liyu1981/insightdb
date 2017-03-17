defmodule Insightdb.CommandRunner do
  require Logger

  @moduledoc """
  Command's life cycle:
    1. update command's data to Mongo doc with cmd_id (status: scheduled)
    2. run command (update status: running)
    3. after finish command, depends on the result, update status: finished or failed
    4. save result/error to new doc in Mongo with ref cmd id to cmd_id, after saving, update
       command's data in Mongo with status: done
  """

  @conn_name :insightdb_mongo_conn
  @coll_cmd_schedule "cmd_schedule"
  @coll_cmd_schedule_error "cmd_schedule_error"
  @coll_cmd_schedule_result "cmd_schedule_result"
  @field__id "_id"
  @field_status "status"
  @status_scheduled "scheduled"
  @status_running "running"
  @status_done "done"
  @status_finished "finished"
  @status_failed "failed"

  def run(cmd_id) do
    try do
      %{"cmd_type" => cmd_type, @field_status => @status_scheduled, "cmd_config" => cmd_config} = find_cmd(cmd_id)
      update_cmd_status(cmd_id, @status_running)
      result = run_command(cmd_type, cmd_config)
      update_cmd_status(cmd_id, @status_finished)
      save_cmd_result(cmd_id, result)
      update_cmd_status(cmd_id, @status_done)
    rescue
      e -> update_cmd_status_and_save_error(cmd_id, Exception.message(e))
    catch
      :exit, reason -> update_cmd_status_and_save_error(cmd_id, Exception.format_exit(reason))
    end
  end

  defp find_cmd(cmd_id) do
    case Mongo.find(:insightdb_mongo_conn, @coll_cmd_schedule, %{@field__id => cmd_id}) do
      nil ->
        raise "can not find cmd with id #{inspect cmd_id}"
      doc ->
        doc
    end
  end

  defp update_cmd_status(cmd_id, @status_failed, [error: error, stacktrace: stacktrace]) do
    Mongo.insert_one!(
      @conn_name, @coll_cmd_schedule_error,
      %{"cmd_id" => cmd_id,
        "error" => "#{inspect error}",
        "stacktrace" => "#{inspect stacktrace}"}
    )
    Mongo.find_one_and_update(
      @conn_name, @coll_cmd_schedule,
      %{@field__id => cmd_id},
      %{"set" => %{@field_status => @status_failed}}
    )
  end

  defp update_cmd_status(cmd_id, new_status) do
    Mongo.find_one_and_update(
      @conn_name, @coll_cmd_schedule,
      %{@field__id => cmd_id},
      %{"set" => %{@field_status => new_status}}
    )
  end

  defp run_command("http_command", [verb: verb, url: url, body: body, headers: headers, options: options]) do
    case Insightdb.HttpCommand.run(verb, url, body, headers, options) do
      {:ok, result} ->
        {:ok, result}
      {:error, error} ->
        raise error
    end
  end

  defp save_cmd_result(cmd_id, result) do
    Mongo.insert_one!(
      @conn_name,
      @coll_cmd_schedule_result,
      %{"cmd_id" => cmd_id,
        "result" => result}
    )
  end

  defp update_cmd_status_and_save_error(cmd_id, errormsg) do
    stacktrace = System.stacktrace() |> Exception.format_stacktrace()
    try do
      update_cmd_status(cmd_id, @status_failed, [error: errormsg, stacktrace: stacktrace])
    rescue
      _ ->
        Logger.error "save error failed for cmd_id #{cmd_id}, error: #{errormsg}, stacktrace: \n#{stacktrace}"
    end
  end

end
