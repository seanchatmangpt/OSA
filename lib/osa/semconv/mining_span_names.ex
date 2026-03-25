defmodule OpenTelemetry.SemConv.Incubating.MiningSpanNames do
  @moduledoc """
  Mining semantic convention span names.

  Namespace: `mining`

  This module is generated from the ChatmanGPT semantic convention registry.
  Do not edit manually — regenerate with:

      weaver registry generate -r ./semconv/model --templates ./semconv/templates elixir ./OSA/lib/osa/semconv/
  """

  @doc """
  Span emitted when CSV event data is ingested from Canopy

  Span: `process.mining.canopy.ingest`
  Kind: `consumer`
  Stability: `development`
  """
  @spec process_mining_canopy_ingest() :: String.t()
  def process_mining_canopy_ingest, do: "process.mining.canopy.ingest"

  @doc """
  Span emitted when declare constraint conformance is checked

  Span: `process.mining.declare.check`
  Kind: `internal`
  Stability: `development`
  """
  @spec process_mining_declare_check() :: String.t()
  def process_mining_declare_check, do: "process.mining.declare.check"

  @doc """
  Span emitted when predictive analytics (next activity, remaining time, outcome) is computed

  Span: `process.mining.prediction.make`
  Kind: `internal`
  Stability: `development`
  """
  @spec process_mining_prediction_make() :: String.t()
  def process_mining_prediction_make, do: "process.mining.prediction.make"

  @doc """
  Span emitted when organizational/social network analysis is performed

  Span: `process.mining.social_network.analyze`
  Kind: `internal`
  Stability: `development`
  """
  @spec process_mining_social_network_analyze() :: String.t()
  def process_mining_social_network_analyze, do: "process.mining.social_network.analyze"

  @doc """
  All span names in this namespace.
  """
  @spec all() :: [String.t()]
  def all do
    [
      process_mining_canopy_ingest(),
      process_mining_declare_check(),
      process_mining_prediction_make(),
      process_mining_social_network_analyze()
    ]
  end
end