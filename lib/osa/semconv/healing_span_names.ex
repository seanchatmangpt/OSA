defmodule OpenTelemetry.SemConv.Incubating.HealingSpanNames do
  @moduledoc """
  Healing semantic convention span names.

  Namespace: `healing`

  This module is generated from the ChatmanGPT semantic convention registry.
  Do not edit manually — regenerate with:

      weaver registry generate -r ./semconv/model --templates ./semconv/templates elixir ./OSA/lib/osa/semconv/
  """

  @doc """
  Adaptive threshold adjustment — updates the healing detection threshold based on observed system behavior.

  Span: `span.healing.adaptive.adjust`
  Kind: `internal`
  Stability: `development`
  """
  @spec healing_adaptive_adjust() :: String.t()
  def healing_adaptive_adjust, do: "healing.adaptive.adjust"

  @doc """
  Anomaly detection scan — identifies abnormal system behavior patterns for healing intervention.

  Span: `span.healing.anomaly.detect`
  Kind: `internal`
  Stability: `development`
  """
  @spec healing_anomaly_detect() :: String.t()
  def healing_anomaly_detect, do: "healing.anomaly.detect"

  @doc """
  Backpressure application — managing healing request flow under system overload.

  Span: `span.healing.backpressure.apply`
  Kind: `internal`
  Stability: `development`
  """
  @spec healing_backpressure_apply() :: String.t()
  def healing_backpressure_apply, do: "healing.backpressure.apply"

  @doc """
  Detecting cascade failure pattern — identifying correlated failures and root cause.

  Span: `span.healing.cascade.detect`
  Kind: `internal`
  Stability: `development`
  """
  @spec healing_cascade_detect() :: String.t()
  def healing_cascade_detect, do: "healing.cascade.detect"

  @doc """
  Healing checkpoint creation — capturing system state as a recovery checkpoint before risky operations.

  Span: `span.healing.checkpoint.create`
  Kind: `internal`
  Stability: `development`
  """
  @spec healing_checkpoint_create() :: String.t()
  def healing_checkpoint_create, do: "healing.checkpoint.create"

  @doc """
  Circuit breaker state transition — healing subsystem trips open to prevent cascade failures.

  Span: `span.healing.circuit_breaker.trip`
  Kind: `internal`
  Stability: `development`
  """
  @spec healing_circuit_breaker_trip() :: String.t()
  def healing_circuit_breaker_trip, do: "healing.circuit_breaker.trip"

  @doc """
  Cold standby promotion — warming up and promoting a cold replica to primary during a healing failover.

  Span: `span.healing.cold_standby.promote`
  Kind: `internal`
  Stability: `development`
  """
  @spec healing_cold_standby_promote() :: String.t()
  def healing_cold_standby_promote, do: "healing.cold_standby.promote"

  @doc """
  Classifies a system failure into a known failure mode with a confidence score.

  Span: `span.healing.diagnosis`
  Kind: `internal`
  Stability: `development`
  """
  @spec healing_diagnosis() :: String.t()
  def healing_diagnosis, do: "healing.diagnosis"

  @doc """
  Escalation to human operator when healing max attempts exceeded.

  Span: `span.healing.escalation`
  Kind: `internal`
  Stability: `development`
  """
  @spec healing_escalation() :: String.t()
  def healing_escalation, do: "healing.escalation"

  @doc """
  Healing failover execution — transitioning service from a failing component to a standby replacement.

  Span: `span.healing.failover.execute`
  Kind: `internal`
  Stability: `development`
  """
  @spec healing_failover_execute() :: String.t()
  def healing_failover_execute, do: "healing.failover.execute"

  @doc """
  Process fingerprinting — computes a failure signature for pattern matching.

  Span: `span.healing.fingerprint`
  Kind: `internal`
  Stability: `development`
  """
  @spec healing_fingerprint() :: String.t()
  def healing_fingerprint, do: "healing.fingerprint"

  @doc """
  Healing intervention scoring — evaluates the effectiveness of a completed healing intervention.

  Span: `span.healing.intervention.score`
  Kind: `internal`
  Stability: `development`
  """
  @spec healing_intervention_score() :: String.t()
  def healing_intervention_score, do: "healing.intervention.score"

  @doc """
  Load shedding application — intentionally dropping requests to protect the system under overload conditions.

  Span: `span.healing.load_shedding.apply`
  Kind: `internal`
  Stability: `development`
  """
  @spec healing_load_shedding_apply() :: String.t()
  def healing_load_shedding_apply, do: "healing.load_shedding.apply"

  @doc """
  Memory snapshot — capturing the current system state to enable fast recovery during healing.

  Span: `span.healing.memory.snapshot`
  Kind: `internal`
  Stability: `development`
  """
  @spec healing_memory_snapshot() :: String.t()
  def healing_memory_snapshot, do: "healing.memory.snapshot"

  @doc """
  Measuring MTTR for a completed healing cycle — from failure detection to full recovery.

  Span: `span.healing.mttr.measure`
  Kind: `internal`
  Stability: `development`
  """
  @spec healing_mttr_measure() :: String.t()
  def healing_mttr_measure, do: "healing.mttr.measure"

  @doc """
  Matching a failure signature against the healing pattern library to identify recovery action.

  Span: `span.healing.pattern.match`
  Kind: `internal`
  Stability: `development`
  """
  @spec healing_pattern_match() :: String.t()
  def healing_pattern_match, do: "healing.pattern.match"

  @doc """
  Execution of a healing recovery playbook — structured series of remediation steps.

  Span: `span.healing.playbook.execute`
  Kind: `internal`
  Stability: `development`
  """
  @spec healing_playbook_execute() :: String.t()
  def healing_playbook_execute, do: "healing.playbook.execute"

  @doc """
  Predictive healing — forecasts failure probability within a time horizon using ML model.

  Span: `span.healing.prediction.make`
  Kind: `internal`
  Stability: `development`
  """
  @spec healing_prediction_make() :: String.t()
  def healing_prediction_make, do: "healing.prediction.make"

  @doc """
  Quarantine application — isolating a component to prevent cascade failures during healing.

  Span: `span.healing.quarantine.apply`
  Kind: `internal`
  Stability: `development`
  """
  @spec healing_quarantine_apply() :: String.t()
  def healing_quarantine_apply, do: "healing.quarantine.apply"

  @doc """
  Rate limit enforcement — throttling healing attempts to prevent cascade recovery storms.

  Span: `span.healing.rate_limit.enforce`
  Kind: `internal`
  Stability: `development`
  """
  @spec healing_rate_limit_enforce() :: String.t()
  def healing_rate_limit_enforce, do: "healing.rate_limit.enforce"

  @doc """
  Recovery simulation — running synthetic failure scenarios to validate healing playbooks and reflex arcs.

  Span: `span.healing.recovery.simulate`
  Kind: `internal`
  Stability: `development`
  """
  @spec healing_recovery_simulate() :: String.t()
  def healing_recovery_simulate, do: "healing.recovery.simulate"

  @doc """
  Bounded recovery loop execution — WvdA liveness-bounded healing iteration.

  Span: `span.healing.recovery_loop`
  Kind: `internal`
  Stability: `development`
  """
  @spec healing_recovery_loop() :: String.t()
  def healing_recovery_loop, do: "healing.recovery_loop"

  @doc """
  Execution of a healing reflex arc — automated recovery action triggered by a detected failure pattern.

  Span: `span.healing.reflex_arc`
  Kind: `internal`
  Stability: `development`
  """
  @spec healing_reflex_arc() :: String.t()
  def healing_reflex_arc, do: "healing.reflex_arc"

  @doc """
  Adaptive retry backoff execution — applying dynamic retry strategy during healing.

  Span: `span.healing.retry.adaptive`
  Kind: `internal`
  Stability: `development`
  """
  @spec healing_retry_adaptive() :: String.t()
  def healing_retry_adaptive, do: "healing.retry.adaptive"

  @doc """
  Rollback execution — reverting the system to a known-good checkpoint or snapshot after a healing failure.

  Span: `span.healing.rollback.execute`
  Kind: `internal`
  Stability: `development`
  """
  @spec healing_rollback_execute() :: String.t()
  def healing_rollback_execute, do: "healing.rollback.execute"

  @doc """
  Triggering an autonomous self-healing action in response to a detected failure.

  Span: `span.healing.self_healing.trigger`
  Kind: `internal`
  Stability: `development`
  """
  @spec healing_self_healing_trigger() :: String.t()
  def healing_self_healing_trigger, do: "healing.self_healing.trigger"

  @doc """
  Detecting a healing surge and applying mitigation strategy.

  Span: `span.healing.surge.detect`
  Kind: `internal`
  Stability: `development`
  """
  @spec healing_surge_detect() :: String.t()
  def healing_surge_detect, do: "healing.surge.detect"

  @doc """
  Warm standby activation — promoting a warm replica to primary during a healing failover event.

  Span: `span.healing.warm_standby.activate`
  Kind: `internal`
  Stability: `development`
  """
  @spec healing_warm_standby_activate() :: String.t()
  def healing_warm_standby_activate, do: "healing.warm_standby.activate"

  @doc """
  All span names in this namespace.
  """
  @spec all() :: [String.t()]
  def all do
    [
      healing_adaptive_adjust(),
      healing_anomaly_detect(),
      healing_backpressure_apply(),
      healing_cascade_detect(),
      healing_checkpoint_create(),
      healing_circuit_breaker_trip(),
      healing_cold_standby_promote(),
      healing_diagnosis(),
      healing_escalation(),
      healing_failover_execute(),
      healing_fingerprint(),
      healing_intervention_score(),
      healing_load_shedding_apply(),
      healing_memory_snapshot(),
      healing_mttr_measure(),
      healing_pattern_match(),
      healing_playbook_execute(),
      healing_prediction_make(),
      healing_quarantine_apply(),
      healing_rate_limit_enforce(),
      healing_recovery_simulate(),
      healing_recovery_loop(),
      healing_reflex_arc(),
      healing_retry_adaptive(),
      healing_rollback_execute(),
      healing_self_healing_trigger(),
      healing_surge_detect(),
      healing_warm_standby_activate()
    ]
  end
end