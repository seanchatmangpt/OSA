defmodule OpenTelemetry.SemConv.ConsensusIter14Attributes do
  @moduledoc "Consensus fault tolerance semantic convention attributes (iter14)."

  @spec consensus_byzantine_faults :: :"consensus.byzantine.faults"
  def consensus_byzantine_faults, do: :"consensus.byzantine.faults"

  @spec consensus_replica_lag_ms :: :"consensus.replica.lag_ms"
  def consensus_replica_lag_ms, do: :"consensus.replica.lag_ms"

  @spec consensus_replica_count :: :"consensus.replica.count"
  def consensus_replica_count, do: :"consensus.replica.count"
end
