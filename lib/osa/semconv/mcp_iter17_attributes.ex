defmodule OpenTelemetry.SemConv.MCPIter17Attributes do
  @moduledoc "Wave 9 Iteration 17: MCP Tool Versioning attributes."
  def mcp_tool_version, do: :"mcp.tool.version"
  def mcp_tool_schema_hash, do: :"mcp.tool.schema_hash"
  def mcp_tool_deprecated, do: :"mcp.tool.deprecated"
  def mcp_tool_deprecation_reason, do: :"mcp.tool.deprecation.reason"
end
