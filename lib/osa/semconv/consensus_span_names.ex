defmodule OpenTelemetry.SemConv.Incubating.ConsensusSpanNames do
  @moduledoc """
  Consensus semantic convention span names.

  Namespace: `consensus`

  This module is generated from the ChatmanGPT semantic convention registry.
  Do not edit manually — regenerate with:

      weaver registry generate -r ./semconv/model --templates ./semconv/templates elixir ./OSA/lib/osa/semconv/
  """

  @doc """
  Committing a decided value as a block in the HotStuff BFT log.

  Span: `span.consensus.block.commit`
  Kind: `internal`
  Stability: `development`
  """
  @spec consensus_block_commit() :: String.t()
  def consensus_block_commit, do: "consensus.block.commit"

  @doc """
  Byzantine fault recovery — adjusts quorum and restores consensus after detecting byzantine behavior.

  Span: `span.consensus.byzantine.recover`
  Kind: `internal`
  Stability: `development`
  """
  @spec consensus_byzantine_recover() :: String.t()
  def consensus_byzantine_recover, do: "consensus.byzantine.recover"

  @doc """
  Epoch advancement — consensus protocol advances to a new epoch after configuration change or key rotation.

  Span: `span.consensus.epoch.advance`
  Kind: `internal`
  Stability: `development`
  """
  @spec consensus_epoch_advance() :: String.t()
  def consensus_epoch_advance, do: "consensus.epoch.advance"

  @doc """
  Epoch finalization — collecting signatures and committing the final state of a consensus epoch.

  Span: `span.consensus.epoch.finalize`
  Kind: `internal`
  Stability: `development`
  """
  @spec consensus_epoch_finalize() :: String.t()
  def consensus_epoch_finalize, do: "consensus.epoch.finalize"

  @doc """
  Epoch key rotation — rotating cryptographic keys for a consensus epoch after a configuration change or compromise.

  Span: `span.consensus.epoch.key_rotate`
  Kind: `internal`
  Stability: `development`
  """
  @spec consensus_epoch_key_rotate() :: String.t()
  def consensus_epoch_key_rotate, do: "consensus.epoch.key_rotate"

  @doc """
  Epoch quorum snapshot — capturing the quorum membership set at an epoch boundary.

  Span: `span.consensus.epoch.quorum_snapshot`
  Kind: `internal`
  Stability: `development`
  """
  @spec consensus_epoch_quorum_snapshot() :: String.t()
  def consensus_epoch_quorum_snapshot, do: "consensus.epoch.quorum_snapshot"

  @doc """
  Epoch transition in the consensus protocol — moving from one epoch to the next.

  Span: `span.consensus.epoch.transition`
  Kind: `internal`
  Stability: `development`
  """
  @spec consensus_epoch_transition() :: String.t()
  def consensus_epoch_transition, do: "consensus.epoch.transition"

  @doc """
  Fork detection in the consensus chain — identifies diverged branches and applies resolution strategy.

  Span: `span.consensus.fork.detect`
  Kind: `internal`
  Stability: `development`
  """
  @spec consensus_fork_detect() :: String.t()
  def consensus_fork_detect, do: "consensus.fork.detect"

  @doc """
  Leader rotation event — current leader yields and new leader is selected via scoring.

  Span: `span.consensus.leader.rotate`
  Kind: `internal`
  Stability: `development`
  """
  @spec consensus_leader_rotate() :: String.t()
  def consensus_leader_rotate, do: "consensus.leader.rotate"

  @doc """
  Leader election event in HotStuff BFT — new leader selected after view change.

  Span: `span.consensus.leader_election`
  Kind: `internal`
  Stability: `development`
  """
  @spec consensus_leader_election() :: String.t()
  def consensus_leader_election, do: "consensus.leader_election"

  @doc """
  Verifying liveness of the consensus protocol — confirming progress is being made.

  Span: `span.consensus.liveness.check`
  Kind: `internal`
  Stability: `development`
  """
  @spec consensus_liveness_check() :: String.t()
  def consensus_liveness_check, do: "consensus.liveness.check"

  @doc """
  Network recovery — restoring consensus network connectivity after partition or node failure.

  Span: `span.consensus.network.recovery`
  Kind: `internal`
  Stability: `development`
  """
  @spec consensus_network_recovery() :: String.t()
  def consensus_network_recovery, do: "consensus.network.recovery"

  @doc """
  Network topology snapshot — capturing current consensus cluster topology for analysis and fault diagnosis.

  Span: `span.consensus.network.topology`
  Kind: `internal`
  Stability: `development`
  """
  @spec consensus_network_topology() :: String.t()
  def consensus_network_topology, do: "consensus.network.topology"

  @doc """
  Network partition recovery — restoring consensus after a partition splits the replica set.

  Span: `span.consensus.partition.recover`
  Kind: `internal`
  Stability: `development`
  """
  @spec consensus_partition_recover() :: String.t()
  def consensus_partition_recover, do: "consensus.partition.recover"

  @doc """
  Quorum growth operation — adding new replicas to expand the consensus quorum size.

  Span: `span.consensus.quorum.grow`
  Kind: `internal`
  Stability: `development`
  """
  @spec consensus_quorum_grow() :: String.t()
  def consensus_quorum_grow, do: "consensus.quorum.grow"

  @doc """
  Quorum shrink operation — removing nodes from the consensus quorum safely.

  Span: `span.consensus.quorum.shrink`
  Kind: `internal`
  Stability: `development`
  """
  @spec consensus_quorum_shrink() :: String.t()
  def consensus_quorum_shrink, do: "consensus.quorum.shrink"

  @doc """
  Synchronization of a replica to catch up with the consensus leader.

  Span: `span.consensus.replica.sync`
  Kind: `internal`
  Stability: `development`
  """
  @spec consensus_replica_sync() :: String.t()
  def consensus_replica_sync, do: "consensus.replica.sync"

  @doc """
  A single round in the OSA HotStuff BFT consensus protocol.

  Span: `span.consensus.round`
  Kind: `internal`
  Stability: `development`
  """
  @spec consensus_round() :: String.t()
  def consensus_round, do: "consensus.round"

  @doc """
  Checking consensus safety — validating that quorum meets safety threshold before committing.

  Span: `span.consensus.safety.check`
  Kind: `internal`
  Stability: `development`
  """
  @spec consensus_safety_check() :: String.t()
  def consensus_safety_check, do: "consensus.safety.check"

  @doc """
  Ongoing safety monitoring — continuously verifies BFT safety invariants across replica set.

  Span: `span.consensus.safety.monitor`
  Kind: `internal`
  Stability: `development`
  """
  @spec consensus_safety_monitor() :: String.t()
  def consensus_safety_monitor, do: "consensus.safety.monitor"

  @doc """
  Consensus threshold adaptation — dynamically adjusting the quorum threshold based on observed fault rates and network conditions.

  Span: `span.consensus.threshold.adapt`
  Kind: `internal`
  Stability: `development`
  """
  @spec consensus_threshold_adapt() :: String.t()
  def consensus_threshold_adapt, do: "consensus.threshold.adapt"

  @doc """
  Consensus threshold voting — executing a threshold-based vote among replicas.

  Span: `span.consensus.threshold.vote`
  Kind: `internal`
  Stability: `development`
  """
  @spec consensus_threshold_vote() :: String.t()
  def consensus_threshold_vote, do: "consensus.threshold.vote"

  @doc """
  View timeout event — current view timed out, triggering view change protocol.

  Span: `span.consensus.timeout_event`
  Kind: `internal`
  Stability: `development`
  """
  @spec consensus_timeout_event() :: String.t()
  def consensus_timeout_event, do: "consensus.timeout_event"

  @doc """
  View change event — leader timeout triggered, transitioning to new leader.

  Span: `span.consensus.view_change`
  Kind: `internal`
  Stability: `development`
  """
  @spec consensus_view_change() :: String.t()
  def consensus_view_change, do: "consensus.view_change"

  @doc """
  Optimized view change with exponential backoff — reduces thrashing during network instability.

  Span: `span.consensus.view_change.optimize`
  Kind: `internal`
  Stability: `development`
  """
  @spec consensus_view_change_optimize() :: String.t()
  def consensus_view_change_optimize, do: "consensus.view_change.optimize"

  @doc """
  Casting or receiving a single vote in a HotStuff BFT round.

  Span: `span.consensus.vote`
  Kind: `internal`
  Stability: `development`
  """
  @spec consensus_vote() :: String.t()
  def consensus_vote, do: "consensus.vote"

  @doc """
  All span names in this namespace.
  """
  @spec all() :: [String.t()]
  def all do
    [
      consensus_block_commit(),
      consensus_byzantine_recover(),
      consensus_epoch_advance(),
      consensus_epoch_finalize(),
      consensus_epoch_key_rotate(),
      consensus_epoch_quorum_snapshot(),
      consensus_epoch_transition(),
      consensus_fork_detect(),
      consensus_leader_rotate(),
      consensus_leader_election(),
      consensus_liveness_check(),
      consensus_network_recovery(),
      consensus_network_topology(),
      consensus_partition_recover(),
      consensus_quorum_grow(),
      consensus_quorum_shrink(),
      consensus_replica_sync(),
      consensus_round(),
      consensus_safety_check(),
      consensus_safety_monitor(),
      consensus_threshold_adapt(),
      consensus_threshold_vote(),
      consensus_timeout_event(),
      consensus_view_change(),
      consensus_view_change_optimize(),
      consensus_vote()
    ]
  end
end