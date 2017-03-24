defmodule Bangify do

  defmacro __using__(_opts) do
     quote do
       import Bangify
     end
  end

  defmacro bangify(result) do
    quote do
      case unquote(result) do
        {:ok, value}    -> value
        {:error, error} -> raise error
        :ok             -> nil
      end
    end
  end

end
