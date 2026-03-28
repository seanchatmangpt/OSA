defmodule OpenTelemetry.SemConv.Incubating.GroqAttributes do
  @moduledoc """
  Groq workflow decision semantic convention attributes.

  Namespace: `groq`, `decision`

  These attributes are emitted on `groq.workflow.decision` spans that bridge
  a Groq LLM response to a YAWL workflow action.
  """

  @doc """
  The Groq model identifier used for the LLM call.

  Attribute: `groq.model`
  Type: `string`
  Stability: `development`
  Requirement: `required`
  Examples: `openai/gpt-oss-20b`, `openai/gpt-oss-20b`
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
  The YAWL Workflow Control-flow Pattern identifier that the Groq decision targets.

  Attribute: `decision.wcp_pattern`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `WCP01`, `WCP02`, `WCP04`
  """
  @spec decision_wcp_pattern() :: :"decision.wcp_pattern"
  def decision_wcp_pattern, do: :"decision.wcp_pattern"

  @doc """
  JSON-encoded result of the Groq workflow decision (e.g. action, confidence).

  Attribute: `decision.result`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `{"action":"launch_case","confidence":0.95}`
  """
  @spec decision_result() :: :"decision.result"
  def decision_result, do: :"decision.result"
end
