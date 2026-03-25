defmodule OpenTelemetry.SemConv.Incubating.ConformanceAttributes do
  @moduledoc """
  Conformance semantic convention attributes.

  This module is generated from the ChatmanGPT semantic convention registry.
  Do not edit manually — regenerate with `weaver registry generate elixir`.
  """

  @doc """
  Conformance fitness score [0.0, 1.0] measuring how well the trace fits the model.

  Stability: `development`
  """
  @spec conformance_fitness() :: :"conformance.fitness"
  def conformance_fitness, do: :"conformance.fitness"

  @doc """
  Conformance precision score [0.0, 1.0] measuring model over-fitting.

  Stability: `development`
  """
  @spec conformance_precision() :: :"conformance.precision"
  def conformance_precision, do: :"conformance.precision"
end