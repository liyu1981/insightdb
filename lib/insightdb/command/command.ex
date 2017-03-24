defmodule Insightdb.Command do
  require Logger
  require Insightdb.Command.Constant
  use Insightdb.Command.HttpCommand

  alias Insightdb.Command.Constant, as: Constant
  alias Insightdb.Command.HttpCommand, as: HttpCommand

  def find_cmd(cmd_id) do
    case Mongo.find_one(Constant.conn_name, Constant.coll_cmd_schedule, %{Constant.field__id => cmd_id}) do
      nil ->
        raise "can not find cmd with id #{inspect cmd_id}"
      doc ->
        doc
    end
  end

  def update_cmd_status(cmd_id, Constant.status_failed, [error: error, stacktrace: stacktrace]) do
    Mongo.insert_one!(
      Constant.conn_name, Constant.coll_cmd_schedule_error,
      %{Constant.field_cmd_id => cmd_id,
        Constant.field_error => "#{inspect error}",
        Constant.field_stacktrace => "#{inspect stacktrace}"}
    )
    Mongo.find_one_and_update(
      Constant.conn_name, Constant.coll_cmd_schedule,
      %{Constant.field__id => cmd_id},
      %{"set" => %{Constant.field_status => Constant.status_failed}}
    )
  end

  def update_cmd_status(cmd_id, new_status) do
    Mongo.find_one_and_update(
      Constant.conn_name, Constant.coll_cmd_schedule,
      %{Constant.field__id => cmd_id},
      %{"set" => %{Constant.field_status => new_status}}
    )
  end

  def run_command(:http_command, [verb: verb, url: url, body: body, headers: headers, options: options]) do
    HttpCommand.run!(verb, url, body, headers, options)
  end

  def save_cmd_result(cmd_id, result) do
    Mongo.insert_one!(
      Constant.conn_name, Constant.coll_cmd_schedule_result,
      %{Constant.field_cmd_id => cmd_id,
        Constant.field_result => result}
    )
  end

  def update_cmd_status_and_save_error(cmd_id, errormsg) do
    stacktrace = System.stacktrace() |> Exception.format_stacktrace()
    try do
      update_cmd_status(cmd_id, Constant.status_failed, [error: errormsg, stacktrace: stacktrace])
    rescue
      _ ->
        Logger.error "save error failed for cmd_id #{cmd_id}, error: #{errormsg}, stacktrace: \n#{stacktrace}"
    end
  end

end
