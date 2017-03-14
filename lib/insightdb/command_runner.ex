defmodule Insightdb.CommandRunner do

  def run(:http_command, verb, url, body \\ "", headers \\ [], options \\ []) do
    alias Insightdb.HttpCommand, as: HttpCommand
    case Keyword.fetch(options, :merge_strategy) do
      {:ok, merge_strategy} ->
        HttpCommand.run(verb, url, body, headers, options) |> post_process(merge_strategy)
      _ ->
        HttpCommand.run(verb, url, body, headers, options)
    end
  end

  defp post_process({:ok, response}, merge_strategy) do
    if is_list(response) do
      {:ok, %{"result" => merge_result(response, merge_strategy, []), "original_response" => response}}
    else
      {:ok, %{"result" => response.body, "original_response" => response}}
    end
  end

  defp post_process({:error, response}, _) do
    {:error, response}
  end

  defp merge_result([hd | tl], merge_strategy, accumulater) do
    #IO.puts "will merge #{inspect hd}, left #{inspect tl}"
    case merge_strategy.(hd, accumulater) do
      {:ok, accumulater} ->
        merge_result(tl, merge_strategy, accumulater)
      {:error, error} ->
        exit(error)
    end
  end

  defp merge_result([], _, accumulater) do
    accumulater
  end

end
