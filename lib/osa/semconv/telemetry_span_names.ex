defmodule OpenTelemetry.SemConv.Incubating.TelemetrySpanNames do
  @moduledoc """
  Telemetry semantic convention span names.

  Namespace: `telemetry`

  This module is generated from the ChatmanGPT semantic convention registry.
  Do not edit manually — regenerate with:

      weaver registry generate -r ./semconv/model --templates ./semconv/templates elixir ./OSA/lib/osa/semconv/
  """

  @doc """
  Telemetry infrastructure span

  Span: `span.telemetry`
  Kind: `internal`
  Stability: `development`
  """
  @spec telemetry() :: String.t()
  def telemetry, do: "telemetry"

  @doc """
  All span names in this namespace.
  """
  @spec all() :: [String.t()]
  def all do
    [
      telemetry()
    ]
  end
end