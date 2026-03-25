defmodule OpenTelemetry.SemConv.Incubating.ProcessSpanNames do
  @moduledoc """
  Process semantic convention span names.

  Namespace: `process`

  This module is generated from the ChatmanGPT semantic convention registry.
  Do not edit manually — regenerate with:

      weaver registry generate -r ./semconv/model --templates ./semconv/templates elixir ./OSA/lib/osa/semconv/
  """

  @doc """
  Alignment analysis — examining multiple alignment results to identify common deviation patterns and fitness trends.

  Span: `span.process.mining.alignment.analyze`
  Kind: `internal`
  Stability: `development`
  """
  @spec process_mining_alignment_analyze() :: String.t()
  def process_mining_alignment_analyze, do: "process.mining.alignment.analyze"

  @doc """
  Bottleneck analysis — scoring and ranking detected bottlenecks by severity and impact.

  Span: `span.process.mining.bottleneck.analyze`
  Kind: `internal`
  Stability: `development`
  """
  @spec process_mining_bottleneck_analyze() :: String.t()
  def process_mining_bottleneck_analyze, do: "process.mining.bottleneck.analyze"

  @doc """
  Bottleneck detection — identifying the activity with the highest average waiting time.

  Span: `span.process.mining.bottleneck_detection`
  Kind: `internal`
  Stability: `development`
  """
  @spec process_mining_bottleneck_detection() :: String.t()
  def process_mining_bottleneck_detection, do: "process.mining.bottleneck_detection"

  @doc """
  Case clustering — grouping process cases by behavioral similarity using ML clustering algorithms.

  Span: `span.process.mining.case.cluster`
  Kind: `internal`
  Stability: `development`
  """
  @spec process_mining_case_cluster() :: String.t()
  def process_mining_case_cluster, do: "process.mining.case.cluster"

  @doc """
  Process complexity measurement — computing complexity metrics for a discovered process model.

  Span: `span.process.mining.complexity.measure`
  Kind: `internal`
  Stability: `development`
  """
  @spec process_mining_complexity_measure() :: String.t()
  def process_mining_complexity_measure, do: "process.mining.complexity.measure"

  @doc """
  Detection of a single conformance deviation during trace alignment.

  Span: `span.process.mining.conformance.deviation`
  Kind: `internal`
  Stability: `development`
  """
  @spec process_mining_conformance_deviation() :: String.t()
  def process_mining_conformance_deviation, do: "process.mining.conformance.deviation"

  @doc """
  Conformance repair — automatically repairing a non-conformant trace to align with the process model.

  Span: `span.process.mining.conformance.repair`
  Kind: `internal`
  Stability: `development`
  """
  @spec process_mining_conformance_repair() :: String.t()
  def process_mining_conformance_repair, do: "process.mining.conformance.repair"

  @doc """
  Conformance threshold check — evaluates all cases against the defined conformance threshold and reports violations.

  Span: `span.process.mining.conformance.threshold`
  Kind: `internal`
  Stability: `development`
  """
  @spec process_mining_conformance_threshold() :: String.t()
  def process_mining_conformance_threshold, do: "process.mining.conformance.threshold"

  @doc """
  Generating a conformance visualization — token replay, alignment diagram, or footprint matrix.

  Span: `span.process.mining.conformance.visualize`
  Kind: `internal`
  Stability: `development`
  """
  @spec process_mining_conformance_visualize() :: String.t()
  def process_mining_conformance_visualize, do: "process.mining.conformance.visualize"

  @doc """
  Mining decision rules from a process log — discovers conditions that determine process branching.

  Span: `span.process.mining.decision.mine`
  Kind: `internal`
  Stability: `development`
  """
  @spec process_mining_decision_mine() :: String.t()
  def process_mining_decision_mine, do: "process.mining.decision.mine"

  @doc """
  Detection of a single conformance deviation during trace alignment.

  Span: `span.process.mining.deviation`
  Kind: `internal`
  Stability: `development`
  """
  @spec process_mining_deviation() :: String.t()
  def process_mining_deviation, do: "process.mining.deviation"

  @doc """
  Computation of a Directly-Follows Graph (DFG) from an event log.

  Span: `span.process.mining.dfg`
  Kind: `internal`
  Stability: `development`
  """
  @spec process_mining_dfg() :: String.t()
  def process_mining_dfg, do: "process.mining.dfg"

  @doc """
  Computation of a Directly-Follows Graph from an event log.

  Span: `span.process.mining.dfg.compute`
  Kind: `internal`
  Stability: `development`
  """
  @spec process_mining_dfg_compute() :: String.t()
  def process_mining_dfg_compute, do: "process.mining.dfg.compute"

  @doc """
  Process model discovery run — applying a mining algorithm to an event log to produce a Petri net or BPMN model.

  Span: `span.process.mining.discovery`
  Kind: `internal`
  Stability: `development`
  """
  @spec process_mining_discovery() :: String.t()
  def process_mining_discovery, do: "process.mining.discovery"

  @doc """
  Process drift correction — applying model adaptation to address detected concept drift.

  Span: `span.process.mining.drift.correct`
  Kind: `internal`
  Stability: `development`
  """
  @spec process_mining_drift_correct() :: String.t()
  def process_mining_drift_correct, do: "process.mining.drift.correct"

  @doc """
  Detecting concept drift in a streaming process mining window.

  Span: `span.process.mining.drift.detect`
  Kind: `internal`
  Stability: `development`
  """
  @spec process_mining_drift_detect() :: String.t()
  def process_mining_drift_detect, do: "process.mining.drift.detect"

  @doc """
  Event abstraction — mapping raw low-level events to higher-level process activities.

  Span: `span.process.mining.event.abstract`
  Kind: `internal`
  Stability: `development`
  """
  @spec process_mining_event_abstract() :: String.t()
  def process_mining_event_abstract, do: "process.mining.event.abstract"

  @doc """
  Building a process hierarchy tree from process mining trace data.

  Span: `span.process.mining.hierarchy.build`
  Kind: `internal`
  Stability: `development`
  """
  @spec process_mining_hierarchy_build() :: String.t()
  def process_mining_hierarchy_build, do: "process.mining.hierarchy.build"

  @doc """
  Preprocessing an event log — filtering, sorting, and preparing for mining or conformance.

  Span: `span.process.mining.log.preprocess`
  Kind: `internal`
  Stability: `development`
  """
  @spec process_mining_log_preprocess() :: String.t()
  def process_mining_log_preprocess, do: "process.mining.log.preprocess"

  @doc """
  Process model enhancement — augmenting a discovered model with performance, conformance, or organizational perspectives.

  Span: `span.process.mining.model.enhance`
  Kind: `internal`
  Stability: `development`
  """
  @spec process_mining_model_enhance() :: String.t()
  def process_mining_model_enhance, do: "process.mining.model.enhance"

  @doc """
  Quality assessment of an enhanced process model — measures coverage, fitness improvement, and enhancement perspective.

  Span: `span.process.mining.model.quality`
  Kind: `internal`
  Stability: `development`
  """
  @spec process_mining_model_quality() :: String.t()
  def process_mining_model_quality, do: "process.mining.model.quality"

  @doc """
  Process outcome prediction — forecasting future trace completion, bottlenecks, or deviations using a predictive model.

  Span: `span.process.mining.prediction.make`
  Kind: `internal`
  Stability: `development`
  """
  @spec process_mining_prediction_make() :: String.t()
  def process_mining_prediction_make, do: "process.mining.prediction.make"

  @doc """
  Alignment-based conformance checking — computing optimal alignments between log and model.

  Span: `span.process.mining.replay.alignment`
  Kind: `internal`
  Stability: `development`
  """
  @spec process_mining_replay_alignment() :: String.t()
  def process_mining_replay_alignment, do: "process.mining.replay.alignment"

  @doc """
  Token replay conformance check — replaying a trace against a Petri net model to measure fitness.

  Span: `span.process.mining.replay.check`
  Kind: `internal`
  Stability: `development`
  """
  @spec process_mining_replay_check() :: String.t()
  def process_mining_replay_check, do: "process.mining.replay.check"

  @doc """
  Replay comparison — comparing fitness scores between baseline and target process models.

  Span: `span.process.mining.replay.compare`
  Kind: `internal`
  Stability: `development`
  """
  @spec process_mining_replay_compare() :: String.t()
  def process_mining_replay_compare, do: "process.mining.replay.compare"

  @doc """
  Root cause analysis of a process anomaly — identifies why a deviation occurred.

  Span: `span.process.mining.root_cause.analyze`
  Kind: `internal`
  Stability: `development`
  """
  @spec process_mining_root_cause_analyze() :: String.t()
  def process_mining_root_cause_analyze, do: "process.mining.root_cause.analyze"

  @doc """
  Running a process simulation — generates synthetic event logs from a discovered model.

  Span: `span.process.mining.simulation.run`
  Kind: `internal`
  Stability: `development`
  """
  @spec process_mining_simulation_run() :: String.t()
  def process_mining_simulation_run, do: "process.mining.simulation.run"

  @doc """
  Social network analysis of a process log — discovering collaboration patterns, handover-of-work, and resource roles.

  Span: `span.process.mining.social_network.analyze`
  Kind: `internal`
  Stability: `development`
  """
  @spec process_mining_social_network_analyze() :: String.t()
  def process_mining_social_network_analyze, do: "process.mining.social_network.analyze"

  @doc """
  Ingesting an event batch into the streaming process mining window.

  Span: `span.process.mining.streaming.ingest`
  Kind: `consumer`
  Stability: `development`
  """
  @spec process_mining_streaming_ingest() :: String.t()
  def process_mining_streaming_ingest, do: "process.mining.streaming.ingest"

  @doc """
  Temporal analysis of a process — detecting drift, seasonality, and trend patterns.

  Span: `span.process.mining.temporal.analyze`
  Kind: `internal`
  Stability: `development`
  """
  @spec process_mining_temporal_analyze() :: String.t()
  def process_mining_temporal_analyze, do: "process.mining.temporal.analyze"

  @doc """
  Analysis of process variants — identifying distinct execution patterns and their frequencies in the event log.

  Span: `span.process.mining.variant.analyze`
  Kind: `internal`
  Stability: `development`
  """
  @spec process_mining_variant_analyze() :: String.t()
  def process_mining_variant_analyze, do: "process.mining.variant.analyze"

  @doc """
  Process variant analysis — identifying and ranking unique execution paths in the event log.

  Span: `span.process.mining.variant_analysis`
  Kind: `internal`
  Stability: `development`
  """
  @spec process_mining_variant_analysis() :: String.t()
  def process_mining_variant_analysis, do: "process.mining.variant_analysis"

  @doc """
  All span names in this namespace.
  """
  @spec all() :: [String.t()]
  def all do
    [
      process_mining_alignment_analyze(),
      process_mining_bottleneck_analyze(),
      process_mining_bottleneck_detection(),
      process_mining_case_cluster(),
      process_mining_complexity_measure(),
      process_mining_conformance_deviation(),
      process_mining_conformance_repair(),
      process_mining_conformance_threshold(),
      process_mining_conformance_visualize(),
      process_mining_decision_mine(),
      process_mining_deviation(),
      process_mining_dfg(),
      process_mining_dfg_compute(),
      process_mining_discovery(),
      process_mining_drift_correct(),
      process_mining_drift_detect(),
      process_mining_event_abstract(),
      process_mining_hierarchy_build(),
      process_mining_log_preprocess(),
      process_mining_model_enhance(),
      process_mining_model_quality(),
      process_mining_prediction_make(),
      process_mining_replay_alignment(),
      process_mining_replay_check(),
      process_mining_replay_compare(),
      process_mining_root_cause_analyze(),
      process_mining_simulation_run(),
      process_mining_social_network_analyze(),
      process_mining_streaming_ingest(),
      process_mining_temporal_analyze(),
      process_mining_variant_analyze(),
      process_mining_variant_analysis()
    ]
  end
end