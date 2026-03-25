defmodule OpenTelemetry.SemConv.PMIter15Attributes do
  @moduledoc "Process Mining Replay semantic convention attributes (iter15)."

  @spec process_mining_replay_enabled_transitions :: :"process.mining.replay.enabled_transitions"
  def process_mining_replay_enabled_transitions, do: :"process.mining.replay.enabled_transitions"

  @spec process_mining_replay_missing_tokens :: :"process.mining.replay.missing_tokens"
  def process_mining_replay_missing_tokens, do: :"process.mining.replay.missing_tokens"

  @spec process_mining_replay_consumed_tokens :: :"process.mining.replay.consumed_tokens"
  def process_mining_replay_consumed_tokens, do: :"process.mining.replay.consumed_tokens"

  @spec process_mining_case_variant_id :: :"process.mining.case.variant_id"
  def process_mining_case_variant_id, do: :"process.mining.case.variant_id"
end
