defmodule OpenTelemetry.SemConv.ConsensusIter17Attributes do
  @moduledoc "Wave 9 Iteration 17: Consensus View Change attributes."
  def consensus_view_change_reason, do: :"consensus.view_change.reason"
  def consensus_view_change_duration_ms, do: :"consensus.view_change.duration_ms"
  def consensus_view_change_backoff_ms, do: :"consensus.view_change.backoff_ms"
end
