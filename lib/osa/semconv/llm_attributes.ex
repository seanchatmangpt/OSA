defmodule OpenTelemetry.SemConv.Incubating.LlmAttributes do
  @moduledoc """
  LLM semantic convention attributes for ChatmanGPT.

  Namespace: `llm`

  This module is generated from the ChatmanGPT semantic convention registry.
  Do not edit manually — regenerate with:

      weaver registry generate -r ./semconv/model --templates ./semconv/templates elixir ./OSA/lib/osa/semconv/

  Wave 9 iteration 8
  """

  @doc """
  The model identifier used for this LLM invocation.

  Attribute: `llm.model`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `claude-sonnet-4-6`, `gpt-4o`, `llama3`
  """
  @spec llm_model() :: :"llm.model"
  def llm_model, do: :"llm.model"

  @doc """
  The provider of the LLM service.

  Attribute: `llm.provider`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `anthropic`, `openai`, `ollama`, `openrouter`
  """
  @spec llm_provider() :: :"llm.provider"
  def llm_provider, do: :"llm.provider"

  @doc """
  Number of input tokens consumed by this LLM invocation.

  Attribute: `llm.token.input`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `128`, `1024`, `8192`
  """
  @spec llm_token_input() :: :"llm.token.input"
  def llm_token_input, do: :"llm.token.input"

  @doc """
  Number of output tokens produced by this LLM invocation.

  Attribute: `llm.token.output`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `64`, `512`, `2048`
  """
  @spec llm_token_output() :: :"llm.token.output"
  def llm_token_output, do: :"llm.token.output"

  @doc """
  End-to-end latency of the LLM invocation in milliseconds.

  Attribute: `llm.latency_ms`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `250`, `1200`, `8500`
  """
  @spec llm_latency_ms() :: :"llm.latency_ms"
  def llm_latency_ms, do: :"llm.latency_ms"

  @doc """
  Sampling temperature used for this LLM invocation.

  Attribute: `llm.temperature`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0.0`, `0.7`, `1.0`
  """
  @spec llm_temperature() :: :"llm.temperature"
  def llm_temperature, do: :"llm.temperature"

  @doc """
  Reason the LLM stopped generating tokens.

  Attribute: `llm.stop_reason`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `end_turn`, `max_tokens`, `stop_sequence`
  """
  @spec llm_stop_reason() :: :"llm.stop_reason"
  def llm_stop_reason, do: :"llm.stop_reason"

  @doc """
  Enumerated values for `llm.stop_reason`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `max_tokens` | `"max_tokens"` | Output was truncated at the token limit |
  | `stop_sequence` | `"stop_sequence"` | A stop sequence was matched |
  | `length` | `"length"` | Maximum length reached |
  | `end_turn` | `"end_turn"` | Model signalled end of turn naturally |
  | `tool_use` | `"tool_use"` | Model is requesting a tool call |
  """
  @spec llm_stop_reason_values() :: %{
    max_tokens: :max_tokens,
    stop_sequence: :stop_sequence,
    length: :length,
    end_turn: :end_turn,
    tool_use: :tool_use
  }
  def llm_stop_reason_values do
    %{
      max_tokens: :max_tokens,
      stop_sequence: :stop_sequence,
      length: :length,
      end_turn: :end_turn,
      tool_use: :tool_use
    }
  end

end
