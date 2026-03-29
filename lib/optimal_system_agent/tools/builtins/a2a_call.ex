defmodule OptimalSystemAgent.Tools.Builtins.A2ACall do
  @moduledoc """
  A2A (Agent-to-Agent) protocol tool.

  Allows OSA agents to discover and communicate with other A2A-compliant
  agents (BusinessOS, Canopy, external agents) via the A2A protocol.

  Uses JSON-RPC 2.0 over HTTP for task creation and tool execution.
  """

  @behaviour OptimalSystemAgent.Tools.Behaviour

  require Logger

  alias OptimalSystemAgent.Observability.Telemetry

  @default_timeout 30_000
  @agent_call_timeout 60_000  # call_agent needs longer timeout due to additional processing

  @impl true
  def safety, do: :sandboxed

  @impl true
  def name, do: "a2a_call"

  @impl true
  def description do
    """
    Call an external agent via A2A (Agent-to-Agent) protocol.

    Supports discovering agent cards, creating tasks, listing tools,
    and executing tools on remote A2A-compliant agents.

    Known agents:
    - BusinessOS: http://localhost:8001/api/integrations/a2a/agents
    - Canopy: http://localhost:9089/api/v1/a2a/agents
    - OSA (self): http://localhost:8089/api/v1/a2a/agent-card
    """
  end

  @impl true
  def parameters do
    %{
      "type" => "object",
      "properties" => %{
        "action" => %{
          "type" => "string",
          "enum" => ["discover", "call", "list_tools", "execute_tool", "tasks_send"],
          "description" => "A2A action to perform"
        },
        "agent_url" => %{
          "type" => "string",
          "description" => "URL of the target A2A agent endpoint"
        },
        "message" => %{
          "type" => "string",
          "description" => "Message to send (for 'call' action)"
        },
        "tool_name" => %{
          "type" => "string",
          "description" => "Tool name to execute (for 'execute_tool' action)"
        },
        "arguments" => %{
          "type" => "object",
          "description" => "Tool arguments (for 'execute_tool' action)"
        },
        "tool" => %{
          "type" => "string",
          "description" => "pm4py skill name for tasks_send (e.g. pm4py_statistics)"
        },
        "args" => %{
          "type" => "object",
          "description" => "Tool arguments for tasks_send action"
        },
        "task_id" => %{
          "type" => "string",
          "description" => "Optional task ID (auto-generated if omitted)"
        },
        "timeout_ms" => %{
          "type" => "integer",
          "description" => "Request timeout in ms (default: 65000)"
        }
      },
      "required" => ["action", "agent_url"]
    }
  end

  @impl true
  def execute(%{"action" => action, "agent_url" => agent_url} = params) do
    # Emit a2a.call span covering the full operation — traceparent already injected
    # into outbound HTTP calls by Traceparent.add_to_request in each action helper.
    span_attrs = %{
      "a2a.target_agent_url" => agent_url,
      "a2a.action" => action
    }

    # Include tool_name if present (execute_tool action)
    span_attrs =
      case params["tool_name"] do
        nil -> span_attrs
        tool_name -> Map.put(span_attrs, "a2a.tool_name", tool_name)
      end

    {:ok, span} = Telemetry.start_span("a2a.call", span_attrs)
    Process.put(:telemetry_current_span_id, span["span_id"])

    result =
      case action do
        "discover" -> discover_agent(agent_url)
        "call" -> call_agent(agent_url, params["message"] || "")
        "list_tools" -> list_tools(agent_url)
        "execute_tool" -> execute_tool(agent_url, params["tool_name"], params["arguments"] || %{})
        "tasks_send" ->
          tool      = Map.get(params, "tool")
          args      = Map.get(params, "args", %{})

          cond do
            is_nil(agent_url) or agent_url == "" ->
              {:error, "tasks_send requires agent_url"}
            is_nil(tool) or tool == "" ->
              {:error, "tasks_send requires tool"}
            true ->
              do_tasks_send(agent_url, tool, args, params)
          end
        _ -> {:error, "Unknown action: #{action}. Use: discover, call, list_tools, execute_tool, tasks_send"}
      end

    case result do
      {:ok, _} -> Telemetry.end_span(span, :ok)
      {:error, reason} -> Telemetry.end_span(span, :error, inspect(reason))
    end

    result
  end

  def execute(_), do: {:error, "Missing required parameters: action, agent_url"}

  # ── Actions ──────────────────────────────────────────────────────

  defp discover_agent(agent_url) do
    start_time = System.monotonic_time(:microsecond)
    base_url = normalize_url(agent_url)

    # Try /.well-known/agent.json (MCP/A2A standard) first,
    # fall back to /api/v1/a2a/agent-card for legacy compatibility.
    well_known_url = "#{base_url}/.well-known/agent.json"
    legacy_url = "#{base_url}/api/v1/a2a/agent-card"

    opts = OptimalSystemAgent.Observability.Traceparent.add_to_request([
      receive_timeout: @default_timeout,
      retry: false
    ])

    result =
      case Req.get(well_known_url, opts) do
        {:ok, %{status: 200, body: body}} when is_map(body) ->
          Logger.info("[A2A] Discovered agent via /.well-known/agent.json at #{base_url}")
          {:ok, body}

        _ ->
          # Fall back to legacy agent-card endpoint
          case Req.get(legacy_url, opts) do
            {:ok, %{status: 200, body: body}} ->
              Logger.info("[A2A] Discovered agent via legacy agent-card at #{base_url}")
              {:ok, body}

            {:ok, %{status: status, body: body}} ->
              {:error, "Agent discovery failed: HTTP #{status} — #{inspect(body)}"}

            {:error, reason} ->
              {:error, "Agent discovery failed: #{inspect(reason)}"}
          end
      end

    duration = System.monotonic_time(:microsecond) - start_time
    status_atom = if match?({:ok, _}, result), do: :ok, else: :error

    :telemetry.execute(
      [:osa, :a2a, :agent_call],
      %{duration: duration},
      %{action: :discover, agent_url: agent_url, status: status_atom}
    )

    result
  end

  defp call_agent(agent_url, message) when is_binary(message) and message != "" do
    start_time = System.monotonic_time(:microsecond)
    url = normalize_url(agent_url)

    # Step 3: Build request with W3C traceparent header
    opts = OptimalSystemAgent.Observability.Traceparent.add_to_request([
      json: %{message: message},
      receive_timeout: @agent_call_timeout
    ])

    case Req.post(url, opts) do
      {:ok, %{status: 200, body: body}} ->
        duration = System.monotonic_time(:microsecond) - start_time
        Logger.info("[A2A] Called agent at #{url}")

        :telemetry.execute(
          [:osa, :a2a, :agent_call],
          %{duration: duration},
          %{action: :call, agent_url: agent_url, status: :ok}
        )

        {:ok, body}

      {:ok, %{status: status, body: body}} ->
        duration = System.monotonic_time(:microsecond) - start_time

        :telemetry.execute(
          [:osa, :a2a, :agent_call],
          %{duration: duration},
          %{action: :call, agent_url: agent_url, status: :error, http_status: status}
        )

        {:error, "Agent call failed: HTTP #{status} — #{inspect(body)}"}

      {:error, reason} ->
        duration = System.monotonic_time(:microsecond) - start_time

        :telemetry.execute(
          [:osa, :a2a, :agent_call],
          %{duration: duration},
          %{action: :call, agent_url: agent_url, status: :error, reason: :connection_failed}
        )

        {:error, "Agent call failed: #{inspect(reason)}"}
    end
  end

  defp call_agent(_, _), do: {:error, "Message must be a non-empty string"}

  defp list_tools(agent_url) do
    start_time = System.monotonic_time(:microsecond)
    url = normalize_url(agent_url <> "/tools")

    # Step 3: Build request with W3C traceparent header
    opts = OptimalSystemAgent.Observability.Traceparent.add_to_request([
      receive_timeout: @default_timeout
    ])

    case Req.get(url, opts) do
      {:ok, %{status: 200, body: body}} ->
        duration = System.monotonic_time(:microsecond) - start_time
        tools = Map.get(body, "tools", [])
        Logger.info("[A2A] Listed #{length(tools)} tools from #{agent_url}")

        :telemetry.execute(
          [:osa, :a2a, :agent_call],
          %{duration: duration},
          %{action: :list_tools, agent_url: agent_url, status: :ok, tool_count: length(tools)}
        )

        {:ok, tools}

      {:ok, %{status: status, body: body}} ->
        duration = System.monotonic_time(:microsecond) - start_time

        :telemetry.execute(
          [:osa, :a2a, :agent_call],
          %{duration: duration},
          %{action: :list_tools, agent_url: agent_url, status: :error, http_status: status}
        )

        {:error, "Tool listing failed: HTTP #{status} — #{inspect(body)}"}

      {:error, reason} ->
        duration = System.monotonic_time(:microsecond) - start_time

        :telemetry.execute(
          [:osa, :a2a, :agent_call],
          %{duration: duration},
          %{action: :list_tools, agent_url: agent_url, status: :error, reason: :connection_failed}
        )

        {:error, "Tool listing failed: #{inspect(reason)}"}
    end
  end

  defp execute_tool(agent_url, tool_name, arguments) do
    start_time = System.monotonic_time(:microsecond)
    url = normalize_url(agent_url <> "/tools/#{URI.encode(tool_name)}")

    # Step 3: Build request with W3C traceparent header
    opts = OptimalSystemAgent.Observability.Traceparent.add_to_request([
      json: arguments,
      receive_timeout: @default_timeout
    ])

    case Req.post(url, opts) do
      {:ok, %{status: 200, body: body}} ->
        duration = System.monotonic_time(:microsecond) - start_time
        Logger.info("[A2A] Executed tool #{tool_name} on #{agent_url}")

        :telemetry.execute(
          [:osa, :a2a, :tool_call],
          %{duration: duration},
          %{agent_url: agent_url, tool_name: tool_name, status: :ok}
        )

        {:ok, body}

      {:ok, %{status: status, body: body}} ->
        duration = System.monotonic_time(:microsecond) - start_time

        :telemetry.execute(
          [:osa, :a2a, :tool_call],
          %{duration: duration},
          %{agent_url: agent_url, tool_name: tool_name, status: :error, http_status: status}
        )

        {:error, "Tool execution failed: HTTP #{status} — #{inspect(body)}"}

      {:error, reason} ->
        duration = System.monotonic_time(:microsecond) - start_time

        :telemetry.execute(
          [:osa, :a2a, :tool_call],
          %{duration: duration},
          %{agent_url: agent_url, tool_name: tool_name, status: :error, reason: :connection_failed}
        )

        {:error, "Tool execution failed: #{inspect(reason)}"}
    end
  end

  # ── Private ──────────────────────────────────────────────────────

  defp normalize_url(url) do
    url = String.trim_trailing(url, "/")

    unless String.starts_with?(url, "http://") or String.starts_with?(url, "https://") do
      "http://#{url}"
    else
      url
    end
  end

  defp do_tasks_send(base_url, tool, args, opts) do
    endpoint =
      if String.ends_with?(base_url, "/a2a"),
        do: base_url,
        else: String.trim_trailing(base_url, "/") <> "/a2a"

    task_id =
      Map.get(opts, "task_id") ||
        (:crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower))

    timeout_ms = Map.get(opts, "timeout_ms", 65_000)

    payload = %{
      "jsonrpc" => "2.0",
      "id" => :erlang.unique_integer([:positive]),
      "method" => "tasks/send",
      "params" => %{
        "id" => task_id,
        "message" => %{
          "role" => "user",
          "parts" => [%{
            "type" => "data",
            "data" => %{"tool" => tool, "args" => args}
          }]
        }
      }
    }

    Logger.debug("[A2ACall] tasks_send → #{endpoint} tool=#{tool}")

    try do
      case Req.post(endpoint, json: payload, receive_timeout: timeout_ms) do
        {:ok, %Req.Response{status: 200, body: %{"result" => result}}} ->
          {:ok, result}

        {:ok, %Req.Response{status: 200, body: %{"error" => error}}} ->
          {:error, {:a2a_error, error}}

        {:ok, %Req.Response{status: status, body: body}} ->
          {:error, {:http_error, status, body}}

        {:error, %Req.TransportError{reason: reason}} ->
          {:error, {:connection_failed, inspect(reason)}}

        {:error, reason} ->
          {:error, {:connection_failed, inspect(reason)}}
      end
    rescue
      e -> {:error, {:connection_failed, Exception.message(e)}}
    end
  end
end
