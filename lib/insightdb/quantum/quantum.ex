defmodule Insightdb.Quantum do

  require Logger

  def install_cronjob(cronjob_list) do
    Enum.each(cronjob_list, fn({datetime, fun, args}) ->
      Logger.info "cronjob: #{inspect datetime} #{inspect fun} #{inspect args}"
    end)
    :ok
  end

end
