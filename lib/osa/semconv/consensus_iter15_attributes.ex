defmodule OpenTelemetry.SemConv.ConsensusIter15Attributes do
  @moduledoc "Consensus Liveness semantic convention attributes (iter15)."

  @spec consensus_liveness_proof_rounds :: :"consensus.liveness.proof_rounds"
  def consensus_liveness_proof_rounds, do: :"consensus.liveness.proof_rounds"

  @spec consensus_network_recovery_ms :: :"consensus.network.recovery_ms"
  def consensus_network_recovery_ms, do: :"consensus.network.recovery_ms"

  @spec consensus_view_duration_ms :: :"consensus.view.duration_ms"
  def consensus_view_duration_ms, do: :"consensus.view.duration_ms"
end
