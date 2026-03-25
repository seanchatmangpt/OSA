defmodule OpenTelemetry.SemConv.Incubating.McpSpanNames do
  @moduledoc """
  Mcp semantic convention span names.

  Namespace: `mcp`

  This module is generated from the ChatmanGPT semantic convention registry.
  Do not edit manually — regenerate with:

      weaver registry generate -r ./semconv/model --templates ./semconv/templates elixir ./OSA/lib/osa/semconv/
  """

  @doc """
  An MCP tool invocation — request from an agent to execute a named tool via MCP protocol.

  Span: `span.mcp.call`
  Kind: `client`
  Stability: `development`
  """
  @spec mcp_call() :: String.t()
  def mcp_call, do: "mcp.call"

  @doc """
  MCP client-server connection establishment — transport negotiation and capability exchange.

  Span: `span.mcp.connection.establish`
  Kind: `client`
  Stability: `development`
  """
  @spec mcp_connection_establish() :: String.t()
  def mcp_connection_establish, do: "mcp.connection.establish"

  @doc """
  Acquiring a connection from the MCP connection pool for use in a client-server interaction.

  Span: `span.mcp.connection.pool.acquire`
  Kind: `internal`
  Stability: `development`
  """
  @spec mcp_connection_pool_acquire() :: String.t()
  def mcp_connection_pool_acquire, do: "mcp.connection.pool.acquire"

  @doc """
  MCP tool discovery — listing available tools from a connected server.

  Span: `span.mcp.registry.discover`
  Kind: `client`
  Stability: `development`
  """
  @spec mcp_registry_discover() :: String.t()
  def mcp_registry_discover, do: "mcp.registry.discover"

  @doc """
  Reading an MCP resource — fetching content from a resource URI exposed by an MCP server.

  Span: `span.mcp.resource.read`
  Kind: `client`
  Stability: `development`
  """
  @spec mcp_resource_read() :: String.t()
  def mcp_resource_read, do: "mcp.resource.read"

  @doc """
  Health check of an MCP server — verifying tool availability and server responsiveness.

  Span: `span.mcp.server.health_check`
  Kind: `internal`
  Stability: `development`
  """
  @spec mcp_server_health_check() :: String.t()
  def mcp_server_health_check, do: "mcp.server.health_check"

  @doc """
  Collecting aggregated metrics from an MCP server instance.

  Span: `span.mcp.server.metrics.collect`
  Kind: `internal`
  Stability: `development`
  """
  @spec mcp_server_metrics_collect() :: String.t()
  def mcp_server_metrics_collect, do: "mcp.server.metrics.collect"

  @doc """
  MCP tool analytics recording — capturing tool usage statistics for performance monitoring and capacity planning.

  Span: `span.mcp.tool.analytics.record`
  Kind: `internal`
  Stability: `development`
  """
  @spec mcp_tool_analytics_record() :: String.t()
  def mcp_tool_analytics_record, do: "mcp.tool.analytics.record"

  @doc """
  MCP tool cache lookup — checking response cache before executing tool.

  Span: `span.mcp.tool.cache.lookup`
  Kind: `internal`
  Stability: `development`
  """
  @spec mcp_tool_cache_lookup() :: String.t()
  def mcp_tool_cache_lookup, do: "mcp.tool.cache.lookup"

  @doc """
  Composition of multiple MCP tools into a chain — sequential, parallel, or fallback execution.

  Span: `span.mcp.tool.compose`
  Kind: `internal`
  Stability: `development`
  """
  @spec mcp_tool_compose() :: String.t()
  def mcp_tool_compose, do: "mcp.tool.compose"

  @doc """
  MCP tool deprecation lifecycle event — marking a tool as deprecated and scheduling its removal.

  Span: `span.mcp.tool.deprecate`
  Kind: `internal`
  Stability: `development`
  """
  @spec mcp_tool_deprecate() :: String.t()
  def mcp_tool_deprecate, do: "mcp.tool.deprecate"

  @doc """
  A retry attempt for a previously failed MCP tool execution.

  Span: `span.mcp.tool.retry`
  Kind: `client`
  Stability: `development`
  """
  @spec mcp_tool_retry() :: String.t()
  def mcp_tool_retry, do: "mcp.tool.retry"

  @doc """
  MCP tool execution timed out — tool did not respond within the configured budget.

  Span: `span.mcp.tool.timeout`
  Kind: `client`
  Stability: `development`
  """
  @spec mcp_tool_timeout() :: String.t()
  def mcp_tool_timeout, do: "mcp.tool.timeout"

  @doc """
  Validating MCP tool input/output schema before execution.

  Span: `span.mcp.tool.validate`
  Kind: `internal`
  Stability: `development`
  """
  @spec mcp_tool_validate() :: String.t()
  def mcp_tool_validate, do: "mcp.tool.validate"

  @doc """
  Version compatibility check for an MCP tool — validates client version against server tool version.

  Span: `span.mcp.tool.version_check`
  Kind: `internal`
  Stability: `development`
  """
  @spec mcp_tool_version_check() :: String.t()
  def mcp_tool_version_check, do: "mcp.tool.version_check"

  @doc """
  Server-side execution of an MCP tool — the handler running the tool logic.

  Span: `span.mcp.tool_execute`
  Kind: `server`
  Stability: `development`
  """
  @spec mcp_tool_execute() :: String.t()
  def mcp_tool_execute, do: "mcp.tool_execute"

  @doc """
  Establishment of an MCP transport connection — initial handshake and protocol negotiation.

  Span: `span.mcp.transport.connect`
  Kind: `client`
  Stability: `development`
  """
  @spec mcp_transport_connect() :: String.t()
  def mcp_transport_connect, do: "mcp.transport.connect"

  @doc """
  All span names in this namespace.
  """
  @spec all() :: [String.t()]
  def all do
    [
      mcp_call(),
      mcp_connection_establish(),
      mcp_connection_pool_acquire(),
      mcp_registry_discover(),
      mcp_resource_read(),
      mcp_server_health_check(),
      mcp_server_metrics_collect(),
      mcp_tool_analytics_record(),
      mcp_tool_cache_lookup(),
      mcp_tool_compose(),
      mcp_tool_deprecate(),
      mcp_tool_retry(),
      mcp_tool_timeout(),
      mcp_tool_validate(),
      mcp_tool_version_check(),
      mcp_tool_execute(),
      mcp_transport_connect()
    ]
  end
end