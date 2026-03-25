defmodule OpenTelemetry.SemConv.Incubating.BusinessOsSpanNames do
  @moduledoc """
  BusinessOs semantic convention span names.

  Namespace: `business_os`

  This module is generated from the ChatmanGPT semantic convention registry.
  Do not edit manually — regenerate with:

      weaver registry generate -r ./semconv/model --templates ./semconv/templates elixir ./OSA/lib/osa/semconv/
  """

  @doc """
  Recording an audit event in the BusinessOS immutable audit trail.

  Span: `span.business_os.audit.record`
  Kind: `internal`
  Stability: `development`
  """
  @spec business_os_audit_record() :: String.t()
  def business_os_audit_record, do: "business_os.audit.record"

  @doc """
  Evaluating a SOC2/HIPAA/GDPR compliance rule against current system state.

  Span: `span.business_os.compliance.check`
  Kind: `internal`
  Stability: `development`
  """
  @spec business_os_compliance_check() :: String.t()
  def business_os_compliance_check, do: "business_os.compliance.check"

  @doc """
  All span names in this namespace.
  """
  @spec all() :: [String.t()]
  def all do
    [
      business_os_audit_record(),
      business_os_compliance_check()
    ]
  end
end