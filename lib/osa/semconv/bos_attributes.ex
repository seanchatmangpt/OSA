defmodule OpenTelemetry.SemConv.Incubating.BosAttributes do
  @moduledoc """
  Bos semantic convention attributes.

  Namespace: `bos`

  This module is generated from the ChatmanGPT semantic convention registry.
  Do not edit manually — regenerate with:

      weaver registry generate -r ./semconv/model --templates ./semconv/templates elixir ./OSA/lib/osa/semconv/
  """

  @doc """
  Name of the BusinessOS AI service or agent handling the operation.

  Attribute: `bos.agent.service`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `bos-compliance`, `bos-decisions`, `bos-workspace`
  """
  @spec bos_agent_service() :: :"bos.agent.service"
  def bos_agent_service, do: :"bos.agent.service"

  @doc """
  Unique identifier for a compliance audit trail entry.

  Attribute: `bos.audit.trail.id`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `audit-2026-03-25-001`, `trail-soc2-xyz`
  """
  @spec bos_audit_trail_id() :: :"bos.audit.trail.id"
  def bos_audit_trail_id, do: :"bos.audit.trail.id"

  @doc """
  Compliance framework being evaluated or enforced.

  Attribute: `bos.compliance.framework`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `SOC2`, `HIPAA`
  """
  @spec bos_compliance_framework() :: :"bos.compliance.framework"
  def bos_compliance_framework, do: :"bos.compliance.framework"

  @doc """
  Enumerated values for `bos.compliance.framework`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `soc2` | `"SOC2"` | SOC2 |
  | `hipaa` | `"HIPAA"` | HIPAA |
  | `gdpr` | `"GDPR"` | GDPR |
  | `sox` | `"SOX"` | SOX |
  """
  @spec bos_compliance_framework_values() :: %{
    soc2: :SOC2,
    hipaa: :HIPAA,
    gdpr: :GDPR,
    sox: :SOX
  }
  def bos_compliance_framework_values do
    %{
      soc2: :SOC2,
      hipaa: :HIPAA,
      gdpr: :GDPR,
      sox: :SOX
    }
  end

  defmodule BosComplianceFrameworkValues do
    @moduledoc """
    Typed constants for the `bos.compliance.framework` attribute.
    """

    @doc "SOC2"
    @spec soc2() :: :SOC2
    def soc2, do: :SOC2

    @doc "HIPAA"
    @spec hipaa() :: :HIPAA
    def hipaa, do: :HIPAA

    @doc "GDPR"
    @spec gdpr() :: :GDPR
    def gdpr, do: :GDPR

    @doc "SOX"
    @spec sox() :: :SOX
    def sox, do: :SOX

  end

  @doc """
  Whether the compliance check passed (true) or failed (false).

  Attribute: `bos.compliance.passed`
  Type: `boolean`
  Stability: `development`
  Requirement: `recommended`
  """
  @spec bos_compliance_passed() :: :"bos.compliance.passed"
  def bos_compliance_passed, do: :"bos.compliance.passed"

  @doc """
  Identifier of the specific compliance rule being checked.

  Attribute: `bos.compliance.rule_id`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `soc2.cc6.1`, `hipaa.164.312.a`
  """
  @spec bos_compliance_rule_id() :: :"bos.compliance.rule_id"
  def bos_compliance_rule_id, do: :"bos.compliance.rule_id"

  @doc """
  Severity level of a compliance rule violation.

  Attribute: `bos.compliance.severity`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `critical`, `high`
  """
  @spec bos_compliance_severity() :: :"bos.compliance.severity"
  def bos_compliance_severity, do: :"bos.compliance.severity"

  @doc """
  Enumerated values for `bos.compliance.severity`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `critical` | `"critical"` | critical |
  | `high` | `"high"` | high |
  | `medium` | `"medium"` | medium |
  | `low` | `"low"` | low |
  """
  @spec bos_compliance_severity_values() :: %{
    critical: :critical,
    high: :high,
    medium: :medium,
    low: :low
  }
  def bos_compliance_severity_values do
    %{
      critical: :critical,
      high: :high,
      medium: :medium,
      low: :low
    }
  end

  defmodule BosComplianceSeverityValues do
    @moduledoc """
    Typed constants for the `bos.compliance.severity` attribute.
    """

    @doc "critical"
    @spec critical() :: :critical
    def critical, do: :critical

    @doc "high"
    @spec high() :: :high
    def high, do: :high

    @doc "medium"
    @spec medium() :: :medium
    def medium, do: :medium

    @doc "low"
    @spec low() :: :low
    def low, do: :low

  end

  @doc """
  Unique identifier for a recorded decision in BusinessOS.

  Attribute: `bos.decision.id`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `dec-2026-001`, `adr-authentication-strategy`
  """
  @spec bos_decision_id() :: :"bos.decision.id"
  def bos_decision_id, do: :"bos.decision.id"

  @doc """
  The outcome of a business decision.

  Attribute: `bos.decision.outcome`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `approved`, `rejected`
  """
  @spec bos_decision_outcome() :: :"bos.decision.outcome"
  def bos_decision_outcome, do: :"bos.decision.outcome"

  @doc """
  Enumerated values for `bos.decision.outcome`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `approved` | `"approved"` | approved |
  | `rejected` | `"rejected"` | rejected |
  | `deferred` | `"deferred"` | deferred |
  | `escalated` | `"escalated"` | escalated |
  """
  @spec bos_decision_outcome_values() :: %{
    approved: :approved,
    rejected: :rejected,
    deferred: :deferred,
    escalated: :escalated
  }
  def bos_decision_outcome_values do
    %{
      approved: :approved,
      rejected: :rejected,
      deferred: :deferred,
      escalated: :escalated
    }
  end

  defmodule BosDecisionOutcomeValues do
    @moduledoc """
    Typed constants for the `bos.decision.outcome` attribute.
    """

    @doc "approved"
    @spec approved() :: :approved
    def approved, do: :approved

    @doc "rejected"
    @spec rejected() :: :rejected
    def rejected, do: :rejected

    @doc "deferred"
    @spec deferred() :: :deferred
    def deferred, do: :deferred

    @doc "escalated"
    @spec escalated() :: :escalated
    def escalated, do: :escalated

  end

  @doc """
  Classification of the decision recorded.

  Attribute: `bos.decision.type`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `architectural`, `operational`
  """
  @spec bos_decision_type() :: :"bos.decision.type"
  def bos_decision_type, do: :"bos.decision.type"

  @doc """
  Enumerated values for `bos.decision.type`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `architectural` | `"architectural"` | architectural |
  | `operational` | `"operational"` | operational |
  | `strategic` | `"strategic"` | strategic |
  | `compliance` | `"compliance"` | compliance |
  """
  @spec bos_decision_type_values() :: %{
    architectural: :architectural,
    operational: :operational,
    strategic: :strategic,
    compliance: :compliance
  }
  def bos_decision_type_values do
    %{
      architectural: :architectural,
      operational: :operational,
      strategic: :strategic,
      compliance: :compliance
    }
  end

  defmodule BosDecisionTypeValues do
    @moduledoc """
    Typed constants for the `bos.decision.type` attribute.
    """

    @doc "architectural"
    @spec architectural() :: :architectural
    def architectural, do: :architectural

    @doc "operational"
    @spec operational() :: :operational
    def operational, do: :operational

    @doc "strategic"
    @spec strategic() :: :strategic
    def strategic, do: :strategic

    @doc "compliance"
    @spec compliance() :: :compliance
    def compliance, do: :compliance

  end

  @doc """
  Identifier for a detected compliance gap.

  Attribute: `bos.gap.id`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `gap-cc6.1-001`, `gap-hipaa-phi-002`
  """
  @spec bos_gap_id() :: :"bos.gap.id"
  def bos_gap_id, do: :"bos.gap.id"

  @doc """
  The current status of a compliance gap.

  Attribute: `bos.gap.status`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `open`, `in_remediation`
  """
  @spec bos_gap_status() :: :"bos.gap.status"
  def bos_gap_status, do: :"bos.gap.status"

  @doc """
  Enumerated values for `bos.gap.status`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `open` | `"open"` | open |
  | `in_remediation` | `"in_remediation"` | in_remediation |
  | `resolved` | `"resolved"` | resolved |
  | `accepted_risk` | `"accepted_risk"` | accepted_risk |
  """
  @spec bos_gap_status_values() :: %{
    open: :open,
    in_remediation: :in_remediation,
    resolved: :resolved,
    accepted_risk: :accepted_risk
  }
  def bos_gap_status_values do
    %{
      open: :open,
      in_remediation: :in_remediation,
      resolved: :resolved,
      accepted_risk: :accepted_risk
    }
  end

  defmodule BosGapStatusValues do
    @moduledoc """
    Typed constants for the `bos.gap.status` attribute.
    """

    @doc "open"
    @spec open() :: :open
    def open, do: :open

    @doc "in_remediation"
    @spec in_remediation() :: :in_remediation
    def in_remediation, do: :in_remediation

    @doc "resolved"
    @spec resolved() :: :resolved
    def resolved, do: :resolved

    @doc "accepted_risk"
    @spec accepted_risk() :: :accepted_risk
    def accepted_risk, do: :accepted_risk

  end

  @doc """
  Version of the compliance policy rule set applied.

  Attribute: `bos.policy.version`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `1.2.0`, `soc2-2026-q1`
  """
  @spec bos_policy_version() :: :"bos.policy.version"
  def bos_policy_version, do: :"bos.policy.version"

  @doc """
  Unique identifier for a BusinessOS workspace.

  Attribute: `bos.workspace.id`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `ws-chatmangpt-001`, `ws-disney-team-abc`
  """
  @spec bos_workspace_id() :: :"bos.workspace.id"
  def bos_workspace_id, do: :"bos.workspace.id"

  @doc """
  Human-readable name of the BusinessOS workspace.

  Attribute: `bos.workspace.name`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `ChatmanGPT HQ`, `Disney Animation Team`
  """
  @spec bos_workspace_name() :: :"bos.workspace.name"
  def bos_workspace_name, do: :"bos.workspace.name"

end