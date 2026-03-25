defmodule OpenTelemetry.SemConv.LlmIter14Attributes do
  @moduledoc "LLM token budget semantic convention attributes (iter14)."

  @spec llm_token_prompt_count :: :"llm.token.prompt_count"
  def llm_token_prompt_count, do: :"llm.token.prompt_count"

  @spec llm_token_completion_count :: :"llm.token.completion_count"
  def llm_token_completion_count, do: :"llm.token.completion_count"

  @spec llm_token_budget_remaining :: :"llm.token.budget_remaining"
  def llm_token_budget_remaining, do: :"llm.token.budget_remaining"

  @spec llm_model_version :: :"llm.model.version"
  def llm_model_version, do: :"llm.model.version"
end
