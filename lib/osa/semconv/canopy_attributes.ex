defmodule OpenTelemetry.SemConv.Incubating.CanopyAttributes do
  @moduledoc """
  Canopy semantic convention attributes.

  Namespace: `canopy`

  This module is generated from the ChatmanGPT semantic convention registry.
  Do not edit manually — regenerate with:

      weaver registry generate -r ./semconv/model --templates ./semconv/templates elixir ./OSA/lib/osa/semconv/
  """

  @doc """
  Action performed by the Canopy adapter.

  Attribute: `canopy.adapter.action`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `start`, `stop`, `send_message`, `get_status`
  """
  @spec canopy_adapter_action() :: :"canopy.adapter.action"
  def canopy_adapter_action, do: :"canopy.adapter.action"

  @doc """
  Cumulative error count from the adapter since last reset.

  Attribute: `canopy.adapter.error_count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0`, `5`, `100`
  """
  @spec canopy_adapter_error_count() :: :"canopy.adapter.error_count"
  def canopy_adapter_error_count, do: :"canopy.adapter.error_count"

  @doc """
  Name of the Canopy adapter being invoked.

  Attribute: `canopy.adapter.name`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `osa`, `business_os`, `mcp`, `a2a`
  """
  @spec canopy_adapter_name() :: :"canopy.adapter.name"
  def canopy_adapter_name, do: :"canopy.adapter.name"

  @doc """
  The type of Canopy adapter handling the request.

  Attribute: `canopy.adapter.type`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `osa`, `mcp`
  """
  @spec canopy_adapter_type() :: :"canopy.adapter.type"
  def canopy_adapter_type, do: :"canopy.adapter.type"

  @doc """
  Enumerated values for `canopy.adapter.type`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `osa` | `"osa"` | osa |
  | `mcp` | `"mcp"` | mcp |
  | `business_os` | `"business_os"` | business_os |
  | `webhook` | `"webhook"` | webhook |
  """
  @spec canopy_adapter_type_values() :: %{
    osa: :osa,
    mcp: :mcp,
    business_os: :business_os,
    webhook: :webhook
  }
  def canopy_adapter_type_values do
    %{
      osa: :osa,
      mcp: :mcp,
      business_os: :business_os,
      webhook: :webhook
    }
  end

  defmodule CanopyAdapterTypeValues do
    @moduledoc """
    Typed constants for the `canopy.adapter.type` attribute.
    """

    @doc "osa"
    @spec osa() :: :osa
    def osa, do: :osa

    @doc "mcp"
    @spec mcp() :: :mcp
    def mcp, do: :mcp

    @doc "business_os"
    @spec business_os() :: :business_os
    def business_os, do: :business_os

    @doc "webhook"
    @spec webhook() :: :webhook
    def webhook, do: :webhook

  end

  @doc """
  Time budget allocated for the Canopy operation in milliseconds.

  Attribute: `canopy.budget.ms`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `100`, `500`, `5000`
  """
  @spec canopy_budget_ms() :: :"canopy.budget.ms"
  def canopy_budget_ms, do: :"canopy.budget.ms"

  @doc """
  Source agent or service that originated the command.

  Attribute: `canopy.command.source`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `osa`, `businessos`, `user`
  """
  @spec canopy_command_source() :: :"canopy.command.source"
  def canopy_command_source, do: :"canopy.command.source"

  @doc """
  Target agent or service for the command.

  Attribute: `canopy.command.target`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `osa`, `pm4py`, `canopy.adapter.osa`
  """
  @spec canopy_command_target() :: :"canopy.command.target"
  def canopy_command_target, do: :"canopy.command.target"

  @doc """
  Type of command being dispatched through Canopy.

  Attribute: `canopy.command.type`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `execute`, `query`
  """
  @spec canopy_command_type() :: :"canopy.command.type"
  def canopy_command_type, do: :"canopy.command.type"

  @doc """
  Enumerated values for `canopy.command.type`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `agent_dispatch` | `"agent_dispatch"` | agent_dispatch |
  | `workflow_trigger` | `"workflow_trigger"` | workflow_trigger |
  | `data_query` | `"data_query"` | data_query |
  | `heartbeat_check` | `"heartbeat_check"` | heartbeat_check |
  | `config_reload` | `"config_reload"` | config_reload |
  | `execute` | `"execute"` | execute |
  | `query` | `"query"` | query |
  | `route` | `"route"` | route |
  | `broadcast` | `"broadcast"` | broadcast |
  | `sync` | `"sync"` | sync |
  | `delegate` | `"delegate"` | delegate |
  """
  @spec canopy_command_type_values() :: %{
    agent_dispatch: :agent_dispatch,
    workflow_trigger: :workflow_trigger,
    data_query: :data_query,
    heartbeat_check: :heartbeat_check,
    config_reload: :config_reload,
    execute: :execute,
    query: :query,
    route: :route,
    broadcast: :broadcast,
    sync: :sync,
    delegate: :delegate
  }
  def canopy_command_type_values do
    %{
      agent_dispatch: :agent_dispatch,
      workflow_trigger: :workflow_trigger,
      data_query: :data_query,
      heartbeat_check: :heartbeat_check,
      config_reload: :config_reload,
      execute: :execute,
      query: :query,
      route: :route,
      broadcast: :broadcast,
      sync: :sync,
      delegate: :delegate
    }
  end

  defmodule CanopyCommandTypeValues do
    @moduledoc """
    Typed constants for the `canopy.command.type` attribute.
    """

    @doc "agent_dispatch"
    @spec agent_dispatch() :: :agent_dispatch
    def agent_dispatch, do: :agent_dispatch

    @doc "workflow_trigger"
    @spec workflow_trigger() :: :workflow_trigger
    def workflow_trigger, do: :workflow_trigger

    @doc "data_query"
    @spec data_query() :: :data_query
    def data_query, do: :data_query

    @doc "heartbeat_check"
    @spec heartbeat_check() :: :heartbeat_check
    def heartbeat_check, do: :heartbeat_check

    @doc "config_reload"
    @spec config_reload() :: :config_reload
    def config_reload, do: :config_reload

    @doc "execute"
    @spec execute() :: :execute
    def execute, do: :execute

    @doc "query"
    @spec query() :: :query
    def query, do: :query

    @doc "route"
    @spec route() :: :route
    def route, do: :route

    @doc "broadcast"
    @spec broadcast() :: :broadcast
    def broadcast, do: :broadcast

    @doc "sync"
    @spec sync() :: :sync
    def sync, do: :sync

    @doc "delegate"
    @spec delegate() :: :delegate
    def delegate, do: :delegate

  end

  @doc """
  Number of state conflicts detected during workspace synchronization.

  Attribute: `canopy.conflict.count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0`, `1`, `5`
  """
  @spec canopy_conflict_count() :: :"canopy.conflict.count"
  def canopy_conflict_count, do: :"canopy.conflict.count"

  @doc """
  Round-trip latency of the heartbeat probe in milliseconds (Armstrong WvdA bounded).

  Attribute: `canopy.heartbeat.latency_ms`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `5`, `50`, `200`
  """
  @spec canopy_heartbeat_latency_ms() :: :"canopy.heartbeat.latency_ms"
  def canopy_heartbeat_latency_ms, do: :"canopy.heartbeat.latency_ms"

  @doc """
  Consecutive missed heartbeats before this probe was sent (liveness indicator).

  Attribute: `canopy.heartbeat.missed_count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0`, `1`, `3`
  """
  @spec canopy_heartbeat_missed_count() :: :"canopy.heartbeat.missed_count"
  def canopy_heartbeat_missed_count, do: :"canopy.heartbeat.missed_count"

  @doc """
  Monotonically increasing sequence number of this heartbeat probe for ordering.

  Attribute: `canopy.heartbeat.sequence_num`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `1`, `42`, `10000`
  """
  @spec canopy_heartbeat_sequence_num() :: :"canopy.heartbeat.sequence_num"
  def canopy_heartbeat_sequence_num, do: :"canopy.heartbeat.sequence_num"

  @doc """
  Health status reported by the heartbeat.

  Attribute: `canopy.heartbeat.status`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `healthy`, `degraded`
  """
  @spec canopy_heartbeat_status() :: :"canopy.heartbeat.status"
  def canopy_heartbeat_status, do: :"canopy.heartbeat.status"

  @doc """
  Enumerated values for `canopy.heartbeat.status`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `healthy` | `"healthy"` | healthy |
  | `degraded` | `"degraded"` | degraded |
  | `critical` | `"critical"` | critical |
  | `timeout` | `"timeout"` | timeout |
  """
  @spec canopy_heartbeat_status_values() :: %{
    healthy: :healthy,
    degraded: :degraded,
    critical: :critical,
    timeout: :timeout
  }
  def canopy_heartbeat_status_values do
    %{
      healthy: :healthy,
      degraded: :degraded,
      critical: :critical,
      timeout: :timeout
    }
  end

  defmodule CanopyHeartbeatStatusValues do
    @moduledoc """
    Typed constants for the `canopy.heartbeat.status` attribute.
    """

    @doc "healthy"
    @spec healthy() :: :healthy
    def healthy, do: :healthy

    @doc "degraded"
    @spec degraded() :: :degraded
    def degraded, do: :degraded

    @doc "critical"
    @spec critical() :: :critical
    def critical, do: :critical

    @doc "timeout"
    @spec timeout() :: :timeout
    def timeout, do: :timeout

  end

  @doc """
  Priority tier of the heartbeat dispatch.

  Attribute: `canopy.heartbeat.tier`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `critical`, `normal`
  """
  @spec canopy_heartbeat_tier() :: :"canopy.heartbeat.tier"
  def canopy_heartbeat_tier, do: :"canopy.heartbeat.tier"

  @doc """
  Enumerated values for `canopy.heartbeat.tier`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `critical` | `"critical"` | critical |
  | `high` | `"high"` | high |
  | `normal` | `"normal"` | normal |
  | `low` | `"low"` | low |
  """
  @spec canopy_heartbeat_tier_values() :: %{
    critical: :critical,
    high: :high,
    normal: :normal,
    low: :low
  }
  def canopy_heartbeat_tier_values do
    %{
      critical: :critical,
      high: :high,
      normal: :normal,
      low: :low
    }
  end

  defmodule CanopyHeartbeatTierValues do
    @moduledoc """
    Typed constants for the `canopy.heartbeat.tier` attribute.
    """

    @doc "critical"
    @spec critical() :: :critical
    def critical, do: :critical

    @doc "high"
    @spec high() :: :high
    def high, do: :high

    @doc "normal"
    @spec normal() :: :normal
    def normal, do: :normal

    @doc "low"
    @spec low() :: :low
    def low, do: :low

  end

  @doc """
  The type of workspace operation being performed.

  Attribute: `canopy.operation.type`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `read`, `write`, `publish`
  """
  @spec canopy_operation_type() :: :"canopy.operation.type"
  def canopy_operation_type, do: :"canopy.operation.type"

  @doc """
  Enumerated values for `canopy.operation.type`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `read` | `"read"` | read |
  | `write` | `"write"` | write |
  | `subscribe` | `"subscribe"` | subscribe |
  | `publish` | `"publish"` | publish |
  """
  @spec canopy_operation_type_values() :: %{
    read: :read,
    write: :write,
    subscribe: :subscribe,
    publish: :publish
  }
  def canopy_operation_type_values do
    %{
      read: :read,
      write: :write,
      subscribe: :subscribe,
      publish: :publish
    }
  end

  defmodule CanopyOperationTypeValues do
    @moduledoc """
    Typed constants for the `canopy.operation.type` attribute.
    """

    @doc "read"
    @spec read() :: :read
    def read, do: :read

    @doc "write"
    @spec write() :: :write
    def write, do: :write

    @doc "subscribe"
    @spec subscribe() :: :subscribe
    def subscribe, do: :subscribe

    @doc "publish"
    @spec publish() :: :publish
    def publish, do: :publish

  end

  @doc """
  Number of peer nodes participating in workspace synchronization.

  Attribute: `canopy.peer.count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `1`, `3`, `10`
  """
  @spec canopy_peer_count() :: :"canopy.peer.count"
  def canopy_peer_count, do: :"canopy.peer.count"

  @doc """
  The version of the Canopy workspace protocol in use.

  Attribute: `canopy.protocol.version`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `1.0`, `2.1`, `3.0-beta`
  """
  @spec canopy_protocol_version() :: :"canopy.protocol.version"
  def canopy_protocol_version, do: :"canopy.protocol.version"

  @doc """
  Time in milliseconds for the Canopy workspace to respond to a command.

  Attribute: `canopy.response_time_ms`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `45`, `120`, `500`
  """
  @spec canopy_response_time_ms() :: :"canopy.response_time_ms"
  def canopy_response_time_ms, do: :"canopy.response_time_ms"

  @doc """
  Unique identifier for the Canopy workspace session.

  Attribute: `canopy.session.id`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `session-abc123`, `canopy-ws-001`
  """
  @spec canopy_session_id() :: :"canopy.session.id"
  def canopy_session_id, do: :"canopy.session.id"

  @doc """
  Signal Theory mode of the workspace signal (M in S=(M,G,T,F,W)).

  Attribute: `canopy.signal.mode`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `linguistic`, `code`, `data`
  """
  @spec canopy_signal_mode() :: :"canopy.signal.mode"
  def canopy_signal_mode, do: :"canopy.signal.mode"

  @doc """
  Compression ratio achieved on the snapshot (uncompressed/compressed), >= 1.0.

  Attribute: `canopy.snapshot.compression_ratio`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `1.5`, `2.8`, `4.2`
  """
  @spec canopy_snapshot_compression_ratio() :: :"canopy.snapshot.compression_ratio"
  def canopy_snapshot_compression_ratio, do: :"canopy.snapshot.compression_ratio"

  @doc """
  Unique identifier of the canopy workspace snapshot.

  Attribute: `canopy.snapshot.id`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `snap-abc123`, `snap-2026-03-25-001`
  """
  @spec canopy_snapshot_id() :: :"canopy.snapshot.id"
  def canopy_snapshot_id, do: :"canopy.snapshot.id"

  @doc """
  Size of the serialized snapshot in bytes.

  Attribute: `canopy.snapshot.size_bytes`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `1024`, `65536`, `1048576`
  """
  @spec canopy_snapshot_size_bytes() :: :"canopy.snapshot.size_bytes"
  def canopy_snapshot_size_bytes, do: :"canopy.snapshot.size_bytes"

  @doc """
  The synchronization strategy used for workspace state reconciliation.

  Attribute: `canopy.sync.strategy`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `immediate`, `batched`
  """
  @spec canopy_sync_strategy() :: :"canopy.sync.strategy"
  def canopy_sync_strategy, do: :"canopy.sync.strategy"

  @doc """
  Enumerated values for `canopy.sync.strategy`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `immediate` | `"immediate"` | immediate |
  | `batched` | `"batched"` | batched |
  | `eventual` | `"eventual"` | eventual |
  | `conflict_free` | `"conflict_free"` | conflict_free |
  """
  @spec canopy_sync_strategy_values() :: %{
    immediate: :immediate,
    batched: :batched,
    eventual: :eventual,
    conflict_free: :conflict_free
  }
  def canopy_sync_strategy_values do
    %{
      immediate: :immediate,
      batched: :batched,
      eventual: :eventual,
      conflict_free: :conflict_free
    }
  end

  defmodule CanopySyncStrategyValues do
    @moduledoc """
    Typed constants for the `canopy.sync.strategy` attribute.
    """

    @doc "immediate"
    @spec immediate() :: :immediate
    def immediate, do: :immediate

    @doc "batched"
    @spec batched() :: :batched
    def batched, do: :batched

    @doc "eventual"
    @spec eventual() :: :eventual
    def eventual, do: :eventual

    @doc "conflict_free"
    @spec conflict_free() :: :conflict_free
    def conflict_free, do: :conflict_free

  end

  @doc """
  Unique identifier for the Canopy workspace session.

  Attribute: `canopy.workspace.id`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `ws-abc-123`, `ws-primary-001`
  """
  @spec canopy_workspace_id() :: :"canopy.workspace.id"
  def canopy_workspace_id, do: :"canopy.workspace.id"

end