defmodule OpenTelemetry.SemConv.Incubating.ConsensusAttributes do
  @moduledoc """
  Consensus semantic convention attributes.

  Namespace: `consensus`

  This module is generated from the ChatmanGPT semantic convention registry.
  Do not edit manually — regenerate with:

      weaver registry generate -r ./semconv/model --templates ./semconv/templates elixir ./OSA/lib/osa/semconv/
  """

  @doc """
  Block height (sequence number) of the committed decision in the consensus log.

  Attribute: `consensus.block.height`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0`, `1000`, `42000`
  """
  @spec consensus_block_height() :: :"consensus.block.height"
  def consensus_block_height, do: :"consensus.block.height"

  @doc """
  Hash of the proposed block in this consensus round.

  Attribute: `consensus.block_hash`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0xabc123def456`, `0x7f8e9d0c1b2a`
  """
  @spec consensus_block_hash() :: :"consensus.block_hash"
  def consensus_block_hash, do: :"consensus.block_hash"

  @doc """
  Number of byzantine faults detected in the current epoch.

  Attribute: `consensus.byzantine.detected_faults`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0`, `1`, `3`
  """
  @spec consensus_byzantine_detected_faults() :: :"consensus.byzantine.detected_faults"
  def consensus_byzantine_detected_faults, do: :"consensus.byzantine.detected_faults"

  @doc """
  Number of quorum size adjustments made during byzantine recovery.

  Attribute: `consensus.byzantine.quorum_adjustments`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0`, `1`, `2`
  """
  @spec consensus_byzantine_quorum_adjustments() :: :"consensus.byzantine.quorum_adjustments"
  def consensus_byzantine_quorum_adjustments, do: :"consensus.byzantine.quorum_adjustments"

  @doc """
  Round number at which byzantine fault recovery was initiated.

  Attribute: `consensus.byzantine.recovery_round`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `1`, `5`, `12`
  """
  @spec consensus_byzantine_recovery_round() :: :"consensus.byzantine.recovery_round"
  def consensus_byzantine_recovery_round, do: :"consensus.byzantine.recovery_round"

  @doc """
  Number of Byzantine (malicious/faulty) nodes detected in the current consensus view.

  Attribute: `consensus.byzantine_faults`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0`, `1`, `2`
  """
  @spec consensus_byzantine_faults() :: :"consensus.byzantine_faults"
  def consensus_byzantine_faults, do: :"consensus.byzantine_faults"

  @doc """
  Hash or compact representation of the decided value (for audit/tracing purposes).

  Attribute: `consensus.decision.value`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `sha256:abc123`, `block:1000:hash`
  """
  @spec consensus_decision_value() :: :"consensus.decision.value"
  def consensus_decision_value, do: :"consensus.decision.value"

  @doc """
  Duration of the consensus epoch in milliseconds.

  Attribute: `consensus.epoch.duration_ms`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `1000`, `5000`, `30000`
  """
  @spec consensus_epoch_duration_ms() :: :"consensus.epoch.duration_ms"
  def consensus_epoch_duration_ms, do: :"consensus.epoch.duration_ms"

  @doc """
  The consensus round number at which the epoch was finalized.

  Attribute: `consensus.epoch.finalization.round`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `100`, `250`, `500`
  """
  @spec consensus_epoch_finalization_round() :: :"consensus.epoch.finalization.round"
  def consensus_epoch_finalization_round, do: :"consensus.epoch.finalization.round"

  @doc """
  Number of validator signatures collected for epoch finalization proof.

  Attribute: `consensus.epoch.finalization.signature_count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `5`, `10`, `21`
  """
  @spec consensus_epoch_finalization_signature_count() :: :"consensus.epoch.finalization.signature_count"
  def consensus_epoch_finalization_signature_count, do: :"consensus.epoch.finalization.signature_count"

  @doc """
  Monotonically increasing epoch identifier for the consensus protocol.

  Attribute: `consensus.epoch.id`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `1`, `42`, `100`
  """
  @spec consensus_epoch_id() :: :"consensus.epoch.id"
  def consensus_epoch_id, do: :"consensus.epoch.id"

  @doc """
  Unique identifier for the key rotation event within a consensus epoch.

  Attribute: `consensus.epoch.key_rotation_id`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `kr-epoch-5-001`, `kr-2026-03-25T12:00:00Z`
  """
  @spec consensus_epoch_key_rotation_id() :: :"consensus.epoch.key_rotation_id"
  def consensus_epoch_key_rotation_id, do: :"consensus.epoch.key_rotation_id"

  @doc """
  Duration of the key rotation operation in milliseconds.

  Attribute: `consensus.epoch.key_rotation_ms`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `50`, `200`, `1000`
  """
  @spec consensus_epoch_key_rotation_ms() :: :"consensus.epoch.key_rotation_ms"
  def consensus_epoch_key_rotation_ms, do: :"consensus.epoch.key_rotation_ms"

  @doc """
  Reason that triggered the epoch key rotation.

  Attribute: `consensus.epoch.key_rotation_reason`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `scheduled`, `compromise`, `membership_change`
  """
  @spec consensus_epoch_key_rotation_reason() :: :"consensus.epoch.key_rotation_reason"
  def consensus_epoch_key_rotation_reason, do: :"consensus.epoch.key_rotation_reason"

  @doc """
  Enumerated values for `consensus.epoch.key_rotation_reason`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `scheduled` | `"scheduled"` | scheduled |
  | `compromise` | `"compromise"` | compromise |
  | `membership_change` | `"membership_change"` | membership_change |
  """
  @spec consensus_epoch_key_rotation_reason_values() :: %{
    scheduled: :scheduled,
    compromise: :compromise,
    membership_change: :membership_change
  }
  def consensus_epoch_key_rotation_reason_values do
    %{
      scheduled: :scheduled,
      compromise: :compromise,
      membership_change: :membership_change
    }
  end

  defmodule ConsensusEpochKeyRotationReasonValues do
    @moduledoc """
    Typed constants for the `consensus.epoch.key_rotation_reason` attribute.
    """

    @doc "scheduled"
    @spec scheduled() :: :scheduled
    def scheduled, do: :scheduled

    @doc "compromise"
    @spec compromise() :: :compromise
    def compromise, do: :compromise

    @doc "membership_change"
    @spec membership_change() :: :membership_change
    def membership_change, do: :membership_change

  end

  @doc """
  Number of leader changes that occurred during this epoch.

  Attribute: `consensus.epoch.leader_changes`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0`, `1`, `5`
  """
  @spec consensus_epoch_leader_changes() :: :"consensus.epoch.leader_changes"
  def consensus_epoch_leader_changes, do: :"consensus.epoch.leader_changes"

  @doc """
  Hash of the quorum membership set for integrity verification.

  Attribute: `consensus.epoch.quorum_snapshot_hash`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `sha256:abc123`, `sha256:def456`
  """
  @spec consensus_epoch_quorum_snapshot_hash() :: :"consensus.epoch.quorum_snapshot_hash"
  def consensus_epoch_quorum_snapshot_hash, do: :"consensus.epoch.quorum_snapshot_hash"

  @doc """
  Round number at which the quorum snapshot was taken.

  Attribute: `consensus.epoch.quorum_snapshot_round`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `100`, `500`, `1200`
  """
  @spec consensus_epoch_quorum_snapshot_round() :: :"consensus.epoch.quorum_snapshot_round"
  def consensus_epoch_quorum_snapshot_round, do: :"consensus.epoch.quorum_snapshot_round"

  @doc """
  Number of nodes in the quorum at snapshot time.

  Attribute: `consensus.epoch.quorum_snapshot_size`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `4`, `7`, `10`
  """
  @spec consensus_epoch_quorum_snapshot_size() :: :"consensus.epoch.quorum_snapshot_size"
  def consensus_epoch_quorum_snapshot_size, do: :"consensus.epoch.quorum_snapshot_size"

  @doc """
  Round number at which this epoch began.

  Attribute: `consensus.epoch.start_round`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0`, `100`, `500`
  """
  @spec consensus_epoch_start_round() :: :"consensus.epoch.start_round"
  def consensus_epoch_start_round, do: :"consensus.epoch.start_round"

  @doc """
  The epoch number transitioning from.

  Attribute: `consensus.epoch.transition.from_epoch`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `1`, `5`, `42`
  """
  @spec consensus_epoch_transition_from_epoch() :: :"consensus.epoch.transition.from_epoch"
  def consensus_epoch_transition_from_epoch, do: :"consensus.epoch.transition.from_epoch"

  @doc """
  The epoch number transitioning to.

  Attribute: `consensus.epoch.transition.to_epoch`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `2`, `6`, `43`
  """
  @spec consensus_epoch_transition_to_epoch() :: :"consensus.epoch.transition.to_epoch"
  def consensus_epoch_transition_to_epoch, do: :"consensus.epoch.transition.to_epoch"

  @doc """
  Trigger that initiated the epoch transition.

  Attribute: `consensus.epoch.transition.trigger`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `timeout`, `quorum_change`, `key_rotation`
  """
  @spec consensus_epoch_transition_trigger() :: :"consensus.epoch.transition.trigger"
  def consensus_epoch_transition_trigger, do: :"consensus.epoch.transition.trigger"

  @doc """
  Enumerated values for `consensus.epoch.transition.trigger`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `timeout` | `"timeout"` | timeout |
  | `quorum_change` | `"quorum_change"` | quorum_change |
  | `key_rotation` | `"key_rotation"` | key_rotation |
  """
  @spec consensus_epoch_transition_trigger_values() :: %{
    timeout: :timeout,
    quorum_change: :quorum_change,
    key_rotation: :key_rotation
  }
  def consensus_epoch_transition_trigger_values do
    %{
      timeout: :timeout,
      quorum_change: :quorum_change,
      key_rotation: :key_rotation
    }
  end

  defmodule ConsensusEpochTransitionTriggerValues do
    @moduledoc """
    Typed constants for the `consensus.epoch.transition.trigger` attribute.
    """

    @doc "timeout"
    @spec timeout() :: :timeout
    def timeout, do: :timeout

    @doc "quorum_change"
    @spec quorum_change() :: :quorum_change
    def quorum_change, do: :quorum_change

    @doc "key_rotation"
    @spec key_rotation() :: :key_rotation
    def key_rotation, do: :key_rotation

  end

  @doc """
  Number of Byzantine failures detected in the current view.

  Attribute: `consensus.failure.count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0`, `1`, `2`
  """
  @spec consensus_failure_count() :: :"consensus.failure.count"
  def consensus_failure_count, do: :"consensus.failure.count"

  @doc """
  Depth of the detected fork — number of diverged blocks.

  Attribute: `consensus.fork.depth`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `1`, `3`, `10`
  """
  @spec consensus_fork_depth() :: :"consensus.fork.depth"
  def consensus_fork_depth, do: :"consensus.fork.depth"

  @doc """
  Whether a fork was detected in the consensus chain.

  Attribute: `consensus.fork.detected`
  Type: `boolean`
  Stability: `development`
  Requirement: `recommended`
  """
  @spec consensus_fork_detected() :: :"consensus.fork.detected"
  def consensus_fork_detected, do: :"consensus.fork.detected"

  @doc """
  Strategy used to resolve the detected fork.

  Attribute: `consensus.fork.resolution_strategy`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `longest_chain`, `epoch_based`
  """
  @spec consensus_fork_resolution_strategy() :: :"consensus.fork.resolution_strategy"
  def consensus_fork_resolution_strategy, do: :"consensus.fork.resolution_strategy"

  @doc """
  Enumerated values for `consensus.fork.resolution_strategy`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `longest_chain` | `"longest_chain"` | longest_chain |
  | `highest_vote` | `"highest_vote"` | highest_vote |
  | `epoch_based` | `"epoch_based"` | epoch_based |
  """
  @spec consensus_fork_resolution_strategy_values() :: %{
    longest_chain: :longest_chain,
    highest_vote: :highest_vote,
    epoch_based: :epoch_based
  }
  def consensus_fork_resolution_strategy_values do
    %{
      longest_chain: :longest_chain,
      highest_vote: :highest_vote,
      epoch_based: :epoch_based
    }
  end

  defmodule ConsensusForkResolutionStrategyValues do
    @moduledoc """
    Typed constants for the `consensus.fork.resolution_strategy` attribute.
    """

    @doc "longest_chain"
    @spec longest_chain() :: :longest_chain
    def longest_chain, do: :longest_chain

    @doc "highest_vote"
    @spec highest_vote() :: :highest_vote
    def highest_vote, do: :highest_vote

    @doc "epoch_based"
    @spec epoch_based() :: :epoch_based
    def epoch_based, do: :epoch_based

  end

  @doc """
  Latency of the consensus round in milliseconds.

  Attribute: `consensus.latency_ms`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `12`, `234`, `1500`
  """
  @spec consensus_latency_ms() :: :"consensus.latency_ms"
  def consensus_latency_ms, do: :"consensus.latency_ms"

  @doc """
  The node ID of the current consensus leader.

  Attribute: `consensus.leader.id`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `node-1`, `osa-primary`
  """
  @spec consensus_leader_id() :: :"consensus.leader.id"
  def consensus_leader_id, do: :"consensus.leader.id"

  @doc """
  Number of leader rotations since consensus started.

  Attribute: `consensus.leader.rotation_count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0`, `3`, `12`
  """
  @spec consensus_leader_rotation_count() :: :"consensus.leader.rotation_count"
  def consensus_leader_rotation_count, do: :"consensus.leader.rotation_count"

  @doc """
  Leader selection score used in the rotation algorithm [0.0, 1.0].

  Attribute: `consensus.leader.score`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0.75`, `0.92`
  """
  @spec consensus_leader_score() :: :"consensus.leader.score"
  def consensus_leader_score, do: :"consensus.leader.score"

  @doc """
  Duration of the current leader's tenure in milliseconds.

  Attribute: `consensus.leader.tenure_ms`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `5000`, `30000`, `120000`
  """
  @spec consensus_leader_tenure_ms() :: :"consensus.leader.tenure_ms"
  def consensus_leader_tenure_ms, do: :"consensus.leader.tenure_ms"

  @doc """
  ID of the leader node for this consensus view.

  Attribute: `consensus.leader_id`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `node-1`, `osa-primary`
  """
  @spec consensus_leader_id() :: :"consensus.leader_id"
  def consensus_leader_id, do: :"consensus.leader_id"

  @doc """
  Number of consecutive rounds completed to prove liveness of the protocol.

  Attribute: `consensus.liveness.proof_rounds`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `3`, `5`, `10`
  """
  @spec consensus_liveness_proof_rounds() :: :"consensus.liveness.proof_rounds"
  def consensus_liveness_proof_rounds, do: :"consensus.liveness.proof_rounds"

  @doc """
  Ratio of elapsed time to view timeout — approaching 1.0 means view change imminent.

  Attribute: `consensus.liveness.timeout_ratio`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0.1`, `0.5`, `0.95`
  """
  @spec consensus_liveness_timeout_ratio() :: :"consensus.liveness.timeout_ratio"
  def consensus_liveness_timeout_ratio, do: :"consensus.liveness.timeout_ratio"

  @doc """
  Network diameter in hops — the longest shortest path between any two nodes.

  Attribute: `consensus.network.diameter_hops`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `2`, `3`, `5`
  """
  @spec consensus_network_diameter_hops() :: :"consensus.network.diameter_hops"
  def consensus_network_diameter_hops, do: :"consensus.network.diameter_hops"

  @doc """
  Average node degree (connections per node) in the consensus network topology.

  Attribute: `consensus.network.node_degree`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `2.5`, `4.0`, `6.8`
  """
  @spec consensus_network_node_degree() :: :"consensus.network.node_degree"
  def consensus_network_node_degree, do: :"consensus.network.node_degree"

  @doc """
  Number of network partitions detected in the consensus cluster.

  Attribute: `consensus.network.partition_count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0`, `1`, `2`
  """
  @spec consensus_network_partition_count() :: :"consensus.network.partition_count"
  def consensus_network_partition_count, do: :"consensus.network.partition_count"

  @doc """
  Whether a network partition has been detected affecting consensus.

  Attribute: `consensus.network.partition_detected`
  Type: `boolean`
  Stability: `development`
  Requirement: `recommended`
  Examples: `true`, `false`
  """
  @spec consensus_network_partition_detected() :: :"consensus.network.partition_detected"
  def consensus_network_partition_detected, do: :"consensus.network.partition_detected"

  @doc """
  Time taken to recover network connectivity in milliseconds.

  Attribute: `consensus.network.recovery.duration_ms`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `100`, `5000`, `30000`
  """
  @spec consensus_network_recovery_duration_ms() :: :"consensus.network.recovery.duration_ms"
  def consensus_network_recovery_duration_ms, do: :"consensus.network.recovery.duration_ms"

  @doc """
  Number of nodes that rejoined the consensus cluster during recovery.

  Attribute: `consensus.network.recovery.nodes_rejoined`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `1`, `2`, `5`
  """
  @spec consensus_network_recovery_nodes_rejoined() :: :"consensus.network.recovery.nodes_rejoined"
  def consensus_network_recovery_nodes_rejoined, do: :"consensus.network.recovery.nodes_rejoined"

  @doc """
  Number of consensus rounds missed during network outage.

  Attribute: `consensus.network.recovery.rounds_missed`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0`, `3`, `15`
  """
  @spec consensus_network_recovery_rounds_missed() :: :"consensus.network.recovery.rounds_missed"
  def consensus_network_recovery_rounds_missed, do: :"consensus.network.recovery.rounds_missed"

  @doc """
  Strategy used to recover consensus network connectivity.

  Attribute: `consensus.network.recovery.strategy`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `reconnect`, `rejoin`
  """
  @spec consensus_network_recovery_strategy() :: :"consensus.network.recovery.strategy"
  def consensus_network_recovery_strategy, do: :"consensus.network.recovery.strategy"

  @doc """
  Enumerated values for `consensus.network.recovery.strategy`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `reconnect` | `"reconnect"` | reconnect |
  | `rejoin` | `"rejoin"` | rejoin |
  | `bootstrap` | `"bootstrap"` | bootstrap |
  """
  @spec consensus_network_recovery_strategy_values() :: %{
    reconnect: :reconnect,
    rejoin: :rejoin,
    bootstrap: :bootstrap
  }
  def consensus_network_recovery_strategy_values do
    %{
      reconnect: :reconnect,
      rejoin: :rejoin,
      bootstrap: :bootstrap
    }
  end

  defmodule ConsensusNetworkRecoveryStrategyValues do
    @moduledoc """
    Typed constants for the `consensus.network.recovery.strategy` attribute.
    """

    @doc "reconnect"
    @spec reconnect() :: :reconnect
    def reconnect, do: :reconnect

    @doc "rejoin"
    @spec rejoin() :: :rejoin
    def rejoin, do: :rejoin

    @doc "bootstrap"
    @spec bootstrap() :: :bootstrap
    def bootstrap, do: :bootstrap

  end

  @doc """
  Time in milliseconds for the network to recover from a partition event.

  Attribute: `consensus.network.recovery_ms`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `100`, `500`, `2000`
  """
  @spec consensus_network_recovery_ms() :: :"consensus.network.recovery_ms"
  def consensus_network_recovery_ms, do: :"consensus.network.recovery_ms"

  @doc """
  The topology type of the consensus network.

  Attribute: `consensus.network.topology_type`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `mesh`, `ring`
  """
  @spec consensus_network_topology_type() :: :"consensus.network.topology_type"
  def consensus_network_topology_type, do: :"consensus.network.topology_type"

  @doc """
  Enumerated values for `consensus.network.topology_type`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `ring` | `"ring"` | ring |
  | `mesh` | `"mesh"` | mesh |
  | `star` | `"star"` | star |
  | `bus` | `"bus"` | bus |
  """
  @spec consensus_network_topology_type_values() :: %{
    ring: :ring,
    mesh: :mesh,
    star: :star,
    bus: :bus
  }
  def consensus_network_topology_type_values do
    %{
      ring: :ring,
      mesh: :mesh,
      star: :star,
      bus: :bus
    }
  end

  defmodule ConsensusNetworkTopologyTypeValues do
    @moduledoc """
    Typed constants for the `consensus.network.topology_type` attribute.
    """

    @doc "ring"
    @spec ring() :: :ring
    def ring, do: :ring

    @doc "mesh"
    @spec mesh() :: :mesh
    def mesh, do: :mesh

    @doc "star"
    @spec star() :: :star
    def star, do: :star

    @doc "bus"
    @spec bus() :: :bus
    def bus, do: :bus

  end

  @doc """
  Identifier of the consensus node.

  Attribute: `consensus.node_id`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `node-1`, `node-primary`
  """
  @spec consensus_node_id() :: :"consensus.node_id"
  def consensus_node_id, do: :"consensus.node_id"

  @doc """
  Whether a network partition was detected in the consensus cluster.

  Attribute: `consensus.partition.detected`
  Type: `boolean`
  Stability: `development`
  Requirement: `recommended`
  Examples: `true`, `false`
  """
  @spec consensus_partition_detected() :: :"consensus.partition.detected"
  def consensus_partition_detected, do: :"consensus.partition.detected"

  @doc """
  The strategy used to heal the consensus state after partition recovery.

  Attribute: `consensus.partition.heal_strategy`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `majority_wins`, `epoch_fence`, `leader_arbitration`
  """
  @spec consensus_partition_heal_strategy() :: :"consensus.partition.heal_strategy"
  def consensus_partition_heal_strategy, do: :"consensus.partition.heal_strategy"

  @doc """
  Enumerated values for `consensus.partition.heal_strategy`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `majority_wins` | `"majority_wins"` | majority_wins |
  | `epoch_fence` | `"epoch_fence"` | epoch_fence |
  | `leader_arbitration` | `"leader_arbitration"` | leader_arbitration |
  | `rollback` | `"rollback"` | rollback |
  """
  @spec consensus_partition_heal_strategy_values() :: %{
    majority_wins: :majority_wins,
    epoch_fence: :epoch_fence,
    leader_arbitration: :leader_arbitration,
    rollback: :rollback
  }
  def consensus_partition_heal_strategy_values do
    %{
      majority_wins: :majority_wins,
      epoch_fence: :epoch_fence,
      leader_arbitration: :leader_arbitration,
      rollback: :rollback
    }
  end

  defmodule ConsensusPartitionHealStrategyValues do
    @moduledoc """
    Typed constants for the `consensus.partition.heal_strategy` attribute.
    """

    @doc "majority_wins"
    @spec majority_wins() :: :majority_wins
    def majority_wins, do: :majority_wins

    @doc "epoch_fence"
    @spec epoch_fence() :: :epoch_fence
    def epoch_fence, do: :epoch_fence

    @doc "leader_arbitration"
    @spec leader_arbitration() :: :leader_arbitration
    def leader_arbitration, do: :leader_arbitration

    @doc "rollback"
    @spec rollback() :: :rollback
    def rollback, do: :rollback

  end

  @doc """
  Duration (ms) for which the partition was isolated before healing began.

  Attribute: `consensus.partition.isolation_ms`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `500`, `5000`, `30000`
  """
  @spec consensus_partition_isolation_ms() :: :"consensus.partition.isolation_ms"
  def consensus_partition_isolation_ms, do: :"consensus.partition.isolation_ms"

  @doc """
  Time in milliseconds to recover from the network partition.

  Attribute: `consensus.partition.recovery_ms`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `500`, `2000`, `10000`
  """
  @spec consensus_partition_recovery_ms() :: :"consensus.partition.recovery_ms"
  def consensus_partition_recovery_ms, do: :"consensus.partition.recovery_ms"

  @doc """
  Number of nodes in the detected partition.

  Attribute: `consensus.partition.size`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `1`, `3`, `5`
  """
  @spec consensus_partition_size() :: :"consensus.partition.size"
  def consensus_partition_size, do: :"consensus.partition.size"

  @doc """
  Strategy used to resolve the network partition.

  Attribute: `consensus.partition.strategy`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `majority_wins`, `epoch_based`
  """
  @spec consensus_partition_strategy() :: :"consensus.partition.strategy"
  def consensus_partition_strategy, do: :"consensus.partition.strategy"

  @doc """
  Enumerated values for `consensus.partition.strategy`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `majority_wins` | `"majority_wins"` | majority_wins |
  | `epoch_based` | `"epoch_based"` | epoch_based |
  | `manual` | `"manual"` | manual |
  """
  @spec consensus_partition_strategy_values() :: %{
    majority_wins: :majority_wins,
    epoch_based: :epoch_based,
    manual: :manual
  }
  def consensus_partition_strategy_values do
    %{
      majority_wins: :majority_wins,
      epoch_based: :epoch_based,
      manual: :manual
    }
  end

  defmodule ConsensusPartitionStrategyValues do
    @moduledoc """
    Typed constants for the `consensus.partition.strategy` attribute.
    """

    @doc "majority_wins"
    @spec majority_wins() :: :majority_wins
    def majority_wins, do: :majority_wins

    @doc "epoch_based"
    @spec epoch_based() :: :epoch_based
    def epoch_based, do: :epoch_based

    @doc "manual"
    @spec manual() :: :manual
    def manual, do: :manual

  end

  @doc """
  The current phase of the HotStuff BFT consensus protocol.

  Attribute: `consensus.phase`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `prepare`, `commit`
  """
  @spec consensus_phase() :: :"consensus.phase"
  def consensus_phase, do: :"consensus.phase"

  @doc """
  Enumerated values for `consensus.phase`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `prepare` | `"prepare"` | HotStuff PREPARE phase — leader proposes |
  | `pre_commit` | `"pre_commit"` | HotStuff PRE-COMMIT phase — collect prepare votes |
  | `commit` | `"commit"` | HotStuff COMMIT phase — collect pre-commit votes |
  | `decide` | `"decide"` | HotStuff DECIDE phase — finalize block |
  | `view_change` | `"view_change"` | View change triggered by leader timeout |
  """
  @spec consensus_phase_values() :: %{
    prepare: :prepare,
    pre_commit: :pre_commit,
    commit: :commit,
    decide: :decide,
    view_change: :view_change
  }
  def consensus_phase_values do
    %{
      prepare: :prepare,
      pre_commit: :pre_commit,
      commit: :commit,
      decide: :decide,
      view_change: :view_change
    }
  end

  defmodule ConsensusPhaseValues do
    @moduledoc """
    Typed constants for the `consensus.phase` attribute.
    """

    @doc "HotStuff PREPARE phase — leader proposes"
    @spec prepare() :: :prepare
    def prepare, do: :prepare

    @doc "HotStuff PRE-COMMIT phase — collect prepare votes"
    @spec pre_commit() :: :pre_commit
    def pre_commit, do: :pre_commit

    @doc "HotStuff COMMIT phase — collect pre-commit votes"
    @spec commit() :: :commit
    def commit, do: :commit

    @doc "HotStuff DECIDE phase — finalize block"
    @spec decide() :: :decide
    def decide, do: :decide

    @doc "View change triggered by leader timeout"
    @spec view_change() :: :view_change
    def view_change, do: :view_change

  end

  @doc """
  Number of new replicas admitted to the quorum during this growth operation.

  Attribute: `consensus.quorum.admitted_count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `2`, `3`
  """
  @spec consensus_quorum_admitted_count() :: :"consensus.quorum.admitted_count"
  def consensus_quorum_admitted_count, do: :"consensus.quorum.admitted_count"

  @doc """
  Current quorum size before the growth operation.

  Attribute: `consensus.quorum.current_size`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `5`, `10`
  """
  @spec consensus_quorum_current_size() :: :"consensus.quorum.current_size"
  def consensus_quorum_current_size, do: :"consensus.quorum.current_size"

  @doc """
  Rate of quorum size growth per epoch, as a fraction of current quorum size.

  Attribute: `consensus.quorum.growth_rate`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0.1`, `0.25`
  """
  @spec consensus_quorum_growth_rate() :: :"consensus.quorum.growth_rate"
  def consensus_quorum_growth_rate, do: :"consensus.quorum.growth_rate"

  @doc """
  Health status of the quorum — based on how many replicas are reachable relative to quorum threshold.

  Attribute: `consensus.quorum.health`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `healthy`, `degraded`
  """
  @spec consensus_quorum_health() :: :"consensus.quorum.health"
  def consensus_quorum_health, do: :"consensus.quorum.health"

  @doc """
  Enumerated values for `consensus.quorum.health`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `healthy` | `"healthy"` | healthy |
  | `degraded` | `"degraded"` | degraded |
  | `critical` | `"critical"` | critical |
  """
  @spec consensus_quorum_health_values() :: %{
    healthy: :healthy,
    degraded: :degraded,
    critical: :critical
  }
  def consensus_quorum_health_values do
    %{
      healthy: :healthy,
      degraded: :degraded,
      critical: :critical
    }
  end

  defmodule ConsensusQuorumHealthValues do
    @moduledoc """
    Typed constants for the `consensus.quorum.health` attribute.
    """

    @doc "healthy"
    @spec healthy() :: :healthy
    def healthy, do: :healthy

    @doc "degraded"
    @spec degraded() :: :degraded
    def degraded, do: :degraded

    @doc "critical"
    @spec critical() :: :critical
    def critical, do: :critical

  end

  @doc """
  New quorum size after the shrink operation completes.

  Attribute: `consensus.quorum.shrink.new_size`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `3`, `5`
  """
  @spec consensus_quorum_shrink_new_size() :: :"consensus.quorum.shrink.new_size"
  def consensus_quorum_shrink_new_size, do: :"consensus.quorum.shrink.new_size"

  @doc """
  The reason for shrinking the consensus quorum.

  Attribute: `consensus.quorum.shrink.reason`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `node_failure`, `rebalance`
  """
  @spec consensus_quorum_shrink_reason() :: :"consensus.quorum.shrink.reason"
  def consensus_quorum_shrink_reason, do: :"consensus.quorum.shrink.reason"

  @doc """
  Enumerated values for `consensus.quorum.shrink.reason`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `node_failure` | `"node_failure"` | node_failure |
  | `config_change` | `"config_change"` | config_change |
  | `rebalance` | `"rebalance"` | rebalance |
  | `decommission` | `"decommission"` | decommission |
  """
  @spec consensus_quorum_shrink_reason_values() :: %{
    node_failure: :node_failure,
    config_change: :config_change,
    rebalance: :rebalance,
    decommission: :decommission
  }
  def consensus_quorum_shrink_reason_values do
    %{
      node_failure: :node_failure,
      config_change: :config_change,
      rebalance: :rebalance,
      decommission: :decommission
    }
  end

  defmodule ConsensusQuorumShrinkReasonValues do
    @moduledoc """
    Typed constants for the `consensus.quorum.shrink.reason` attribute.
    """

    @doc "node_failure"
    @spec node_failure() :: :node_failure
    def node_failure, do: :node_failure

    @doc "config_change"
    @spec config_change() :: :config_change
    def config_change, do: :config_change

    @doc "rebalance"
    @spec rebalance() :: :rebalance
    def rebalance, do: :rebalance

    @doc "decommission"
    @spec decommission() :: :decommission
    def decommission, do: :decommission

  end

  @doc """
  Number of nodes removed from the quorum in this shrink operation.

  Attribute: `consensus.quorum.shrink.removed_count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `1`, `2`
  """
  @spec consensus_quorum_shrink_removed_count() :: :"consensus.quorum.shrink.removed_count"
  def consensus_quorum_shrink_removed_count, do: :"consensus.quorum.shrink.removed_count"

  @doc """
  Fault tolerance margin remaining after shrink, as fraction [0.0, 1.0].

  Attribute: `consensus.quorum.shrink.safety_margin`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0.33`, `0.5`
  """
  @spec consensus_quorum_shrink_safety_margin() :: :"consensus.quorum.shrink.safety_margin"
  def consensus_quorum_shrink_safety_margin, do: :"consensus.quorum.shrink.safety_margin"

  @doc """
  Target quorum size after growth operation completes.

  Attribute: `consensus.quorum.target_size`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `7`, `13`
  """
  @spec consensus_quorum_target_size() :: :"consensus.quorum.target_size"
  def consensus_quorum_target_size, do: :"consensus.quorum.target_size"

  @doc """
  Number of votes required for quorum (typically 2f+1 for f Byzantine faults).

  Attribute: `consensus.quorum_size`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `3`, `5`, `7`
  """
  @spec consensus_quorum_size() :: :"consensus.quorum_size"
  def consensus_quorum_size, do: :"consensus.quorum_size"

  @doc """
  Total number of replicas participating in the consensus protocol.

  Attribute: `consensus.replica.count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `4`, `7`, `10`
  """
  @spec consensus_replica_count() :: :"consensus.replica.count"
  def consensus_replica_count, do: :"consensus.replica.count"

  @doc """
  Replication lag in milliseconds — how far behind the slowest replica is.

  Attribute: `consensus.replica.lag_ms`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `5`, `50`, `500`
  """
  @spec consensus_replica_lag_ms() :: :"consensus.replica.lag_ms"
  def consensus_replica_lag_ms, do: :"consensus.replica.lag_ms"

  @doc """
  The round number within the BFT consensus protocol.

  Attribute: `consensus.round_num`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `1`, `5`, `42`
  """
  @spec consensus_round_num() :: :"consensus.round_num"
  def consensus_round_num, do: :"consensus.round_num"

  @doc """
  Phase of the BFT consensus round.

  Attribute: `consensus.round_type`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `prepare`, `accept`
  """
  @spec consensus_round_type() :: :"consensus.round_type"
  def consensus_round_type, do: :"consensus.round_type"

  @doc """
  Enumerated values for `consensus.round_type`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `prepare` | `"prepare"` | BFT prepare phase |
  | `promise` | `"promise"` | BFT promise phase |
  | `accept` | `"accept"` | BFT accept phase |
  | `learn` | `"learn"` | BFT learn phase |
  """
  @spec consensus_round_type_values() :: %{
    prepare: :prepare,
    promise: :promise,
    accept: :accept,
    learn: :learn
  }
  def consensus_round_type_values do
    %{
      prepare: :prepare,
      promise: :promise,
      accept: :accept,
      learn: :learn
    }
  end

  defmodule ConsensusRoundTypeValues do
    @moduledoc """
    Typed constants for the `consensus.round_type` attribute.
    """

    @doc "BFT prepare phase"
    @spec prepare() :: :prepare
    def prepare, do: :prepare

    @doc "BFT promise phase"
    @spec promise() :: :promise
    def promise, do: :promise

    @doc "BFT accept phase"
    @spec accept() :: :accept
    def accept, do: :accept

    @doc "BFT learn phase"
    @spec learn() :: :learn
    def learn, do: :learn

  end

  @doc """
  Interval between consecutive safety checks in milliseconds.

  Attribute: `consensus.safety.check_interval_ms`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `100`, `500`, `1000`
  """
  @spec consensus_safety_check_interval_ms() :: :"consensus.safety.check_interval_ms"
  def consensus_safety_check_interval_ms, do: :"consensus.safety.check_interval_ms"

  @doc """
  Achieved safety quorum ratio during the consensus round, range [0.0, 1.0].

  Attribute: `consensus.safety.quorum_ratio`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0.67`, `0.75`, `1.0`
  """
  @spec consensus_safety_quorum_ratio() :: :"consensus.safety.quorum_ratio"
  def consensus_safety_quorum_ratio, do: :"consensus.safety.quorum_ratio"

  @doc """
  Minimum fraction of replicas required for a safe consensus decision [0.0, 1.0]. Typical: 0.67 (2/3).

  Attribute: `consensus.safety.threshold`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0.67`, `0.75`, `0.51`
  """
  @spec consensus_safety_threshold() :: :"consensus.safety.threshold"
  def consensus_safety_threshold, do: :"consensus.safety.threshold"

  @doc """
  Number of safety violations detected in the current consensus epoch.

  Attribute: `consensus.safety.violation_count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0`, `1`, `3`
  """
  @spec consensus_safety_violation_count() :: :"consensus.safety.violation_count"
  def consensus_safety_violation_count, do: :"consensus.safety.violation_count"

  @doc """
  Number of valid cryptographic signatures collected in this round.

  Attribute: `consensus.signature_count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `4`, `7`, `10`
  """
  @spec consensus_signature_count() :: :"consensus.signature_count"
  def consensus_signature_count, do: :"consensus.signature_count"

  @doc """
  Rate at which the consensus threshold is adapted per round, range [0.0, 1.0].

  Attribute: `consensus.threshold.adaptation_rate`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0.05`, `0.1`
  """
  @spec consensus_threshold_adaptation_rate() :: :"consensus.threshold.adaptation_rate"
  def consensus_threshold_adaptation_rate, do: :"consensus.threshold.adaptation_rate"

  @doc """
  Current consensus threshold value (fraction of replicas required for quorum), range (0.5, 1.0].

  Attribute: `consensus.threshold.current`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0.67`, `0.75`
  """
  @spec consensus_threshold_current() :: :"consensus.threshold.current"
  def consensus_threshold_current, do: :"consensus.threshold.current"

  @doc """
  Target fault tolerance ratio (max fraction of Byzantine faults tolerated), range [0.0, 0.5).

  Attribute: `consensus.threshold.fault_tolerance_target`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0.33`, `0.25`
  """
  @spec consensus_threshold_fault_tolerance_target() :: :"consensus.threshold.fault_tolerance_target"
  def consensus_threshold_fault_tolerance_target, do: :"consensus.threshold.fault_tolerance_target"

  @doc """
  Number of negative votes cast.

  Attribute: `consensus.threshold.nay_count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `1`, `0`, `3`
  """
  @spec consensus_threshold_nay_count() :: :"consensus.threshold.nay_count"
  def consensus_threshold_nay_count, do: :"consensus.threshold.nay_count"

  @doc """
  The voting threshold type required for consensus.

  Attribute: `consensus.threshold.vote_type`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `supermajority`, `simple`
  """
  @spec consensus_threshold_vote_type() :: :"consensus.threshold.vote_type"
  def consensus_threshold_vote_type, do: :"consensus.threshold.vote_type"

  @doc """
  Enumerated values for `consensus.threshold.vote_type`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `supermajority` | `"supermajority"` | supermajority |
  | `simple` | `"simple"` | simple |
  | `unanimous` | `"unanimous"` | unanimous |
  """
  @spec consensus_threshold_vote_type_values() :: %{
    supermajority: :supermajority,
    simple: :simple,
    unanimous: :unanimous
  }
  def consensus_threshold_vote_type_values do
    %{
      supermajority: :supermajority,
      simple: :simple,
      unanimous: :unanimous
    }
  end

  defmodule ConsensusThresholdVoteTypeValues do
    @moduledoc """
    Typed constants for the `consensus.threshold.vote_type` attribute.
    """

    @doc "supermajority"
    @spec supermajority() :: :supermajority
    def supermajority, do: :supermajority

    @doc "simple"
    @spec simple() :: :simple
    def simple, do: :simple

    @doc "unanimous"
    @spec unanimous() :: :unanimous
    def unanimous, do: :unanimous

  end

  @doc """
  Number of affirmative votes cast.

  Attribute: `consensus.threshold.yea_count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `7`, `4`, `10`
  """
  @spec consensus_threshold_yea_count() :: :"consensus.threshold.yea_count"
  def consensus_threshold_yea_count, do: :"consensus.threshold.yea_count"

  @doc """
  Timeout in milliseconds for the current consensus round.

  Attribute: `consensus.timeout_ms`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `1000`, `5000`, `30000`
  """
  @spec consensus_timeout_ms() :: :"consensus.timeout_ms"
  def consensus_timeout_ms, do: :"consensus.timeout_ms"

  @doc """
  Duration of the current consensus view in milliseconds.

  Attribute: `consensus.view.duration_ms`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `50`, `200`, `1000`
  """
  @spec consensus_view_duration_ms() :: :"consensus.view.duration_ms"
  def consensus_view_duration_ms, do: :"consensus.view.duration_ms"

  @doc """
  Exponential backoff delay applied before attempting view change.

  Attribute: `consensus.view_change.backoff_ms`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `100`, `400`, `1600`
  """
  @spec consensus_view_change_backoff_ms() :: :"consensus.view_change.backoff_ms"
  def consensus_view_change_backoff_ms, do: :"consensus.view_change.backoff_ms"

  @doc """
  Duration of the view change protocol in milliseconds.

  Attribute: `consensus.view_change.duration_ms`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `50`, `200`, `1000`
  """
  @spec consensus_view_change_duration_ms() :: :"consensus.view_change.duration_ms"
  def consensus_view_change_duration_ms, do: :"consensus.view_change.duration_ms"

  @doc """
  Reason that triggered the view change.

  Attribute: `consensus.view_change.reason`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  """
  @spec consensus_view_change_reason() :: :"consensus.view_change.reason"
  def consensus_view_change_reason, do: :"consensus.view_change.reason"

  @doc """
  Enumerated values for `consensus.view_change.reason`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `timeout` | `"timeout"` | timeout |
  | `leader_failure` | `"leader_failure"` | leader_failure |
  | `network_partition` | `"network_partition"` | network_partition |
  | `manual` | `"manual"` | manual |
  | `equivocation` | `"equivocation"` | equivocation |
  """
  @spec consensus_view_change_reason_values() :: %{
    timeout: :timeout,
    leader_failure: :leader_failure,
    network_partition: :network_partition,
    manual: :manual,
    equivocation: :equivocation
  }
  def consensus_view_change_reason_values do
    %{
      timeout: :timeout,
      leader_failure: :leader_failure,
      network_partition: :network_partition,
      manual: :manual,
      equivocation: :equivocation
    }
  end

  defmodule ConsensusViewChangeReasonValues do
    @moduledoc """
    Typed constants for the `consensus.view_change.reason` attribute.
    """

    @doc "timeout"
    @spec timeout() :: :timeout
    def timeout, do: :timeout

    @doc "leader_failure"
    @spec leader_failure() :: :leader_failure
    def leader_failure, do: :leader_failure

    @doc "network_partition"
    @spec network_partition() :: :network_partition
    def network_partition, do: :network_partition

    @doc "manual"
    @spec manual() :: :manual
    def manual, do: :manual

    @doc "equivocation"
    @spec equivocation() :: :equivocation
    def equivocation, do: :equivocation

  end

  @doc """
  The current view number in the HotStuff protocol (monotonically increasing).

  Attribute: `consensus.view_number`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `1`, `42`, `1000`
  """
  @spec consensus_view_number() :: :"consensus.view_number"
  def consensus_view_number, do: :"consensus.view_number"

  @doc """
  Timeout in milliseconds for the current view (Armstrong fault tolerance budget).

  Attribute: `consensus.view_timeout_ms`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `1000`, `5000`
  """
  @spec consensus_view_timeout_ms() :: :"consensus.view_timeout_ms"
  def consensus_view_timeout_ms, do: :"consensus.view_timeout_ms"

  @doc """
  Current number of votes collected for this round.

  Attribute: `consensus.vote_count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `2`, `3`, `5`
  """
  @spec consensus_vote_count() :: :"consensus.vote_count"
  def consensus_vote_count, do: :"consensus.vote_count"

end