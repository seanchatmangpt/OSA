defmodule OpenTelemetry.SemConv.Incubating.BosAttributes do
  @moduledoc """
  Bos semantic convention attributes.

  This module is generated from the ChatmanGPT semantic convention registry.
  Do not edit manually — regenerate with `weaver registry generate elixir`.
  """

  @doc """
  Name of the BusinessOS AI service or agent handling the operation.

  Stability: `development`
  """
  @spec bos_agent_service() :: :"bos.agent.service"
  def bos_agent_service, do: :"bos.agent.service"

  @doc """
  Compliance framework being evaluated or enforced.

  Stability: `development`
  """
  @spec bos_compliance_framework() :: :"bos.compliance.framework"
  def bos_compliance_framework, do: :"bos.compliance.framework"

  @doc """
  Values for `bos.compliance.framework`.
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

  @doc """
  Whether the compliance check passed (true) or failed (false).

  Stability: `development`
  """
  @spec bos_compliance_passed() :: :"bos.compliance.passed"
  def bos_compliance_passed, do: :"bos.compliance.passed"

  @doc """
  Identifier of the specific compliance rule being checked.

  Stability: `development`
  """
  @spec bos_compliance_rule_id() :: :"bos.compliance.rule_id"
  def bos_compliance_rule_id, do: :"bos.compliance.rule_id"

  @doc """
  Severity level of a compliance rule violation.

  Stability: `development`
  """
  @spec bos_compliance_severity() :: :"bos.compliance.severity"
  def bos_compliance_severity, do: :"bos.compliance.severity"

  @doc """
  Values for `bos.compliance.severity`.
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

  @doc """
  Unique identifier for a recorded decision in BusinessOS.

  Stability: `development`
  """
  @spec bos_decision_id() :: :"bos.decision.id"
  def bos_decision_id, do: :"bos.decision.id"

  @doc """
  Classification of the decision recorded.

  Stability: `development`
  """
  @spec bos_decision_type() :: :"bos.decision.type"
  def bos_decision_type, do: :"bos.decision.type"

  @doc """
  Values for `bos.decision.type`.
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

  @doc """
  Unique identifier for a BusinessOS workspace.

  Stability: `development`
  """
  @spec bos_workspace_id() :: :"bos.workspace.id"
  def bos_workspace_id, do: :"bos.workspace.id"

  @doc """
  Human-readable name of the BusinessOS workspace.

  Stability: `development`
  """
  @spec bos_workspace_name() :: :"bos.workspace.name"
  def bos_workspace_name, do: :"bos.workspace.name"
end