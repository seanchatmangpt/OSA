defmodule OpenTelemetry.SemConv.Incubating.ConversationAttributes do
  @moduledoc """
  Conversation semantic convention attributes.

  Namespace: `conversation`

  This module is generated from the ChatmanGPT semantic convention registry.
  Do not edit manually — regenerate with:

      weaver registry generate -r ./semconv/model --templates ./semconv/templates elixir ./OSA/lib/osa/semconv/
  """

  @doc """
  Current context window usage in tokens for this conversation.

  Attribute: `conversation.context_tokens`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `1024`, `16384`, `100000`
  """
  @spec conversation_context_tokens() :: :"conversation.context_tokens"
  def conversation_context_tokens, do: :"conversation.context_tokens"

  @doc """
  Unique identifier for this conversation session.

  Attribute: `conversation.id`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `conv-abc123-x7y`, `session-20260325-001`
  """
  @spec conversation_id() :: :"conversation.id"
  def conversation_id, do: :"conversation.id"

  @doc """
  Role of the message sender in the conversation.

  Attribute: `conversation.message.role`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `user`, `assistant`
  """
  @spec conversation_message_role() :: :"conversation.message.role"
  def conversation_message_role, do: :"conversation.message.role"

  @doc """
  Enumerated values for `conversation.message.role`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `user` | `"user"` | user |
  | `assistant` | `"assistant"` | assistant |
  | `system` | `"system"` | system |
  | `tool` | `"tool"` | tool |
  """
  @spec conversation_message_role_values() :: %{
    user: :user,
    assistant: :assistant,
    system: :system,
    tool: :tool
  }
  def conversation_message_role_values do
    %{
      user: :user,
      assistant: :assistant,
      system: :system,
      tool: :tool
    }
  end

  defmodule ConversationMessageRoleValues do
    @moduledoc """
    Typed constants for the `conversation.message.role` attribute.
    """

    @doc "user"
    @spec user() :: :user
    def user, do: :user

    @doc "assistant"
    @spec assistant() :: :assistant
    def assistant, do: :assistant

    @doc "system"
    @spec system() :: :system
    def system, do: :system

    @doc "tool"
    @spec tool() :: :tool
    def tool, do: :tool

  end

  @doc """
  The LLM model driving this conversation (same as llm.model but conversation-scoped).

  Attribute: `conversation.model`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `claude-sonnet-4-6`, `claude-opus-4-6`
  """
  @spec conversation_model() :: :"conversation.model"
  def conversation_model, do: :"conversation.model"

  @doc """
  Current phase of the conversation lifecycle.

  Attribute: `conversation.phase`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `active`, `complete`
  """
  @spec conversation_phase() :: :"conversation.phase"
  def conversation_phase, do: :"conversation.phase"

  @doc """
  Enumerated values for `conversation.phase`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `init` | `"init"` | init |
  | `active` | `"active"` | active |
  | `waiting` | `"waiting"` | waiting |
  | `complete` | `"complete"` | complete |
  | `error` | `"error"` | error |
  """
  @spec conversation_phase_values() :: %{
    init: :init,
    active: :active,
    waiting: :waiting,
    complete: :complete,
    error: :error
  }
  def conversation_phase_values do
    %{
      init: :init,
      active: :active,
      waiting: :waiting,
      complete: :complete,
      error: :error
    }
  end

  defmodule ConversationPhaseValues do
    @moduledoc """
    Typed constants for the `conversation.phase` attribute.
    """

    @doc "init"
    @spec init() :: :init
    def init, do: :init

    @doc "active"
    @spec active() :: :active
    def active, do: :active

    @doc "waiting"
    @spec waiting() :: :waiting
    def waiting, do: :waiting

    @doc "complete"
    @spec complete() :: :complete
    def complete, do: :complete

    @doc "error"
    @spec error() :: :error
    def error, do: :error

  end

  @doc """
  Token count of the compressed summary after context compression.

  Attribute: `conversation.summary.tokens`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `512`, `1024`, `2048`
  """
  @spec conversation_summary_tokens() :: :"conversation.summary.tokens"
  def conversation_summary_tokens, do: :"conversation.summary.tokens"

  @doc """
  Cumulative number of tool calls made during this conversation.

  Attribute: `conversation.tool_calls`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0`, `5`, `100`
  """
  @spec conversation_tool_calls() :: :"conversation.tool_calls"
  def conversation_tool_calls, do: :"conversation.tool_calls"

  @doc """
  Total number of turns (human+assistant message pairs) in this conversation.

  Attribute: `conversation.turn_count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `1`, `5`, `50`
  """
  @spec conversation_turn_count() :: :"conversation.turn_count"
  def conversation_turn_count, do: :"conversation.turn_count"

  @doc """
  Anonymized identifier of the user in this conversation (for correlation, not PII).

  Attribute: `conversation.user_id`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `user-hash-abc123`, `anon-7f8d9e`
  """
  @spec conversation_user_id() :: :"conversation.user_id"
  def conversation_user_id, do: :"conversation.user_id"

end