defmodule Insightdb.Command.Constant do
  use Constants

  constant conn_name, :insightdb_mongo_conn

  constant coll_cmd_schedule, "cmd_schedule"
  constant coll_cmd_schedule_error, "cmd_schedule_error"
  constant coll_cmd_schedule_result, "cmd_schedule_result"

  constant field__id, "_id"
  constant field_status, "status"
  constant field_cmd_id, "cmd_id"
  constant field_cmd_type, "cmd_type"
  constant field_cmd_config, "cmd_config"
  constant field_error, "error"
  constant field_stacktrace, "stacktrace"
  constant field_result, "result"

  constant status_scheduled, "scheduled"
  constant status_running, "running"
  constant status_done, "done"
  constant status_finished, "finished"
  constant status_failed, "failed"

end
