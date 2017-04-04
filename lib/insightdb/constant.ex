defmodule Insightdb.Constant do
  use Constants

  constant db, "insightdb"

  constant coll_system, "system"
  constant coll_cmd_schedule, "cmd_schedule"
  constant coll_cmd_schedule_error, "cmd_schedule_error"
  constant coll_cmd_schedule_result, "cmd_schedule_result"
  constant coll_request, "request"
  constant coll_request_archive, "request_archive"
  constant coll_request_error, "request_error"

  constant field__id, "_id"
  constant field_status, "status"
  constant field_cmd_id, "cmd_id"
  constant field_cmd_type, "cmd_type"
  constant field_cmd_config, "cmd_config"
  constant field_error, "error"
  constant field_stacktrace, "stacktrace"
  constant field_result, "result"
  constant field_ds, "ds"
  constant field_ref_request_id, "ref_request_id"

  constant status_scheduled, "scheduled"
  constant status_running, "running"
  constant status_done, "done"
  constant status_finished, "finished"
  constant status_failed, "failed"

  constant request_field_req_id, "req_id"
  constant request_field_type, "type"
  constant request_field_payload, "payload"

  constant request_type_repeat, "repeat"
  constant request_type_once, "once"

end
