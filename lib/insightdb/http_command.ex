defmodule Insightdb.HttpCommand do
  require Logger

  defmacro __using__(_) do
    HTTPoison.start
  end

  def run(verb, url, body \\ "", headers \\ [], options \\ []) do
    case {verb, Keyword.fetch(options, :paging_strategy)} do
      {:get, {:ok, paging_strategy}} ->
        run_with_paging(verb, url, body, headers, options, paging_strategy, [])
      _ ->
        run_single(verb, url, body, headers, options)
    end
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
      {ok?, response} ->
        {ok?, response}
    end
  end

  defp run_single(verb, url, body, headers, options) do
    Logger.info "http #{verb} request to #{url}, with headers: #{inspect headers}, body:#{inspect body}"
    case send_http_request(verb, url, body, headers, options) do
      {:ok, response} ->
        header_map = Enum.into(response.headers, %{})
        response = %{response | headers: header_map}
        case response.headers["Content-Type"] do
          "application/json" <> _ ->
            try_parse_json_body(response)
          "text/javascript" <> _ ->
            try_parse_json_body(response)
          _->
            {:ok, response}
        end
      {:error, error} ->
        exit(error)
    end
  end

  defp send_http_request(verb, url, body, headers, options) do
    {ok?, response} = case verb do
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
    case ok? do
      :ok ->
        verify_http_response(response, verb, url, body, headers, options)
      :error ->
        {:error, {:verify_error, response}}
      _ ->
        {:error, "Unknown code #{ok?} and response #{inspect response}"}
    end
  end

  defp verify_http_response(response, verb, url, body, headers, options) do
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
    {ok?, bodyjson} = Poison.Parser.parse(response.body)
    case ok? do
      :ok ->
        {:ok, %{response | body: bodyjson}}
      _ ->
        {:error, {:parse_body_fail, response}}
    end
  end

end
