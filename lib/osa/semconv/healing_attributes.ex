defmodule OpenTelemetry.SemConv.Incubating.HealingAttributes do
  @moduledoc """
  Healing semantic convention attributes.

  Namespace: `healing`

  This module is generated from the ChatmanGPT semantic convention registry.
  Do not edit manually — regenerate with:

      weaver registry generate -r ./semconv/model --templates ./semconv/templates elixir ./OSA/lib/osa/semconv/
  """

  @doc """
  Identifier of the OSA agent that owns the healing operation.

  Attribute: `healing.agent_id`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `healing-agent-1`, `osa-primary`
  """
  @spec healing_agent_id() :: :"healing.agent_id"
  def healing_agent_id, do: :"healing.agent_id"

  @doc """
  The number of healing attempts made for this failure (1-indexed).

  Attribute: `healing.attempt_number`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `1`, `2`, `3`
  """
  @spec healing_attempt_number() :: :"healing.attempt_number"
  def healing_attempt_number, do: :"healing.attempt_number"

  @doc """
  Confidence score for the failure mode classification, in range [0.0, 1.0].

  Attribute: `healing.confidence`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0.95`, `0.8`, `0.7`
  """
  @spec healing_confidence() :: :"healing.confidence"
  def healing_confidence, do: :"healing.confidence"

  @doc """
  The current stage of the healing diagnosis pipeline.

  Attribute: `healing.diagnosis_stage`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `detection`, `classification`
  """
  @spec healing_diagnosis_stage() :: :"healing.diagnosis_stage"
  def healing_diagnosis_stage, do: :"healing.diagnosis_stage"

  @doc """
  Enumerated values for `healing.diagnosis_stage`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `detection` | `"detection"` | Initial anomaly detection phase |
  | `classification` | `"classification"` | Failure mode classification phase |
  | `verification` | `"verification"` | Verification of classification accuracy |
  | `escalation` | `"escalation"` | Escalation to human operator |
  """
  @spec healing_diagnosis_stage_values() :: %{
    detection: :detection,
    classification: :classification,
    verification: :verification,
    escalation: :escalation
  }
  def healing_diagnosis_stage_values do
    %{
      detection: :detection,
      classification: :classification,
      verification: :verification,
      escalation: :escalation
    }
  end

  defmodule HealingDiagnosisStageValues do
    @moduledoc """
    Typed constants for the `healing.diagnosis_stage` attribute.
    """

    @doc "Initial anomaly detection phase"
    @spec detection() :: :detection
    def detection, do: :detection

    @doc "Failure mode classification phase"
    @spec classification() :: :classification
    def classification, do: :classification

    @doc "Verification of classification accuracy"
    @spec verification() :: :verification
    def verification, do: :verification

    @doc "Escalation to human operator"
    @spec escalation() :: :escalation
    def escalation, do: :escalation

  end

  @doc """
  The classified failure mode detected by the healing diagnosis engine.

  Attribute: `healing.failure_mode`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `deadlock`, `timeout`, `cascading_failure`
  """
  @spec healing_failure_mode() :: :"healing.failure_mode"
  def healing_failure_mode, do: :"healing.failure_mode"

  @doc """
  Enumerated values for `healing.failure_mode`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `deadlock` | `"deadlock"` | Circular wait between processes |
  | `timeout` | `"timeout"` | Operation exceeded its time budget |
  | `race_condition` | `"race_condition"` | Non-deterministic state conflict between processes |
  | `memory_leak` | `"memory_leak"` | Unbounded memory growth detected |
  | `cascading_failure` | `"cascading_failure"` | Failure propagated from upstream dependency |
  | `stagnation` | `"stagnation"` | Process stuck with no forward progress |
  | `livelock` | `"livelock"` | Processes active but making no progress |
  """
  @spec healing_failure_mode_values() :: %{
    deadlock: :deadlock,
    timeout: :timeout,
    race_condition: :race_condition,
    memory_leak: :memory_leak,
    cascading_failure: :cascading_failure,
    stagnation: :stagnation,
    livelock: :livelock
  }
  def healing_failure_mode_values do
    %{
      deadlock: :deadlock,
      timeout: :timeout,
      race_condition: :race_condition,
      memory_leak: :memory_leak,
      cascading_failure: :cascading_failure,
      stagnation: :stagnation,
      livelock: :livelock
    }
  end

  defmodule HealingFailureModeValues do
    @moduledoc """
    Typed constants for the `healing.failure_mode` attribute.
    """

    @doc "Circular wait between processes"
    @spec deadlock() :: :deadlock
    def deadlock, do: :deadlock

    @doc "Operation exceeded its time budget"
    @spec timeout() :: :timeout
    def timeout, do: :timeout

    @doc "Non-deterministic state conflict between processes"
    @spec race_condition() :: :race_condition
    def race_condition, do: :race_condition

    @doc "Unbounded memory growth detected"
    @spec memory_leak() :: :memory_leak
    def memory_leak, do: :memory_leak

    @doc "Failure propagated from upstream dependency"
    @spec cascading_failure() :: :cascading_failure
    def cascading_failure, do: :cascading_failure

    @doc "Process stuck with no forward progress"
    @spec stagnation() :: :stagnation
    def stagnation, do: :stagnation

    @doc "Processes active but making no progress"
    @spec livelock() :: :livelock
    def livelock, do: :livelock

  end

  @doc """
  Process fingerprint hash for identifying similar failure patterns.

  Attribute: `healing.fingerprint`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `fp-a3b2c1`, `fp-deadlock-7f8e`
  """
  @spec healing_fingerprint() :: :"healing.fingerprint"
  def healing_fingerprint, do: :"healing.fingerprint"

  @doc """
  Maximum number of healing attempts before escalation.

  Attribute: `healing.max_attempts`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `3`, `5`
  """
  @spec healing_max_attempts() :: :"healing.max_attempts"
  def healing_max_attempts, do: :"healing.max_attempts"

  @doc """
  Mean time to recovery in milliseconds for the healing operation.

  Attribute: `healing.mttr_ms`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `45000`, `1200`, `30000`
  """
  @spec healing_mttr_ms() :: :"healing.mttr_ms"
  def healing_mttr_ms, do: :"healing.mttr_ms"

  @doc """
  The recovery action taken by the reflex arc.

  Attribute: `healing.recovery_action`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `restart_worker`, `drain_queue`, `escalate_to_supervisor`, `kill_process`
  """
  @spec healing_recovery_action() :: :"healing.recovery_action"
  def healing_recovery_action, do: :"healing.recovery_action"

  @doc """
  The recovery strategy selected by the healing engine.

  Attribute: `healing.recovery_strategy`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `restart`, `circuit_break`
  """
  @spec healing_recovery_strategy() :: :"healing.recovery_strategy"
  def healing_recovery_strategy, do: :"healing.recovery_strategy"

  @doc """
  Enumerated values for `healing.recovery_strategy`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `restart` | `"restart"` | Restart the affected process |
  | `rollback` | `"rollback"` | Rollback to last known good state |
  | `circuit_break` | `"circuit_break"` | Open circuit breaker to shed load |
  | `isolate` | `"isolate"` | Isolate the failing component |
  | `degrade` | `"degrade"` | Gracefully degrade to reduced functionality |
  """
  @spec healing_recovery_strategy_values() :: %{
    restart: :restart,
    rollback: :rollback,
    circuit_break: :circuit_break,
    isolate: :isolate,
    degrade: :degrade
  }
  def healing_recovery_strategy_values do
    %{
      restart: :restart,
      rollback: :rollback,
      circuit_break: :circuit_break,
      isolate: :isolate,
      degrade: :degrade
    }
  end

  defmodule HealingRecoveryStrategyValues do
    @moduledoc """
    Typed constants for the `healing.recovery_strategy` attribute.
    """

    @doc "Restart the affected process"
    @spec restart() :: :restart
    def restart, do: :restart

    @doc "Rollback to last known good state"
    @spec rollback() :: :rollback
    def rollback, do: :rollback

    @doc "Open circuit breaker to shed load"
    @spec circuit_break() :: :circuit_break
    def circuit_break, do: :circuit_break

    @doc "Isolate the failing component"
    @spec isolate() :: :isolate
    def isolate, do: :isolate

    @doc "Gracefully degrade to reduced functionality"
    @spec degrade() :: :degrade
    def degrade, do: :degrade

  end

  @doc """
  The named reflex arc triggered during healing.

  Attribute: `healing.reflex_arc`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `deadlock_detection`, `memory_pressure_relief`, `stagnation_detection`
  """
  @spec healing_reflex_arc() :: :"healing.reflex_arc"
  def healing_reflex_arc, do: :"healing.reflex_arc"

end