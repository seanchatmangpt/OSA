defmodule OpenTelemetry.SemConv.Incubating.ErrorSpanNames do
  @moduledoc """
  Error semantic convention span names.

  Namespace: `error`

  This module is generated from the ChatmanGPT semantic convention registry.
  Do not edit manually — regenerate with:

      weaver registry generate -r ./semconv/model --templates ./semconv/templates elixir ./OSA/lib/osa/semconv/
  """

  @doc """
  Error handling span

  Span: `span.error`
  Kind: `internal`
  Stability: `development`
  """
  @spec error() :: String.t()
  def error, do: "error"

  @doc """
  All span names in this namespace.
  """
  @spec all() :: [String.t()]
  def all do
    [
      error()
    ]
  end
end