defmodule Insightdb.Command do
  require Logger
  require Insightdb.Command.Constant
  alias Insightdb.Command.Constant, as: Constant
  alias Insightdb.Command.HttpCommand, as: HttpCommand

  @moduledoc """
  Command's life cycle:
    1. update command's data to Mongo doc with cmd_id (status: scheduled)
    2. run command (update status: running)
    3. after finish command, depends on the result, update status: finished or failed
    4. save result/error to new doc in Mongo with ref cmd id to cmd_id, after saving, update
       command's data in Mongo with status: done
  """

  def reg(cmd_type, cmd_config) do
    case Mongo.insert_one(Constant.conn_name, Constant.coll_cmd_schedule, %{
      "cmd_type" => cmd_type,
      "status" => Constant.status_scheduled,
      "cmd_config" => cmd_config
    }) do
      {:ok, %{inserted_id: cmd_id}} ->
        {:ok, cmd_id}
      {:error, error} ->
        {:ok, error}
    end
  end

  def status(cmd_id) do
    try do
      doc = find_cmd(cmd_id)
      {:ok, doc[Constant.field_status]}
    rescue
      e ->
        {:error, e}
    end
  end

  def run(cmd_id) do
    try do
      %{"cmd_type" => cmd_type, Constant.field_status => Constant.status_scheduled, "cmd_config" => cmd_config} =
        find_cmd(cmd_id)
      update_cmd_status(cmd_id, Constant.status_running)
      result = run_command(cmd_type, cmd_config)
      update_cmd_status(cmd_id, Constant.status_finished)
      save_cmd_result(cmd_id, result)
      update_cmd_status(cmd_id, Constant.status_done)
    rescue
      e -> update_cmd_status_and_save_error(cmd_id, Exception.message(e))
    catch
      :exit, reason -> update_cmd_status_and_save_error(cmd_id, Exception.format_exit(reason))
    end
  end

  defp find_cmd(cmd_id) do
    case Mongo.find_one(Constant.conn_name, Constant.coll_cmd_schedule, %{Constant.field__id => cmd_id}) do
      nil ->
        raise "can not find cmd with id #{inspect cmd_id}"
      doc ->
        doc
    end
  end

  defp update_cmd_status(cmd_id, Constant.status_failed, [error: error, stacktrace: stacktrace]) do
    Mongo.insert_one!(
      Constant.conn_name, Constant.coll_cmd_schedule_error,
      %{"cmd_id" => cmd_id,
        "error" => "#{inspect error}",
        "stacktrace" => "#{inspect stacktrace}"}
    )
    Mongo.find_one_and_update(
      Constant.conn_name, Constant.coll_cmd_schedule,
      %{Constant.field__id => cmd_id},
      %{"set" => %{Constant.field_status => Constant.status_failed}}
    )
  end

  defp update_cmd_status(cmd_id, new_status) do
    Mongo.find_one_and_update(
      Constant.conn_name, Constant.coll_cmd_schedule,
      %{Constant.field__id => cmd_id},
      %{"set" => %{Constant.field_status => new_status}}
    )
  end

  defp run_command(:http_command, [verb: verb, url: url, body: body, headers: headers, options: options]) do
    case HttpCommand.run(verb, url, body, headers, options) do
      {:ok, result} ->
        {:ok, result}
      {:error, error} ->
        raise error
    end
  end

  defp save_cmd_result(cmd_id, result) do
    Mongo.insert_one!(
      Constant.conn_name, Constant.coll_cmd_schedule_result,
      %{"cmd_id" => cmd_id,
        "result" => result}
    )
  end

  defp update_cmd_status_and_save_error(cmd_id, errormsg) do
    stacktrace = System.stacktrace() |> Exception.format_stacktrace()
    try do
      update_cmd_status(cmd_id, Constant.status_failed, [error: errormsg, stacktrace: stacktrace])
    rescue
      _ ->
        Logger.error "save error failed for cmd_id #{cmd_id}, error: #{errormsg}, stacktrace: \n#{stacktrace}"
    end
  end

end
