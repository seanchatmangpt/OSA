defmodule OpenTelemetry.SemConv.Incubating.ConversationAttributes do
  @moduledoc """
  Conversation session semantic convention attributes.

  Namespace: `conversation`

  This module is generated from the ChatmanGPT semantic convention registry.
  Do not edit manually — regenerate with:

      weaver registry generate -r ./semconv/model --templates ./semconv/templates elixir ./OSA/lib/osa/semconv/
  """

  @doc """
  Unique identifier for the conversation session.

  Attribute: `conversation.id`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `conv-abc-001`, `sess-20260325-xyz`
  """
  @spec conversation_id :: :"conversation.id"
  def conversation_id, do: :"conversation.id"

  @doc """
  Total number of turns (user+assistant exchanges) in the conversation.

  Attribute: `conversation.turn_count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `1`, `5`, `20`
  """
  @spec conversation_turn_count :: :"conversation.turn_count"
  def conversation_turn_count, do: :"conversation.turn_count"

  @doc """
  LLM model identifier used for this conversation.

  Attribute: `conversation.model`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `claude-sonnet-4-6`, `gpt-4o`, `llama-3.1-70b`
  """
  @spec conversation_model :: :"conversation.model"
  def conversation_model, do: :"conversation.model"

  @doc """
  Current context window size in tokens.

  Attribute: `conversation.context_tokens`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `1024`, `8192`, `200000`
  """
  @spec conversation_context_tokens :: :"conversation.context_tokens"
  def conversation_context_tokens, do: :"conversation.context_tokens"

  @doc """
  Current lifecycle phase of the conversation.

  Attribute: `conversation.phase`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `init`, `active`, `complete`
  """
  @spec conversation_phase :: :"conversation.phase"
  def conversation_phase, do: :"conversation.phase"

  @doc """
  Enumerated values for `conversation.phase`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `init` | `"init"` | Conversation initializing |
  | `active` | `"active"` | Actively exchanging turns |
  | `waiting` | `"waiting"` | Waiting for user input |
  | `complete` | `"complete"` | Conversation finished successfully |
  | `error` | `"error"` | Conversation ended in error |
  """
  @spec conversation_phase_values() :: %{
    init: :init,
    active: :active,
    waiting: :waiting,
    complete: :complete,
    error: :error
  }
  def conversation_phase_values do
    %{init: :init, active: :active, waiting: :waiting, complete: :complete, error: :error}
  end

end
