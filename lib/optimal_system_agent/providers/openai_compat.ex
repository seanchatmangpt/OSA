defmodule OptimalSystemAgent.Providers.OpenAICompat do
  @moduledoc """
  Shared chat completion logic for all OpenAI-compatible APIs.

  Providers that use this module only need to supply:
  - base URL
  - API key
  - model name

  The wire format (POST /chat/completions), tool call formatting, and
  response parsing are identical across all OpenAI-compatible endpoints.
  """

  require Logger

  alias OptimalSystemAgent.Providers.ToolCallParsers
  alias OptimalSystemAgent.Utils.Text

  @doc """
  Execute a chat completion against any OpenAI-compatible endpoint.

  Full form with all parameters.
  Returns `{:ok, %{content: String.t(), tool_calls: list()}}` or `{:error, reason}`.
  """
  @spec chat(String.t(), String.t() | nil, String.t(), list(), keyword()) ::
          {:ok, map()} | {:error, String.t()}
  def chat(base_url, api_key, model, messages, opts) do
    unless api_key do
      {:error, "API key not configured"}
    else
      do_chat(base_url, api_key, model, messages, opts)
    end
  end

  @doc """
  Simplified chat completion using application config defaults.

  Uses:
  - API key from `:openai_api_key` config
  - Base URL from `:openai_base_url` config (default: OpenAI)
  - Model from `:openai_model` config (default: "gpt-4o-mini")

  Returns `{:ok, %{content: String.t(), tool_calls: list()}}` or `{:error, reason}`.
  """
  @spec chat(list()) :: {:ok, map()} | {:error, String.t()}
  def chat(messages) do
    api_key = Application.get_env(:optimal_system_agent, :openai_api_key)

    unless api_key do
      {:error, "OPENAI_API_KEY not configured"}
    else
      base_url = Application.get_env(:optimal_system_agent, :openai_base_url, "https://api.openai.com/v1")
      model = Application.get_env(:optimal_system_agent, :openai_model, default_model())
      chat(base_url, api_key, model, messages, [])
    end
  end

  @doc """
  Streaming chat completion for OpenAI-compatible endpoints.

  Sends SSE-streamed tokens to the callback as `{:text_delta, text}`,
  `{:thinking_delta, text}`, and `{:done, result}`.

  Returns `:ok` on success or `{:error, reason}` on failure.
  """
  @spec chat_stream(String.t(), String.t() | nil, String.t(), list(), function(), keyword()) ::
          :ok | {:error, String.t()}
  def chat_stream(base_url, api_key, model, messages, callback, opts) do
    unless api_key do
      {:error, "API key not configured"}
    else
      do_chat_stream(base_url, api_key, model, messages, callback, opts)
    end
  end

  @doc "Get the provider name."
  @spec name() :: :openai_compat
  def name, do: :openai_compat

  @doc "Get the default model name."
  @spec default_model() :: String.t()
  def default_model, do: "gpt-4o-mini"

  defp do_chat(base_url, api_key, model, messages, opts) do
    start_time = System.monotonic_time(:millisecond)

    # Inject model into opts so maybe_add_tools can check parallel_tool_calls support
    opts_with_model = Keyword.put(opts, :model, model)

    body =
      %{
        model: model,
        messages: format_messages(messages),
        temperature: Keyword.get(opts, :temperature, 0.7)
      }
      |> maybe_add_tools(opts_with_model)
      |> maybe_add_max_tokens(model, opts)
      |> maybe_add_reasoning(model, opts)
      |> maybe_add_response_format(opts)

    extra_headers = Keyword.get(opts, :extra_headers, [])

    headers =
      [
        {"Authorization", "Bearer #{api_key}"},
        {"Content-Type", "application/json"}
      ] ++ extra_headers

    url = "#{base_url}/chat/completions"
    # Reasoning models (o3, deepseek-reasoner, etc.) need 300+ s for chain-of-thought
    timeout = Keyword.get(opts, :receive_timeout, 120_000)

    try do
      case Req.post(url, json: body, headers: headers, receive_timeout: timeout) do
        {:ok, %{status: 200, body: %{"choices" => [%{"message" => msg} | _]} = resp}} ->
          duration_ms = System.monotonic_time(:millisecond) - start_time

          # Emit telemetry for successful chat completion
          :telemetry.execute(
            [:osa, :providers, :chat, :complete],
            %{duration: duration_ms},
            %{provider: provider_from_url(base_url), model: model}
          )

          raw_content = msg["content"] || ""
          tool_calls = parse_tool_calls(msg, model)

          # Emit telemetry for tool calls if present
          if tool_calls != [] do
            :telemetry.execute(
              [:osa, :providers, :tool_call, :complete],
              %{count: length(tool_calls)},
              %{provider: provider_from_url(base_url), model: model}
            )
          end
          # Strip XML tool-call markup from content when calls were parsed from text (not tool_calls field)
          content =
            if tool_calls != [] and not Map.has_key?(msg, "tool_calls") do
              strip_tool_call_markup(raw_content)
            else
              raw_content
            end
            |> Text.strip_thinking_tokens()
          usage = parse_usage(resp)
          {:ok, %{content: content, tool_calls: tool_calls, usage: usage}}

        {:ok, %{status: 429, body: resp_body, headers: resp_headers}} ->
          duration_ms = System.monotonic_time(:millisecond) - start_time
          retry_after = parse_retry_after(resp_headers)
          error_msg = extract_error_message(resp_body)
          Logger.warning("Rate limited by provider (HTTP 429): #{error_msg}")

          :telemetry.execute(
            [:osa, :providers, :chat, :error],
            %{duration: duration_ms},
            %{provider: provider_from_url(base_url), model: model, reason: :rate_limited}
          )

          {:error, {:rate_limited, retry_after}}

        {:ok, %{status: status, body: %{"error" => %{"code" => "tool_use_failed"} = error} = resp_body}} ->
          # Some OpenAI-compatible providers return this when the model generates XML-style
          # tool calls instead of JSON. The failed_generation field contains the XML tool
          # call that we can parse and recover (e.g., <function=name>...</function>)
          case Map.get(error, "failed_generation") do
            nil ->
              # No failed_generation field, fall through to generic error handling
              error_msg = extract_error_message(resp_body)
              {:error, "HTTP #{status}: #{error_msg}"}

            failed_gen ->
              # Parse the XML tool call using existing infrastructure
              parsed_calls = parse_tool_calls_from_content(failed_gen)

              if parsed_calls == [] do
                # Failed to parse, return generic error
                Logger.warning("[OpenAICompat] Failed to parse tool_use_failed failed_generation")
                error_msg = extract_error_message(resp_body)
                {:error, "HTTP #{status}: #{error_msg}"}
              else
                # Return structured error with parsed tool calls for recovery
                Logger.info("[OpenAICompat] Recovered #{length(parsed_calls)} tool calls from failed_generation")
                {:error, {:tool_call_format_failed, %{
                  original_error: Map.get(error, "message"),
                  failed_generation: failed_gen,
                  recovered_tool_calls: parsed_calls
                }}}
              end
          end

        {:ok, %{status: status, body: resp_body}} ->
          duration_ms = System.monotonic_time(:millisecond) - start_time
          error_msg = extract_error_message(resp_body)

          :telemetry.execute(
            [:osa, :providers, :chat, :error],
            %{duration: duration_ms},
            %{provider: provider_from_url(base_url), model: model, reason: :http_error, status: status}
          )

          {:error, "HTTP #{status}: #{error_msg}"}

        {:error, reason} ->
          duration_ms = System.monotonic_time(:millisecond) - start_time

          :telemetry.execute(
            [:osa, :providers, :chat, :error],
            %{duration: duration_ms},
            %{provider: provider_from_url(base_url), model: model, reason: :connection_failed}
          )

          {:error, "Connection failed: #{inspect(reason)}"}
      end
    rescue
      e ->
        duration_ms = System.monotonic_time(:millisecond) - start_time

        :telemetry.execute(
          [:osa, :providers, :chat, :error],
          %{duration: duration_ms},
          %{provider: provider_from_url(base_url), model: model, reason: :exception}
        )

        {:error, "Unexpected error: #{Exception.message(e)}"}
    end
  end

  # ── Streaming implementation ───────────────────────────────────────────

  defp do_chat_stream(base_url, api_key, model, messages, callback, opts) do
    body =
      %{
        model: model,
        messages: format_messages(messages),
        temperature: Keyword.get(opts, :temperature, 0.7),
        stream: true
      }
      |> maybe_add_tools(opts)
      |> maybe_add_max_tokens(model, opts)
      |> maybe_add_reasoning(model, opts)

    extra_headers = Keyword.get(opts, :extra_headers, [])

    headers =
      [
        {"Authorization", "Bearer #{api_key}"},
        {"Content-Type", "application/json"}
      ] ++ extra_headers

    url = "#{base_url}/chat/completions"
    timeout = Keyword.get(opts, :receive_timeout, 600_000)

    # Accumulator for streamed data (stored in process dictionary like Ollama)
    stream_key = {__MODULE__, :stream, make_ref()}
    Process.put(stream_key, %{
      buffer: "",
      content: "",
      tool_calls: %{},   # index → %{id, name, arguments_json}
      usage: %{}
    })

    try do
      case Req.post(url,
             json: body,
             headers: headers,
             receive_timeout: timeout,
             into: fn {:data, data}, {req, resp} ->
               acc = Process.get(stream_key)
               acc = handle_sse_chunk(data, callback, acc)
               Process.put(stream_key, acc)
               {:cont, {req, resp}}
             end
           ) do
        {:ok, _resp} ->
          acc = Process.get(stream_key)
          Process.delete(stream_key)
          finalize_sse_stream(acc, callback, model)

        {:error, reason} ->
          Process.delete(stream_key)
          Logger.error("OpenAI-compat stream failed: #{inspect(reason)}")
          {:error, "Stream connection failed: #{inspect(reason)}"}
      end
    rescue
      e ->
        Process.delete(stream_key)
        Logger.error("OpenAI-compat stream error: #{Exception.message(e)}")
        {:error, "Stream error: #{Exception.message(e)}"}
    end
  end

  # Parse SSE data lines. OpenAI SSE format:
  #   data: {"choices":[{"delta":{"content":"tok"}}]}
  #   data: [DONE]
  defp handle_sse_chunk(data, callback, acc) do
    {lines, new_buffer} = split_sse_lines(acc.buffer <> data)
    acc = %{acc | buffer: new_buffer}
    Enum.reduce(lines, acc, &process_sse_line(&1, callback, &2))
  end

  defp split_sse_lines(data) do
    lines = String.split(data, "\n")
    {complete, [remainder]} = Enum.split(lines, -1)
    # Only keep lines starting with "data:" — skip comments, empty lines, event: lines
    sse_data =
      complete
      |> Enum.filter(&String.starts_with?(&1, "data:"))
      |> Enum.map(fn "data:" <> rest -> String.trim_leading(rest) end)

    {sse_data, remainder}
  end

  defp process_sse_line("[DONE]", _callback, acc), do: acc

  defp process_sse_line(json_str, callback, acc) do
    case Jason.decode(json_str) do
      {:ok, %{"choices" => [%{"delta" => delta} | _]} = chunk} ->
        acc = process_delta(delta, callback, acc)
        # Capture usage if present (some providers send it in the final chunk)
        case chunk do
          %{"usage" => %{"prompt_tokens" => inp, "completion_tokens" => out}} ->
            %{acc | usage: %{input_tokens: inp, output_tokens: out}}
          _ ->
            acc
        end

      {:ok, %{"usage" => %{"prompt_tokens" => inp, "completion_tokens" => out}}} ->
        %{acc | usage: %{input_tokens: inp, output_tokens: out}}

      {:ok, %{"error" => %{"message" => msg}}} ->
        Logger.error("OpenAI-compat stream error: #{msg}")
        acc

      {:error, _} ->
        # Malformed JSON — skip
        acc

      _ ->
        acc
    end
  end

  defp process_delta(delta, callback, acc) do
    # Text content
    acc =
      case delta do
        %{"content" => text} when is_binary(text) and text != "" ->
          # Suppress XML tool-call markup from streaming output — it will be stripped in finalize
          unless xml_tool_call_content?(acc.content <> text) do
            callback.({:text_delta, text})
          end
          %{acc | content: acc.content <> text}

        _ ->
          acc
      end

    # Reasoning/thinking content (DeepSeek, Groq gpt-oss, and some providers)
    # Groq gpt-oss models send "reasoning" field with optional "channel" key
    acc =
      case delta do
        %{"reasoning_content" => text} when is_binary(text) and text != "" ->
          callback.({:thinking_delta, text})
          acc

        %{"reasoning" => text} when is_binary(text) and text != "" ->
          callback.({:thinking_delta, text})
          acc

        _ ->
          acc
      end

    # Tool call deltas — accumulate across chunks.
    # OpenAI streams tool calls as: index, id (first chunk), function.name (first),
    # function.arguments (subsequent chunks, partial JSON).
    case delta do
      %{"tool_calls" => tool_deltas} when is_list(tool_deltas) ->
        Enum.reduce(tool_deltas, acc, fn tc_delta, a ->
          idx = tc_delta["index"] || 0
          existing = Map.get(a.tool_calls, idx, %{id: nil, name: "", arguments_json: ""})

          updated =
            existing
            |> maybe_set_id(tc_delta)
            |> maybe_append_name(tc_delta)
            |> maybe_append_args(tc_delta)

          %{a | tool_calls: Map.put(a.tool_calls, idx, updated)}
        end)

      _ ->
        acc
    end
  end

  defp maybe_set_id(tc, %{"id" => id}) when is_binary(id), do: %{tc | id: id}
  defp maybe_set_id(tc, _), do: tc

  defp maybe_append_name(tc, %{"function" => %{"name" => name}}) when is_binary(name),
    do: %{tc | name: tc.name <> name}
  defp maybe_append_name(tc, _), do: tc

  defp maybe_append_args(tc, %{"function" => %{"arguments" => args}}) when is_binary(args),
    do: %{tc | arguments_json: tc.arguments_json <> args}
  defp maybe_append_args(tc, _), do: tc

  defp finalize_sse_stream(acc, callback, model) do
    content = Text.strip_thinking_tokens(acc.content)

    # Build tool_calls from accumulated deltas
    streamed_tool_calls =
      acc.tool_calls
      |> Enum.sort_by(fn {idx, _} -> idx end)
      |> Enum.map(fn {_idx, tc} ->
        args =
          case Jason.decode(tc.arguments_json) do
            {:ok, parsed} when is_map(parsed) -> parsed
            _ -> %{}
          end

        %{
          id: tc.id || generate_id(),
          name: tc.name |> normalize_tool_name(),
          arguments: args
        }
      end)

    # Fallback: parse tool calls from content if none streamed
    {tool_calls, content} =
      if streamed_tool_calls != [] do
        {streamed_tool_calls, content}
      else
        parsed =
          case ToolCallParsers.parse(acc.content, model) do
            [] -> parse_tool_calls_from_content(acc.content)
            calls -> calls
          end

        if parsed != [] do
          clean = acc.content |> strip_tool_call_markup() |> Text.strip_thinking_tokens()
          {parsed, clean}
        else
          {[], content}
        end
      end

    result = %{content: content, tool_calls: tool_calls, usage: acc.usage}
    callback.({:done, result})
    :ok
  end

  @doc "Format messages into the OpenAI wire format."
  def format_messages(messages) do
    Enum.map(messages, fn
      # Tool result messages — preserve tool_call_id and name for the API.
      # `name` identifies which function produced this result; Groq and some
      # OpenAI-compat providers require it to match the original tool call on
      # iteration 2+ (Bug 5: tool name mismatch on 2nd iteration).
      %{role: "tool", content: content, tool_call_id: id} = msg ->
        base = %{"role" => "tool", "content" => to_string(content), "tool_call_id" => to_string(id)}
        case Map.get(msg, :name) do
          nil -> base
          name -> Map.put(base, "name", to_string(name))
        end

      # Assistant messages with tool_calls — preserve structured tool calls
      %{role: "assistant", content: content, tool_calls: calls} when is_list(calls) and calls != [] ->
        msg = %{"role" => "assistant", "content" => to_string(content)}

        formatted_calls =
          Enum.map(calls, fn tc ->
            %{
              "id" => to_string(tc[:id] || tc["id"] || ""),
              "type" => "function",
              "function" => %{
                "name" => (tc[:name] || tc["name"] || "") |> to_string() |> normalize_tool_name(),
                "arguments" =>
                  case tc[:arguments] || tc["arguments"] do
                    a when is_binary(a) -> a
                    a when is_map(a) -> Jason.encode!(a)
                    _ -> "{}"
                  end
              }
            }
          end)

        Map.put(msg, "tool_calls", formatted_calls)

      # Generic atom-keyed messages
      %{role: role, content: content} ->
        %{"role" => to_string(role), "content" => to_string(content)}

      %{"role" => _role} = msg ->
        msg

      msg when is_map(msg) ->
        msg
    end)
  end

  @doc """
  Format tools into the OpenAI function-calling format.

  Accepts:
  - Structs with .name, .description, .parameters fields
  - Plain maps with atom or string keys
  - Already-formatted OpenAI tool maps (passed through as-is)
  """
  def format_tools(tools) do
    Enum.map(tools, fn
      # Already formatted — has "function" key with nested structure
      %{"type" => "function", "function" => %{}} = tool ->
        tool

      %{type: "function", function: %{}} = tool ->
        stringify_keys(tool)

      # Struct or flat map — needs wrapping
      tool ->
        name = access_field(tool, :name)
        description = access_field(tool, :description)
        parameters = access_field(tool, :parameters)

        %{
          "type" => "function",
          "function" => %{
            "name" => name,
            "description" => description,
            "parameters" => parameters
          }
        }
    end)
  end

  defp stringify_keys(map) when is_map(map) do
    Map.new(map, fn
      {k, v} when is_atom(k) -> {to_string(k), stringify_keys(v)}
      {k, v} -> {k, stringify_keys(v)}
    end)
  end

  defp stringify_keys(other), do: other

  # Access field from struct (dot access) or map (atom/string key access)
  defp access_field(tool, field) when is_map(tool) do
    case Map.fetch(tool, field) do
      {:ok, val} -> val
      :error ->
        # Try string key
        Map.get(tool, to_string(field))
    end
  rescue
    _ -> Access.get(tool, field)
  end

  @doc "Parse tool_calls from an OpenAI-style message map."
  def parse_tool_calls(%{"tool_calls" => calls}) when is_list(calls) do
    Enum.map(calls, fn call ->
      args =
        case Jason.decode(call["function"]["arguments"] || "{}") do
          {:ok, parsed} -> parsed
          _ -> %{}
        end

      %{
        id: call["id"] || generate_id(),
        name: call["function"]["name"] |> to_string() |> normalize_tool_name(),
        arguments: args
      }
    end)
  end

  # Fallback: detect tool calls embedded as XML/JSON in the content field
  def parse_tool_calls(%{"content" => content}) when is_binary(content) do
    parse_tool_calls_from_content(content)
  end

  def parse_tool_calls(_), do: []

  @doc """
  Model-aware variant — tries model-specific parsers before the generic fallback.
  """
  def parse_tool_calls(%{"tool_calls" => calls}, _model) when is_list(calls) do
    parse_tool_calls(%{"tool_calls" => calls})
  end

  def parse_tool_calls(%{"content" => content} = _msg, model) when is_binary(content) do
    case ToolCallParsers.parse(content, model) do
      [] -> parse_tool_calls_from_content(content)
      calls -> calls
    end
  end

  def parse_tool_calls(msg, _model), do: parse_tool_calls(msg)

  @doc false
  def parse_tool_calls_from_content(content) when is_binary(content) do
    cond do
      # Format 2: <function_call>{"name": "...", "arguments": {...}}</function_call>
      # Must be checked BEFORE Format 1 — "<function_call>" contains "<function"
      String.contains?(content, "<function_call>") ->
        ~r/<function_call>\s*/s
        |> Regex.split(content, include_captures: false)
        |> Enum.drop(1)
        |> Enum.flat_map(fn chunk ->
          case extract_balanced_json(chunk) do
            {:ok, json_str} ->
              case Jason.decode(json_str) do
                {:ok, %{"name" => name, "arguments" => args}} when is_map(args) ->
                  [%{id: generate_id(), name: normalize_tool_name(name), arguments: args}]

                {:ok, %{"name" => name, "arguments" => args}} when is_binary(args) ->
                  parsed = case Jason.decode(args) do
                    {:ok, a} -> a
                    _ -> %{}
                  end
                  [%{id: generate_id(), name: normalize_tool_name(name), arguments: parsed}]

                _ -> []
              end

            _ -> []
          end
        end)

      # Format 1: <function name="tool_name" parameters={...}></function>
      String.contains?(content, "<function") ->
        extract_xml_function_calls(content)

      # Format 3: raw JSON tool call object {"name": "...", "arguments": {...}}
      String.contains?(content, "\"name\"") and String.contains?(content, "\"arguments\"") ->
        extract_json_tool_calls(content)

      true ->
        []
    end
  end

  def parse_tool_calls_from_content(_), do: []

  # Extract <function name="..." parameters={...}></function> tags with proper
  # balanced-brace JSON parsing (fixes non-greedy regex failure on nested JSON).
  @xml_fn_pattern ~r/<function\s+name="([^"\s{(]*).*?parameters=/s

  defp extract_xml_function_calls(content) do
    @xml_fn_pattern
    |> Regex.scan(content, return: :index)
    |> Enum.flat_map(fn [{match_start, match_len}, {name_start, name_len}] ->
      name = binary_part(content, name_start, name_len)
      json_offset = match_start + match_len
      rest = binary_part(content, json_offset, byte_size(content) - json_offset)

      case extract_balanced_json(rest) do
        {:ok, args_str} ->
          args = case Jason.decode(args_str) do
            {:ok, parsed} -> parsed
            _ -> %{}
          end
          [%{id: generate_id(), name: normalize_tool_name(name), arguments: args}]

        _ -> []
      end
    end)
  end

  # Extract all JSON tool call objects from free-form text (Format 3).
  defp extract_json_tool_calls(content) do
    content
    |> scan_json_objects()
    |> Enum.flat_map(fn json_str ->
      case Jason.decode(json_str) do
        {:ok, %{"name" => name, "arguments" => args}} when is_map(args) ->
          [%{id: generate_id(), name: normalize_tool_name(name), arguments: args}]
        _ -> []
      end
    end)
  end

  # Scan a string for all top-level JSON objects, returning them as strings.
  defp scan_json_objects(str), do: scan_json_objects(str, [])

  defp scan_json_objects("", acc), do: Enum.reverse(acc)

  defp scan_json_objects(str, acc) do
    case :binary.match(str, "{") do
      :nomatch ->
        Enum.reverse(acc)

      {pos, 1} ->
        substr = binary_part(str, pos, byte_size(str) - pos)

        case extract_balanced_json(substr) do
          {:ok, json_str} ->
            rest_pos = pos + byte_size(json_str)
            rest = binary_part(str, rest_pos, byte_size(str) - rest_pos)
            scan_json_objects(rest, [json_str | acc])

          _ ->
            rest = binary_part(str, pos + 1, byte_size(str) - pos - 1)
            scan_json_objects(rest, acc)
        end
    end
  end

  # Extract a balanced JSON object starting at the first `{` in the string.
  # Handles nested objects and quoted strings (including escaped quotes).
  # Returns {:ok, json_string} or :error.
  defp extract_balanced_json(str) do
    case :binary.match(str, "{") do
      :nomatch -> :error
      {start, 1} ->
        substr = binary_part(str, start, byte_size(str) - start)
        case scan_balanced(substr, 0, 0) do
          {:ok, len} -> {:ok, binary_part(substr, 0, len)}
          :error -> :error
        end
    end
  end

  defp scan_balanced(str, depth, pos)

  defp scan_balanced("", depth, _pos) when depth > 0, do: :error
  defp scan_balanced("", 0, pos), do: {:ok, pos}

  # Enter a quoted string — skip until closing unescaped quote
  defp scan_balanced(<<"\"", rest::binary>>, depth, pos) do
    case skip_json_string(rest, pos + 1) do
      {:ok, new_pos} -> scan_balanced(binary_part(rest, new_pos - pos - 1, byte_size(rest) - (new_pos - pos - 1)), depth, new_pos)
      :error -> :error
    end
  end

  defp scan_balanced(<<"{", rest::binary>>, depth, pos) do
    scan_balanced(rest, depth + 1, pos + 1)
  end

  defp scan_balanced(<<"}", _rest::binary>>, 1, pos) do
    {:ok, pos + 1}
  end

  defp scan_balanced(<<"}", rest::binary>>, depth, pos) when depth > 1 do
    scan_balanced(rest, depth - 1, pos + 1)
  end

  defp scan_balanced(<<_byte, rest::binary>>, depth, pos) do
    scan_balanced(rest, depth, pos + 1)
  end

  # Skip over a JSON string (already consumed the opening `"`).
  # Returns {:ok, position_after_closing_quote} or :error.
  defp skip_json_string(str, pos)

  defp skip_json_string("", _pos), do: :error

  defp skip_json_string(<<"\\", _escaped, rest::binary>>, pos) do
    skip_json_string(rest, pos + 2)
  end

  defp skip_json_string(<<"\"", _rest::binary>>, pos) do
    {:ok, pos + 1}
  end

  defp skip_json_string(<<_byte, rest::binary>>, pos) do
    skip_json_string(rest, pos + 1)
  end

  defp normalize_tool_name(name) when is_binary(name) do
    name |> String.split(~r/[\s({]/) |> List.first() |> String.trim()
  end

  defp strip_tool_call_markup(content) when is_binary(content) do
    content
    |> String.replace(~r/<function\s+name="[^"]+"\s+parameters=\{.*?\}\s*>\s*<\/function>/s, "")
    |> String.replace(~r/<function_call>.*?<\/function_call>/s, "")
    |> String.trim()
  end
  defp strip_tool_call_markup(content), do: content

  defp xml_tool_call_content?(content) when is_binary(content) do
    String.contains?(content, "<function") or String.contains?(content, "<function_call>")
  end
  defp xml_tool_call_content?(_), do: false

  # --- Private helpers ---

  defp maybe_add_tools(body, opts) do
    case Keyword.get(opts, :tools) do
      nil -> body
      [] -> body
      tools ->
        body = body
        |> Map.put(:tools, format_tools(tools))
        |> Map.put(:tool_choice, "auto")

        # Only enable parallel tool calls for models that support it.
        # openai/gpt-oss-* models do NOT support parallel tool calls.
        model = Keyword.get(opts, :model, "")
        if supports_parallel_tool_calls?(model) do
          Map.put(body, :parallel_tool_calls, true)
        else
          body
        end
    end
  end

  defp supports_parallel_tool_calls?(model) do
    name = String.downcase(to_string(model))
    not String.contains?(name, "gpt-oss")
  end

  defp maybe_add_response_format(body, opts) do
    case Keyword.get(opts, :response_format) do
      nil -> body
      format -> Map.put(body, :response_format, format)
    end
  end

  # Reasoning models (gpt-oss, o3, deepseek-reasoner, etc.) use internal
  # reasoning tokens that count against max_tokens.  A low budget (e.g. 80
  # or 150) is entirely consumed by reasoning, producing an EMPTY response.
  # Floor: 500 tokens when the model is a reasoning model.
  @reasoning_min_tokens 500

  defp maybe_add_max_tokens(body, model, opts) do
    case Keyword.get(opts, :max_tokens) do
      nil ->
        body

      n when is_integer(n) ->
        effective = if reasoning_model?(model) and n < @reasoning_min_tokens, do: @reasoning_min_tokens, else: n
        Map.put(body, :max_tokens, effective)

      n ->
        Map.put(body, :max_tokens, n)
    end
  end

  # Add reasoning_effort for OpenAI o-series models.
  # o3/o3-mini/o4-mini support "low", "medium", "high" (default: medium).
  # For non-reasoning models this is a no-op.
  defp maybe_add_reasoning(body, model, opts) do
    case Keyword.get(opts, :reasoning_effort) do
      nil ->
        if reasoning_model?(model) do
          Map.put(body, :reasoning_effort, "medium")
        else
          body
        end

      effort when effort in ["low", "medium", "high"] ->
        Map.put(body, :reasoning_effort, effort)

      _ ->
        body
    end
  end

  @doc "Returns true for models that use chain-of-thought reasoning."
  def reasoning_model?(model) do
    name = String.downcase(to_string(model))

    String.starts_with?(name, "o3") or
      String.starts_with?(name, "o4") or
      String.starts_with?(name, "o1") or
      name == "deepseek-reasoner" or
      String.contains?(name, "kimi") or
      # Groq-hosted OpenAI open-source reasoning models (e.g. openai/gpt-oss-20b)
      String.contains?(name, "gpt-oss")
  end

  defp parse_usage(%{"usage" => %{"prompt_tokens" => inp, "completion_tokens" => out}}),
    do: %{input_tokens: inp, output_tokens: out}

  defp parse_usage(_), do: %{}

  defp extract_error_message(%{"error" => %{"message" => msg}}), do: msg
  defp extract_error_message(%{"error" => msg}) when is_binary(msg), do: msg
  defp extract_error_message(body), do: inspect(body)

  # Parse the Retry-After header from HTTP 429 responses.
  # Handles both integer seconds and RFC 7231 HTTP-date strings.
  # Returns the number of seconds to wait, or nil if the header is absent/unparseable.
  defp parse_retry_after(headers) when is_list(headers) do
    headers
    |> Enum.find_value(fn
      {"retry-after", v} -> v
      {"Retry-After", v} -> v
      _ -> nil
    end)
    |> parse_retry_after_value()
  end

  defp parse_retry_after(_), do: nil

  # Integer seconds: "30"
  defp parse_retry_after_value(nil), do: nil

  defp parse_retry_after_value(v) when is_binary(v) do
    case Integer.parse(String.trim(v)) do
      {seconds, ""} when seconds > 0 ->
        seconds

      _ ->
        # RFC 7231 HTTP-date: "Thu, 01 Jan 2026 00:00:30 GMT"
        case parse_http_date(v) do
          {:ok, future_dt} ->
            diff = DateTime.diff(future_dt, DateTime.utc_now(), :second)
            if diff > 0, do: diff, else: nil

          :error ->
            nil
        end
    end
  end

  @http_date_months %{
    "Jan" => 1, "Feb" => 2, "Mar" => 3, "Apr" => 4,
    "May" => 5, "Jun" => 6, "Jul" => 7, "Aug" => 8,
    "Sep" => 9, "Oct" => 10, "Nov" => 11, "Dec" => 12
  }

  # Parse RFC 7231 date format: "Thu, 01 Jan 2026 00:00:30 GMT"
  defp parse_http_date(v) when is_binary(v) do
    pattern = ~r/\w{3},\s+(\d{1,2})\s+(\w{3})\s+(\d{4})\s+(\d{2}):(\d{2}):(\d{2})\s+GMT/

    case Regex.run(pattern, v) do
      [_, day_s, month_s, year_s, hour_s, min_s, sec_s] ->
        with {day, ""} <- Integer.parse(day_s),
             {month, _} <- Map.fetch(@http_date_months, month_s) |> then(fn
               {:ok, m} -> {m, ""}
               :error -> :error
             end),
             {year, ""} <- Integer.parse(year_s),
             {hour, ""} <- Integer.parse(hour_s),
             {minute, ""} <- Integer.parse(min_s),
             {second, ""} <- Integer.parse(sec_s),
             {:ok, dt} <- DateTime.new(Date.new!(year, month, day), Time.new!(hour, minute, second)) do
          {:ok, dt}
        else
          _ -> :error
        end

      _ ->
        :error
    end
  end

  @doc """
  Generate a unique tool call ID.

  Public for use in error recovery when reconstructing assistant messages
  from failed_generation content.
  """
  def generate_tool_call_id, do: OptimalSystemAgent.Utils.ID.generate()

  defp generate_id,
    do: generate_tool_call_id()

  # Extract provider name from base URL for telemetry metadata
  defp provider_from_url(url) when is_binary(url) do
    cond do
      String.contains?(url, "groq.com") -> :groq
      String.contains?(url, "api.openai.com") -> :openai
      String.contains?(url, "api.anthropic.com") -> :anthropic
      String.contains?(url, "openrouter.ai") -> :openrouter
      String.contains?(url, "ollama") -> :ollama
      true -> :unknown
    end
  end
  defp provider_from_url(_), do: :unknown
end
