defmodule OpenTelemetry.SemConv.Incubating.McpAttributes do
  @moduledoc """
  Mcp semantic convention attributes.

  This module is generated from the ChatmanGPT semantic convention registry.
  Do not edit manually — regenerate with `weaver registry generate elixir`.
  """

  @doc """
  Transport protocol used for MCP communication.

  Stability: `development`
  """
  @spec mcp_protocol() :: :"mcp.protocol"
  def mcp_protocol, do: :"mcp.protocol"

  @doc """
  Values for `mcp.protocol`.
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

  @doc """
  Name of the MCP server hosting the tool.

  Stability: `development`
  """
  @spec mcp_server_name() :: :"mcp.server.name"
  def mcp_server_name, do: :"mcp.server.name"

  @doc """
  Name of the MCP tool being invoked.

  Stability: `development`
  """
  @spec mcp_tool_name() :: :"mcp.tool.name"
  def mcp_tool_name, do: :"mcp.tool.name"

  @doc """
  Number of results returned by the MCP tool.

  Stability: `development`
  """
  @spec mcp_tool_result_count() :: :"mcp.tool.result_count"
  def mcp_tool_result_count, do: :"mcp.tool.result_count"
end