defmodule Insightdb.Test do

  defmacro __using__(_opts) do
    quote do
      import Insightdb.Test
    end
  end

  defmacro kill_all_on_exit(pid_list) do
    if Mix.env == :test do
      quote do
        on_exit(fn -> unquote(pid_list) |> Enum.each(fn(pid) -> Process.exit(pid, :kill) end) end)
      end
    else
      # nothing
    end
  end

end
