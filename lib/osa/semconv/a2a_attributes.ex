defmodule OpenTelemetry.SemConv.Incubating.A2aAttributes do
  @moduledoc """
  A2a semantic convention attributes.

  Namespace: `a2a`

  This module is generated from the ChatmanGPT semantic convention registry.
  Do not edit manually — regenerate with:

      weaver registry generate -r ./semconv/model --templates ./semconv/templates elixir ./OSA/lib/osa/semconv/
  """

  @doc """
  Identifier of the target agent in an A2A call.

  Attribute: `a2a.agent.id`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `businessos-agent`, `osa-healing-agent`, `canopy-adapter`
  """
  @spec a2a_agent_id() :: :"a2a.agent.id"
  def a2a_agent_id, do: :"a2a.agent.id"

  @doc """
  Name of the capability being advertised or requested in A2A negotiation.

  Attribute: `a2a.capability.name`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `healing.diagnosis`, `process.mining`, `compliance.check`
  """
  @spec a2a_capability_name() :: :"a2a.capability.name"
  def a2a_capability_name, do: :"a2a.capability.name"

  @doc """
  Identifier of the deal being created or operated on via A2A.

  Attribute: `a2a.deal.id`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `deal-abc123`, `deal-2026-001`
  """
  @spec a2a_deal_id() :: :"a2a.deal.id"
  def a2a_deal_id, do: :"a2a.deal.id"

  @doc """
  Type of the A2A deal.

  Attribute: `a2a.deal.type`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `data_access`, `compute_task`, `agent_collaboration`
  """
  @spec a2a_deal_type() :: :"a2a.deal.type"
  def a2a_deal_type, do: :"a2a.deal.type"

  @doc """
  The negotiation round number in a multi-round deal negotiation.

  Attribute: `a2a.negotiation.round`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `1`, `2`, `3`
  """
  @spec a2a_negotiation_round() :: :"a2a.negotiation.round"
  def a2a_negotiation_round, do: :"a2a.negotiation.round"

  @doc """
  Current status of an A2A deal negotiation.

  Attribute: `a2a.negotiation.status`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `pending`, `accepted`
  """
  @spec a2a_negotiation_status() :: :"a2a.negotiation.status"
  def a2a_negotiation_status, do: :"a2a.negotiation.status"

  @doc """
  Enumerated values for `a2a.negotiation.status`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `pending` | `"pending"` | pending |
  | `accepted` | `"accepted"` | accepted |
  | `rejected` | `"rejected"` | rejected |
  | `counter_offer` | `"counter_offer"` | counter_offer |
  | `expired` | `"expired"` | expired |
  """
  @spec a2a_negotiation_status_values() :: %{
    pending: :pending,
    accepted: :accepted,
    rejected: :rejected,
    counter_offer: :counter_offer,
    expired: :expired
  }
  def a2a_negotiation_status_values do
    %{
      pending: :pending,
      accepted: :accepted,
      rejected: :rejected,
      counter_offer: :counter_offer,
      expired: :expired
    }
  end

  defmodule A2aNegotiationStatusValues do
    @moduledoc """
    Typed constants for the `a2a.negotiation.status` attribute.
    """

    @doc "pending"
    @spec pending() :: :pending
    def pending, do: :pending

    @doc "accepted"
    @spec accepted() :: :accepted
    def accepted, do: :accepted

    @doc "rejected"
    @spec rejected() :: :rejected
    def rejected, do: :rejected

    @doc "counter_offer"
    @spec counter_offer() :: :counter_offer
    def counter_offer, do: :counter_offer

    @doc "expired"
    @spec expired() :: :expired
    def expired, do: :expired

  end

  @doc """
  The A2A operation name being invoked.

  Attribute: `a2a.operation`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `create_deal`, `query_status`, `dispatch_task`, `get_capabilities`
  """
  @spec a2a_operation() :: :"a2a.operation"
  def a2a_operation, do: :"a2a.operation"

  @doc """
  Service initiating the A2A call (sender).

  Attribute: `a2a.source.service`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `osa`, `businessos`, `canopy`
  """
  @spec a2a_source_service() :: :"a2a.source.service"
  def a2a_source_service, do: :"a2a.source.service"

  @doc """
  Service receiving the A2A call (receiver).

  Attribute: `a2a.target.service`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `osa`, `businessos`, `canopy`
  """
  @spec a2a_target_service() :: :"a2a.target.service"
  def a2a_target_service, do: :"a2a.target.service"

  @doc """
  Unique identifier for a delegated task in A2A task delegation.

  Attribute: `a2a.task.id`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `task-abc-123`, `task-mining-456`
  """
  @spec a2a_task_id() :: :"a2a.task.id"
  def a2a_task_id, do: :"a2a.task.id"

  @doc """
  Priority level of a delegated A2A task.

  Attribute: `a2a.task.priority`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `high`, `normal`
  """
  @spec a2a_task_priority() :: :"a2a.task.priority"
  def a2a_task_priority, do: :"a2a.task.priority"

  @doc """
  Enumerated values for `a2a.task.priority`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `critical` | `"critical"` | critical |
  | `high` | `"high"` | high |
  | `normal` | `"normal"` | normal |
  | `low` | `"low"` | low |
  """
  @spec a2a_task_priority_values() :: %{
    critical: :critical,
    high: :high,
    normal: :normal,
    low: :low
  }
  def a2a_task_priority_values do
    %{
      critical: :critical,
      high: :high,
      normal: :normal,
      low: :low
    }
  end

  defmodule A2aTaskPriorityValues do
    @moduledoc """
    Typed constants for the `a2a.task.priority` attribute.
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

end