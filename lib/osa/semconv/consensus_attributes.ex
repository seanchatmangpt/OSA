defmodule OpenTelemetry.SemConv.Incubating.ConsensusAttributes do
  @moduledoc """
  Consensus semantic convention attributes.

  Namespace: `consensus`

  This module is generated from the ChatmanGPT semantic convention registry.
  Do not edit manually — regenerate with:

      weaver registry generate -r ./semconv/model --templates ./semconv/templates elixir ./OSA/lib/osa/semconv/
  """

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
  Current number of votes collected for this round.

  Attribute: `consensus.vote_count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `2`, `3`, `5`
  """
  @spec consensus_vote_count() :: :"consensus.vote_count"
  def consensus_vote_count, do: :"consensus.vote_count"

  @doc """
  View timeout in milliseconds before triggering a view change.

  Attribute: `consensus.view_timeout_ms`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `1000`, `5000`, `10000`
  """
  @spec consensus_view_timeout_ms() :: :"consensus.view_timeout_ms"
  def consensus_view_timeout_ms, do: :"consensus.view_timeout_ms"

  @doc """
  Number of cryptographic signatures collected for this consensus round.

  Attribute: `consensus.signature_count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `3`, `5`, `7`
  """
  @spec consensus_signature_count() :: :"consensus.signature_count"
  def consensus_signature_count, do: :"consensus.signature_count"

  # --- iter11: consensus quorum health ---

  @doc """
  Health status of the quorum (healthy, degraded, failed).

  Attribute: `consensus.quorum.health`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `healthy`, `degraded`, `failed`
  """
  @spec consensus_quorum_health() :: :"consensus.quorum.health"
  def consensus_quorum_health, do: :"consensus.quorum.health"

  @doc """
  Height of the most recently committed block.

  Attribute: `consensus.block.height`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `1`, `100`, `42000`
  """
  @spec consensus_block_height() :: :"consensus.block.height"
  def consensus_block_height, do: :"consensus.block.height"

  @doc """
  Total number of replicas participating in consensus.

  Attribute: `consensus.replica.count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `3`, `5`, `7`
  """
  @spec consensus_replica_count() :: :"consensus.replica.count"
  def consensus_replica_count, do: :"consensus.replica.count"

  @doc """
  Number of replica failures detected in the current epoch.

  Attribute: `consensus.failure.count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0`, `1`, `2`
  """
  @spec consensus_failure_count() :: :"consensus.failure.count"
  def consensus_failure_count, do: :"consensus.failure.count"

end