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
  """
  @spec process_mining_algorithm_values() :: %{
    alpha_miner: :alpha_miner,
    inductive_miner: :inductive_miner,
    heuristics_miner: :heuristics_miner
  }
  def process_mining_algorithm_values do
    %{
      alpha_miner: :alpha_miner,
      inductive_miner: :inductive_miner,
      heuristics_miner: :heuristics_miner
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

  end

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
  Number of unique trace variants in the event log.

  Attribute: `process.mining.variant_count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `15`, `80`, `500`
  """
  @spec process_mining_variant_count() :: :"process.mining.variant_count"
  def process_mining_variant_count, do: :"process.mining.variant_count"

  # === Wave 9 Iteration 9: Process Mining Advanced ===

  @doc """
  Average time (ms) for a case to complete end-to-end.

  Attribute: `process.mining.throughput_time_ms`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `120000`, `3600000`, `86400000`
  """
  @spec process_mining_throughput_time_ms() :: :"process.mining.throughput_time_ms"
  def process_mining_throughput_time_ms, do: :"process.mining.throughput_time_ms"

  @doc """
  Name of the activity identified as the bottleneck in the process.

  Attribute: `process.mining.bottleneck.activity`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `Examine Thoroughly`, `Await Lab Results`, `Manager Approval`
  """
  @spec process_mining_bottleneck_activity() :: :"process.mining.bottleneck.activity"
  def process_mining_bottleneck_activity, do: :"process.mining.bottleneck.activity"

  @doc """
  Average wait time (ms) at the identified bottleneck activity.

  Attribute: `process.mining.bottleneck.wait_ms`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `30000`, `600000`, `7200000`
  """
  @spec process_mining_bottleneck_wait_ms() :: :"process.mining.bottleneck.wait_ms"
  def process_mining_bottleneck_wait_ms, do: :"process.mining.bottleneck.wait_ms"

  @doc """
  Total number of events in the XES event log being analyzed.

  Attribute: `process.mining.log.size`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `5000`, `150000`, `2000000`
  """
  @spec process_mining_log_size() :: :"process.mining.log.size"
  def process_mining_log_size, do: :"process.mining.log.size"

  @doc """
  Token replay fitness score measuring how well traces fit the discovered model [0.0, 1.0].

  Attribute: `process.mining.replay_fitness`
  Type: `float`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0.85`, `0.97`, `1.0`
  """
  @spec process_mining_replay_fitness() :: :"process.mining.replay_fitness"
  def process_mining_replay_fitness, do: :"process.mining.replay_fitness"

end