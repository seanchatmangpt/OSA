defmodule OpenTelemetry.SemConv.Incubating.ServiceSpanNames do
  @moduledoc """
  Service semantic convention span names.

  Namespace: `service`

  This module is generated from the ChatmanGPT semantic convention registry.
  Do not edit manually — regenerate with:

      weaver registry generate -r ./semconv/model --templates ./semconv/templates elixir ./OSA/lib/osa/semconv/
  """

  @doc """
  Service-level observability span

  Span: `span.service`
  Kind: `internal`
  Stability: `development`
  """
  @spec service() :: String.t()
  def service, do: "service"

  @doc """
  All span names in this namespace.
  """
  @spec all() :: [String.t()]
  def all do
    [
      service()
    ]
  end
end