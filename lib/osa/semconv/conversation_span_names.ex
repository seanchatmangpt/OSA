defmodule OpenTelemetry.SemConv.Incubating.ConversationSpanNames do
  @moduledoc """
  Conversation semantic convention span names.

  Namespace: `conversation`

  This module is generated from the ChatmanGPT semantic convention registry.
  Do not edit manually — regenerate with:

      weaver registry generate -r ./semconv/model --templates ./semconv/templates elixir ./OSA/lib/osa/semconv/
  """

  @doc """
  Context compression — summarizing or truncating conversation history to fit context window.

  Span: `span.conversation.compress`
  Kind: `internal`
  Stability: `development`
  """
  @spec conversation_compress() :: String.t()
  def conversation_compress, do: "conversation.compress"

  @doc """
  Conversation session initialization — first turn, context loaded.

  Span: `span.conversation.start`
  Kind: `internal`
  Stability: `development`
  """
  @spec conversation_start() :: String.t()
  def conversation_start, do: "conversation.start"

  @doc """
  Single conversation turn — user message received, assistant response generated.

  Span: `span.conversation.turn`
  Kind: `internal`
  Stability: `development`
  """
  @spec conversation_turn() :: String.t()
  def conversation_turn, do: "conversation.turn"

  @doc """
  All span names in this namespace.
  """
  @spec all() :: [String.t()]
  def all do
    [
      conversation_compress(),
      conversation_start(),
      conversation_turn()
    ]
  end
end