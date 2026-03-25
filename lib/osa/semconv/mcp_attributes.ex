defmodule OpenTelemetry.SemConv.Incubating.McpAttributes do
  @moduledoc """
  Mcp semantic convention attributes.

  Namespace: `mcp`

  This module is generated from the ChatmanGPT semantic convention registry.
  Do not edit manually — regenerate with:

      weaver registry generate -r ./semconv/model --templates ./semconv/templates elixir ./OSA/lib/osa/semconv/
  """

  @doc """
  Unique identifier for this MCP client-server connection.

  Attribute: `mcp.connection.id`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `conn-abc123`, `mcp-conn-001`
  """
  @spec mcp_connection_id() :: :"mcp.connection.id"
  def mcp_connection_id, do: :"mcp.connection.id"

  @doc """
  Number of currently active connections in the pool.

  Attribute: `mcp.connection.pool.active_count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0`, `3`, `10`
  """
  @spec mcp_connection_pool_active_count() :: :"mcp.connection.pool.active_count"
  def mcp_connection_pool_active_count, do: :"mcp.connection.pool.active_count"

  @doc """
  Number of idle connections available in the pool.

  Attribute: `mcp.connection.pool.idle_count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0`, `2`, `5`
  """
  @spec mcp_connection_pool_idle_count() :: :"mcp.connection.pool.idle_count"
  def mcp_connection_pool_idle_count, do: :"mcp.connection.pool.idle_count"

  @doc """
  Total size (max connections) of the MCP connection pool.

  Attribute: `mcp.connection.pool.size`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `5`, `10`, `50`
  """
  @spec mcp_connection_pool_size() :: :"mcp.connection.pool.size"
  def mcp_connection_pool_size, do: :"mcp.connection.pool.size"

  @doc """
  Time in milliseconds the request waited to acquire a connection.

  Attribute: `mcp.connection.pool.wait_ms`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0.0`, `50.5`, `500.0`
  """
  @spec mcp_connection_pool_wait_ms() :: :"mcp.connection.pool.wait_ms"
  def mcp_connection_pool_wait_ms, do: :"mcp.connection.pool.wait_ms"

  @doc """
  Transport protocol used for this MCP connection.

  Attribute: `mcp.connection.transport`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `stdio`, `http`
  """
  @spec mcp_connection_transport() :: :"mcp.connection.transport"
  def mcp_connection_transport, do: :"mcp.connection.transport"

  @doc """
  Enumerated values for `mcp.connection.transport`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `stdio` | `"stdio"` | stdio |
  | `http` | `"http"` | http |
  | `sse` | `"sse"` | sse |
  """
  @spec mcp_connection_transport_values() :: %{
    stdio: :stdio,
    http: :http,
    sse: :sse
  }
  def mcp_connection_transport_values do
    %{
      stdio: :stdio,
      http: :http,
      sse: :sse
    }
  end

  defmodule McpConnectionTransportValues do
    @moduledoc """
    Typed constants for the `mcp.connection.transport` attribute.
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
  MCP protocol version negotiated for this connection.

  Attribute: `mcp.protocol.version`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `2024-11-05`, `2025-03-26`
  """
  @spec mcp_protocol_version() :: :"mcp.protocol.version"
  def mcp_protocol_version, do: :"mcp.protocol.version"

  @doc """
  Number of active MCP servers in the registry.

  Attribute: `mcp.registry.server_count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `1`, `3`, `10`
  """
  @spec mcp_registry_server_count() :: :"mcp.registry.server_count"
  def mcp_registry_server_count, do: :"mcp.registry.server_count"

  @doc """
  Number of tools registered with this MCP server.

  Attribute: `mcp.registry.tool_count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `5`, `20`, `100`
  """
  @spec mcp_registry_tool_count() :: :"mcp.registry.tool_count"
  def mcp_registry_tool_count, do: :"mcp.registry.tool_count"

  @doc """
  MIME type of the MCP resource content.

  Attribute: `mcp.resource.mime_type`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `application/json`, `text/plain`, `text/yaml`
  """
  @spec mcp_resource_mime_type() :: :"mcp.resource.mime_type"
  def mcp_resource_mime_type, do: :"mcp.resource.mime_type"

  @doc """
  Size of the MCP resource content in bytes.

  Attribute: `mcp.resource.size_bytes`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `256`, `4096`, `65536`
  """
  @spec mcp_resource_size_bytes() :: :"mcp.resource.size_bytes"
  def mcp_resource_size_bytes, do: :"mcp.resource.size_bytes"

  @doc """
  URI identifying the MCP resource being accessed.

  Attribute: `mcp.resource.uri`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `file:///etc/config.yaml`, `db://users/42`, `s3://bucket/key`
  """
  @spec mcp_resource_uri() :: :"mcp.resource.uri"
  def mcp_resource_uri, do: :"mcp.resource.uri"

  @doc """
  Duration of the health check in milliseconds.

  Attribute: `mcp.server.health.check_duration_ms`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `5`, `50`, `500`
  """
  @spec mcp_server_health_check_duration_ms() :: :"mcp.server.health.check_duration_ms"
  def mcp_server_health_check_duration_ms, do: :"mcp.server.health.check_duration_ms"

  @doc """
  Health status of the MCP server.

  Attribute: `mcp.server.health.status`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `healthy`, `degraded`
  """
  @spec mcp_server_health_status() :: :"mcp.server.health.status"
  def mcp_server_health_status, do: :"mcp.server.health.status"

  @doc """
  Enumerated values for `mcp.server.health.status`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `healthy` | `"healthy"` | healthy |
  | `degraded` | `"degraded"` | degraded |
  | `unhealthy` | `"unhealthy"` | unhealthy |
  | `unknown` | `"unknown"` | unknown |
  """
  @spec mcp_server_health_status_values() :: %{
    healthy: :healthy,
    degraded: :degraded,
    unhealthy: :unhealthy,
    unknown: :unknown
  }
  def mcp_server_health_status_values do
    %{
      healthy: :healthy,
      degraded: :degraded,
      unhealthy: :unhealthy,
      unknown: :unknown
    }
  end

  defmodule McpServerHealthStatusValues do
    @moduledoc """
    Typed constants for the `mcp.server.health.status` attribute.
    """

    @doc "healthy"
    @spec healthy() :: :healthy
    def healthy, do: :healthy

    @doc "degraded"
    @spec degraded() :: :degraded
    def degraded, do: :degraded

    @doc "unhealthy"
    @spec unhealthy() :: :unhealthy
    def unhealthy, do: :unhealthy

    @doc "unknown"
    @spec unknown() :: :unknown
    def unknown, do: :unknown

  end

  @doc """
  Number of tools registered on the MCP server.

  Attribute: `mcp.server.health.tool_count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `5`, `12`, `30`
  """
  @spec mcp_server_health_tool_count() :: :"mcp.server.health.tool_count"
  def mcp_server_health_tool_count, do: :"mcp.server.health.tool_count"

  @doc """
  Uptime of the MCP server in milliseconds.

  Attribute: `mcp.server.health.uptime_ms`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `60000`, `3600000`
  """
  @spec mcp_server_health_uptime_ms() :: :"mcp.server.health.uptime_ms"
  def mcp_server_health_uptime_ms, do: :"mcp.server.health.uptime_ms"

  @doc """
  Error rate of the MCP server as a fraction [0.0, 1.0].

  Attribute: `mcp.server.metrics.error_rate`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0.0`, `0.05`, `0.25`
  """
  @spec mcp_server_metrics_error_rate() :: :"mcp.server.metrics.error_rate"
  def mcp_server_metrics_error_rate, do: :"mcp.server.metrics.error_rate"

  @doc """
  99th percentile latency in milliseconds for MCP server request handling.

  Attribute: `mcp.server.metrics.p99_latency_ms`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `45.0`, `120.5`, `500.0`
  """
  @spec mcp_server_metrics_p99_latency_ms() :: :"mcp.server.metrics.p99_latency_ms"
  def mcp_server_metrics_p99_latency_ms, do: :"mcp.server.metrics.p99_latency_ms"

  @doc """
  Total number of requests received by the MCP server.

  Attribute: `mcp.server.metrics.request_count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0`, `100`, `5000`
  """
  @spec mcp_server_metrics_request_count() :: :"mcp.server.metrics.request_count"
  def mcp_server_metrics_request_count, do: :"mcp.server.metrics.request_count"

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
  Session identifier for the MCP client-server connection.

  Attribute: `mcp.session.id`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `sess-001`, `mcp-session-abc123`
  """
  @spec mcp_session_id() :: :"mcp.session.id"
  def mcp_session_id, do: :"mcp.session.id"

  @doc """
  Average latency (ms) for MCP tool invocations in the reporting window.

  Attribute: `mcp.tool.analytics.avg_latency_ms`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `10.5`, `250.0`, `1500.0`
  """
  @spec mcp_tool_analytics_avg_latency_ms() :: :"mcp.tool.analytics.avg_latency_ms"
  def mcp_tool_analytics_avg_latency_ms, do: :"mcp.tool.analytics.avg_latency_ms"

  @doc """
  Total number of calls made to this MCP tool in the current reporting window.

  Attribute: `mcp.tool.analytics.call_count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `1`, `10`, `100`
  """
  @spec mcp_tool_analytics_call_count() :: :"mcp.tool.analytics.call_count"
  def mcp_tool_analytics_call_count, do: :"mcp.tool.analytics.call_count"

  @doc """
  Error rate for MCP tool invocations in the reporting window, range [0.0, 1.0].

  Attribute: `mcp.tool.analytics.error_rate`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0.0`, `0.05`, `0.2`
  """
  @spec mcp_tool_analytics_error_rate() :: :"mcp.tool.analytics.error_rate"
  def mcp_tool_analytics_error_rate, do: :"mcp.tool.analytics.error_rate"

  @doc """
  Whether the tool response was served from cache.

  Attribute: `mcp.tool.cache.hit`
  Type: `boolean`
  Stability: `development`
  Requirement: `recommended`
  Examples: `true`, `false`
  """
  @spec mcp_tool_cache_hit() :: :"mcp.tool.cache.hit"
  def mcp_tool_cache_hit, do: :"mcp.tool.cache.hit"

  @doc """
  Cache key used for tool response lookup.

  Attribute: `mcp.tool.cache.key`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `mcp:fs:read:/etc/hosts`, `mcp:weather:current:LA`
  """
  @spec mcp_tool_cache_key() :: :"mcp.tool.cache.key"
  def mcp_tool_cache_key, do: :"mcp.tool.cache.key"

  @doc """
  Cache time-to-live in milliseconds.

  Attribute: `mcp.tool.cache.ttl_ms`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `60000`, `300000`
  """
  @spec mcp_tool_cache_ttl_ms() :: :"mcp.tool.cache.ttl_ms"
  def mcp_tool_cache_ttl_ms, do: :"mcp.tool.cache.ttl_ms"

  @doc """
  Number of steps completed successfully in the composition chain.

  Attribute: `mcp.tool.composition.completed_steps`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `2`, `5`
  """
  @spec mcp_tool_composition_completed_steps() :: :"mcp.tool.composition.completed_steps"
  def mcp_tool_composition_completed_steps, do: :"mcp.tool.composition.completed_steps"

  @doc """
  Number of tool steps in the composition chain.

  Attribute: `mcp.tool.composition.step_count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `3`, `5`, `10`
  """
  @spec mcp_tool_composition_step_count() :: :"mcp.tool.composition.step_count"
  def mcp_tool_composition_step_count, do: :"mcp.tool.composition.step_count"

  @doc """
  The composition strategy for chaining multiple MCP tools together.

  Attribute: `mcp.tool.composition.strategy`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `sequential`, `parallel`
  """
  @spec mcp_tool_composition_strategy() :: :"mcp.tool.composition.strategy"
  def mcp_tool_composition_strategy, do: :"mcp.tool.composition.strategy"

  @doc """
  Enumerated values for `mcp.tool.composition.strategy`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `sequential` | `"sequential"` | sequential |
  | `parallel` | `"parallel"` | parallel |
  | `fallback` | `"fallback"` | fallback |
  | `pipeline` | `"pipeline"` | pipeline |
  """
  @spec mcp_tool_composition_strategy_values() :: %{
    sequential: :sequential,
    parallel: :parallel,
    fallback: :fallback,
    pipeline: :pipeline
  }
  def mcp_tool_composition_strategy_values do
    %{
      sequential: :sequential,
      parallel: :parallel,
      fallback: :fallback,
      pipeline: :pipeline
    }
  end

  defmodule McpToolCompositionStrategyValues do
    @moduledoc """
    Typed constants for the `mcp.tool.composition.strategy` attribute.
    """

    @doc "sequential"
    @spec sequential() :: :sequential
    def sequential, do: :sequential

    @doc "parallel"
    @spec parallel() :: :parallel
    def parallel, do: :parallel

    @doc "fallback"
    @spec fallback() :: :fallback
    def fallback, do: :fallback

    @doc "pipeline"
    @spec pipeline() :: :pipeline
    def pipeline, do: :pipeline

  end

  @doc """
  Total timeout for the entire composition chain in milliseconds.

  Attribute: `mcp.tool.composition.timeout_ms`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `5000`, `30000`
  """
  @spec mcp_tool_composition_timeout_ms() :: :"mcp.tool.composition.timeout_ms"
  def mcp_tool_composition_timeout_ms, do: :"mcp.tool.composition.timeout_ms"

  @doc """
  Unique identifier for a composed tool pipeline.

  Attribute: `mcp.tool.composition_id`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `compose-abc123`, `pipeline-def456`
  """
  @spec mcp_tool_composition_id() :: :"mcp.tool.composition_id"
  def mcp_tool_composition_id, do: :"mcp.tool.composition_id"

  @doc """
  Total latency in milliseconds for the composed tool pipeline execution.

  Attribute: `mcp.tool.composition_latency_ms`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `120`, `450`
  """
  @spec mcp_tool_composition_latency_ms() :: :"mcp.tool.composition_latency_ms"
  def mcp_tool_composition_latency_ms, do: :"mcp.tool.composition_latency_ms"

  @doc """
  Whether the MCP tool is deprecated.

  Attribute: `mcp.tool.deprecated`
  Type: `boolean`
  Stability: `development`
  Requirement: `recommended`
  """
  @spec mcp_tool_deprecated() :: :"mcp.tool.deprecated"
  def mcp_tool_deprecated, do: :"mcp.tool.deprecated"

  @doc """
  The deprecation policy applied to the tool.

  Attribute: `mcp.tool.deprecation.policy`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `immediate`, `grace_period`, `warn_only`
  """
  @spec mcp_tool_deprecation_policy() :: :"mcp.tool.deprecation.policy"
  def mcp_tool_deprecation_policy, do: :"mcp.tool.deprecation.policy"

  @doc """
  Enumerated values for `mcp.tool.deprecation.policy`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `immediate` | `"immediate"` | immediate |
  | `grace_period` | `"grace_period"` | grace_period |
  | `warn_only` | `"warn_only"` | warn_only |
  """
  @spec mcp_tool_deprecation_policy_values() :: %{
    immediate: :immediate,
    grace_period: :grace_period,
    warn_only: :warn_only
  }
  def mcp_tool_deprecation_policy_values do
    %{
      immediate: :immediate,
      grace_period: :grace_period,
      warn_only: :warn_only
    }
  end

  defmodule McpToolDeprecationPolicyValues do
    @moduledoc """
    Typed constants for the `mcp.tool.deprecation.policy` attribute.
    """

    @doc "immediate"
    @spec immediate() :: :immediate
    def immediate, do: :immediate

    @doc "grace_period"
    @spec grace_period() :: :grace_period
    def grace_period, do: :grace_period

    @doc "warn_only"
    @spec warn_only() :: :warn_only
    def warn_only, do: :warn_only

  end

  @doc """
  Reason the tool was deprecated (if applicable).

  Attribute: `mcp.tool.deprecation.reason`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `replaced_by_v2`, `security_vulnerability`
  """
  @spec mcp_tool_deprecation_reason() :: :"mcp.tool.deprecation.reason"
  def mcp_tool_deprecation_reason, do: :"mcp.tool.deprecation.reason"

  @doc """
  The name of the replacement tool that supersedes the deprecated tool.

  Attribute: `mcp.tool.deprecation.replacement_tool`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `mcp.tool.v2.process`, `mcp.tool.enhanced.search`
  """
  @spec mcp_tool_deprecation_replacement_tool() :: :"mcp.tool.deprecation.replacement_tool"
  def mcp_tool_deprecation_replacement_tool, do: :"mcp.tool.deprecation.replacement_tool"

  @doc """
  Unix timestamp (ms) when the deprecated tool will be removed.

  Attribute: `mcp.tool.deprecation.sunset_date_ms`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `1735689600000`, `1751328000000`
  """
  @spec mcp_tool_deprecation_sunset_date_ms() :: :"mcp.tool.deprecation.sunset_date_ms"
  def mcp_tool_deprecation_sunset_date_ms, do: :"mcp.tool.deprecation.sunset_date_ms"

  @doc """
  Size in bytes of the tool input payload.

  Attribute: `mcp.tool.input_size`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `128`, `4096`
  """
  @spec mcp_tool_input_size() :: :"mcp.tool.input_size"
  def mcp_tool_input_size, do: :"mcp.tool.input_size"

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
  Size in bytes of the tool output payload.

  Attribute: `mcp.tool.output_size`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `256`, `8192`
  """
  @spec mcp_tool_output_size() :: :"mcp.tool.output_size"
  def mcp_tool_output_size, do: :"mcp.tool.output_size"

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
  Number of retry attempts for a tool execution (0 = first attempt succeeded).

  Attribute: `mcp.tool.retry_count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0`, `1`, `3`
  """
  @spec mcp_tool_retry_count() :: :"mcp.tool.retry_count"
  def mcp_tool_retry_count, do: :"mcp.tool.retry_count"

  @doc """
  Hash of the tool's input/output JSON schema (for schema drift detection).

  Attribute: `mcp.tool.schema_hash`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `sha256:abc123`, `md5:def456`
  """
  @spec mcp_tool_schema_hash() :: :"mcp.tool.schema_hash"
  def mcp_tool_schema_hash, do: :"mcp.tool.schema_hash"

  @doc """
  Configured timeout in milliseconds for tool execution (Armstrong budget constraint).

  Attribute: `mcp.tool.timeout_ms`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `5000`, `30000`
  """
  @spec mcp_tool_timeout_ms() :: :"mcp.tool.timeout_ms"
  def mcp_tool_timeout_ms, do: :"mcp.tool.timeout_ms"

  @doc """
  Version of the MCP tool being invoked.

  Attribute: `mcp.tool.version`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `1.0.0`, `2.3.1`, `latest`
  """
  @spec mcp_tool_version() :: :"mcp.tool.version"
  def mcp_tool_version, do: :"mcp.tool.version"

  @doc """
  Number of transport-level errors since last reset.

  Attribute: `mcp.transport.error_count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0`, `2`, `5`
  """
  @spec mcp_transport_error_count() :: :"mcp.transport.error_count"
  def mcp_transport_error_count, do: :"mcp.transport.error_count"

  @doc """
  Latency of the MCP transport connection in milliseconds.

  Attribute: `mcp.transport.latency_ms`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `12.5`, `45.0`
  """
  @spec mcp_transport_latency_ms() :: :"mcp.transport.latency_ms"
  def mcp_transport_latency_ms, do: :"mcp.transport.latency_ms"

  @doc """
  Number of reconnection attempts for the MCP transport.

  Attribute: `mcp.transport.reconnect_count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0`, `1`, `3`
  """
  @spec mcp_transport_reconnect_count() :: :"mcp.transport.reconnect_count"
  def mcp_transport_reconnect_count, do: :"mcp.transport.reconnect_count"

  @doc """
  Transport protocol used by the MCP connection.

  Attribute: `mcp.transport.type`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `stdio`, `http`, `sse`, `websocket`
  """
  @spec mcp_transport_type() :: :"mcp.transport.type"
  def mcp_transport_type, do: :"mcp.transport.type"

  @doc """
  Enumerated values for `mcp.transport.type`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `stdio` | `"stdio"` | stdio |
  | `http` | `"http"` | http |
  | `sse` | `"sse"` | sse |
  | `websocket` | `"websocket"` | websocket |
  """
  @spec mcp_transport_type_values() :: %{
    stdio: :stdio,
    http: :http,
    sse: :sse,
    websocket: :websocket
  }
  def mcp_transport_type_values do
    %{
      stdio: :stdio,
      http: :http,
      sse: :sse,
      websocket: :websocket
    }
  end

  defmodule McpTransportTypeValues do
    @moduledoc """
    Typed constants for the `mcp.transport.type` attribute.
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

    @doc "websocket"
    @spec websocket() :: :websocket
    def websocket, do: :websocket

  end

end