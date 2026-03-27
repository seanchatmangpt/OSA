defmodule OptimalSystemAgent.Tools.Builtins.A2ACall do
  @moduledoc """
  A2A (Agent-to-Agent) protocol tool.

  Allows OSA agents to discover and communicate with other A2A-compliant
  agents (BusinessOS, Canopy, external agents) via the A2A protocol.

  Uses JSON-RPC 2.0 over HTTP for task creation and tool execution.
  """

  @behaviour OptimalSystemAgent.Tools.Behaviour

  require Logger

  @default_timeout 30_000

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
    - OSA (self): http://localhost:9089/api/v1/a2a/agent-card
    """
  end

  @impl true
  def parameters do
    %{
      "type" => "object",
      "properties" => %{
        "action" => %{
          "type" => "string",
          "enum" => ["discover", "call", "list_tools", "execute_tool"],
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
        }
      },
      "required" => ["action", "agent_url"]
    }
  end

  @impl true
  def execute(%{"action" => action, "agent_url" => agent_url} = params) do
    case action do
      "discover" -> discover_agent(agent_url)
      "call" -> call_agent(agent_url, params["message"] || "")
      "list_tools" -> list_tools(agent_url)
      "execute_tool" -> execute_tool(agent_url, params["tool_name"], params["arguments"] || %{})
      _ -> {:error, "Unknown action: #{action}. Use: discover, call, list_tools, execute_tool"}
    end
  end

  def execute(_), do: {:error, "Missing required parameters: action, agent_url"}

  # ── Actions ──────────────────────────────────────────────────────

  defp discover_agent(agent_url) do
    start_time = System.monotonic_time(:microsecond)
    url = normalize_url(agent_url)

    # Step 3: Build request with W3C traceparent header
    opts = OptimalSystemAgent.Observability.Traceparent.add_to_request([
      receive_timeout: @default_timeout
    ])

    case Req.get(url, opts) do
      {:ok, %{status: 200, body: body}} ->
        duration = System.monotonic_time(:microsecond) - start_time
        Logger.info("[A2A] Discovered agent at #{url}")

        :telemetry.execute(
          [:osa, :a2a, :agent_call],
          %{duration: duration},
          %{action: :discover, agent_url: agent_url, status: :ok}
        )

        {:ok, body}

      {:ok, %{status: status, body: body}} ->
        duration = System.monotonic_time(:microsecond) - start_time

        :telemetry.execute(
          [:osa, :a2a, :agent_call],
          %{duration: duration},
          %{action: :discover, agent_url: agent_url, status: :error, http_status: status}
        )

        {:error, "Agent discovery failed: HTTP #{status} — #{inspect(body)}"}

      {:error, reason} ->
        duration = System.monotonic_time(:microsecond) - start_time

        :telemetry.execute(
          [:osa, :a2a, :agent_call],
          %{duration: duration},
          %{action: :discover, agent_url: agent_url, status: :error, reason: :connection_failed}
        )

        {:error, "Agent discovery failed: #{inspect(reason)}"}
    end
  end

  defp call_agent(agent_url, message) when is_binary(message) and message != "" do
    start_time = System.monotonic_time(:microsecond)
    url = normalize_url(agent_url)

    # Step 3: Build request with W3C traceparent header
    opts = OptimalSystemAgent.Observability.Traceparent.add_to_request([
      json: %{message: message},
      receive_timeout: 60_000
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
end
