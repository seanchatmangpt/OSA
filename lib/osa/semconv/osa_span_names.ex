defmodule OpenTelemetry.SemConv.Incubating.OsaSpanNames do
  @moduledoc """
  Osa semantic convention span names.

  Namespace: `osa`

  This module is generated from the ChatmanGPT semantic convention registry.
  Do not edit manually — regenerate with:

      weaver registry generate -r ./semconv/model --templates ./semconv/templates elixir ./OSA/lib/osa/semconv/
  """

  @doc """
  OSA provider chat completion — LLM inference call bridged from telemetry to OTEL.

  Span: `span.osa.providers.chat.complete`
  Kind: `internal`
  Stability: `development`
  """
  @spec osa_providers_chat_complete() :: String.t()
  def osa_providers_chat_complete, do: "osa.providers.chat.complete"

  @doc """
  All span names in this namespace.
  """
  @spec all() :: [String.t()]
  def all do
    [
      osa_providers_chat_complete()
    ]
  end
end