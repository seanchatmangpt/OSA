defmodule OpenTelemetry.SemConv.Incubating.GroqAttributes do
  @moduledoc """
  Groq semantic convention attributes.

  Namespace: `groq`

  This module is generated from the ChatmanGPT semantic convention registry.
  Do not edit manually — regenerate with:

      weaver registry generate -r ./semconv/model --templates ./semconv/templates elixir ./OSA/lib/osa/semconv/
  """

  @doc """
  The Groq model identifier used for the LLM call.

  Attribute: `groq.model`
  Type: `string`
  Stability: `development`
  Requirement: `required`
  Examples: `openai/gpt-oss-20b`, `llama-3.3-70b-versatile`
  """
  @spec groq_model() :: :"groq.model"
  def groq_model, do: :"groq.model"

  @doc """
  Number of prompt tokens consumed by the Groq LLM call.

  Attribute: `groq.prompt_tokens`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `128`, `256`
  """
  @spec groq_prompt_tokens() :: :"groq.prompt_tokens"
  def groq_prompt_tokens, do: :"groq.prompt_tokens"

  @doc """
  The WCP (Workflow Control Pattern) number selected by the Groq decision call.

  Attribute: `decision.wcp_pattern`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `WCP01`, `WCP02`, `WCP04`
  """
  @spec decision_wcp_pattern() :: :"decision.wcp_pattern"
  def decision_wcp_pattern, do: :"decision.wcp_pattern"

  @doc """
  The JSON-encoded decision result returned by the Groq LLM call.

  Attribute: `decision.result`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `{"action":"launch_case"}`, `{"action":"skip"}`
  """
  @spec decision_result() :: :"decision.result"
  def decision_result, do: :"decision.result"

end