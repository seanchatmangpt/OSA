defmodule OpenTelemetry.SemConv.LLMIter17Attributes do
  @moduledoc "Wave 9 Iteration 17: LLM Context Management attributes."
  def llm_context_max_tokens, do: :"llm.context.max_tokens"
  def llm_context_overflow_strategy, do: :"llm.context.overflow_strategy"
  def llm_context_utilization, do: :"llm.context.utilization"
end
