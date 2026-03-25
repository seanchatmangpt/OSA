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
  The type of command dispatched from the Canopy command center.

  Attribute: `canopy.command.type`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `agent_dispatch`, `workflow_trigger`
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
  """
  @spec canopy_command_type_values() :: %{
    agent_dispatch: :agent_dispatch,
    workflow_trigger: :workflow_trigger,
    data_query: :data_query,
    heartbeat_check: :heartbeat_check,
    config_reload: :config_reload
  }
  def canopy_command_type_values do
    %{
      agent_dispatch: :agent_dispatch,
      workflow_trigger: :workflow_trigger,
      data_query: :data_query,
      heartbeat_check: :heartbeat_check,
      config_reload: :config_reload
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

  Attribute: `canopy.workspace.id`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `ws-abc-123`, `ws-primary-001`
  """
  @spec canopy_workspace_id() :: :"canopy.workspace.id"
  def canopy_workspace_id, do: :"canopy.workspace.id"

  @doc """
  Heartbeat round-trip latency in milliseconds.

  Attribute: `canopy.heartbeat.latency_ms`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `5`, `22`, `150`
  """
  @spec canopy_heartbeat_latency_ms :: :"canopy.heartbeat.latency_ms"
  def canopy_heartbeat_latency_ms, do: :"canopy.heartbeat.latency_ms"

  @doc """
  Monotonically-increasing heartbeat sequence number.

  Attribute: `canopy.heartbeat.sequence_num`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `1`, `42`, `10001`
  """
  @spec canopy_heartbeat_sequence_num :: :"canopy.heartbeat.sequence_num"
  def canopy_heartbeat_sequence_num, do: :"canopy.heartbeat.sequence_num"

  @doc """
  Number of consecutive missed heartbeats.

  Attribute: `canopy.heartbeat.missed_count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0`, `1`, `3`
  """
  @spec canopy_heartbeat_missed_count :: :"canopy.heartbeat.missed_count"
  def canopy_heartbeat_missed_count, do: :"canopy.heartbeat.missed_count"

  @doc """
  Unique identifier for the Canopy session (distinct from workspace).

  Attribute: `canopy.session.id`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `sess-001`, `sess-abc123`
  """
  @spec canopy_session_id :: :"canopy.session.id"
  def canopy_session_id, do: :"canopy.session.id"

end