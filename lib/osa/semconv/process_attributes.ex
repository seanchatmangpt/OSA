defmodule OpenTelemetry.SemConv.Incubating.ProcessAttributes do
  @moduledoc """
  Process semantic convention attributes.

  Namespace: `process`

  This module is generated from the ChatmanGPT semantic convention registry.
  Do not edit manually — regenerate with:

      weaver registry generate -r ./semconv/model --templates ./semconv/templates elixir ./OSA/lib/osa/semconv/
  """

  @doc """
  Name of the process activity (event class) from the XES log.

  Attribute: `process.mining.activity`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `Register`, `Examine`, `Diagnose`, `Treat`, `Release`
  """
  @spec process_mining_activity() :: :"process.mining.activity"
  def process_mining_activity, do: :"process.mining.activity"

  @doc """
  Relative frequency of this activity in the process log [0.0, 1.0].

  Attribute: `process.mining.activity.frequency`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0.15`, `0.72`
  """
  @spec process_mining_activity_frequency() :: :"process.mining.activity.frequency"
  def process_mining_activity_frequency, do: :"process.mining.activity.frequency"

  @doc """
  Waiting time before an activity was executed in milliseconds.

  Attribute: `process.mining.activity.waiting_ms`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0`, `500`, `3600000`
  """
  @spec process_mining_activity_waiting_ms() :: :"process.mining.activity.waiting_ms"
  def process_mining_activity_waiting_ms, do: :"process.mining.activity.waiting_ms"

  @doc """
  Process discovery algorithm used.

  Attribute: `process.mining.algorithm`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `alpha_miner`, `inductive_miner`
  """
  @spec process_mining_algorithm() :: :"process.mining.algorithm"
  def process_mining_algorithm, do: :"process.mining.algorithm"

  @doc """
  Enumerated values for `process.mining.algorithm`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `alpha_miner` | `"alpha_miner"` | alpha_miner |
  | `inductive_miner` | `"inductive_miner"` | inductive_miner |
  | `heuristics_miner` | `"heuristics_miner"` | heuristics_miner |
  | `heuristic_miner` | `"heuristic_miner"` | heuristic_miner |
  | `directly_follows` | `"directly_follows"` | directly_follows |
  """
  @spec process_mining_algorithm_values() :: %{
    alpha_miner: :alpha_miner,
    inductive_miner: :inductive_miner,
    heuristics_miner: :heuristics_miner,
    heuristic_miner: :heuristic_miner,
    directly_follows: :directly_follows
  }
  def process_mining_algorithm_values do
    %{
      alpha_miner: :alpha_miner,
      inductive_miner: :inductive_miner,
      heuristics_miner: :heuristics_miner,
      heuristic_miner: :heuristic_miner,
      directly_follows: :directly_follows
    }
  end

  defmodule ProcessMiningAlgorithmValues do
    @moduledoc """
    Typed constants for the `process.mining.algorithm` attribute.
    """

    @doc "alpha_miner"
    @spec alpha_miner() :: :alpha_miner
    def alpha_miner, do: :alpha_miner

    @doc "inductive_miner"
    @spec inductive_miner() :: :inductive_miner
    def inductive_miner, do: :inductive_miner

    @doc "heuristics_miner"
    @spec heuristics_miner() :: :heuristics_miner
    def heuristics_miner, do: :heuristics_miner

    @doc "heuristic_miner"
    @spec heuristic_miner() :: :heuristic_miner
    def heuristic_miner, do: :heuristic_miner

    @doc "directly_follows"
    @spec directly_follows() :: :directly_follows
    def directly_follows, do: :directly_follows

  end

  @doc """
  Total alignment cost for token-based or alignment-based conformance checking. Lower is better.

  Attribute: `process.mining.alignment.cost`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0.0`, `12.5`, `45.0`
  """
  @spec process_mining_alignment_cost() :: :"process.mining.alignment.cost"
  def process_mining_alignment_cost, do: :"process.mining.alignment.cost"

  @doc """
  Change in fitness score compared to the previous alignment computation.

  Attribute: `process.mining.alignment.fitness_delta`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `-0.05`, `0.12`, `0.0`
  """
  @spec process_mining_alignment_fitness_delta() :: :"process.mining.alignment.fitness_delta"
  def process_mining_alignment_fitness_delta, do: :"process.mining.alignment.fitness_delta"

  @doc """
  Total number of moves (log moves + model moves) in the computed alignment.

  Attribute: `process.mining.alignment.move_count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `5`, `18`, `42`
  """
  @spec process_mining_alignment_move_count() :: :"process.mining.alignment.move_count"
  def process_mining_alignment_move_count, do: :"process.mining.alignment.move_count"

  @doc """
  Length of the optimal synchronization path found by the alignment algorithm.

  Attribute: `process.mining.alignment.optimal_path_length`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `12`, `35`, `78`
  """
  @spec process_mining_alignment_optimal_path_length() :: :"process.mining.alignment.optimal_path_length"
  def process_mining_alignment_optimal_path_length, do: :"process.mining.alignment.optimal_path_length"

  @doc """
  Anomaly score for the detected process deviation [0.0, 1.0].

  Attribute: `process.mining.anomaly.score`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0.7`, `0.92`
  """
  @spec process_mining_anomaly_score() :: :"process.mining.anomaly.score"
  def process_mining_anomaly_score, do: :"process.mining.anomaly.score"

  @doc """
  Name of the activity identified as a bottleneck in the process model.

  Attribute: `process.mining.bottleneck.activity`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `approve_request`, `review_document`
  """
  @spec process_mining_bottleneck_activity() :: :"process.mining.bottleneck.activity"
  def process_mining_bottleneck_activity, do: :"process.mining.bottleneck.activity"

  @doc """
  Estimated total time impact in milliseconds caused by this bottleneck across all cases.

  Attribute: `process.mining.bottleneck.impact_ms`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `5000`, `30000`, `120000`
  """
  @spec process_mining_bottleneck_impact_ms() :: :"process.mining.bottleneck.impact_ms"
  def process_mining_bottleneck_impact_ms, do: :"process.mining.bottleneck.impact_ms"

  @doc """
  Ordinal rank of the bottleneck among all detected bottlenecks (1 = most severe).

  Attribute: `process.mining.bottleneck.rank`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `1`, `2`, `5`
  """
  @spec process_mining_bottleneck_rank() :: :"process.mining.bottleneck.rank"
  def process_mining_bottleneck_rank, do: :"process.mining.bottleneck.rank"

  @doc """
  Composite bottleneck severity score for an activity, range [0.0, 1.0]. Higher = more severe.

  Attribute: `process.mining.bottleneck.score`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0.85`, `0.42`, `0.95`
  """
  @spec process_mining_bottleneck_score() :: :"process.mining.bottleneck.score"
  def process_mining_bottleneck_score, do: :"process.mining.bottleneck.score"

  @doc """
  Average waiting time in milliseconds at the identified bottleneck activity.

  Attribute: `process.mining.bottleneck.wait_ms`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `120000`, `3600000`
  """
  @spec process_mining_bottleneck_wait_ms() :: :"process.mining.bottleneck.wait_ms"
  def process_mining_bottleneck_wait_ms, do: :"process.mining.bottleneck.wait_ms"

  @doc """
  Total throughput time for a case in milliseconds from first to last event.

  Attribute: `process.mining.case.throughput_ms`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `1000`, `86400000`, `604800000`
  """
  @spec process_mining_case_throughput_ms() :: :"process.mining.case.throughput_ms"
  def process_mining_case_throughput_ms, do: :"process.mining.case.throughput_ms"

  @doc """
  Identifier for the process variant (unique execution path) of this case.

  Attribute: `process.mining.case.variant_id`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `variant-001`, `variant-abc`, `path-42`
  """
  @spec process_mining_case_variant_id() :: :"process.mining.case.variant_id"
  def process_mining_case_variant_id, do: :"process.mining.case.variant_id"

  @doc """
  Number of process cases (traces) in the event log being analyzed.

  Attribute: `process.mining.case_count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `100`, `1500`, `50000`
  """
  @spec process_mining_case_count() :: :"process.mining.case_count"
  def process_mining_case_count, do: :"process.mining.case_count"

  @doc """
  Identifier of the process case (instance) in the event log.

  Attribute: `process.mining.case_id`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `case-001`, `case-2026-xyz`, `instance-42`
  """
  @spec process_mining_case_id() :: :"process.mining.case_id"
  def process_mining_case_id, do: :"process.mining.case_id"

  @doc """
  Algorithm used to cluster process mining cases.

  Attribute: `process.mining.cluster.algorithm`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `kmeans`, `dbscan`
  """
  @spec process_mining_cluster_algorithm() :: :"process.mining.cluster.algorithm"
  def process_mining_cluster_algorithm, do: :"process.mining.cluster.algorithm"

  @doc """
  Enumerated values for `process.mining.cluster.algorithm`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `kmeans` | `"kmeans"` | kmeans |
  | `dbscan` | `"dbscan"` | dbscan |
  | `hierarchical` | `"hierarchical"` | hierarchical |
  | `spectral` | `"spectral"` | spectral |
  """
  @spec process_mining_cluster_algorithm_values() :: %{
    kmeans: :kmeans,
    dbscan: :dbscan,
    hierarchical: :hierarchical,
    spectral: :spectral
  }
  def process_mining_cluster_algorithm_values do
    %{
      kmeans: :kmeans,
      dbscan: :dbscan,
      hierarchical: :hierarchical,
      spectral: :spectral
    }
  end

  defmodule ProcessMiningClusterAlgorithmValues do
    @moduledoc """
    Typed constants for the `process.mining.cluster.algorithm` attribute.
    """

    @doc "kmeans"
    @spec kmeans() :: :kmeans
    def kmeans, do: :kmeans

    @doc "dbscan"
    @spec dbscan() :: :dbscan
    def dbscan, do: :dbscan

    @doc "hierarchical"
    @spec hierarchical() :: :hierarchical
    def hierarchical, do: :hierarchical

    @doc "spectral"
    @spec spectral() :: :spectral
    def spectral, do: :spectral

  end

  @doc """
  Number of cases assigned to this cluster.

  Attribute: `process.mining.cluster.case_count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `42`, `150`
  """
  @spec process_mining_cluster_case_count() :: :"process.mining.cluster.case_count"
  def process_mining_cluster_case_count, do: :"process.mining.cluster.case_count"

  @doc """
  Identifier for the case cluster produced by the clustering algorithm.

  Attribute: `process.mining.cluster.id`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `cluster-1`, `cluster-high-complexity`
  """
  @spec process_mining_cluster_id() :: :"process.mining.cluster.id"
  def process_mining_cluster_id, do: :"process.mining.cluster.id"

  @doc """
  Silhouette score measuring cluster quality, range [-1.0, 1.0].

  Attribute: `process.mining.cluster.silhouette_score`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0.72`, `0.85`
  """
  @spec process_mining_cluster_silhouette_score() :: :"process.mining.cluster.silhouette_score"
  def process_mining_cluster_silhouette_score, do: :"process.mining.cluster.silhouette_score"

  @doc """
  The complexity metric applied to the process model.

  Attribute: `process.mining.complexity.metric`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `cyclomatic`, `cognitive`
  """
  @spec process_mining_complexity_metric() :: :"process.mining.complexity.metric"
  def process_mining_complexity_metric, do: :"process.mining.complexity.metric"

  @doc """
  Enumerated values for `process.mining.complexity.metric`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `cyclomatic` | `"cyclomatic"` | cyclomatic |
  | `cognitive` | `"cognitive"` | cognitive |
  | `structural` | `"structural"` | structural |
  """
  @spec process_mining_complexity_metric_values() :: %{
    cyclomatic: :cyclomatic,
    cognitive: :cognitive,
    structural: :structural
  }
  def process_mining_complexity_metric_values do
    %{
      cyclomatic: :cyclomatic,
      cognitive: :cognitive,
      structural: :structural
    }
  end

  defmodule ProcessMiningComplexityMetricValues do
    @moduledoc """
    Typed constants for the `process.mining.complexity.metric` attribute.
    """

    @doc "cyclomatic"
    @spec cyclomatic() :: :cyclomatic
    def cyclomatic, do: :cyclomatic

    @doc "cognitive"
    @spec cognitive() :: :cognitive
    def cognitive, do: :cognitive

    @doc "structural"
    @spec structural() :: :structural
    def structural, do: :structural

  end

  @doc """
  Complexity score of the discovered process model.

  Attribute: `process.mining.complexity.score`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `1.2`, `4.7`, `12.0`
  """
  @spec process_mining_complexity_score() :: :"process.mining.complexity.score"
  def process_mining_complexity_score, do: :"process.mining.complexity.score"

  @doc """
  Number of distinct process variants contributing to complexity.

  Attribute: `process.mining.complexity.variant_count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `5`, `23`, `100`
  """
  @spec process_mining_complexity_variant_count() :: :"process.mining.complexity.variant_count"
  def process_mining_complexity_variant_count, do: :"process.mining.complexity.variant_count"

  @doc """
  Minimum conformance threshold per case — cases below this are flagged as violations.

  Attribute: `process.mining.conformance.case_threshold`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0.7`, `0.85`, `0.95`
  """
  @spec process_mining_conformance_case_threshold() :: :"process.mining.conformance.case_threshold"
  def process_mining_conformance_case_threshold, do: :"process.mining.conformance.case_threshold"

  @doc """
  Number of deviating traces in the conformance checking result.

  Attribute: `process.mining.conformance.deviation_count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0`, `5`, `23`
  """
  @spec process_mining_conformance_deviation_count() :: :"process.mining.conformance.deviation_count"
  def process_mining_conformance_deviation_count, do: :"process.mining.conformance.deviation_count"

  @doc """
  Type of conformance deviation detected during trace alignment.

  Attribute: `process.mining.conformance.deviation_type`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `missing_activity`, `wrong_order`
  """
  @spec process_mining_conformance_deviation_type() :: :"process.mining.conformance.deviation_type"
  def process_mining_conformance_deviation_type, do: :"process.mining.conformance.deviation_type"

  @doc """
  Enumerated values for `process.mining.conformance.deviation_type`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `missing_activity` | `"missing_activity"` | Expected activity not found in trace |
  | `extra_activity` | `"extra_activity"` | Unexpected activity found in trace |
  | `wrong_order` | `"wrong_order"` | Activities in wrong execution order |
  | `loop_violation` | `"loop_violation"` | Loop constraints violated |
  """
  @spec process_mining_conformance_deviation_type_values() :: %{
    missing_activity: :missing_activity,
    extra_activity: :extra_activity,
    wrong_order: :wrong_order,
    loop_violation: :loop_violation
  }
  def process_mining_conformance_deviation_type_values do
    %{
      missing_activity: :missing_activity,
      extra_activity: :extra_activity,
      wrong_order: :wrong_order,
      loop_violation: :loop_violation
    }
  end

  defmodule ProcessMiningConformanceDeviationTypeValues do
    @moduledoc """
    Typed constants for the `process.mining.conformance.deviation_type` attribute.
    """

    @doc "Expected activity not found in trace"
    @spec missing_activity() :: :missing_activity
    def missing_activity, do: :missing_activity

    @doc "Unexpected activity found in trace"
    @spec extra_activity() :: :extra_activity
    def extra_activity, do: :extra_activity

    @doc "Activities in wrong execution order"
    @spec wrong_order() :: :wrong_order
    def wrong_order, do: :wrong_order

    @doc "Loop constraints violated"
    @spec loop_violation() :: :loop_violation
    def loop_violation, do: :loop_violation

  end

  @doc """
  Computation time for the repair operation in milliseconds.

  Attribute: `process.mining.conformance.repair_cost_ms`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `50`, `200`, `1000`
  """
  @spec process_mining_conformance_repair_cost_ms() :: :"process.mining.conformance.repair_cost_ms"
  def process_mining_conformance_repair_cost_ms, do: :"process.mining.conformance.repair_cost_ms"

  @doc """
  Number of repair operations applied to achieve conformance.

  Attribute: `process.mining.conformance.repair_count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `1`, `5`, `20`
  """
  @spec process_mining_conformance_repair_count() :: :"process.mining.conformance.repair_count"
  def process_mining_conformance_repair_count, do: :"process.mining.conformance.repair_count"

  @doc """
  Number of repair moves needed to align non-conforming traces.

  Attribute: `process.mining.conformance.repair_steps`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0`, `3`, `15`
  """
  @spec process_mining_conformance_repair_steps() :: :"process.mining.conformance.repair_steps"
  def process_mining_conformance_repair_steps, do: :"process.mining.conformance.repair_steps"

  @doc """
  Type of conformance repair operation applied to the trace.

  Attribute: `process.mining.conformance.repair_type`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `insert`, `delete`
  """
  @spec process_mining_conformance_repair_type() :: :"process.mining.conformance.repair_type"
  def process_mining_conformance_repair_type, do: :"process.mining.conformance.repair_type"

  @doc """
  Enumerated values for `process.mining.conformance.repair_type`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `insert` | `"insert"` | insert |
  | `delete` | `"delete"` | delete |
  | `move` | `"move"` | move |
  | `replace` | `"replace"` | replace |
  """
  @spec process_mining_conformance_repair_type_values() :: %{
    insert: :insert,
    delete: :delete,
    move: :move,
    replace: :replace
  }
  def process_mining_conformance_repair_type_values do
    %{
      insert: :insert,
      delete: :delete,
      move: :move,
      replace: :replace
    }
  end

  defmodule ProcessMiningConformanceRepairTypeValues do
    @moduledoc """
    Typed constants for the `process.mining.conformance.repair_type` attribute.
    """

    @doc "insert"
    @spec insert() :: :insert
    def insert, do: :insert

    @doc "delete"
    @spec delete() :: :delete
    def delete, do: :delete

    @doc "move"
    @spec move() :: :move
    def move, do: :move

    @doc "replace"
    @spec replace() :: :replace
    def replace, do: :replace

  end

  @doc """
  Fitness score after repair operations, range [0.0, 1.0].

  Attribute: `process.mining.conformance.repaired_fitness`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0.85`, `0.95`, `1.0`
  """
  @spec process_mining_conformance_repaired_fitness() :: :"process.mining.conformance.repaired_fitness"
  def process_mining_conformance_repaired_fitness, do: :"process.mining.conformance.repaired_fitness"

  @doc """
  Overall conformance fitness score measuring how well event traces follow the process model. Range [0.0, 1.0].

  Attribute: `process.mining.conformance.score`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0.95`, `0.82`, `0.67`
  """
  @spec process_mining_conformance_score() :: :"process.mining.conformance.score"
  def process_mining_conformance_score, do: :"process.mining.conformance.score"

  @doc """
  Number of cases violating the conformance threshold.

  Attribute: `process.mining.conformance.violation_count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0`, `5`, `42`
  """
  @spec process_mining_conformance_violation_count() :: :"process.mining.conformance.violation_count"
  def process_mining_conformance_violation_count, do: :"process.mining.conformance.violation_count"

  @doc """
  The visualization technique used for conformance checking results.

  Attribute: `process.mining.conformance.visualization_type`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `token_replay`, `alignment`
  """
  @spec process_mining_conformance_visualization_type() :: :"process.mining.conformance.visualization_type"
  def process_mining_conformance_visualization_type, do: :"process.mining.conformance.visualization_type"

  @doc """
  Enumerated values for `process.mining.conformance.visualization_type`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `token_replay` | `"token_replay"` | token_replay |
  | `alignment` | `"alignment"` | alignment |
  | `footprint` | `"footprint"` | footprint |
  | `anti_alignment` | `"anti_alignment"` | anti_alignment |
  """
  @spec process_mining_conformance_visualization_type_values() :: %{
    token_replay: :token_replay,
    alignment: :alignment,
    footprint: :footprint,
    anti_alignment: :anti_alignment
  }
  def process_mining_conformance_visualization_type_values do
    %{
      token_replay: :token_replay,
      alignment: :alignment,
      footprint: :footprint,
      anti_alignment: :anti_alignment
    }
  end

  defmodule ProcessMiningConformanceVisualizationTypeValues do
    @moduledoc """
    Typed constants for the `process.mining.conformance.visualization_type` attribute.
    """

    @doc "token_replay"
    @spec token_replay() :: :token_replay
    def token_replay, do: :token_replay

    @doc "alignment"
    @spec alignment() :: :alignment
    def alignment, do: :alignment

    @doc "footprint"
    @spec footprint() :: :footprint
    def footprint, do: :footprint

    @doc "anti_alignment"
    @spec anti_alignment() :: :anti_alignment
    def anti_alignment, do: :anti_alignment

  end

  @doc """
  Confidence score for the decision outcome prediction [0.0, 1.0].

  Attribute: `process.mining.decision.confidence`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0.85`, `0.92`
  """
  @spec process_mining_decision_confidence() :: :"process.mining.decision.confidence"
  def process_mining_decision_confidence, do: :"process.mining.decision.confidence"

  @doc """
  The outcome chosen at the decision point.

  Attribute: `process.mining.decision.outcome`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `approved`, `rejected`, `escalated`
  """
  @spec process_mining_decision_outcome() :: :"process.mining.decision.outcome"
  def process_mining_decision_outcome, do: :"process.mining.decision.outcome"

  @doc """
  Identifier of the decision point in the process model.

  Attribute: `process.mining.decision.point_id`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `dp-001`, `gateway-approve`
  """
  @spec process_mining_decision_point_id() :: :"process.mining.decision.point_id"
  def process_mining_decision_point_id, do: :"process.mining.decision.point_id"

  @doc """
  Number of decision rules evaluated at the decision point.

  Attribute: `process.mining.decision.rule_count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `3`, `10`, `25`
  """
  @spec process_mining_decision_rule_count() :: :"process.mining.decision.rule_count"
  def process_mining_decision_rule_count, do: :"process.mining.decision.rule_count"

  @doc """
  Type of conformance deviation found during trace alignment.

  Attribute: `process.mining.deviation.type`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `skip`, `insert`, `move_log`
  """
  @spec process_mining_deviation_type() :: :"process.mining.deviation.type"
  def process_mining_deviation_type, do: :"process.mining.deviation.type"

  @doc """
  Enumerated values for `process.mining.deviation.type`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `skip` | `"skip"` | skip |
  | `insert` | `"insert"` | insert |
  | `move_model` | `"move_model"` | move_model |
  | `move_log` | `"move_log"` | move_log |
  """
  @spec process_mining_deviation_type_values() :: %{
    skip: :skip,
    insert: :insert,
    move_model: :move_model,
    move_log: :move_log
  }
  def process_mining_deviation_type_values do
    %{
      skip: :skip,
      insert: :insert,
      move_model: :move_model,
      move_log: :move_log
    }
  end

  defmodule ProcessMiningDeviationTypeValues do
    @moduledoc """
    Typed constants for the `process.mining.deviation.type` attribute.
    """

    @doc "skip"
    @spec skip() :: :skip
    def skip, do: :skip

    @doc "insert"
    @spec insert() :: :insert
    def insert, do: :insert

    @doc "move_model"
    @spec move_model() :: :move_model
    def move_model, do: :move_model

    @doc "move_log"
    @spec move_log() :: :move_log
    def move_log, do: :move_log

  end

  @doc """
  Number of edges in the Directly-Follows Graph.

  Attribute: `process.mining.dfg.edge_count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `45`, `120`, `800`
  """
  @spec process_mining_dfg_edge_count() :: :"process.mining.dfg.edge_count"
  def process_mining_dfg_edge_count, do: :"process.mining.dfg.edge_count"

  @doc """
  Number of nodes (activities) in the Directly-Follows Graph.

  Attribute: `process.mining.dfg.node_count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `12`, `25`, `80`
  """
  @spec process_mining_dfg_node_count() :: :"process.mining.dfg.node_count"
  def process_mining_dfg_node_count, do: :"process.mining.dfg.node_count"

  @doc """
  The magnitude of drift correction applied (change in fitness/conformance score).

  Attribute: `process.mining.drift.correction.delta`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0.05`, `0.12`, `0.3`
  """
  @spec process_mining_drift_correction_delta() :: :"process.mining.drift.correction.delta"
  def process_mining_drift_correction_delta, do: :"process.mining.drift.correction.delta"

  @doc """
  Time taken (ms) to apply the drift correction.

  Attribute: `process.mining.drift.correction.duration_ms`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `500`, `5000`, `30000`
  """
  @spec process_mining_drift_correction_duration_ms() :: :"process.mining.drift.correction.duration_ms"
  def process_mining_drift_correction_duration_ms, do: :"process.mining.drift.correction.duration_ms"

  @doc """
  The type of correction applied to address the detected process drift.

  Attribute: `process.mining.drift.correction_type`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `retrain`, `threshold_adjust`, `model_swap`
  """
  @spec process_mining_drift_correction_type() :: :"process.mining.drift.correction_type"
  def process_mining_drift_correction_type, do: :"process.mining.drift.correction_type"

  @doc """
  Enumerated values for `process.mining.drift.correction_type`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `retrain` | `"retrain"` | retrain |
  | `threshold_adjust` | `"threshold_adjust"` | threshold_adjust |
  | `model_swap` | `"model_swap"` | model_swap |
  | `incremental_update` | `"incremental_update"` | incremental_update |
  """
  @spec process_mining_drift_correction_type_values() :: %{
    retrain: :retrain,
    threshold_adjust: :threshold_adjust,
    model_swap: :model_swap,
    incremental_update: :incremental_update
  }
  def process_mining_drift_correction_type_values do
    %{
      retrain: :retrain,
      threshold_adjust: :threshold_adjust,
      model_swap: :model_swap,
      incremental_update: :incremental_update
    }
  end

  defmodule ProcessMiningDriftCorrectionTypeValues do
    @moduledoc """
    Typed constants for the `process.mining.drift.correction_type` attribute.
    """

    @doc "retrain"
    @spec retrain() :: :retrain
    def retrain, do: :retrain

    @doc "threshold_adjust"
    @spec threshold_adjust() :: :threshold_adjust
    def threshold_adjust, do: :threshold_adjust

    @doc "model_swap"
    @spec model_swap() :: :model_swap
    def model_swap, do: :model_swap

    @doc "incremental_update"
    @spec incremental_update() :: :incremental_update
    def incremental_update, do: :incremental_update

  end

  @doc """
  Whether concept drift was detected in the current event window.

  Attribute: `process.mining.drift.detected`
  Type: `boolean`
  Stability: `development`
  Requirement: `recommended`
  Examples: `true`, `false`
  """
  @spec process_mining_drift_detected() :: :"process.mining.drift.detected"
  def process_mining_drift_detected, do: :"process.mining.drift.detected"

  @doc """
  Severity classification of the detected concept drift.

  Attribute: `process.mining.drift.severity`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `none`, `gradual`, `sudden`
  """
  @spec process_mining_drift_severity() :: :"process.mining.drift.severity"
  def process_mining_drift_severity, do: :"process.mining.drift.severity"

  @doc """
  Enumerated values for `process.mining.drift.severity`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `none` | `"none"` | none |
  | `gradual` | `"gradual"` | gradual |
  | `sudden` | `"sudden"` | sudden |
  | `incremental` | `"incremental"` | incremental |
  """
  @spec process_mining_drift_severity_values() :: %{
    none: :none,
    gradual: :gradual,
    sudden: :sudden,
    incremental: :incremental
  }
  def process_mining_drift_severity_values do
    %{
      none: :none,
      gradual: :gradual,
      sudden: :sudden,
      incremental: :incremental
    }
  end

  defmodule ProcessMiningDriftSeverityValues do
    @moduledoc """
    Typed constants for the `process.mining.drift.severity` attribute.
    """

    @doc "none"
    @spec none() :: :none
    def none, do: :none

    @doc "gradual"
    @spec gradual() :: :gradual
    def gradual, do: :gradual

    @doc "sudden"
    @spec sudden() :: :sudden
    def sudden, do: :sudden

    @doc "incremental"
    @spec incremental() :: :incremental
    def incremental, do: :incremental

  end

  @doc """
  Identifier of the base process model being enhanced.

  Attribute: `process.mining.enhancement.base_model_id`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `model-abc123`, `petri-net-v2`
  """
  @spec process_mining_enhancement_base_model_id() :: :"process.mining.enhancement.base_model_id"
  def process_mining_enhancement_base_model_id, do: :"process.mining.enhancement.base_model_id"

  @doc """
  Percentage of cases covered by the enhanced model, range [0.0, 100.0].

  Attribute: `process.mining.enhancement.coverage_pct`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `85.5`, `99.1`
  """
  @spec process_mining_enhancement_coverage_pct() :: :"process.mining.enhancement.coverage_pct"
  def process_mining_enhancement_coverage_pct, do: :"process.mining.enhancement.coverage_pct"

  @doc """
  Duration in milliseconds of the model enhancement operation.

  Attribute: `process.mining.enhancement.duration_ms`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `450`, `2000`
  """
  @spec process_mining_enhancement_duration_ms() :: :"process.mining.enhancement.duration_ms"
  def process_mining_enhancement_duration_ms, do: :"process.mining.enhancement.duration_ms"

  @doc """
  Relative improvement rate achieved by the enhancement, range [0.0, 1.0].

  Attribute: `process.mining.enhancement.improvement_rate`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0.12`, `0.35`
  """
  @spec process_mining_enhancement_improvement_rate() :: :"process.mining.enhancement.improvement_rate"
  def process_mining_enhancement_improvement_rate, do: :"process.mining.enhancement.improvement_rate"

  @doc """
  Unique identifier of the base process model being enhanced.

  Attribute: `process.mining.enhancement.model_id`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `model-001`, `petri-net-v2`
  """
  @spec process_mining_enhancement_model_id() :: :"process.mining.enhancement.model_id"
  def process_mining_enhancement_model_id, do: :"process.mining.enhancement.model_id"

  @doc """
  The perspective from which the process model is being enhanced.

  Attribute: `process.mining.enhancement.perspective`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `performance`, `conformance`
  """
  @spec process_mining_enhancement_perspective() :: :"process.mining.enhancement.perspective"
  def process_mining_enhancement_perspective, do: :"process.mining.enhancement.perspective"

  @doc """
  Enumerated values for `process.mining.enhancement.perspective`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `performance` | `"performance"` | performance |
  | `conformance` | `"conformance"` | conformance |
  | `organizational` | `"organizational"` | organizational |
  | `decision` | `"decision"` | decision |
  """
  @spec process_mining_enhancement_perspective_values() :: %{
    performance: :performance,
    conformance: :conformance,
    organizational: :organizational,
    decision: :decision
  }
  def process_mining_enhancement_perspective_values do
    %{
      performance: :performance,
      conformance: :conformance,
      organizational: :organizational,
      decision: :decision
    }
  end

  defmodule ProcessMiningEnhancementPerspectiveValues do
    @moduledoc """
    Typed constants for the `process.mining.enhancement.perspective` attribute.
    """

    @doc "performance"
    @spec performance() :: :performance
    def performance, do: :performance

    @doc "conformance"
    @spec conformance() :: :conformance
    def conformance, do: :conformance

    @doc "organizational"
    @spec organizational() :: :organizational
    def organizational, do: :organizational

    @doc "decision"
    @spec decision() :: :decision
    def decision, do: :decision

  end

  @doc """
  Quality score of the enhanced process model, range [0.0, 1.0].

  Attribute: `process.mining.enhancement.quality_score`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0.87`, `0.95`
  """
  @spec process_mining_enhancement_quality_score() :: :"process.mining.enhancement.quality_score"
  def process_mining_enhancement_quality_score, do: :"process.mining.enhancement.quality_score"

  @doc """
  Type of process model enhancement applied — augmenting a discovered model with additional perspectives.

  Attribute: `process.mining.enhancement.type`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `performance`, `conformance`
  """
  @spec process_mining_enhancement_type() :: :"process.mining.enhancement.type"
  def process_mining_enhancement_type, do: :"process.mining.enhancement.type"

  @doc """
  Enumerated values for `process.mining.enhancement.type`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `performance` | `"performance"` | performance |
  | `conformance` | `"conformance"` | conformance |
  | `organizational` | `"organizational"` | organizational |
  | `social_network` | `"social_network"` | social_network |
  """
  @spec process_mining_enhancement_type_values() :: %{
    performance: :performance,
    conformance: :conformance,
    organizational: :organizational,
    social_network: :social_network
  }
  def process_mining_enhancement_type_values do
    %{
      performance: :performance,
      conformance: :conformance,
      organizational: :organizational,
      social_network: :social_network
    }
  end

  defmodule ProcessMiningEnhancementTypeValues do
    @moduledoc """
    Typed constants for the `process.mining.enhancement.type` attribute.
    """

    @doc "performance"
    @spec performance() :: :performance
    def performance, do: :performance

    @doc "conformance"
    @spec conformance() :: :conformance
    def conformance, do: :conformance

    @doc "organizational"
    @spec organizational() :: :organizational
    def organizational, do: :organizational

    @doc "social_network"
    @spec social_network() :: :social_network
    def social_network, do: :social_network

  end

  @doc """
  Number of raw events before abstraction.

  Attribute: `process.mining.event.abstraction_input_count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `100`, `5000`, `100000`
  """
  @spec process_mining_event_abstraction_input_count() :: :"process.mining.event.abstraction_input_count"
  def process_mining_event_abstraction_input_count, do: :"process.mining.event.abstraction_input_count"

  @doc """
  Abstraction level of the process mining event.

  Attribute: `process.mining.event.abstraction_level`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `raw`, `activity`, `case`, `process`
  """
  @spec process_mining_event_abstraction_level() :: :"process.mining.event.abstraction_level"
  def process_mining_event_abstraction_level, do: :"process.mining.event.abstraction_level"

  @doc """
  Enumerated values for `process.mining.event.abstraction_level`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `raw` | `"raw"` | raw |
  | `activity` | `"activity"` | activity |
  | `case` | `"case"` | case |
  | `process` | `"process"` | process |
  """
  @spec process_mining_event_abstraction_level_values() :: %{
    raw: :raw,
    activity: :activity,
    case: :case,
    process: :process
  }
  def process_mining_event_abstraction_level_values do
    %{
      raw: :raw,
      activity: :activity,
      case: :case,
      process: :process
    }
  end

  defmodule ProcessMiningEventAbstractionLevelValues do
    @moduledoc """
    Typed constants for the `process.mining.event.abstraction_level` attribute.
    """

    @doc "raw"
    @spec raw() :: :raw
    def raw, do: :raw

    @doc "activity"
    @spec activity() :: :activity
    def activity, do: :activity

    @doc "case"
    @spec case() :: :case
    def case, do: :case

    @doc "process"
    @spec process() :: :process
    def process, do: :process

  end

  @doc """
  Number of mapping rules applied during event abstraction.

  Attribute: `process.mining.event.abstraction_mapping_rules`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0`, `5`, `20`
  """
  @spec process_mining_event_abstraction_mapping_rules() :: :"process.mining.event.abstraction_mapping_rules"
  def process_mining_event_abstraction_mapping_rules, do: :"process.mining.event.abstraction_mapping_rules"

  @doc """
  Number of abstracted events after abstraction.

  Attribute: `process.mining.event.abstraction_output_count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `50`, `2000`, `80000`
  """
  @spec process_mining_event_abstraction_output_count() :: :"process.mining.event.abstraction_output_count"
  def process_mining_event_abstraction_output_count, do: :"process.mining.event.abstraction_output_count"

  @doc """
  Sequence number of this event within the trace (0-indexed).

  Attribute: `process.mining.event.sequence_number`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0`, `1`, `42`
  """
  @spec process_mining_event_sequence_number() :: :"process.mining.event.sequence_number"
  def process_mining_event_sequence_number, do: :"process.mining.event.sequence_number"

  @doc """
  Number of events in the process trace.

  Attribute: `process.mining.event_count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `5`, `23`, `150`
  """
  @spec process_mining_event_count() :: :"process.mining.event_count"
  def process_mining_event_count, do: :"process.mining.event_count"

  @doc """
  Fitness score [0.0, 1.0] measuring how well a trace fits the process model.

  Attribute: `process.mining.fitness`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0.98`, `0.85`, `0.42`
  """
  @spec process_mining_fitness() :: :"process.mining.fitness"
  def process_mining_fitness, do: :"process.mining.fitness"

  @doc """
  Minimum fitness score threshold for conformance acceptance [0.0, 1.0].

  Attribute: `process.mining.fitness_threshold`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0.8`, `0.95`
  """
  @spec process_mining_fitness_threshold() :: :"process.mining.fitness_threshold"
  def process_mining_fitness_threshold, do: :"process.mining.fitness_threshold"

  @doc """
  Number of child processes under this node in the hierarchy.

  Attribute: `process.mining.hierarchy.child_count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0`, `3`, `10`
  """
  @spec process_mining_hierarchy_child_count() :: :"process.mining.hierarchy.child_count"
  def process_mining_hierarchy_child_count, do: :"process.mining.hierarchy.child_count"

  @doc """
  Depth of the process in the process hierarchy tree.

  Attribute: `process.mining.hierarchy.depth`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0`, `1`, `5`
  """
  @spec process_mining_hierarchy_depth() :: :"process.mining.hierarchy.depth"
  def process_mining_hierarchy_depth, do: :"process.mining.hierarchy.depth"

  @doc """
  Identifier of the parent process in the hierarchy.

  Attribute: `process.mining.hierarchy.parent_process_id`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `proc-root-001`, `proc-parent-42`
  """
  @spec process_mining_hierarchy_parent_process_id() :: :"process.mining.hierarchy.parent_process_id"
  def process_mining_hierarchy_parent_process_id, do: :"process.mining.hierarchy.parent_process_id"

  @doc """
  Number of cuts made during inductive mining.

  Attribute: `process.mining.inductive.cut_count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `1`, `5`, `20`
  """
  @spec process_mining_inductive_cut_count() :: :"process.mining.inductive.cut_count"
  def process_mining_inductive_cut_count, do: :"process.mining.inductive.cut_count"

  @doc """
  Type of split in inductive miner tree.

  Attribute: `process.mining.inductive.split_type`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `exclusive`, `parallel`, `loop`, `sequence`
  """
  @spec process_mining_inductive_split_type() :: :"process.mining.inductive.split_type"
  def process_mining_inductive_split_type, do: :"process.mining.inductive.split_type"

  @doc """
  Enumerated values for `process.mining.inductive.split_type`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `exclusive` | `"exclusive"` | exclusive |
  | `parallel` | `"parallel"` | parallel |
  | `loop` | `"loop"` | loop |
  | `sequence` | `"sequence"` | sequence |
  """
  @spec process_mining_inductive_split_type_values() :: %{
    exclusive: :exclusive,
    parallel: :parallel,
    loop: :loop,
    sequence: :sequence
  }
  def process_mining_inductive_split_type_values do
    %{
      exclusive: :exclusive,
      parallel: :parallel,
      loop: :loop,
      sequence: :sequence
    }
  end

  defmodule ProcessMiningInductiveSplitTypeValues do
    @moduledoc """
    Typed constants for the `process.mining.inductive.split_type` attribute.
    """

    @doc "exclusive"
    @spec exclusive() :: :exclusive
    def exclusive, do: :exclusive

    @doc "parallel"
    @spec parallel() :: :parallel
    def parallel, do: :parallel

    @doc "loop"
    @spec loop() :: :loop
    def loop, do: :loop

    @doc "sequence"
    @spec sequence() :: :sequence
    def sequence, do: :sequence

  end

  @doc """
  Maximum depth of inductive miner tree.

  Attribute: `process.mining.inductive.tree_depth`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0`, `3`, `10`
  """
  @spec process_mining_inductive_tree_depth() :: :"process.mining.inductive.tree_depth"
  def process_mining_inductive_tree_depth, do: :"process.mining.inductive.tree_depth"

  @doc """
  Unique identifier of the event log being processed.

  Attribute: `process.mining.log.id`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `log-001`, `hospital-2026`, `running-example`
  """
  @spec process_mining_log_id() :: :"process.mining.log.id"
  def process_mining_log_id, do: :"process.mining.log.id"

  @doc """
  Number of event log entries (events) processed in this mining operation.

  Attribute: `process.mining.log.size`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `1000`, `50000`, `1000000`
  """
  @spec process_mining_log_size() :: :"process.mining.log.size"
  def process_mining_log_size, do: :"process.mining.log.size"

  @doc """
  ISO 8601 timestamp of the earliest event in the event log.

  Attribute: `process.mining.log.start_timestamp`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `2024-01-01T00:00:00Z`, `2025-03-25T08:00:00Z`
  """
  @spec process_mining_log_start_timestamp() :: :"process.mining.log.start_timestamp"
  def process_mining_log_start_timestamp, do: :"process.mining.log.start_timestamp"

  @doc """
  File path or identifier of the XES event log being mined.

  Attribute: `process.mining.log_path`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `/data/hospital.xes`, `running-example.xes`
  """
  @spec process_mining_log_path() :: :"process.mining.log_path"
  def process_mining_log_path, do: :"process.mining.log_path"

  @doc """
  The type of process model used for conformance checking.

  Attribute: `process.mining.model.type`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `petri_net`, `bpmn`
  """
  @spec process_mining_model_type() :: :"process.mining.model.type"
  def process_mining_model_type, do: :"process.mining.model.type"

  @doc """
  Enumerated values for `process.mining.model.type`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `petri_net` | `"petri_net"` | petri_net |
  | `bpmn` | `"bpmn"` | bpmn |
  | `dfg` | `"dfg"` | dfg |
  | `declare` | `"declare"` | declare |
  """
  @spec process_mining_model_type_values() :: %{
    petri_net: :petri_net,
    bpmn: :bpmn,
    dfg: :dfg,
    declare: :declare
  }
  def process_mining_model_type_values do
    %{
      petri_net: :petri_net,
      bpmn: :bpmn,
      dfg: :dfg,
      declare: :declare
    }
  end

  defmodule ProcessMiningModelTypeValues do
    @moduledoc """
    Typed constants for the `process.mining.model.type` attribute.
    """

    @doc "petri_net"
    @spec petri_net() :: :petri_net
    def petri_net, do: :petri_net

    @doc "bpmn"
    @spec bpmn() :: :bpmn
    def bpmn, do: :bpmn

    @doc "dfg"
    @spec dfg() :: :dfg
    def dfg, do: :dfg

    @doc "declare"
    @spec declare() :: :declare
    def declare, do: :declare

  end

  @doc """
  Number of places in the discovered Petri net model.

  Attribute: `process.mining.petri_net.place_count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `8`, `20`, `45`
  """
  @spec process_mining_petri_net_place_count() :: :"process.mining.petri_net.place_count"
  def process_mining_petri_net_place_count, do: :"process.mining.petri_net.place_count"

  @doc """
  Number of transitions in the discovered Petri net model.

  Attribute: `process.mining.petri_net.transition_count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `10`, `25`, `60`
  """
  @spec process_mining_petri_net_transition_count() :: :"process.mining.petri_net.transition_count"
  def process_mining_petri_net_transition_count, do: :"process.mining.petri_net.transition_count"

  @doc """
  Confidence score of the process outcome prediction, range [0.0, 1.0].

  Attribute: `process.mining.prediction.confidence`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0.75`, `0.9`, `0.95`
  """
  @spec process_mining_prediction_confidence() :: :"process.mining.prediction.confidence"
  def process_mining_prediction_confidence, do: :"process.mining.prediction.confidence"

  @doc """
  Time horizon (ms) for which the process outcome prediction is made.

  Attribute: `process.mining.prediction.horizon_ms`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `3600000`, `86400000`, `604800000`
  """
  @spec process_mining_prediction_horizon_ms() :: :"process.mining.prediction.horizon_ms"
  def process_mining_prediction_horizon_ms, do: :"process.mining.prediction.horizon_ms"

  @doc """
  The type of predictive model used (e.g., lstm, xgboost, conformance_replay).

  Attribute: `process.mining.prediction.model_type`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `lstm`, `xgboost`, `conformance_replay`, `markov`
  """
  @spec process_mining_prediction_model_type() :: :"process.mining.prediction.model_type"
  def process_mining_prediction_model_type, do: :"process.mining.prediction.model_type"

  @doc """
  Fitness score of the baseline model [0.0, 1.0].

  Attribute: `process.mining.replay.comparison.baseline_fitness`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0.82`, `0.95`
  """
  @spec process_mining_replay_comparison_baseline_fitness() :: :"process.mining.replay.comparison.baseline_fitness"
  def process_mining_replay_comparison_baseline_fitness, do: :"process.mining.replay.comparison.baseline_fitness"

  @doc """
  Difference (target - baseline) in fitness scores.

  Attribute: `process.mining.replay.comparison.delta`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0.06`, `-0.02`, `0.12`
  """
  @spec process_mining_replay_comparison_delta() :: :"process.mining.replay.comparison.delta"
  def process_mining_replay_comparison_delta, do: :"process.mining.replay.comparison.delta"

  @doc """
  Fitness score of the target model [0.0, 1.0].

  Attribute: `process.mining.replay.comparison.target_fitness`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0.88`, `0.97`
  """
  @spec process_mining_replay_comparison_target_fitness() :: :"process.mining.replay.comparison.target_fitness"
  def process_mining_replay_comparison_target_fitness, do: :"process.mining.replay.comparison.target_fitness"

  @doc """
  Unique identifier for the replay comparison run.

  Attribute: `process.mining.replay.comparison_id`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `cmp-001`, `replay-baseline-vs-v2`
  """
  @spec process_mining_replay_comparison_id() :: :"process.mining.replay.comparison_id"
  def process_mining_replay_comparison_id, do: :"process.mining.replay.comparison_id"

  @doc """
  Number of tokens consumed during the complete token replay.

  Attribute: `process.mining.replay.consumed_tokens`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `48`, `200`, `1000`
  """
  @spec process_mining_replay_consumed_tokens() :: :"process.mining.replay.consumed_tokens"
  def process_mining_replay_consumed_tokens, do: :"process.mining.replay.consumed_tokens"

  @doc """
  Number of transitions enabled (fireable) during token replay.

  Attribute: `process.mining.replay.enabled_transitions`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `12`, `48`, `200`
  """
  @spec process_mining_replay_enabled_transitions() :: :"process.mining.replay.enabled_transitions"
  def process_mining_replay_enabled_transitions, do: :"process.mining.replay.enabled_transitions"

  @doc """
  Replay fitness score [0.0, 1.0] measuring how well the log fits the discovered model via token replay.

  Attribute: `process.mining.replay.fitness`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0.85`, `0.97`, `1.0`
  """
  @spec process_mining_replay_fitness() :: :"process.mining.replay.fitness"
  def process_mining_replay_fitness, do: :"process.mining.replay.fitness"

  @doc """
  Generalization score — measures how well the model generalizes beyond observed traces [0.0, 1.0].

  Attribute: `process.mining.replay.generalization`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0.78`, `0.95`
  """
  @spec process_mining_replay_generalization() :: :"process.mining.replay.generalization"
  def process_mining_replay_generalization, do: :"process.mining.replay.generalization"

  @doc """
  Number of missing tokens encountered during token replay conformance checking.

  Attribute: `process.mining.replay.missing_tokens`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0`, `3`, `15`
  """
  @spec process_mining_replay_missing_tokens() :: :"process.mining.replay.missing_tokens"
  def process_mining_replay_missing_tokens, do: :"process.mining.replay.missing_tokens"

  @doc """
  Precision score of replay conformance check — measures how much of the model behaviour is in the log [0.0, 1.0].

  Attribute: `process.mining.replay.precision`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0.85`, `0.92`
  """
  @spec process_mining_replay_precision() :: :"process.mining.replay.precision"
  def process_mining_replay_precision, do: :"process.mining.replay.precision"

  @doc """
  Simplicity score — measures the structural simplicity of the discovered model [0.0, 1.0].

  Attribute: `process.mining.replay.simplicity`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0.7`, `0.88`
  """
  @spec process_mining_replay_simplicity() :: :"process.mining.replay.simplicity"
  def process_mining_replay_simplicity, do: :"process.mining.replay.simplicity"

  @doc """
  Number of tokens produced and consumed during token replay conformance checking.

  Attribute: `process.mining.replay.token_count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `48`, `200`, `1500`
  """
  @spec process_mining_replay_token_count() :: :"process.mining.replay.token_count"
  def process_mining_replay_token_count, do: :"process.mining.replay.token_count"

  @doc """
  Confidence score for the root cause classification [0.0, 1.0].

  Attribute: `process.mining.root_cause.confidence`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0.88`, `0.95`
  """
  @spec process_mining_root_cause_confidence() :: :"process.mining.root_cause.confidence"
  def process_mining_root_cause_confidence, do: :"process.mining.root_cause.confidence"

  @doc """
  Identifier of the root cause detected in the process anomaly.

  Attribute: `process.mining.root_cause.id`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `rc-001`, `rc-data-quality-03`
  """
  @spec process_mining_root_cause_id() :: :"process.mining.root_cause.id"
  def process_mining_root_cause_id, do: :"process.mining.root_cause.id"

  @doc """
  Type classification of the detected root cause.

  Attribute: `process.mining.root_cause.type`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  """
  @spec process_mining_root_cause_type() :: :"process.mining.root_cause.type"
  def process_mining_root_cause_type, do: :"process.mining.root_cause.type"

  @doc """
  Enumerated values for `process.mining.root_cause.type`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `data_quality` | `"data_quality"` | data_quality |
  | `model_drift` | `"model_drift"` | model_drift |
  | `process_change` | `"process_change"` | process_change |
  | `resource_bottleneck` | `"resource_bottleneck"` | resource_bottleneck |
  | `compliance_violation` | `"compliance_violation"` | compliance_violation |
  """
  @spec process_mining_root_cause_type_values() :: %{
    data_quality: :data_quality,
    model_drift: :model_drift,
    process_change: :process_change,
    resource_bottleneck: :resource_bottleneck,
    compliance_violation: :compliance_violation
  }
  def process_mining_root_cause_type_values do
    %{
      data_quality: :data_quality,
      model_drift: :model_drift,
      process_change: :process_change,
      resource_bottleneck: :resource_bottleneck,
      compliance_violation: :compliance_violation
    }
  end

  defmodule ProcessMiningRootCauseTypeValues do
    @moduledoc """
    Typed constants for the `process.mining.root_cause.type` attribute.
    """

    @doc "data_quality"
    @spec data_quality() :: :data_quality
    def data_quality, do: :data_quality

    @doc "model_drift"
    @spec model_drift() :: :model_drift
    def model_drift, do: :model_drift

    @doc "process_change"
    @spec process_change() :: :process_change
    def process_change, do: :process_change

    @doc "resource_bottleneck"
    @spec resource_bottleneck() :: :resource_bottleneck
    def resource_bottleneck, do: :resource_bottleneck

    @doc "compliance_violation"
    @spec compliance_violation() :: :compliance_violation
    def compliance_violation, do: :compliance_violation

  end

  @doc """
  Number of process cases (traces) generated in the simulation run.

  Attribute: `process.mining.simulation.cases`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `100`, `1000`, `5000`
  """
  @spec process_mining_simulation_cases() :: :"process.mining.simulation.cases"
  def process_mining_simulation_cases, do: :"process.mining.simulation.cases"

  @doc """
  Duration of the simulation run in milliseconds.

  Attribute: `process.mining.simulation.duration_ms`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `250`, `1200`, `5000`
  """
  @spec process_mining_simulation_duration_ms() :: :"process.mining.simulation.duration_ms"
  def process_mining_simulation_duration_ms, do: :"process.mining.simulation.duration_ms"

  @doc """
  Fraction of simulated traces that include random noise/deviations, range [0.0, 1.0].

  Attribute: `process.mining.simulation.noise_rate`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0.05`, `0.1`, `0.2`
  """
  @spec process_mining_simulation_noise_rate() :: :"process.mining.simulation.noise_rate"
  def process_mining_simulation_noise_rate, do: :"process.mining.simulation.noise_rate"

  @doc """
  Maximum betweenness centrality score across all nodes in the social network.

  Attribute: `process.mining.social_network.centrality_max`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0.25`, `0.6`, `0.9`
  """
  @spec process_mining_social_network_centrality_max() :: :"process.mining.social_network.centrality_max"
  def process_mining_social_network_centrality_max, do: :"process.mining.social_network.centrality_max"

  @doc """
  Density of the social network graph derived from the process log, range [0.0, 1.0].

  Attribute: `process.mining.social_network.density`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0.3`, `0.7`, `0.95`
  """
  @spec process_mining_social_network_density() :: :"process.mining.social_network.density"
  def process_mining_social_network_density, do: :"process.mining.social_network.density"

  @doc """
  Number of handover-of-work edges in the social network.

  Attribute: `process.mining.social_network.handover_count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `10`, `50`, `200`
  """
  @spec process_mining_social_network_handover_count() :: :"process.mining.social_network.handover_count"
  def process_mining_social_network_handover_count, do: :"process.mining.social_network.handover_count"

  @doc """
  Number of nodes (resources/roles) in the social network.

  Attribute: `process.mining.social_network.node_count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `5`, `20`, `100`
  """
  @spec process_mining_social_network_node_count() :: :"process.mining.social_network.node_count"
  def process_mining_social_network_node_count, do: :"process.mining.social_network.node_count"

  @doc """
  Current throughput rate of the streaming process mining engine.

  Attribute: `process.mining.streaming.events_per_second`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `100.0`, `2500.0`, `50000.0`
  """
  @spec process_mining_streaming_events_per_second() :: :"process.mining.streaming.events_per_second"
  def process_mining_streaming_events_per_second, do: :"process.mining.streaming.events_per_second"

  @doc """
  Current lag in milliseconds between event stream and mining output.

  Attribute: `process.mining.streaming.lag_ms`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `10`, `500`, `5000`
  """
  @spec process_mining_streaming_lag_ms() :: :"process.mining.streaming.lag_ms"
  def process_mining_streaming_lag_ms, do: :"process.mining.streaming.lag_ms"

  @doc """
  Sliding window size in number of events for streaming process mining.

  Attribute: `process.mining.streaming.window_size`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `100`, `500`, `1000`
  """
  @spec process_mining_streaming_window_size() :: :"process.mining.streaming.window_size"
  def process_mining_streaming_window_size, do: :"process.mining.streaming.window_size"

  @doc """
  Temporal drift detected in the process — deviation from expected timing baseline in milliseconds.

  Attribute: `process.mining.temporal.drift_ms`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `100`, `5000`, `30000`
  """
  @spec process_mining_temporal_drift_ms() :: :"process.mining.temporal.drift_ms"
  def process_mining_temporal_drift_ms, do: :"process.mining.temporal.drift_ms"

  @doc """
  Detected seasonality period in the process temporal pattern in milliseconds.

  Attribute: `process.mining.temporal.seasonality_period_ms`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `86400000`, `604800000`
  """
  @spec process_mining_temporal_seasonality_period_ms() :: :"process.mining.temporal.seasonality_period_ms"
  def process_mining_temporal_seasonality_period_ms, do: :"process.mining.temporal.seasonality_period_ms"

  @doc """
  Slope of the temporal trend in the process — positive = accelerating, negative = decelerating.

  Attribute: `process.mining.temporal.trend_slope`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0.05`, `-0.12`, `1.5`
  """
  @spec process_mining_temporal_trend_slope() :: :"process.mining.temporal.trend_slope"
  def process_mining_temporal_trend_slope, do: :"process.mining.temporal.trend_slope"

  @doc """
  Average throughput time (start to completion) across all trace instances, in milliseconds.

  Attribute: `process.mining.throughput_time_ms`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `3600000`, `86400000`
  """
  @spec process_mining_throughput_time_ms() :: :"process.mining.throughput_time_ms"
  def process_mining_throughput_time_ms, do: :"process.mining.throughput_time_ms"

  @doc """
  Identifier of the process trace from the XES event log.

  Attribute: `process.mining.trace_id`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `trace-001`, `case-2026-abc`, `patient-123`
  """
  @spec process_mining_trace_id() :: :"process.mining.trace_id"
  def process_mining_trace_id, do: :"process.mining.trace_id"

  @doc """
  Deviation score from the reference model for this variant, range [0.0, 1.0]. Higher = more deviant.

  Attribute: `process.mining.variant.deviation_score`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0.0`, `0.35`, `0.89`
  """
  @spec process_mining_variant_deviation_score() :: :"process.mining.variant.deviation_score"
  def process_mining_variant_deviation_score, do: :"process.mining.variant.deviation_score"

  @doc """
  Relative frequency of this variant in the event log, range [0.0, 1.0].

  Attribute: `process.mining.variant.frequency`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0.42`, `0.15`, `0.03`
  """
  @spec process_mining_variant_frequency() :: :"process.mining.variant.frequency"
  def process_mining_variant_frequency, do: :"process.mining.variant.frequency"

  @doc """
  Unique identifier for a process variant (distinct execution trace pattern).

  Attribute: `process.mining.variant.id`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `variant-001`, `trace-pattern-A7`
  """
  @spec process_mining_variant_id() :: :"process.mining.variant.id"
  def process_mining_variant_id, do: :"process.mining.variant.id"

  @doc """
  Whether this variant represents the optimal (most efficient) process path.

  Attribute: `process.mining.variant.is_optimal`
  Type: `boolean`
  Stability: `development`
  Requirement: `recommended`
  Examples: `true`, `false`
  """
  @spec process_mining_variant_is_optimal() :: :"process.mining.variant.is_optimal"
  def process_mining_variant_is_optimal, do: :"process.mining.variant.is_optimal"

  @doc """
  Number of unique trace variants in the event log.

  Attribute: `process.mining.variant_count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `15`, `80`, `500`
  """
  @spec process_mining_variant_count() :: :"process.mining.variant_count"
  def process_mining_variant_count, do: :"process.mining.variant_count"

end