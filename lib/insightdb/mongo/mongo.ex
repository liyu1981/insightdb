defmodule Insightdb.Mongo do

  defmacro gen_start_link do
    case Mix.env do
      :test -> quote do: fn(params) ->
          apply(String.to_atom("Elixir.Insightdb.MongoMocks"), :start_link, [params])
        end
      _prod_or_dev -> quote do: fn(params) -> apply(Mongo, :start_link, [params]) end
    end
  end

end
