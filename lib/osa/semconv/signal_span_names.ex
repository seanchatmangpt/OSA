defmodule OpenTelemetry.SemConv.Incubating.SignalSpanNames do
  @moduledoc """
  Signal semantic convention span names.

  Namespace: `signal`

  This module is generated from the ChatmanGPT semantic convention registry.
  Do not edit manually — regenerate with:

      weaver registry generate -r ./semconv/model --templates ./semconv/templates elixir ./OSA/lib/osa/semconv/
  """

  @doc """
  Batch aggregation of signals — collecting signals within a time window and processing them as a group.

  Span: `span.signal.batch.aggregate`
  Kind: `internal`
  Stability: `development`
  """
  @spec signal_batch_aggregate() :: String.t()
  def signal_batch_aggregate, do: "signal.batch.aggregate"

  @doc """
  Classifies a signal's mode, genre, and type according to Signal Theory S=(M,G,T,F,W).

  Span: `span.signal.classify`
  Kind: `internal`
  Stability: `development`
  """
  @spec signal_classify() :: String.t()
  def signal_classify, do: "signal.classify"

  @doc """
  Compressing a signal payload before transmission — bandwidth optimization.

  Span: `span.signal.compress`
  Kind: `internal`
  Stability: `development`
  """
  @spec signal_compress() :: String.t()
  def signal_compress, do: "signal.compress"

  @doc """
  Signal deserialization — decoding a received signal payload from its wire format.

  Span: `span.signal.decode`
  Kind: `internal`
  Stability: `development`
  """
  @spec signal_decode() :: String.t()
  def signal_decode, do: "signal.decode"

  @doc """
  Encoding of a signal using the S=(M,G,T,F,W) Signal Theory model.

  Span: `span.signal.encode`
  Kind: `internal`
  Stability: `development`
  """
  @spec signal_encode() :: String.t()
  def signal_encode, do: "signal.encode"

  @doc """
  Applies the S/N gate to filter noise — signals below the weight threshold are rejected.

  Span: `span.signal.filter`
  Kind: `internal`
  Stability: `development`
  """
  @spec signal_filter() :: String.t()
  def signal_filter, do: "signal.filter"

  @doc """
  Assessing the composite quality of a signal against acceptance thresholds.

  Span: `span.signal.quality.assess`
  Kind: `internal`
  Stability: `development`
  """
  @spec signal_quality_assess() :: String.t()
  def signal_quality_assess, do: "signal.quality.assess"

  @doc """
  Signal routing decision — determining which service or agent receives this signal.

  Span: `span.signal.route`
  Kind: `internal`
  Stability: `development`
  """
  @spec signal_route() :: String.t()
  def signal_route, do: "signal.route"

  @doc """
  Signal quality gate — filters signals below S/N ratio threshold.

  Span: `span.signal.sn_gate`
  Kind: `internal`
  Stability: `development`
  """
  @spec signal_sn_gate() :: String.t()
  def signal_sn_gate, do: "signal.sn_gate"

  @doc """
  All span names in this namespace.
  """
  @spec all() :: [String.t()]
  def all do
    [
      signal_batch_aggregate(),
      signal_classify(),
      signal_compress(),
      signal_decode(),
      signal_encode(),
      signal_filter(),
      signal_quality_assess(),
      signal_route(),
      signal_sn_gate()
    ]
  end
end