defmodule Insightdb.Command.HttpCommand do
  require Logger
  use Bangify

  defmacro __using__(_) do
    HTTPoison.start
  end

  def run!(verb, url, body \\ "", headers \\ [], options \\ []) do
    bangify(run(verb, url, body, headers, options))
  end

  def run(verb, url, body \\ "", headers \\ [], options \\ []) do
    (case {verb, Keyword.fetch(options, :paging_strategy)} do
      {:get, {:ok, paging_strategy}} ->
        run_with_paging(verb, url, body, headers, options, paging_strategy, [])
      _ ->
        run_single(verb, url, body, headers, options)
    end) |>
    try_merge_result(Keyword.fetch(options, :merge_strategy))
  end

  defp run_with_paging(verb, url, body, headers, options, paging_strategy, accumulator) do
    case run_single(verb, url, body, headers, options) do
      {:ok, response} ->
        case paging_strategy.(response) do
          {:ok, next_url} ->
            run_with_paging(verb, next_url, body, headers, options, paging_strategy, [response | accumulator])
          _ ->
            {:ok, [response | accumulator]}
        end
      {:error, error} ->
        {:error, error}
    end
  end

  defp run_single(verb, url, body, headers, options) do
    Logger.info "http #{verb} request to #{url}, with headers: #{inspect headers}, body:#{inspect body}"
    with {:ok, response} <- send_http_request(verb, url, body, headers, options),
         header_map <- Enum.into(response.headers, %{}),
         response <- %{response | headers: header_map},
         do: try_parse_json_body(response)
  end

  defp send_http_request(verb, url, body, headers, options) do
    do_verb = fn ->
      case verb do
        :get ->
          HTTPoison.get(url, headers, options)
        :post ->
          HTTPoison.post(url, body, headers, options)
        :put ->
          HTTPoison.put(url, body, headers, options)
        :delete ->
          HTTPoison.delete(url, headers, options)
        _ ->
          {:error, "Do not know how to handle http verb: #{verb}"}
      end
    end
    with {:ok, response} <- do_verb.(),
         do: verify_http_response(response, verb, url, body, headers, options)
  end

  defp verify_http_response(response, verb, _url, body, headers, options) do
    case response.status_code do
      200 ->
        {:ok, response}
      302 ->
        header_map = Enum.into(response.headers, %{})
        send_http_request(verb, header_map["Location"], body, headers, options)
      _ ->
        {:error, response}
    end
  end

  defp try_parse_json_body(response) do
    case response.headers["Content-Type"] do
      "application/json" <> _ -> parse_json_body(response)
      "text/javascript" <> _ -> parse_json_body(response)
      _-> {:ok, response}
    end
  end

  defp parse_json_body(response) do
    case Poison.Parser.parse(response.body) do
      {:ok, bodyjson} ->
        {:ok, %{response | body: bodyjson}}
      _ ->
        {:error, {:parse_body_fail, response}}
    end
  end

  defp try_merge_result({:ok, response}, {:ok, merge_strategy}) do
    if is_list(response) do
      {:ok, %{"result" => merge_result(response, merge_strategy, []), "original_response" => response}}
    else
      {:ok, %{"result" => response.body, "original_response" => response}}
    end
  end

  defp try_merge_result({:ok, response}, :error) do
    {:ok, %{"result" => response.body, "original_response" => response}}
  end

  defp try_merge_result({:error, response}, _) do
    {:error, response}
  end

  defp merge_result([hd | tl], merge_strategy, accumulater) do
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
