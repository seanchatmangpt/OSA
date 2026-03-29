defmodule OptimalSystemAgent.MCP.Native.RequestHandler do
  @moduledoc """
  Pure-functional JSON-RPC 2.0 handler for the native MCP server.

  Handles the MCP protocol lifecycle:
  - `initialize`             — capability exchange handshake
  - `notifications/initialized` — client confirmation (notification, no reply)
  - `tools/list`             — return all tools from OptimalSystemAgent.Tools.Registry
  - `tools/call`             — execute a tool with 30s Task.await timeout

  All functions are pure (no GenServer state) — sessionless by design.
  Error codes follow the MCP 2024-11-05 specification:
    -32600 Invalid Request
    -32601 Method Not Found
    -32602 Invalid Params
    -32001 Tool Execution Error
  """
  require Logger

  alias OptimalSystemAgent.Tools.Registry, as: Tools

  @protocol_version "2024-11-05"
  @server_name "osa"
  @tool_timeout_ms 30_000

  # MCP JSON-RPC error codes
  @err_invalid_request -32_600
  @err_method_not_found -32_601
  @err_invalid_params -32_602
  @err_tool_error -32_001

  # ── Public API ────────────────────────────────────────────────────────

  @doc """
  Handle a decoded JSON-RPC request map. Returns a response map or nil
  (for notifications that require no reply).
  """
  @spec handle(map()) :: map() | nil
  def handle(%{"jsonrpc" => "2.0", "method" => method, "id" => id} = req) do
    params = Map.get(req, "params", %{})
    dispatch(method, id, params)
  end

  # Notification: no id — handle but return nil
  def handle(%{"jsonrpc" => "2.0", "method" => method} = req) do
    params = Map.get(req, "params", %{})
    handle_notification(method, params)
    nil
  end

  def handle(_invalid) do
    error_response(nil, @err_invalid_request, "Invalid JSON-RPC 2.0 request")
  end

  # ── Method dispatch ───────────────────────────────────────────────────

  defp dispatch("initialize", id, params) do
    client_version = get_in(params, ["protocolVersion"]) || "unknown"

    Logger.debug("[MCP.Native] initialize from client version=#{client_version}")

    success_response(id, %{
      protocolVersion: @protocol_version,
      capabilities: %{
        tools: %{listChanged: false}
      },
      serverInfo: %{
        name: @server_name,
        version: osa_version()
      }
    })
  end

  defp dispatch("tools/list", id, _params) do
    tools =
      Tools.list_tools_direct()
      |> Enum.map(fn tool ->
        %{
          name: tool.name,
          description: tool.description,
          inputSchema: tool.parameters || %{type: "object", properties: %{}}
        }
      end)

    success_response(id, %{tools: tools})
  end

  defp dispatch("tools/call", id, params) do
    tool_name = Map.get(params, "name")
    arguments = Map.get(params, "arguments") || %{}

    if is_nil(tool_name) || tool_name == "" do
      error_response(id, @err_invalid_params, "tools/call requires 'name' param")
    else
      execute_tool(id, tool_name, arguments)
    end
  end

  defp dispatch(method, id, _params) do
    Logger.debug("[MCP.Native] unknown method: #{method}")
    error_response(id, @err_method_not_found, "Method not found: #{method}")
  end

  # ── Tool execution ────────────────────────────────────────────────────

  defp execute_tool(id, tool_name, arguments) do
    task = Task.async(fn -> Tools.execute(tool_name, arguments) end)

    case Task.yield(task, @tool_timeout_ms) || Task.shutdown(task) do
      {:ok, {:ok, result}} ->
        content = [%{type: "text", text: format_result(result)}]
        success_response(id, %{content: content})

      {:ok, {:error, reason}} ->
        error_response(id, @err_tool_error, "Tool error: #{inspect(reason)}")

      nil ->
        error_response(id, @err_tool_error, "Tool #{tool_name} timed out after #{@tool_timeout_ms}ms")
    end
  end

  defp format_result(result) when is_binary(result), do: result
  defp format_result(result), do: inspect(result)

  # ── Notification handling (no response) ──────────────────────────────

  defp handle_notification("notifications/initialized", _params) do
    Logger.debug("[MCP.Native] client initialized")
    :ok
  end

  defp handle_notification(method, _params) do
    Logger.debug("[MCP.Native] unhandled notification: #{method}")
    :ok
  end

  # ── Response builders ─────────────────────────────────────────────────

  defp success_response(id, result) do
    %{jsonrpc: "2.0", id: id, result: result}
  end

  defp error_response(id, code, message) do
    %{jsonrpc: "2.0", id: id, error: %{code: code, message: message}}
  end

  # ── Helpers ───────────────────────────────────────────────────────────

  defp osa_version do
    case Application.spec(:optimal_system_agent, :vsn) do
      nil -> "0.2.5"
      vsn -> to_string(vsn)
    end
  end
end
