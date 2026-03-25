defmodule OpenTelemetry.SemConv.Incubating.McpAttributes do
  @moduledoc """
  Mcp semantic convention attributes.

  Namespace: `mcp`

  This module is generated from the ChatmanGPT semantic convention registry.
  Do not edit manually — regenerate with:

      weaver registry generate -r ./semconv/model --templates ./semconv/templates elixir ./OSA/lib/osa/semconv/
  """

  @doc """
  Transport protocol used for MCP communication.

  Attribute: `mcp.protocol`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `stdio`, `http`
  """
  @spec mcp_protocol() :: :"mcp.protocol"
  def mcp_protocol, do: :"mcp.protocol"

  @doc """
  Enumerated values for `mcp.protocol`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `stdio` | `"stdio"` | stdio |
  | `http` | `"http"` | http |
  | `sse` | `"sse"` | sse |
  """
  @spec mcp_protocol_values() :: %{
    stdio: :stdio,
    http: :http,
    sse: :sse
  }
  def mcp_protocol_values do
    %{
      stdio: :stdio,
      http: :http,
      sse: :sse
    }
  end

  defmodule McpProtocolValues do
    @moduledoc """
    Typed constants for the `mcp.protocol` attribute.
    """

    @doc "stdio"
    @spec stdio() :: :stdio
    def stdio, do: :stdio

    @doc "http"
    @spec http() :: :http
    def http, do: :http

    @doc "sse"
    @spec sse() :: :sse
    def sse, do: :sse

  end

  @doc """
  Name of the MCP server hosting the tool.

  Attribute: `mcp.server.name`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `osa-mcp-server`, `businessos-mcp`
  """
  @spec mcp_server_name() :: :"mcp.server.name"
  def mcp_server_name, do: :"mcp.server.name"

  @doc """
  Name of the MCP tool being invoked.

  Attribute: `mcp.tool.name`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `search`, `code_execute`, `file_read`, `a2a_call`
  """
  @spec mcp_tool_name() :: :"mcp.tool.name"
  def mcp_tool_name, do: :"mcp.tool.name"

  @doc """
  Number of results returned by the MCP tool.

  Attribute: `mcp.tool.result_count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0`, `1`, `5`
  """
  @spec mcp_tool_result_count() :: :"mcp.tool.result_count"
  def mcp_tool_result_count, do: :"mcp.tool.result_count"

  @doc """
  Size in bytes of the MCP tool input payload.

  Attribute: `mcp.tool.input_size`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `128`, `1024`, `65536`
  """
  @spec mcp_tool_input_size() :: :"mcp.tool.input_size"
  def mcp_tool_input_size, do: :"mcp.tool.input_size"

  @doc """
  Size in bytes of the MCP tool output payload.

  Attribute: `mcp.tool.output_size`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `256`, `2048`, `131072`
  """
  @spec mcp_tool_output_size() :: :"mcp.tool.output_size"
  def mcp_tool_output_size, do: :"mcp.tool.output_size"

  @doc """
  Number of retries attempted for this MCP tool invocation.

  Attribute: `mcp.tool.retry_count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0`, `1`, `3`
  """
  @spec mcp_tool_retry_count() :: :"mcp.tool.retry_count"
  def mcp_tool_retry_count, do: :"mcp.tool.retry_count"

  @doc """
  Timeout in milliseconds for this MCP tool invocation.

  Attribute: `mcp.tool.timeout_ms`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `1000`, `5000`, `30000`
  """
  @spec mcp_tool_timeout_ms() :: :"mcp.tool.timeout_ms"
  def mcp_tool_timeout_ms, do: :"mcp.tool.timeout_ms"

end