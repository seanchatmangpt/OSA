defmodule OpenTelemetry.SemConv.Incubating.HealingAttributes do
  @moduledoc """
  Healing semantic convention attributes.

  Namespace: `healing`

  This module is generated from the ChatmanGPT semantic convention registry.
  Do not edit manually — regenerate with:

      weaver registry generate -r ./semconv/model --templates ./semconv/templates elixir ./OSA/lib/osa/semconv/
  """

  @doc """
  Current retry attempt number (1-indexed) for adaptive retry logic.

  Attribute: `healing.retry.adaptive.attempt`
  Type: `int`
  Stability: `development`
  Requirement: `required`
  Examples: `1`, `2`, `3`, `5`
  """
  @spec healing_retry_adaptive_attempt() :: :healing_retry_adaptive_attempt
  def healing_retry_adaptive_attempt, do: :healing_retry_adaptive_attempt

  @doc """
  Backoff duration in milliseconds before the next retry attempt.

  Attribute: `healing.retry.adaptive.backoff_ms`
  Type: `int`
  Stability: `development`
  Requirement: `required`
  Examples: `100`, `500`, `2000`, `5000`
  """
  @spec healing_retry_adaptive_backoff_ms() :: :healing_retry_adaptive_backoff_ms
  def healing_retry_adaptive_backoff_ms, do: :healing_retry_adaptive_backoff_ms

  @doc """
  Backoff strategy for adaptive retries during healing.

  Attribute: `healing.retry.adaptive.strategy`
  Type: `enum`
  Stability: `development`
  Requirement: `required`
  Examples: `exponential`, `linear`, `fibonacci`, `constant`
  """
  @spec healing_retry_adaptive_strategy() :: :healing_retry_adaptive_strategy
  def healing_retry_adaptive_strategy, do: :healing_retry_adaptive_strategy

  @doc """
  Enumerated values for `healing.retry.adaptive.strategy`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `exponential` | `"exponential"` | Exponential backoff (2^attempt * base_ms) |
  | `linear` | `"linear"` | Linear backoff (attempt * base_ms) |
  | `fibonacci` | `"fibonacci"` | Fibonacci backoff sequence |
  | `constant` | `"constant"` | Constant backoff (base_ms) |
  """
  @spec healing_retry_adaptive_strategy_values() :: %{
    exponential: :exponential,
    linear: :linear,
    fibonacci: :fibonacci,
    constant: :constant
  }
  def healing_retry_adaptive_strategy_values do
    %{
      exponential: :exponential,
      linear: :linear,
      fibonacci: :fibonacci,
      constant: :constant
    }
  end

  defmodule HealingRetryAdaptiveStrategyValues do
    @moduledoc """
    Typed constants for the `healing.retry.adaptive.strategy` attribute.
    """

    @doc "Exponential backoff (2^attempt * base_ms)"
    @spec exponential() :: :exponential
    def exponential, do: :exponential

    @doc "Linear backoff (attempt * base_ms)"
    @spec linear() :: :linear
    def linear, do: :linear

    @doc "Fibonacci backoff sequence"
    @spec fibonacci() :: :fibonacci
    def fibonacci, do: :fibonacci

    @doc "Constant backoff (base_ms)"
    @spec constant() :: :constant
    def constant, do: :constant

  end

  @doc """
  Learning rate used to adjust the adaptive healing threshold — controls how quickly it adapts.

  Attribute: `healing.adaptive.learning_rate`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0.01`, `0.05`, `0.1`
  """
  @spec healing_adaptive_learning_rate() :: :healing_adaptive_learning_rate
  def healing_adaptive_learning_rate, do: :healing_adaptive_learning_rate

  @doc """
  Current adaptive healing threshold — dynamically adjusted based on system behavior.

  Attribute: `healing.adaptive.threshold_current`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0.75`, `0.9`, `0.95`
  """
  @spec healing_adaptive_threshold_current() :: :healing_adaptive_threshold_current
  def healing_adaptive_threshold_current, do: :healing_adaptive_threshold_current

  @doc """
  Maximum allowed value for the adaptive healing threshold.

  Attribute: `healing.adaptive.threshold_max`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0.99`, `1.0`
  """
  @spec healing_adaptive_threshold_max() :: :healing_adaptive_threshold_max
  def healing_adaptive_threshold_max, do: :healing_adaptive_threshold_max

  @doc """
  Minimum allowed value for the adaptive healing threshold.

  Attribute: `healing.adaptive.threshold_min`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0.5`, `0.7`
  """
  @spec healing_adaptive_threshold_min() :: :healing_adaptive_threshold_min
  def healing_adaptive_threshold_min, do: :healing_adaptive_threshold_min

  @doc """
  Identifier of the OSA agent that owns the healing operation.

  Attribute: `healing.agent_id`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `healing-agent-1`, `osa-primary`
  """
  @spec healing_agent_id() :: :healing_agent_id
  def healing_agent_id, do: :healing_agent_id

  @doc """
  Baseline observation window in milliseconds used for anomaly detection.

  Attribute: `healing.anomaly.baseline_ms`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `1000`, `5000`, `60000`
  """
  @spec healing_anomaly_baseline_ms() :: :healing_anomaly_baseline_ms
  def healing_anomaly_baseline_ms, do: :healing_anomaly_baseline_ms

  @doc """
  Method used to detect the system anomaly.

  Attribute: `healing.anomaly.detection_method`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `statistical`, `ml`, `rule_based`, `hybrid`
  """
  @spec healing_anomaly_detection_method() :: :healing_anomaly_detection_method
  def healing_anomaly_detection_method, do: :healing_anomaly_detection_method

  @doc """
  Enumerated values for `healing.anomaly.detection_method`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `statistical` | `"statistical"` | statistical |
  | `ml` | `"ml"` | ml |
  | `rule_based` | `"rule_based"` | rule_based |
  | `hybrid` | `"hybrid"` | hybrid |
  """
  @spec healing_anomaly_detection_method_values() :: %{
    statistical: :statistical,
    ml: :ml,
    rule_based: :rule_based,
    hybrid: :hybrid
  }
  def healing_anomaly_detection_method_values do
    %{
      statistical: :statistical,
      ml: :ml,
      rule_based: :rule_based,
      hybrid: :hybrid
    }
  end

  defmodule HealingAnomalyDetectionMethodValues do
    @moduledoc """
    Typed constants for the `healing.anomaly.detection_method` attribute.
    """

    @doc "statistical"
    @spec statistical() :: :statistical
    def statistical, do: :statistical

    @doc "ml"
    @spec ml() :: :ml
    def ml, do: :ml

    @doc "rule_based"
    @spec rule_based() :: :rule_based
    def rule_based, do: :rule_based

    @doc "hybrid"
    @spec hybrid() :: :hybrid
    def hybrid, do: :hybrid

  end

  @doc """
  Anomaly score for the detected system behavior, range [0.0, 1.0]. Higher = more anomalous.

  Attribute: `healing.anomaly.score`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0.0`, `0.45`, `0.92`
  """
  @spec healing_anomaly_score() :: :healing_anomaly_score
  def healing_anomaly_score, do: :healing_anomaly_score

  @doc """
  Score threshold above which behavior is classified as anomalous, range [0.0, 1.0].

  Attribute: `healing.anomaly.threshold`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0.5`, `0.7`, `0.9`
  """
  @spec healing_anomaly_threshold() :: :healing_anomaly_threshold
  def healing_anomaly_threshold, do: :healing_anomaly_threshold

  @doc """
  Current healing attempt number (1-indexed) for this failure event.

  Attribute: `healing.attempt`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `1`, `2`, `3`
  """
  @spec healing_attempt() :: :healing_attempt
  def healing_attempt, do: :healing_attempt

  @doc """
  The number of healing attempts made for this failure (1-indexed).

  Attribute: `healing.attempt_number`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `1`, `2`, `3`
  """
  @spec healing_attempt_number() :: :healing_attempt_number
  def healing_attempt_number, do: :healing_attempt_number

  @doc """
  Fraction of healing requests dropped due to backpressure [0.0, 1.0].

  Attribute: `healing.backpressure.drop_rate`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0.0`, `0.15`, `0.5`
  """
  @spec healing_backpressure_drop_rate() :: :healing_backpressure_drop_rate
  def healing_backpressure_drop_rate, do: :healing_backpressure_drop_rate

  @doc """
  Current backpressure level in the healing pipeline.

  Attribute: `healing.backpressure.level`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `none`, `medium`, `critical`
  """
  @spec healing_backpressure_level() :: :healing_backpressure_level
  def healing_backpressure_level, do: :healing_backpressure_level

  @doc """
  Enumerated values for `healing.backpressure.level`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `none` | `"none"` | none |
  | `low` | `"low"` | low |
  | `medium` | `"medium"` | medium |
  | `high` | `"high"` | high |
  | `critical` | `"critical"` | critical |
  """
  @spec healing_backpressure_level_values() :: %{
    none: :none,
    low: :low,
    medium: :medium,
    high: :high,
    critical: :critical
  }
  def healing_backpressure_level_values do
    %{
      none: :none,
      low: :low,
      medium: :medium,
      high: :high,
      critical: :critical
    }
  end

  defmodule HealingBackpressureLevelValues do
    @moduledoc """
    Typed constants for the `healing.backpressure.level` attribute.
    """

    @doc "none"
    @spec none() :: :none
    def none, do: :none

    @doc "low"
    @spec low() :: :low
    def low, do: :low

    @doc "medium"
    @spec medium() :: :medium
    def medium, do: :medium

    @doc "high"
    @spec high() :: :high
    def high, do: :high

    @doc "critical"
    @spec critical() :: :critical
    def critical, do: :critical

  end

  @doc """
  Current number of healing requests queued.

  Attribute: `healing.backpressure.queue_depth`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0`, `50`, `500`
  """
  @spec healing_backpressure_queue_depth() :: :healing_backpressure_queue_depth
  def healing_backpressure_queue_depth, do: :healing_backpressure_queue_depth

  @doc """
  Depth of the cascade failure chain — number of chained failures detected.

  Attribute: `healing.cascade.depth`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `1`, `2`, `5`
  """
  @spec healing_cascade_depth() :: :healing_cascade_depth
  def healing_cascade_depth, do: :healing_cascade_depth

  @doc """
  Whether a cascade failure was detected during healing (multiple correlated failures).

  Attribute: `healing.cascade.detected`
  Type: `boolean`
  Stability: `development`
  Requirement: `recommended`
  Examples: `true`, `false`
  """
  @spec healing_cascade_detected() :: :healing_cascade_detected
  def healing_cascade_detected, do: :healing_cascade_detected

  @doc """
  Compression ratio of the healing checkpoint data, range [0.0, 1.0].

  Attribute: `healing.checkpoint.compression_ratio`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0.3`, `0.6`, `0.8`
  """
  @spec healing_checkpoint_compression_ratio() :: :healing_checkpoint_compression_ratio
  def healing_checkpoint_compression_ratio, do: :healing_checkpoint_compression_ratio

  @doc """
  Unique identifier for the healing checkpoint.

  Attribute: `healing.checkpoint.id`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `chk-001`, `healing-checkpoint-2026-001`
  """
  @spec healing_checkpoint_id() :: :healing_checkpoint_id
  def healing_checkpoint_id, do: :healing_checkpoint_id

  @doc """
  Time taken to restore from the checkpoint in milliseconds.

  Attribute: `healing.checkpoint.restore_ms`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `50`, `200`, `1000`
  """
  @spec healing_checkpoint_restore_ms() :: :healing_checkpoint_restore_ms
  def healing_checkpoint_restore_ms, do: :healing_checkpoint_restore_ms

  @doc """
  Size of the healing checkpoint in bytes.

  Attribute: `healing.checkpoint.size_bytes`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `1024`, `65536`, `1048576`
  """
  @spec healing_checkpoint_size_bytes() :: :healing_checkpoint_size_bytes
  def healing_checkpoint_size_bytes, do: :healing_checkpoint_size_bytes

  @doc """
  Total number of calls passed through the circuit breaker in current window.

  Attribute: `healing.circuit_breaker.call_count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0`, `10`, `100`
  """
  @spec healing_circuit_breaker_call_count() :: :healing_circuit_breaker_call_count
  def healing_circuit_breaker_call_count, do: :healing_circuit_breaker_call_count

  @doc """
  Number of consecutive failures that triggered the circuit breaker.

  Attribute: `healing.circuit_breaker.failure_count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0`, `3`, `5`
  """
  @spec healing_circuit_breaker_failure_count() :: :healing_circuit_breaker_failure_count
  def healing_circuit_breaker_failure_count, do: :healing_circuit_breaker_failure_count

  @doc """
  Time in milliseconds before the circuit breaker attempts half-open reset.

  Attribute: `healing.circuit_breaker.reset_ms`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `5000`, `30000`, `60000`
  """
  @spec healing_circuit_breaker_reset_ms() :: :healing_circuit_breaker_reset_ms
  def healing_circuit_breaker_reset_ms, do: :healing_circuit_breaker_reset_ms

  @doc """
  Current state of the healing circuit breaker.

  Attribute: `healing.circuit_breaker.state`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `closed`, `open`, `half_open`
  """
  @spec healing_circuit_breaker_state() :: :healing_circuit_breaker_state
  def healing_circuit_breaker_state, do: :healing_circuit_breaker_state

  @doc """
  Enumerated values for `healing.circuit_breaker.state`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `closed` | `"closed"` | closed |
  | `open` | `"open"` | open |
  | `half_open` | `"half_open"` | half_open |
  """
  @spec healing_circuit_breaker_state_values() :: %{
    closed: :closed,
    open: :open,
    half_open: :half_open
  }
  def healing_circuit_breaker_state_values do
    %{
      closed: :closed,
      open: :open,
      half_open: :half_open
    }
  end

  defmodule HealingCircuitBreakerStateValues do
    @moduledoc """
    Typed constants for the `healing.circuit_breaker.state` attribute.
    """

    @doc "closed"
    @spec closed() :: :closed
    def closed, do: :closed

    @doc "open"
    @spec open() :: :open
    def open, do: :open

    @doc "half_open"
    @spec half_open() :: :half_open
    def half_open, do: :half_open

  end

  @doc """
  Data replication lag of the cold standby at the time of promotion, in milliseconds.

  Attribute: `healing.cold_standby.data_lag_ms`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `100`, `5000`
  """
  @spec healing_cold_standby_data_lag_ms() :: :healing_cold_standby_data_lag_ms
  def healing_cold_standby_data_lag_ms, do: :healing_cold_standby_data_lag_ms

  @doc """
  Unique identifier of the cold standby instance being promoted.

  Attribute: `healing.cold_standby.id`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `standby-001`, `cold-replica-primary`
  """
  @spec healing_cold_standby_id() :: :healing_cold_standby_id
  def healing_cold_standby_id, do: :healing_cold_standby_id

  @doc """
  Readiness state of the cold standby instance.

  Attribute: `healing.cold_standby.readiness`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `cold`, `warming`, `ready`
  """
  @spec healing_cold_standby_readiness() :: :healing_cold_standby_readiness
  def healing_cold_standby_readiness, do: :healing_cold_standby_readiness

  @doc """
  Enumerated values for `healing.cold_standby.readiness`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `cold` | `"cold"` | cold |
  | `warming` | `"warming"` | warming |
  | `ready` | `"ready"` | ready |
  | `failed` | `"failed"` | failed |
  """
  @spec healing_cold_standby_readiness_values() :: %{
    cold: :cold,
    warming: :warming,
    ready: :ready,
    failed: :failed
  }
  def healing_cold_standby_readiness_values do
    %{
      cold: :cold,
      warming: :warming,
      ready: :ready,
      failed: :failed
    }
  end

  defmodule HealingColdStandbyReadinessValues do
    @moduledoc """
    Typed constants for the `healing.cold_standby.readiness` attribute.
    """

    @doc "cold"
    @spec cold() :: :cold
    def cold, do: :cold

    @doc "warming"
    @spec warming() :: :warming
    def warming, do: :warming

    @doc "ready"
    @spec ready() :: :ready
    def ready, do: :ready

    @doc "failed"
    @spec failed() :: :failed
    def failed, do: :failed

  end

  @doc """
  Time in milliseconds required to warm up the cold standby before it can serve traffic.

  Attribute: `healing.cold_standby.warmup_ms`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `5000`, `30000`
  """
  @spec healing_cold_standby_warmup_ms() :: :healing_cold_standby_warmup_ms
  def healing_cold_standby_warmup_ms, do: :healing_cold_standby_warmup_ms

  @doc """
  Confidence score for the failure mode classification, in range [0.0, 1.0].

  Attribute: `healing.confidence`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0.95`, `0.8`, `0.7`
  """
  @spec healing_confidence() :: :healing_confidence
  def healing_confidence, do: :healing_confidence

  @doc """
  The diagnosis mode or strategy used in the healing classify operation.

  Attribute: `healing.diagnosis.mode`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `deterministic`, `probabilistic`, `adaptive`
  """
  @spec healing_diagnosis_mode() :: :healing_diagnosis_mode
  def healing_diagnosis_mode, do: :healing_diagnosis_mode

  @doc """
  The current stage of the healing diagnosis pipeline.

  Attribute: `healing.diagnosis_stage`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `detection`, `classification`
  """
  @spec healing_diagnosis_stage() :: :healing_diagnosis_stage
  def healing_diagnosis_stage, do: :healing_diagnosis_stage

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
  Escalation level when automatic healing fails — determines alerting response.

  Attribute: `healing.escalation.level`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `none`, `warn`, `critical`
  """
  @spec healing_escalation_level() :: :healing_escalation_level
  def healing_escalation_level, do: :healing_escalation_level

  @doc """
  Enumerated values for `healing.escalation.level`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `none` | `"none"` | none |
  | `warn` | `"warn"` | warn |
  | `critical` | `"critical"` | critical |
  | `page` | `"page"` | page |
  """
  @spec healing_escalation_level_values() :: %{
    none: :none,
    warn: :warn,
    critical: :critical,
    page: :page
  }
  def healing_escalation_level_values do
    %{
      none: :none,
      warn: :warn,
      critical: :critical,
      page: :page
    }
  end

  defmodule HealingEscalationLevelValues do
    @moduledoc """
    Typed constants for the `healing.escalation.level` attribute.
    """

    @doc "none"
    @spec none() :: :none
    def none, do: :none

    @doc "warn"
    @spec warn() :: :warn
    def warn, do: :warn

    @doc "critical"
    @spec critical() :: :critical
    def critical, do: :critical

    @doc "page"
    @spec page() :: :page
    def page, do: :page

  end

  @doc """
  Human-readable reason explaining why the healing operation was escalated to a human operator.

  Attribute: `healing.escalation_reason`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `max_attempts_exceeded`, `unknown_failure_mode`, `supervisor_timeout`
  """
  @spec healing_escalation_reason() :: :healing_escalation_reason
  def healing_escalation_reason, do: :healing_escalation_reason

  @doc """
  Duration (ms) of the failover operation from start to completion.

  Attribute: `healing.failover.duration_ms`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `250`, `1500`, `5000`
  """
  @spec healing_failover_duration_ms() :: :healing_failover_duration_ms
  def healing_failover_duration_ms, do: :healing_failover_duration_ms

  @doc """
  The identifier of the source (failing) system component.

  Attribute: `healing.failover.source_id`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `primary-node-1`, `osa-replica-a`
  """
  @spec healing_failover_source_id() :: :healing_failover_source_id
  def healing_failover_source_id, do: :healing_failover_source_id

  @doc """
  The identifier of the target (replacement) system component.

  Attribute: `healing.failover.target_id`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `warm-standby-2`, `osa-replica-b`
  """
  @spec healing_failover_target_id() :: :healing_failover_target_id
  def healing_failover_target_id, do: :healing_failover_target_id

  @doc """
  The type of failover transition being performed.

  Attribute: `healing.failover.type`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `primary_to_warm`, `warm_to_cold`, `geographic`
  """
  @spec healing_failover_type() :: :healing_failover_type
  def healing_failover_type, do: :healing_failover_type

  @doc """
  Enumerated values for `healing.failover.type`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `warm_to_cold` | `"warm_to_cold"` | warm_to_cold |
  | `primary_to_warm` | `"primary_to_warm"` | primary_to_warm |
  | `primary_to_cold` | `"primary_to_cold"` | primary_to_cold |
  | `geographic` | `"geographic"` | geographic |
  """
  @spec healing_failover_type_values() :: %{
    warm_to_cold: :warm_to_cold,
    primary_to_warm: :primary_to_warm,
    primary_to_cold: :primary_to_cold,
    geographic: :geographic
  }
  def healing_failover_type_values do
    %{
      warm_to_cold: :warm_to_cold,
      primary_to_warm: :primary_to_warm,
      primary_to_cold: :primary_to_cold,
      geographic: :geographic
    }
  end

  defmodule HealingFailoverTypeValues do
    @moduledoc """
    Typed constants for the `healing.failover.type` attribute.
    """

    @doc "warm_to_cold"
    @spec warm_to_cold() :: :warm_to_cold
    def warm_to_cold, do: :warm_to_cold

    @doc "primary_to_warm"
    @spec primary_to_warm() :: :primary_to_warm
    def primary_to_warm, do: :primary_to_warm

    @doc "primary_to_cold"
    @spec primary_to_cold() :: :primary_to_cold
    def primary_to_cold, do: :primary_to_cold

    @doc "geographic"
    @spec geographic() :: :geographic
    def geographic, do: :geographic

  end

  @doc """
  The classified failure mode detected by the healing diagnosis engine.

  Attribute: `healing.failure_mode`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `deadlock`, `timeout`, `cascading_failure`
  """
  @spec healing_failure_mode() :: :healing_failure_mode
  def healing_failure_mode, do: :healing_failure_mode

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
  @spec healing_fingerprint() :: :healing_fingerprint
  def healing_fingerprint, do: :healing_fingerprint

  @doc """
  The outcome result of the healing fix operation.

  Attribute: `healing.fix.result`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `success`, `partial`, `failed`
  """
  @spec healing_fix_result() :: :healing_fix_result
  def healing_fix_result, do: :healing_fix_result

  @doc """
  Enumerated values for `healing.fix.result`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `success` | `"success"` | success |
  | `partial` | `"partial"` | partial |
  | `failed` | `"failed"` | failed |
  """
  @spec healing_fix_result_values() :: %{
    success: :success,
    partial: :partial,
    failed: :failed
  }
  def healing_fix_result_values do
    %{
      success: :success,
      partial: :partial,
      failed: :failed
    }
  end

  defmodule HealingFixResultValues do
    @moduledoc """
    Typed constants for the `healing.fix.result` attribute.
    """

    @doc "success"
    @spec success() :: :success
    def success, do: :success

    @doc "partial"
    @spec partial() :: :partial
    def partial, do: :partial

    @doc "failed"
    @spec failed() :: :failed
    def failed, do: :failed

  end

  @doc """
  Duration of the healing intervention in milliseconds.

  Attribute: `healing.intervention.duration_ms`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `100`, `500`, `5000`
  """
  @spec healing_intervention_duration_ms() :: :healing_intervention_duration_ms
  def healing_intervention_duration_ms, do: :healing_intervention_duration_ms

  @doc """
  Outcome of the healing intervention.

  Attribute: `healing.intervention.outcome`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `success`, `partial`
  """
  @spec healing_intervention_outcome() :: :healing_intervention_outcome
  def healing_intervention_outcome, do: :healing_intervention_outcome

  @doc """
  Enumerated values for `healing.intervention.outcome`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `success` | `"success"` | success |
  | `partial` | `"partial"` | partial |
  | `failed` | `"failed"` | failed |
  | `escalated` | `"escalated"` | escalated |
  """
  @spec healing_intervention_outcome_values() :: %{
    success: :success,
    partial: :partial,
    failed: :failed,
    escalated: :escalated
  }
  def healing_intervention_outcome_values do
    %{
      success: :success,
      partial: :partial,
      failed: :failed,
      escalated: :escalated
    }
  end

  defmodule HealingInterventionOutcomeValues do
    @moduledoc """
    Typed constants for the `healing.intervention.outcome` attribute.
    """

    @doc "success"
    @spec success() :: :success
    def success, do: :success

    @doc "partial"
    @spec partial() :: :partial
    def partial, do: :partial

    @doc "failed"
    @spec failed() :: :failed
    def failed, do: :failed

    @doc "escalated"
    @spec escalated() :: :escalated
    def escalated, do: :escalated

  end

  @doc """
  Intervention effectiveness score in range [0.0, 1.0] — higher is more effective.

  Attribute: `healing.intervention.score`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0.6`, `0.85`, `0.99`
  """
  @spec healing_intervention_score() :: :healing_intervention_score
  def healing_intervention_score, do: :healing_intervention_score

  @doc """
  Type of healing intervention applied.

  Attribute: `healing.intervention.type`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `automatic`, `manual`
  """
  @spec healing_intervention_type() :: :healing_intervention_type
  def healing_intervention_type, do: :healing_intervention_type

  @doc """
  Enumerated values for `healing.intervention.type`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `automatic` | `"automatic"` | automatic |
  | `manual` | `"manual"` | manual |
  | `assisted` | `"assisted"` | assisted |
  | `deferred` | `"deferred"` | deferred |
  """
  @spec healing_intervention_type_values() :: %{
    automatic: :automatic,
    manual: :manual,
    assisted: :assisted,
    deferred: :deferred
  }
  def healing_intervention_type_values do
    %{
      automatic: :automatic,
      manual: :manual,
      assisted: :assisted,
      deferred: :deferred
    }
  end

  defmodule HealingInterventionTypeValues do
    @moduledoc """
    Typed constants for the `healing.intervention.type` attribute.
    """

    @doc "automatic"
    @spec automatic() :: :automatic
    def automatic, do: :automatic

    @doc "manual"
    @spec manual() :: :manual
    def manual, do: :manual

    @doc "assisted"
    @spec assisted() :: :assisted
    def assisted, do: :assisted

    @doc "deferred"
    @spec deferred() :: :deferred
    def deferred, do: :deferred

  end

  @doc """
  Current iteration count in the recovery loop.

  Attribute: `healing.iteration`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `1`, `2`, `3`
  """
  @spec healing_iteration() :: :healing_iteration
  def healing_iteration, do: :healing_iteration

  @doc """
  Percentage of requests shed (dropped) during this load shedding event, range [0.0, 100.0].

  Attribute: `healing.load_shedding.shed_pct`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `10.0`, `25.0`, `50.0`
  """
  @spec healing_load_shedding_shed_pct() :: :healing_load_shedding_shed_pct
  def healing_load_shedding_shed_pct, do: :healing_load_shedding_shed_pct

  @doc """
  The strategy used to select which requests to shed.

  Attribute: `healing.load_shedding.strategy`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `random`, `priority`, `oldest`
  """
  @spec healing_load_shedding_strategy() :: :healing_load_shedding_strategy
  def healing_load_shedding_strategy, do: :healing_load_shedding_strategy

  @doc """
  Enumerated values for `healing.load_shedding.strategy`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `random` | `"random"` | random |
  | `priority` | `"priority"` | priority |
  | `oldest` | `"oldest"` | oldest |
  """
  @spec healing_load_shedding_strategy_values() :: %{
    random: :random,
    priority: :priority,
    oldest: :oldest
  }
  def healing_load_shedding_strategy_values do
    %{
      random: :random,
      priority: :priority,
      oldest: :oldest
    }
  end

  defmodule HealingLoadSheddingStrategyValues do
    @moduledoc """
    Typed constants for the `healing.load_shedding.strategy` attribute.
    """

    @doc "random"
    @spec random() :: :random
    def random, do: :random

    @doc "priority"
    @spec priority() :: :priority
    def priority, do: :priority

    @doc "oldest"
    @spec oldest() :: :oldest
    def oldest, do: :oldest

  end

  @doc """
  The load threshold (0.0-1.0) at which load shedding is triggered.

  Attribute: `healing.load_shedding.threshold`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0.8`, `0.9`, `0.95`
  """
  @spec healing_load_shedding_threshold() :: :healing_load_shedding_threshold
  def healing_load_shedding_threshold, do: :healing_load_shedding_threshold

  @doc """
  Maximum number of healing attempts before escalation.

  Attribute: `healing.max_attempts`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `3`, `5`
  """
  @spec healing_max_attempts() :: :healing_max_attempts
  def healing_max_attempts, do: :healing_max_attempts

  @doc """
  Maximum number of recovery iterations before escalation (WvdA liveness bound).

  Attribute: `healing.max_iterations`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `3`, `5`, `10`
  """
  @spec healing_max_iterations() :: :healing_max_iterations
  def healing_max_iterations, do: :healing_max_iterations

  @doc """
  Compression ratio of the memory snapshot, range [0.0, 1.0] (1.0 = no compression).

  Attribute: `healing.memory.compression_ratio`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0.45`, `0.72`
  """
  @spec healing_memory_compression_ratio() :: :healing_memory_compression_ratio
  def healing_memory_compression_ratio, do: :healing_memory_compression_ratio

  @doc """
  Duration in milliseconds to restore the system state from a memory snapshot.

  Attribute: `healing.memory.restore_ms`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `50`, `500`
  """
  @spec healing_memory_restore_ms() :: :healing_memory_restore_ms
  def healing_memory_restore_ms, do: :healing_memory_restore_ms

  @doc """
  Unique identifier for a healing memory snapshot used for state preservation.

  Attribute: `healing.memory.snapshot_id`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `snap-abc123`, `memory-checkpoint-007`
  """
  @spec healing_memory_snapshot_id() :: :healing_memory_snapshot_id
  def healing_memory_snapshot_id, do: :healing_memory_snapshot_id

  @doc """
  Size in bytes of the healing memory snapshot.

  Attribute: `healing.memory.snapshot_size_bytes`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `4096`, `65536`
  """
  @spec healing_memory_snapshot_size_bytes() :: :healing_memory_snapshot_size_bytes
  def healing_memory_snapshot_size_bytes, do: :healing_memory_snapshot_size_bytes

  @doc """
  Mean time to recovery in milliseconds for the healing operation.

  Attribute: `healing.mttr_ms`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `45000`, `1200`, `30000`
  """
  @spec healing_mttr_ms() :: :healing_mttr_ms
  def healing_mttr_ms, do: :healing_mttr_ms

  @doc """
  Identifier of the healing pattern matched from the pattern library.

  Attribute: `healing.pattern.id`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `deadlock-restart-1`, `timeout-backoff-2`, `cascade-isolate-3`
  """
  @spec healing_pattern_id() :: :healing_pattern_id
  def healing_pattern_id, do: :healing_pattern_id

  @doc """
  Number of patterns currently loaded in the healing pattern library.

  Attribute: `healing.pattern.library_size`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `12`, `24`, `48`
  """
  @spec healing_pattern_library_size() :: :healing_pattern_library_size
  def healing_pattern_library_size, do: :healing_pattern_library_size

  @doc """
  Confidence score for the matched healing pattern, range [0.0, 1.0].

  Attribute: `healing.pattern.match_confidence`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0.85`, `0.92`, `1.0`
  """
  @spec healing_pattern_match_confidence() :: :healing_pattern_match_confidence
  def healing_pattern_match_confidence, do: :healing_pattern_match_confidence

  @doc """
  Total execution time of the playbook in milliseconds.

  Attribute: `healing.playbook.execution_ms`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `500`, `2000`, `15000`
  """
  @spec healing_playbook_execution_ms() :: :healing_playbook_execution_ms
  def healing_playbook_execution_ms, do: :healing_playbook_execution_ms

  @doc """
  Identifier of the recovery playbook being executed.

  Attribute: `healing.playbook.id`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `pb-deadlock-v1`, `pb-memory-oom-v2`
  """
  @spec healing_playbook_id() :: :healing_playbook_id
  def healing_playbook_id, do: :healing_playbook_id

  @doc """
  Total number of steps in the recovery playbook.

  Attribute: `healing.playbook.step_count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `3`, `7`, `12`
  """
  @spec healing_playbook_step_count() :: :healing_playbook_step_count
  def healing_playbook_step_count, do: :healing_playbook_step_count

  @doc """
  Current step number being executed in the playbook.

  Attribute: `healing.playbook.step_current`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `1`, `3`, `7`
  """
  @spec healing_playbook_step_current() :: :healing_playbook_step_current
  def healing_playbook_step_current, do: :healing_playbook_step_current

  @doc """
  Confidence score for the failure prediction [0.0, 1.0].

  Attribute: `healing.prediction.confidence`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0.82`, `0.95`
  """
  @spec healing_prediction_confidence() :: :healing_prediction_confidence
  def healing_prediction_confidence, do: :healing_prediction_confidence

  @doc """
  Time horizon in milliseconds for which the failure prediction is made.

  Attribute: `healing.prediction.horizon_ms`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `5000`, `30000`, `300000`
  """
  @spec healing_prediction_horizon_ms() :: :healing_prediction_horizon_ms
  def healing_prediction_horizon_ms, do: :healing_prediction_horizon_ms

  @doc """
  Name or version of the predictive model used for failure prediction.

  Attribute: `healing.prediction.model`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `lstm-v2`, `random_forest_v1`
  """
  @spec healing_prediction_model() :: :healing_prediction_model
  def healing_prediction_model, do: :healing_prediction_model

  @doc """
  Whether the quarantine is currently active.

  Attribute: `healing.quarantine.active`
  Type: `boolean`
  Stability: `development`
  Requirement: `recommended`
  Examples: `true`, `false`
  """
  @spec healing_quarantine_active() :: :healing_quarantine_active
  def healing_quarantine_active, do: :healing_quarantine_active

  @doc """
  Duration in milliseconds the component remained in quarantine.

  Attribute: `healing.quarantine.duration_ms`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `5000`, `60000`, `300000`
  """
  @spec healing_quarantine_duration_ms() :: :healing_quarantine_duration_ms
  def healing_quarantine_duration_ms, do: :healing_quarantine_duration_ms

  @doc """
  Unique identifier for the quarantine zone applied to an isolated component.

  Attribute: `healing.quarantine.id`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `qz-node-42`, `qz-svc-billing-2026-03-25`
  """
  @spec healing_quarantine_id() :: :healing_quarantine_id
  def healing_quarantine_id, do: :healing_quarantine_id

  @doc """
  Reason the component was placed into quarantine.

  Attribute: `healing.quarantine.reason`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `anomaly`, `cascade_risk`
  """
  @spec healing_quarantine_reason() :: :healing_quarantine_reason
  def healing_quarantine_reason, do: :healing_quarantine_reason

  @doc """
  Enumerated values for `healing.quarantine.reason`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `anomaly` | `"anomaly"` | anomaly |
  | `compliance` | `"compliance"` | compliance |
  | `cascade_risk` | `"cascade_risk"` | cascade_risk |
  | `manual` | `"manual"` | manual |
  """
  @spec healing_quarantine_reason_values() :: %{
    anomaly: :anomaly,
    compliance: :compliance,
    cascade_risk: :cascade_risk,
    manual: :manual
  }
  def healing_quarantine_reason_values do
    %{
      anomaly: :anomaly,
      compliance: :compliance,
      cascade_risk: :cascade_risk,
      manual: :manual
    }
  end

  defmodule HealingQuarantineReasonValues do
    @moduledoc """
    Typed constants for the `healing.quarantine.reason` attribute.
    """

    @doc "anomaly"
    @spec anomaly() :: :anomaly
    def anomaly, do: :anomaly

    @doc "compliance"
    @spec compliance() :: :compliance
    def compliance, do: :compliance

    @doc "cascade_risk"
    @spec cascade_risk() :: :cascade_risk
    def cascade_risk, do: :cascade_risk

    @doc "manual"
    @spec manual() :: :manual
    def manual, do: :manual

  end

  @doc """
  Maximum burst size above the base rate limit.

  Attribute: `healing.rate_limit.burst_size`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `5`, `20`, `50`
  """
  @spec healing_rate_limit_burst_size() :: :healing_rate_limit_burst_size
  def healing_rate_limit_burst_size, do: :healing_rate_limit_burst_size

  @doc """
  Current observed request rate per second.

  Attribute: `healing.rate_limit.current_rate`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `7.2`, `45.5`, `98.1`
  """
  @spec healing_rate_limit_current_rate() :: :healing_rate_limit_current_rate
  def healing_rate_limit_current_rate, do: :healing_rate_limit_current_rate

  @doc """
  Maximum allowed recovery requests per second.

  Attribute: `healing.rate_limit.requests_per_sec`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `10.0`, `50.0`, `100.0`
  """
  @spec healing_rate_limit_requests_per_sec() :: :healing_rate_limit_requests_per_sec
  def healing_rate_limit_requests_per_sec, do: :healing_rate_limit_requests_per_sec

  @doc """
  The recovery action taken by the reflex arc.

  Attribute: `healing.recovery_action`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `restart_worker`, `drain_queue`, `escalate_to_supervisor`, `kill_process`
  """
  @spec healing_recovery_action() :: :healing_recovery_action
  def healing_recovery_action, do: :healing_recovery_action

  @doc """
  Whether the healing operation reached a terminal state (success or escalated).

  Attribute: `healing.recovery_complete`
  Type: `boolean`
  Stability: `development`
  Requirement: `recommended`
  Examples: `true`, `false`
  """
  @spec healing_recovery_complete() :: :healing_recovery_complete
  def healing_recovery_complete, do: :healing_recovery_complete

  @doc """
  The recovery strategy selected by the healing engine.

  Attribute: `healing.recovery_strategy`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `restart`, `circuit_break`
  """
  @spec healing_recovery_strategy() :: :healing_recovery_strategy
  def healing_recovery_strategy, do: :healing_recovery_strategy

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
  @spec healing_reflex_arc() :: :healing_reflex_arc
  def healing_reflex_arc, do: :healing_reflex_arc

  @doc """
  The repair strategy applied during healing recovery.

  Attribute: `healing.repair.strategy`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `restart`, `rollback`
  """
  @spec healing_repair_strategy() :: :healing_repair_strategy
  def healing_repair_strategy, do: :healing_repair_strategy

  @doc """
  Enumerated values for `healing.repair.strategy`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `restart` | `"restart"` | restart |
  | `rollback` | `"rollback"` | rollback |
  | `failover` | `"failover"` | failover |
  | `rebalance` | `"rebalance"` | rebalance |
  """
  @spec healing_repair_strategy_values() :: %{
    restart: :restart,
    rollback: :rollback,
    failover: :failover,
    rebalance: :rebalance
  }
  def healing_repair_strategy_values do
    %{
      restart: :restart,
      rollback: :rollback,
      failover: :failover,
      rebalance: :rebalance
    }
  end

  defmodule HealingRepairStrategyValues do
    @moduledoc """
    Typed constants for the `healing.repair.strategy` attribute.
    """

    @doc "restart"
    @spec restart() :: :restart
    def restart, do: :restart

    @doc "rollback"
    @spec rollback() :: :rollback
    def rollback, do: :rollback

    @doc "failover"
    @spec failover() :: :failover
    def failover, do: :failover

    @doc "rebalance"
    @spec rebalance() :: :rebalance
    def rebalance, do: :rebalance

  end

  @doc """
  Identifier of the checkpoint or snapshot used as the rollback target.

  Attribute: `healing.rollback.checkpoint_id`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `ckpt-2026-03-25T12:00:00Z`, `snap-v3.2.1`
  """
  @spec healing_rollback_checkpoint_id() :: :healing_rollback_checkpoint_id
  def healing_rollback_checkpoint_id, do: :healing_rollback_checkpoint_id

  @doc """
  Time in milliseconds to complete the rollback operation.

  Attribute: `healing.rollback.recovery_ms`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `250`, `1200`, `8000`
  """
  @spec healing_rollback_recovery_ms() :: :healing_rollback_recovery_ms
  def healing_rollback_recovery_ms, do: :healing_rollback_recovery_ms

  @doc """
  Strategy used to roll back the system to a known-good state.

  Attribute: `healing.rollback.strategy`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `checkpoint`, `snapshot`, `incremental`
  """
  @spec healing_rollback_strategy() :: :healing_rollback_strategy
  def healing_rollback_strategy, do: :healing_rollback_strategy

  @doc """
  Enumerated values for `healing.rollback.strategy`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `checkpoint` | `"checkpoint"` | checkpoint |
  | `snapshot` | `"snapshot"` | snapshot |
  | `incremental` | `"incremental"` | incremental |
  """
  @spec healing_rollback_strategy_values() :: %{
    checkpoint: :checkpoint,
    snapshot: :snapshot,
    incremental: :incremental
  }
  def healing_rollback_strategy_values do
    %{
      checkpoint: :checkpoint,
      snapshot: :snapshot,
      incremental: :incremental
    }
  end

  defmodule HealingRollbackStrategyValues do
    @moduledoc """
    Typed constants for the `healing.rollback.strategy` attribute.
    """

    @doc "checkpoint"
    @spec checkpoint() :: :checkpoint
    def checkpoint, do: :checkpoint

    @doc "snapshot"
    @spec snapshot() :: :snapshot
    def snapshot, do: :snapshot

    @doc "incremental"
    @spec incremental() :: :incremental
    def incremental, do: :incremental

  end

  @doc """
  Whether the rollback operation completed successfully.

  Attribute: `healing.rollback.success`
  Type: `boolean`
  Stability: `development`
  Requirement: `recommended`
  Examples: `true`, `false`
  """
  @spec healing_rollback_success() :: :healing_rollback_success
  def healing_rollback_success, do: :healing_rollback_success

  @doc """
  Identifier of the root cause failure that triggered this cascade.

  Attribute: `healing.root_cause.id`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `failure-001`, `osa-agent-3-timeout`
  """
  @spec healing_root_cause_id() :: :healing_root_cause_id
  def healing_root_cause_id, do: :healing_root_cause_id

  @doc """
  Whether autonomous self-healing is enabled for this component.

  Attribute: `healing.self_healing.enabled`
  Type: `boolean`
  Stability: `development`
  Requirement: `recommended`
  Examples: `true`, `false`
  """
  @spec healing_self_healing_enabled() :: :healing_self_healing_enabled
  def healing_self_healing_enabled, do: :healing_self_healing_enabled

  @doc """
  Fraction of self-healing attempts that succeeded, range [0.0, 1.0].

  Attribute: `healing.self_healing.success_rate`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0.95`, `0.8`, `1.0`
  """
  @spec healing_self_healing_success_rate() :: :healing_self_healing_success_rate
  def healing_self_healing_success_rate, do: :healing_self_healing_success_rate

  @doc """
  Number of times self-healing has been triggered in the current session.

  Attribute: `healing.self_healing.trigger_count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0`, `3`, `12`
  """
  @spec healing_self_healing_trigger_count() :: :healing_self_healing_trigger_count
  def healing_self_healing_trigger_count, do: :healing_self_healing_trigger_count

  @doc """
  Total duration in milliseconds of the recovery simulation run.

  Attribute: `healing.simulation.duration_ms`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `1200`, `5000`
  """
  @spec healing_simulation_duration_ms() :: :healing_simulation_duration_ms
  def healing_simulation_duration_ms, do: :healing_simulation_duration_ms

  @doc """
  Number of distinct failure modes simulated in this recovery simulation.

  Attribute: `healing.simulation.failure_mode_count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `3`, `11`
  """
  @spec healing_simulation_failure_mode_count() :: :healing_simulation_failure_mode_count
  def healing_simulation_failure_mode_count, do: :healing_simulation_failure_mode_count

  @doc """
  Unique identifier for a healing recovery simulation run.

  Attribute: `healing.simulation.id`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `sim-abc123`, `chaos-run-007`
  """
  @spec healing_simulation_id() :: :healing_simulation_id
  def healing_simulation_id, do: :healing_simulation_id

  @doc """
  Fraction of simulated recovery scenarios that succeeded, range [0.0, 1.0].

  Attribute: `healing.simulation.success_rate`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0.91`, `0.75`
  """
  @spec healing_simulation_success_rate() :: :healing_simulation_success_rate
  def healing_simulation_success_rate, do: :healing_simulation_success_rate

  @doc """
  Time window in milliseconds over which surge is detected.

  Attribute: `healing.surge.detection_window_ms`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `1000`, `5000`, `30000`
  """
  @spec healing_surge_detection_window_ms() :: :healing_surge_detection_window_ms
  def healing_surge_detection_window_ms, do: :healing_surge_detection_window_ms

  @doc """
  Strategy applied to mitigate healing request surge.

  Attribute: `healing.surge.mitigation_strategy`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `shed`, `queue`, `throttle`
  """
  @spec healing_surge_mitigation_strategy() :: :healing_surge_mitigation_strategy
  def healing_surge_mitigation_strategy, do: :healing_surge_mitigation_strategy

  @doc """
  Enumerated values for `healing.surge.mitigation_strategy`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `shed` | `"shed"` | shed |
  | `queue` | `"queue"` | queue |
  | `throttle` | `"throttle"` | throttle |
  """
  @spec healing_surge_mitigation_strategy_values() :: %{
    shed: :shed,
    queue: :queue,
    throttle: :throttle
  }
  def healing_surge_mitigation_strategy_values do
    %{
      shed: :shed,
      queue: :queue,
      throttle: :throttle
    }
  end

  defmodule HealingSurgeMitigationStrategyValues do
    @moduledoc """
    Typed constants for the `healing.surge.mitigation_strategy` attribute.
    """

    @doc "shed"
    @spec shed() :: :shed
    def shed, do: :shed

    @doc "queue"
    @spec queue() :: :queue
    def queue, do: :queue

    @doc "throttle"
    @spec throttle() :: :throttle
    def throttle, do: :throttle

  end

  @doc """
  Multiplier applied to baseline thresholds to detect a healing surge.

  Attribute: `healing.surge.threshold_multiplier`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `1.5`, `2.0`, `3.0`
  """
  @spec healing_surge_threshold_multiplier() :: :healing_surge_threshold_multiplier
  def healing_surge_threshold_multiplier, do: :healing_surge_threshold_multiplier

  @doc """
  Maximum time budget for the healing operation in milliseconds (WvdA deadlock freedom).

  Attribute: `healing.timeout_ms`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `5000`, `30000`, `60000`
  """
  @spec healing_timeout_ms() :: :healing_timeout_ms
  def healing_timeout_ms, do: :healing_timeout_ms

  @doc """
  Execution time in milliseconds for the healing verification operation.

  Attribute: `healing.verification.execution_time_ms`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `100`, `500`, `2000`
  """
  @spec healing_verification_execution_time_ms() :: :healing_verification_execution_time_ms
  def healing_verification_execution_time_ms, do: :healing_verification_execution_time_ms

  @doc """
  Number of tests that failed during healing verification.

  Attribute: `healing.verification.failed_tests`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0`, `1`, `3`
  """
  @spec healing_verification_failed_tests() :: :healing_verification_failed_tests
  def healing_verification_failed_tests, do: :healing_verification_failed_tests

  @doc """
  Number of tests that passed during healing verification.

  Attribute: `healing.verification.passed_tests`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0`, `5`, `10`
  """
  @spec healing_verification_passed_tests() :: :healing_verification_passed_tests
  def healing_verification_passed_tests, do: :healing_verification_passed_tests

  @doc """
  Overall verification status for the healing operation.

  Attribute: `healing.verification.status`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `pass`, `fail`
  """
  @spec healing_verification_status() :: :healing_verification_status
  def healing_verification_status, do: :healing_verification_status

  @doc """
  Enumerated values for `healing.verification.status`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `pass` | `"pass"` | pass |
  | `fail` | `"fail"` | fail |
  | `inconclusive` | `"inconclusive"` | inconclusive |
  """
  @spec healing_verification_status_values() :: %{
    pass: :pass,
    fail: :fail,
    inconclusive: :inconclusive
  }
  def healing_verification_status_values do
    %{
      pass: :pass,
      fail: :fail,
      inconclusive: :inconclusive
    }
  end

  defmodule HealingVerificationStatusValues do
    @moduledoc """
    Typed constants for the `healing.verification.status` attribute.
    """

    @doc "pass"
    @spec pass() :: :pass
    def pass, do: :pass

    @doc "fail"
    @spec fail() :: :fail
    def fail, do: :fail

    @doc "inconclusive"
    @spec inconclusive() :: :inconclusive
    def inconclusive, do: :inconclusive

  end

  @doc """
  Unique identifier for the warm standby replica.

  Attribute: `healing.warm_standby.id`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `ws-001`, `warm-standby-primary`
  """
  @spec healing_warm_standby_id() :: :healing_warm_standby_id
  def healing_warm_standby_id, do: :healing_warm_standby_id

  @doc """
  Activation latency of the warm standby in milliseconds — time from trigger to live.

  Attribute: `healing.warm_standby.latency_ms`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `50`, `200`, `1000`
  """
  @spec healing_warm_standby_latency_ms() :: :healing_warm_standby_latency_ms
  def healing_warm_standby_latency_ms, do: :healing_warm_standby_latency_ms

  @doc """
  Readiness state of the warm standby replica.

  Attribute: `healing.warm_standby.readiness`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `ready`, `warming`
  """
  @spec healing_warm_standby_readiness() :: :healing_warm_standby_readiness
  def healing_warm_standby_readiness, do: :healing_warm_standby_readiness

  @doc """
  Enumerated values for `healing.warm_standby.readiness`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `ready` | `"ready"` | ready |
  | `warming` | `"warming"` | warming |
  | `unavailable` | `"unavailable"` | unavailable |
  """
  @spec healing_warm_standby_readiness_values() :: %{
    ready: :ready,
    warming: :warming,
    unavailable: :unavailable
  }
  def healing_warm_standby_readiness_values do
    %{
      ready: :ready,
      warming: :warming,
      unavailable: :unavailable
    }
  end

  defmodule HealingWarmStandbyReadinessValues do
    @moduledoc """
    Typed constants for the `healing.warm_standby.readiness` attribute.
    """

    @doc "ready"
    @spec ready() :: :ready
    def ready, do: :ready

    @doc "warming"
    @spec warming() :: :warming
    def warming, do: :warming

    @doc "unavailable"
    @spec unavailable() :: :unavailable
    def unavailable, do: :unavailable

  end

  @doc """
  Number of warm standby replicas available for failover.

  Attribute: `healing.warm_standby.replica_count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `1`, `2`, `3`
  """
  @spec healing_warm_standby_replica_count() :: :healing_warm_standby_replica_count
  def healing_warm_standby_replica_count, do: :healing_warm_standby_replica_count

end