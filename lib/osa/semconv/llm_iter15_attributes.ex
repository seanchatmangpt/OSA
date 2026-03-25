defmodule OpenTelemetry.SemConv.LLMIter15Attributes do
  @moduledoc "LLM Evaluation semantic convention attributes (iter15)."

  @spec llm_evaluation_score :: :"llm.evaluation.score"
  def llm_evaluation_score, do: :"llm.evaluation.score"

  @spec llm_evaluation_rubric :: :"llm.evaluation.rubric"
  def llm_evaluation_rubric, do: :"llm.evaluation.rubric"

  @spec llm_evaluation_passes_threshold :: :"llm.evaluation.passes_threshold"
  def llm_evaluation_passes_threshold, do: :"llm.evaluation.passes_threshold"
end
