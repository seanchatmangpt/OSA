defmodule OpenTelemetry.SemConv.Incubating.ConformanceSpanNames do
  @moduledoc """
  Conformance semantic convention span names.

  Namespace: `conformance`

  This module is generated from the ChatmanGPT semantic convention registry.
  Do not edit manually — regenerate with:

      weaver registry generate -r ./semconv/model --templates ./semconv/templates elixir ./OSA/lib/osa/semconv/
  """

  @doc """
  Conformance checking span

  Span: `span.conformance`
  Kind: `internal`
  Stability: `development`
  """
  @spec conformance() :: String.t()
  def conformance, do: "conformance"

  @doc """
  Conformance checking — comparing a process trace against a discovered model.

  Span: `span.conformance.check`
  Kind: `internal`
  Stability: `development`
  """
  @spec conformance_check() :: String.t()
  def conformance_check, do: "conformance.check"

  @doc """
  All span names in this namespace.
  """
  @spec all() :: [String.t()]
  def all do
    [
      conformance(),
      conformance_check()
    ]
  end
end