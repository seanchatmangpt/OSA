defmodule OpenTelemetry.SemConv.Incubating.HostSpanNames do
  @moduledoc """
  Host semantic convention span names.

  Namespace: `host`

  This module is generated from the ChatmanGPT semantic convention registry.
  Do not edit manually — regenerate with:

      weaver registry generate -r ./semconv/model --templates ./semconv/templates elixir ./OSA/lib/osa/semconv/
  """

  @doc """
  Host-level observability span

  Span: `span.host`
  Kind: `internal`
  Stability: `development`
  """
  @spec host() :: String.t()
  def host, do: "host"

  @doc """
  All span names in this namespace.
  """
  @spec all() :: [String.t()]
  def all do
    [
      host()
    ]
  end
end