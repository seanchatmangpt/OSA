defmodule OpenTelemetry.SemConv.ConsensusIter16Attributes do
  @moduledoc "Wave 9 Iteration 16: Consensus Leader Rotation attributes."

  def consensus_leader_rotation_count, do: :"consensus.leader.rotation_count"
  def consensus_leader_tenure_ms, do: :"consensus.leader.tenure_ms"
  def consensus_leader_score, do: :"consensus.leader.score"
end
