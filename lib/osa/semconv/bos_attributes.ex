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
  @spec bos_agent_service() :: :bos_agent_service
  def bos_agent_service, do: :bos_agent_service

  @doc """
  Identity of the actor performing the audited operation.

  Attribute: `bos.audit.actor_id`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `user-123`, `service-account-bos`
  """
  @spec bos_audit_actor_id() :: :bos_audit_actor_id
  def bos_audit_actor_id, do: :bos_audit_actor_id

  @doc """
  Type of audit event recorded.

  Attribute: `bos.audit.event_type`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `data_access`, `config_change`
  """
  @spec bos_audit_event_type() :: :bos_audit_event_type
  def bos_audit_event_type, do: :bos_audit_event_type

  @doc """
  Enumerated values for `bos.audit.event_type`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `data_access` | `"data_access"` | data_access |
  | `config_change` | `"config_change"` | config_change |
  | `permission_grant` | `"permission_grant"` | permission_grant |
  | `compliance_check` | `"compliance_check"` | compliance_check |
  | `gap_detection` | `"gap_detection"` | gap_detection |
  """
  @spec bos_audit_event_type_values() :: %{
    data_access: :data_access,
    config_change: :config_change,
    permission_grant: :permission_grant,
    compliance_check: :compliance_check,
    gap_detection: :gap_detection
  }
  def bos_audit_event_type_values do
    %{
      data_access: :data_access,
      config_change: :config_change,
      permission_grant: :permission_grant,
      compliance_check: :compliance_check,
      gap_detection: :gap_detection
    }
  end

  defmodule BosAuditEventTypeValues do
    @moduledoc """
    Typed constants for the `bos.audit.event_type` attribute.
    """

    @doc "data_access"
    @spec data_access() :: :data_access
    def data_access, do: :data_access

    @doc "config_change"
    @spec config_change() :: :config_change
    def config_change, do: :config_change

    @doc "permission_grant"
    @spec permission_grant() :: :permission_grant
    def permission_grant, do: :permission_grant

    @doc "compliance_check"
    @spec compliance_check() :: :compliance_check
    def compliance_check, do: :compliance_check

    @doc "gap_detection"
    @spec gap_detection() :: :gap_detection
    def gap_detection, do: :gap_detection

  end

  @doc """
  Unique identifier for a compliance audit trail entry.

  Attribute: `bos.audit.trail.id`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `audit-2026-03-25-001`, `trail-soc2-xyz`
  """
  @spec bos_audit_trail_id() :: :bos_audit_trail_id
  def bos_audit_trail_id, do: :bos_audit_trail_id

  @doc """
  Control ID within the compliance framework.

  Attribute: `bos.compliance.control_id`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `CC6.1`, `A3.2`
  """
  @spec bos_compliance_control_id() :: :bos_compliance_control_id
  def bos_compliance_control_id, do: :bos_compliance_control_id

  @doc """
  Compliance framework being evaluated or enforced.

  Attribute: `bos.compliance.framework`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `SOC2`, `GDPR`
  """
  @spec bos_compliance_framework() :: :bos_compliance_framework
  def bos_compliance_framework, do: :bos_compliance_framework

  @doc """
  Enumerated values for `bos.compliance.framework`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `soc2` | `"SOC2"` | SOC2 |
  | `hipaa` | `"HIPAA"` | HIPAA |
  | `gdpr` | `"GDPR"` | GDPR |
  | `sox` | `"SOX"` | SOX |
  | `custom` | `"CUSTOM"` | CUSTOM |
  """
  @spec bos_compliance_framework_values() :: %{
    soc2: :SOC2,
    hipaa: :HIPAA,
    gdpr: :GDPR,
    sox: :SOX,
    custom: :CUSTOM
  }
  def bos_compliance_framework_values do
    %{
      soc2: :SOC2,
      hipaa: :HIPAA,
      gdpr: :GDPR,
      sox: :SOX,
      custom: :CUSTOM
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

    @doc "CUSTOM"
    @spec custom() :: :CUSTOM
    def custom, do: :CUSTOM

  end

  @doc """
  Whether the compliance check passed (true) or failed (false).

  Attribute: `bos.compliance.passed`
  Type: `boolean`
  Stability: `development`
  Requirement: `recommended`
  """
  @spec bos_compliance_passed() :: :bos_compliance_passed
  def bos_compliance_passed, do: :bos_compliance_passed

  @doc """
  Identifier of the specific compliance rule being checked.

  Attribute: `bos.compliance.rule_id`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `soc2.cc6.1`, `hipaa.164.312.a`
  """
  @spec bos_compliance_rule_id() :: :bos_compliance_rule_id
  def bos_compliance_rule_id, do: :bos_compliance_rule_id

  @doc """
  Severity level of a compliance rule violation.

  Attribute: `bos.compliance.severity`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `critical`, `high`
  """
  @spec bos_compliance_severity() :: :bos_compliance_severity
  def bos_compliance_severity, do: :bos_compliance_severity

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
  @spec bos_decision_id() :: :bos_decision_id
  def bos_decision_id, do: :bos_decision_id

  @doc """
  The outcome of a business decision.

  Attribute: `bos.decision.outcome`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `approved`, `rejected`
  """
  @spec bos_decision_outcome() :: :bos_decision_outcome
  def bos_decision_outcome, do: :bos_decision_outcome

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
  @spec bos_decision_type() :: :bos_decision_type
  def bos_decision_type, do: :bos_decision_type

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
  @spec bos_gap_id() :: :bos_gap_id
  def bos_gap_id, do: :bos_gap_id

  @doc """
  Target days to remediate the detected gap.

  Attribute: `bos.gap.remediation_days`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `7`, `30`, `90`
  """
  @spec bos_gap_remediation_days() :: :bos_gap_remediation_days
  def bos_gap_remediation_days, do: :bos_gap_remediation_days

  @doc """
  Severity of the detected compliance gap.

  Attribute: `bos.gap.severity`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `critical`, `high`
  """
  @spec bos_gap_severity() :: :bos_gap_severity
  def bos_gap_severity, do: :bos_gap_severity

  @doc """
  Enumerated values for `bos.gap.severity`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `critical` | `"critical"` | critical |
  | `high` | `"high"` | high |
  | `medium` | `"medium"` | medium |
  | `low` | `"low"` | low |
  """
  @spec bos_gap_severity_values() :: %{
    critical: :critical,
    high: :high,
    medium: :medium,
    low: :low
  }
  def bos_gap_severity_values do
    %{
      critical: :critical,
      high: :high,
      medium: :medium,
      low: :low
    }
  end

  defmodule BosGapSeverityValues do
    @moduledoc """
    Typed constants for the `bos.gap.severity` attribute.
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
  The current status of a compliance gap.

  Attribute: `bos.gap.status`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `open`, `in_remediation`
  """
  @spec bos_gap_status() :: :bos_gap_status
  def bos_gap_status, do: :bos_gap_status

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
  @spec bos_policy_version() :: :bos_policy_version
  def bos_policy_version, do: :bos_policy_version

  @doc """
  Unique identifier for a BusinessOS workspace.

  Attribute: `bos.workspace.id`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `ws-chatmangpt-001`, `ws-disney-team-abc`
  """
  @spec bos_workspace_id() :: :bos_workspace_id
  def bos_workspace_id, do: :bos_workspace_id

  @doc """
  Human-readable name of the BusinessOS workspace.

  Attribute: `bos.workspace.name`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `ChatmanGPT HQ`, `Disney Animation Team`
  """
  @spec bos_workspace_name() :: :bos_workspace_name
  def bos_workspace_name, do: :bos_workspace_name

end