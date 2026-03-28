defmodule OpenTelemetry.SemConv.Incubating.OcpmSpanNames do
  @moduledoc """
  Ocpm semantic convention span names.

  Namespace: `ocpm`

  This module is generated from the ChatmanGPT semantic convention registry.
  Do not edit manually — regenerate with:

      weaver registry generate -r ./semconv/model --templates ./semconv/templates elixir ./OSA/lib/osa/semconv/
  """

  @doc """
  Object-Centric token replay conformance check

  Span: `span.ocpm.conformance.check`
  Kind: `internal`
  Stability: `development`
  """
  @spec ocpm_conformance_check() :: String.t()
  def ocpm_conformance_check, do: "ocpm.conformance.check"

  @doc """
  Object-Centric DFG discovery from an OCEL 2.0 log

  Span: `span.ocpm.discovery.dfg`
  Kind: `internal`
  Stability: `development`
  """
  @spec ocpm_discovery_dfg() :: String.t()
  def ocpm_discovery_dfg, do: "ocpm.discovery.dfg"

  @doc """
  Object-Centric Petri Net discovery from an OCEL 2.0 log

  Span: `span.ocpm.discovery.petri_net`
  Kind: `internal`
  Stability: `development`
  """
  @spec ocpm_discovery_petri_net() :: String.t()
  def ocpm_discovery_petri_net, do: "ocpm.discovery.petri_net"

  @doc """
  OCEL-grounded LLM query — RAG over real process data (Connection 4)

  Span: `span.ocpm.llm.query`
  Kind: `client`
  Stability: `development`
  """
  @spec ocpm_llm_query() :: String.t()
  def ocpm_llm_query, do: "ocpm.llm.query"

  @doc """
  OCEL 2.0 log ingestion — parse and load into ObjectCentricEventLog

  Span: `span.ocpm.ocel.ingest`
  Kind: `internal`
  Stability: `development`
  """
  @spec ocpm_ocel_ingest() :: String.t()
  def ocpm_ocel_ingest, do: "ocpm.ocel.ingest"

  @doc """
  Object-Centric bottleneck detection — top-N edges by severity score

  Span: `span.ocpm.performance.bottleneck`
  Kind: `internal`
  Stability: `development`
  """
  @spec ocpm_performance_bottleneck() :: String.t()
  def ocpm_performance_bottleneck, do: "ocpm.performance.bottleneck"

  @doc """
  Object-Centric throughput computation — end-to-end duration per object type

  Span: `span.ocpm.performance.throughput`
  Kind: `internal`
  Stability: `development`
  """
  @spec ocpm_performance_throughput() :: String.t()
  def ocpm_performance_throughput, do: "ocpm.performance.throughput"

  @doc """
  All span names in this namespace.
  """
  @spec all() :: [String.t()]
  def all do
    [
      ocpm_conformance_check(),
      ocpm_discovery_dfg(),
      ocpm_discovery_petri_net(),
      ocpm_llm_query(),
      ocpm_ocel_ingest(),
      ocpm_performance_bottleneck(),
      ocpm_performance_throughput()
    ]
  end
end