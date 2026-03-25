defmodule OpenTelemetry.SemConv.ConsensusIter13Attributes do
  @moduledoc "Consensus safety semantic convention attributes (iter13)."
  def consensus_safety_threshold, do: :"consensus.safety.threshold"
  def consensus_liveness_timeout_ratio, do: :"consensus.liveness.timeout_ratio"
  def consensus_network_partition_detected, do: :"consensus.network.partition_detected"
end
