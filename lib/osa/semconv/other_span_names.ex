defmodule OpenTelemetry.SemConv.Incubating.OtherSpanNames do
  @moduledoc """
  Other semantic convention span names.

  Namespace: `other`

  This module is generated from the ChatmanGPT semantic convention registry.
  Do not edit manually — regenerate with:

      weaver registry generate -r ./semconv/model --templates ./semconv/templates elixir ./OSA/lib/osa/semconv/
  """

  @doc """
  Other/miscellaneous span

  Span: `span.other`
  Kind: `internal`
  Stability: `development`
  """
  @spec other() :: String.t()
  def other, do: "other"

  @doc """
  All span names in this namespace.
  """
  @spec all() :: [String.t()]
  def all do
    [
      other()
    ]
  end
end