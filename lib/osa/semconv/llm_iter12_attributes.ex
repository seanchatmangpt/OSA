defmodule OpenTelemetry.SemConv.LlmIter12Attributes do
  @moduledoc "LLM safety and guardrails semantic convention attributes (iter12)."

  @spec llm_safety_score :: :"llm.safety.score"
  def llm_safety_score, do: :"llm.safety.score"

  @spec llm_guardrail_triggered :: :"llm.guardrail.triggered"
  def llm_guardrail_triggered, do: :"llm.guardrail.triggered"

  @spec llm_guardrail_type :: :"llm.guardrail.type"
  def llm_guardrail_type, do: :"llm.guardrail.type"

  @spec llm_retry_count :: :"llm.retry.count"
  def llm_retry_count, do: :"llm.retry.count"
end
