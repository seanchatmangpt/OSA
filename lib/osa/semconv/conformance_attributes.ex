defmodule OpenTelemetry.SemConv.Incubating.ConformanceAttributes do
  @moduledoc """
  Conformance semantic convention attributes.

  Namespace: `conformance`

  This module is generated from the ChatmanGPT semantic convention registry.
  Do not edit manually — regenerate with:

      weaver registry generate -r ./semconv/model --templates ./semconv/templates elixir ./OSA/lib/osa/semconv/
  """

  @doc """
  Conformance fitness score [0.0, 1.0] measuring how well the trace fits the model.

  Attribute: `conformance.fitness`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0.98`, `0.85`, `0.42`
  """
  @spec conformance_fitness() :: :conformance_fitness
  def conformance_fitness, do: :conformance_fitness

  @doc """
  Conformance precision score [0.0, 1.0] measuring model over-fitting.

  Attribute: `conformance.precision`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0.95`, `0.8`
  """
  @spec conformance_precision() :: :conformance_precision
  def conformance_precision, do: :conformance_precision

end