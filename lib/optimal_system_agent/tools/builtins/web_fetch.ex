defmodule OptimalSystemAgent.Tools.Builtins.WebFetch do
  @behaviour OptimalSystemAgent.Tools.Behaviour

  @default_max_length 10_000

  @impl true
  def safety, do: :read_only

  @impl true
  def name, do: "web_fetch"

  @impl true
  def description,
    do:
      "Fetch content from a URL. Returns readable text for HTML pages, raw content for JSON/text."

  @impl true
  def parameters do
    %{
      "type" => "object",
      "properties" => %{
        "url" => %{
          "type" => "string",
          "description" => "The URL to fetch (must be https:// except for localhost)"
        },
        "max_length" => %{
          "type" => "integer",
          "description" => "Maximum characters to return (default #{@default_max_length})"
        }
      },
      "required" => ["url"]
    }
  end

  @impl true
  def execute(%{"url" => url} = params) when is_binary(url) do
    max_length = params["max_length"] || @default_max_length

    case validate_url(url) do
      {:error, reason} ->
        {:error, reason}

      :ok ->
        do_fetch(url, max_length)
    end
  end

  def execute(%{"url" => _}), do: {:error, "url must be a string"}
  def execute(_), do: {:error, "Missing required parameter: url"}

  # --- Private ---

  defp validate_url(url) do
    uri = URI.parse(url)

    case uri.scheme do
      "https" ->
        :ok

      "http" ->
        host = uri.host || ""

        if host == "localhost" or String.starts_with?(host, "127.") or host == "::1" do
          :ok
        else
          {:error, "Only HTTPS URLs are allowed (got http://#{host})"}
        end

      other ->
        {:error, "Unsupported URL scheme: #{other}. Only https:// is allowed."}
    end
  end

  defp do_fetch(url, max_length) do
    # Step 3: Build request with W3C traceparent header
    opts = OptimalSystemAgent.Observability.Traceparent.add_to_request([
      receive_timeout: 30_000,
      redirect: true,
      max_redirects: 3
    ])

    response = Req.get(url, opts)

    case response do
      {:ok, %Req.Response{status: status, body: body, headers: headers}} when status in 200..299 ->
        content_type = extract_content_type(headers)
        formatted = format_body(body, content_type, max_length)
        {:ok, "#{url}\n#{content_type}\n---\n#{formatted}"}

      {:ok, %Req.Response{status: status}} ->
        {:error, "HTTP #{status} fetching #{url}"}

      {:error, %Req.TransportError{reason: reason}} ->
        {:error, "Network error fetching #{url}: #{inspect(reason)}"}

      {:error, reason} ->
        {:error, "Error fetching #{url}: #{inspect(reason)}"}
    end
  end

  defp extract_content_type(headers) when is_list(headers) do
    case List.keyfind(headers, "content-type", 0) do
      {_, value} -> value
      nil -> "text/plain"
    end
  end

  defp extract_content_type(headers) when is_map(headers) do
    Map.get(headers, "content-type", "text/plain")
  end

  defp extract_content_type(_), do: "text/plain"

  defp format_body(body, content_type, max_length) when is_binary(body) do
    cond do
      String.contains?(content_type, "text/html") ->
        body |> strip_html_tags() |> truncate(max_length)

      String.contains?(content_type, "application/json") or
          String.contains?(content_type, "text/json") ->
        case Jason.decode(body) do
          {:ok, decoded} ->
            decoded |> Jason.encode!(pretty: true) |> truncate(max_length)

          _ ->
            truncate(body, max_length)
        end

      true ->
        truncate(body, max_length)
    end
  end

  defp format_body(body, content_type, max_length) do
    # Body may have been decoded to a map/list by Req for JSON responses
    cond do
      String.contains?(content_type, "application/json") ->
        body |> Jason.encode!(pretty: true) |> truncate(max_length)

      is_map(body) or is_list(body) ->
        body |> inspect(pretty: true, limit: max_length) |> truncate(max_length)

      true ->
        body |> to_string() |> truncate(max_length)
    end
  end

  # Strip HTML tags and decode common HTML entities, collapsing whitespace.
  defp strip_html_tags(html) do
    html
    |> String.replace(~r/<script[^>]*>.*?<\/script>/is, " ")
    |> String.replace(~r/<style[^>]*>.*?<\/style>/is, " ")
    |> String.replace(~r/<[^>]+>/, " ")
    |> decode_html_entities()
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end

  defp decode_html_entities(text) do
    text
    |> String.replace("&amp;", "&")
    |> String.replace("&lt;", "<")
    |> String.replace("&gt;", ">")
    |> String.replace("&quot;", "\"")
    |> String.replace("&#39;", "'")
    |> String.replace("&nbsp;", " ")
  end

  defp truncate(text, max_length) when is_binary(text) do
    if String.length(text) > max_length do
      String.slice(text, 0, max_length) <> "\n[truncated at #{max_length} characters]"
    else
      text
    end
  end
end
