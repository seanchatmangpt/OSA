defmodule OpenTelemetry.SemConv.Incubating.BosSpanNames do
  @moduledoc """
  Bos semantic convention span names.

  Namespace: `bos`

  This module is generated from the ChatmanGPT semantic convention registry.
  Do not edit manually — regenerate with:

      weaver registry generate -r ./semconv/model --templates ./semconv/templates elixir ./OSA/lib/osa/semconv/
  """

  @doc """
  Audit record for configuration change operation.

  Span: `span.bos.audit.config_change`
  Kind: `server`
  Stability: `development`
  """
  @spec bos_audit_config_change() :: String.t()
  def bos_audit_config_change, do: "bos.audit.config_change"

  @doc """
  Audit record for permission grant or revocation.

  Span: `span.bos.audit.permission_grant`
  Kind: `server`
  Stability: `development`
  """
  @spec bos_audit_permission_grant() :: String.t()
  def bos_audit_permission_grant, do: "bos.audit.permission_grant"

  @doc """
  Recording of a compliance audit trail entry.

  Span: `span.bos.audit.record`
  Kind: `internal`
  Stability: `development`
  """
  @spec bos_audit_record() :: String.t()
  def bos_audit_record, do: "bos.audit.record"

  @doc """
  Evaluation of a single compliance rule against current workspace state.

  Span: `span.bos.compliance.check`
  Kind: `internal`
  Stability: `development`
  """
  @spec bos_compliance_check() :: String.t()
  def bos_compliance_check, do: "bos.compliance.check"

  @doc """
  Evaluation of a compliance control against current system state.

  Span: `span.bos.compliance.evaluate`
  Kind: `internal`
  Stability: `development`
  """
  @spec bos_compliance_evaluate() :: String.t()
  def bos_compliance_evaluate, do: "bos.compliance.evaluate"

  @doc """
  Recording of an architectural or operational decision in BusinessOS.

  Span: `span.bos.decision.record`
  Kind: `internal`
  Stability: `development`
  """
  @spec bos_decision_record() :: String.t()
  def bos_decision_record, do: "bos.decision.record"

  @doc """
  Detection and classification of a compliance gap.

  Span: `span.bos.gap.detect`
  Kind: `internal`
  Stability: `development`
  """
  @spec bos_gap_detect() :: String.t()
  def bos_gap_detect, do: "bos.gap.detect"

  @doc """
  An operation performed against a BusinessOS workspace (create, update, query).

  Span: `span.bos.workspace.operation`
  Kind: `internal`
  Stability: `development`
  """
  @spec bos_workspace_operation() :: String.t()
  def bos_workspace_operation, do: "bos.workspace.operation"

  @doc """
  All span names in this namespace.
  """
  @spec all() :: [String.t()]
  def all do
    [
      bos_audit_config_change(),
      bos_audit_permission_grant(),
      bos_audit_record(),
      bos_compliance_check(),
      bos_compliance_evaluate(),
      bos_decision_record(),
      bos_gap_detect(),
      bos_workspace_operation()
    ]
  end
end