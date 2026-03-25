defmodule OpenTelemetry.SemConv.PMIter16Attributes do
  @moduledoc "Wave 9 Iteration 16: Process Mining Decision Mining attributes."

  def process_mining_decision_point_id, do: :"process.mining.decision.point_id"
  def process_mining_decision_outcome, do: :"process.mining.decision.outcome"
  def process_mining_decision_confidence, do: :"process.mining.decision.confidence"
  def process_mining_decision_rule_count, do: :"process.mining.decision.rule_count"
end
