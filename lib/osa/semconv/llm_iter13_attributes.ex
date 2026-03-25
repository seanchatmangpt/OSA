defmodule OpenTelemetry.SemConv.LlmIter13Attributes do
  @moduledoc "LLM chain-of-thought semantic convention attributes (iter13)."
  def llm_chain_of_thought_steps, do: :"llm.chain_of_thought.steps"
  def llm_chain_of_thought_enabled, do: :"llm.chain_of_thought.enabled"
  def llm_tool_call_count, do: :"llm.tool.call_count"
  def llm_cache_hit, do: :"llm.cache.hit"
end
