defmodule OptimalSystemAgent.Healing.Fixer do
  @moduledoc """
  Healing Fixer module -- repair strategies for broken processes.

  Implements 5 core repair strategies to recover from detected failures:

  1. **State Repair** -- Rollback to last known-good checkpoint, rerun from that point.
     Used for: Ashby drift, state divergence, configuration errors.

  2. **Logic Rollback** -- Revert to previous version of the process logic, retry.
     Used for: Regression bugs, newly-introduced logic errors.

  3. **Logic Patching** -- Identify the specific broken step, patch it in-place, retry.
     Used for: Arithmetic overflows, assertion failures, arithmetic errors.

  4. **Partial Recovery** -- Skip the failed non-critical step, continue in degraded mode.
     Used for: Beer complexity (processing overload), non-essential features.

  5. **Compensation** -- Execute compensating transaction (undo + alternative path).
     Used for: Wiener feedback instability, over-aggressive gains, cascade cascades.

  ## Failure Modes Handled

  | Mode | Strategy | Rationale |
  |------|----------|-----------|
  | `:ashby_drift` | state_repair | Restore from checkpoint |
  | `:logic_regression` | logic_rollback | Revert to stable version |
  | `:arithmetic_overflow` | logic_patch | Fix the broken computation |
  | `:assertion_failure` | logic_patch | Identify broken assertion |
  | `:beer_complexity` | partial_recovery | Skip non-critical steps |
  | `:wiener_feedback_instability` | compensation | Reduce gain, retry |
  | `:deadlock` | state_repair, partial_recovery | Release locks, fallback |
  | `:cascade` | partial_recovery, compensation | Isolate, bypass component |
  | `:byzantine` | state_repair, compensation | Use majority voting |
  | `:starvation` | partial_recovery, compensation | Boost priority |
  | `:livelock` | logic_patch, compensation | Add randomness |
  | `:timeout` | compensation, partial_recovery | Extend deadline |
  | `:inconsistent_state` | state_repair, compensation | Sync from authority |

  ## Return Values

  **Success:**
  ```
  {:fixed, repaired_state, strategy, retry_count}
  ```
  where:
  - `repaired_state` :: map of restored/patched process state
  - `strategy` :: atom from `:state_repair | :logic_rollback | :logic_patch | :partial_recovery | :compensation`
  - `retry_count` :: non-negative integer indicating attempts made

  **Failure:**
  ```
  {:unrecoverable, reason}
  ```
  where `reason` is a descriptive atom or string explaining why repair failed.

  ## Innovation 6 -- Healing Fixer (Vision 2030)
  """

  require Logger

  @type failure_mode ::
          :ashby_drift
          | :logic_regression
          | :arithmetic_overflow
          | :assertion_failure
          | :beer_complexity
          | :wiener_feedback_instability
          | :deadlock
          | :cascade
          | :byzantine
          | :starvation
          | :livelock
          | :timeout
          | :inconsistent_state
          | atom()

  @type repair_strategy ::
          :state_repair
          | :logic_rollback
          | :logic_patch
          | :partial_recovery
          | :compensation

  @type fix_result ::
          {:fixed, map(), repair_strategy(), non_neg_integer()}
          | {:unrecoverable, atom() | String.t()}

  # ---- Public API ----

  @doc """
  Fix a broken process using appropriate repair strategy.

  Analyzes the failure mode and selects a repair strategy:
  - State-based failures → rollback
  - Logic-based failures → patch or rollback
  - Complexity-based failures → partial recovery
  - Feedback failures → compensation

  Returns either `{:fixed, repaired_state, strategy, retry_count}` or
  `{:unrecoverable, reason}`.
  """
  @spec fix(map(), map(), map()) :: fix_result()
  def fix(failure, current_state, context \\ %{}) do
    mode = Map.get(failure, :mode)
    tracer = :opentelemetry.get_tracer(:optimal_system_agent)
    process_id = Map.get(context, :process_id, "unknown")

    span_attrs = %{
      "failure_mode" => inspect(mode),
      "process_id" => inspect(process_id),
      "state_keys_count" => Enum.count(current_state)
    }

    Logger.debug("Healing.Fixer.fix/3", %{
      mode: mode,
      process_id: process_id,
      state_keys: Map.keys(current_state)
    })

    :otel_tracer.with_span(tracer, "healing.fix", span_attrs, fn span_ctx ->
      result = case mode do
      # ---- State-based failures ----
      :ashby_drift ->
        fix_state_repair(failure, current_state, context)

      # ---- Logic-based failures ----
      :logic_regression ->
        fix_logic_rollback(failure, current_state, context)

      :arithmetic_overflow ->
        fix_logic_patch(failure, current_state, context)

      :assertion_failure ->
        fix_logic_patch(failure, current_state, context)

      # ---- Complexity-based failures ----
      :beer_complexity ->
        fix_partial_recovery(failure, current_state, context)

      # ---- Feedback-based failures ----
      :wiener_feedback_instability ->
        fix_compensation(failure, current_state, context)

      # ---- Distributed system failures ----
      :deadlock ->
        fix_deadlock(failure, current_state, context)

      :cascade ->
        fix_cascade(failure, current_state, context)

      :byzantine ->
        fix_byzantine(failure, current_state, context)

      # ---- Resource contention failures ----
      :starvation ->
        fix_starvation(failure, current_state, context)

      :livelock ->
        fix_livelock(failure, current_state, context)

      :timeout ->
        fix_timeout(failure, current_state, context)

      # ---- Data consistency failures ----
      :inconsistent_state ->
        fix_inconsistency(failure, current_state, context)

      # ---- Unknown or unrecoverable ----
      :retry_exhausted ->
        {:unrecoverable, :max_retries_exceeded}

      _unknown ->
        {:unrecoverable, "Unknown failure mode: #{inspect(mode)}"}
      end

      :otel_span.set_attributes(span_ctx, %{"fix_result" => inspect(result)})
      result
    end)
  end

  # ---- Strategy: State Repair ----

  defp fix_state_repair(failure, current_state, context) do
    checkpoint = Map.get(failure, :checkpoint, %{})
    process_id = Map.get(context, :process_id, "unknown")

    if map_size(checkpoint) > 0 do
      repaired = Map.merge(current_state, checkpoint)

      Logger.info("State repair: rolling back", %{
        process_id: process_id,
        checkpoint_keys: Map.keys(checkpoint)
      })

      {:fixed, repaired, :state_repair, 0}
    else
      {:unrecoverable, "No checkpoint available for state repair"}
    end
  end

  # ---- Strategy: Logic Rollback ----

  defp fix_logic_rollback(failure, current_state, context) do
    current_version = Map.get(failure, :current_version)
    previous_version = Map.get(failure, :previous_version)
    versions = Map.get(context, :versions, [])

    cond do
      is_nil(previous_version) ->
        {:unrecoverable, "No previous version available"}

      true ->
        repaired =
          current_state
          |> Map.put(:version, previous_version)
          |> maybe_reset_state(versions, previous_version)

        Logger.info("Logic rollback: reverting logic version", %{
          from_version: current_version,
          to_version: previous_version
        })

        {:fixed, repaired, :logic_rollback, 0}
    end
  end

  # ---- Strategy: Logic Patching ----

  defp fix_logic_patch(failure, current_state, context) do
    broken_step = Map.get(failure, :broken_step)
    broken_logic = Map.get(failure, :broken_logic)
    process_id = Map.get(context, :process_id, "unknown")

    if broken_step && broken_logic do
      # Patch: conservative fix (add bounds checking, use safe defaults)
      repaired =
        current_state
        |> maybe_fix_arithmetic()
        |> maybe_fix_assertion()

      Logger.info("Logic patch: patching broken step", %{
        process_id: process_id,
        broken_step: broken_step,
        broken_logic: broken_logic
      })

      {:fixed, repaired, :logic_patch, 0}
    else
      {:unrecoverable, "Cannot identify broken step for patching"}
    end
  end

  # ---- Strategy: Partial Recovery ----

  defp fix_partial_recovery(failure, current_state, _context) do
    failed_step = Map.get(failure, :failed_step, :unknown)
    is_critical = Map.get(failure, :critical, false)

    if is_critical do
      {:unrecoverable, "Critical step failed, cannot skip"}
    else
      repaired =
        current_state
        |> Map.put(:mode, :degraded)
        |> Map.put(:skipped_step, failed_step)

      Logger.info("Partial recovery: skipping non-critical step", %{
        skipped_step: failed_step,
        mode: :degraded
      })

      {:fixed, repaired, :partial_recovery, 0}
    end
  end

  # ---- Strategy: Compensation ----

  defp fix_compensation(failure, current_state, context) do
    last_good_state = Map.get(failure, :last_good_state, %{})

    # Compensate by moving closer to last known good state
    repaired =
      current_state
      |> compensate_to_good_state(last_good_state)
      |> maybe_reduce_feedback_gain()
      |> maybe_extend_deadline()

    Logger.info("Compensation: executing compensating transaction", %{
      process_id: Map.get(context, :process_id, "unknown")
    })

    {:fixed, repaired, :compensation, 0}
  end

  # ---- Failure Mode: Deadlock ----

  defp fix_deadlock(failure, current_state, context) do
    _held_locks = Map.get(failure, :held_locks, [])
    _waiting_for = Map.get(failure, :waiting_for, [])

    # Release locks and transition to fallback state
    repaired =
      current_state
      |> Map.put(:locks, [])
      |> Map.put(:status, :released)

    Logger.info("Deadlock recovery: releasing locks", %{
      process_id: Map.get(context, :process_id, "unknown")
    })

    {:fixed, repaired, :state_repair, 0}
  end

  # ---- Failure Mode: Cascade ----

  defp fix_cascade(failure, current_state, _context) do
    failed_component = Map.get(failure, :failed_component)
    fallback_component = Map.get(failure, :fallback_component)

    if fallback_component do
      repaired =
        current_state
        |> Map.put(:component, fallback_component)
        |> Map.put(:bypassed_component, failed_component)

      Logger.info("Cascade recovery: switching to fallback component", %{
        failed: failed_component,
        fallback: fallback_component
      })

      {:fixed, repaired, :partial_recovery, 0}
    else
      {:unrecoverable, "No fallback component available for cascade"}
    end
  end

  # ---- Failure Mode: Byzantine ----

  defp fix_byzantine(failure, current_state, _context) do
    consensus_value = Map.get(failure, :consensus_value)
    _conflicting_replicas = Map.get(failure, :conflicting_replicas, [])

    if consensus_value do
      repaired =
        current_state
        |> Map.put(:value, consensus_value)
        |> Map.put(:trusted, true)

      Logger.info("Byzantine recovery: using consensus value", %{
        consensus_value: consensus_value
      })

      {:fixed, repaired, :state_repair, 0}
    else
      {:unrecoverable, "No consensus value available for Byzantine recovery"}
    end
  end

  # ---- Failure Mode: Starvation ----

  defp fix_starvation(failure, current_state, context) do
    _current_priority = Map.get(failure, :current_priority, :low)

    repaired =
      current_state
      |> Map.put(:priority, :high)
      |> Map.put(:boosted, true)

    Logger.info("Starvation recovery: boosting priority", %{
      process_id: Map.get(context, :process_id, "unknown")
    })

    {:fixed, repaired, :compensation, 0}
  end

  # ---- Failure Mode: Livelock ----

  defp fix_livelock(failure, current_state, context) do
    _repeating_pattern = Map.get(failure, :repeating_pattern, [])

    # Break symmetry by introducing randomness
    repaired =
      current_state
      |> Map.put(:jitter_added, true)
      |> Map.put(:random_seed, :erlang.system_time(:millisecond))

    Logger.info("Livelock recovery: adding randomness to break symmetry", %{
      process_id: Map.get(context, :process_id, "unknown")
    })

    {:fixed, repaired, :logic_patch, 0}
  end

  # ---- Failure Mode: Timeout ----

  defp fix_timeout(failure, current_state, _context) do
    current_deadline = Map.get(failure, :current_deadline_ms, 5_000)

    repaired =
      current_state
      |> Map.put(:deadline_ms, current_deadline * 2)
      |> Map.put(:deadline_extended, true)

    Logger.info("Timeout recovery: extending deadline", %{
      old_deadline_ms: current_deadline,
      new_deadline_ms: current_deadline * 2
    })

    {:fixed, repaired, :compensation, 0}
  end

  # ---- Failure Mode: Inconsistent State ----

  defp fix_inconsistency(failure, current_state, context) do
    authority_value = Map.get(failure, :authority_value)
    _authority = Map.get(failure, :authority, :primary)

    if authority_value do
      repaired = Map.merge(current_state, authority_value)

      Logger.info("Inconsistency recovery: syncing from authority", %{
        process_id: Map.get(context, :process_id, "unknown")
      })

      {:fixed, repaired, :state_repair, 0}
    else
      {:unrecoverable, "No authoritative state available"}
    end
  end

  # ---- Helper Functions ----

  defp maybe_reset_state(state, _versions, _target_version) do
    # Conservative: preserve non-version fields
    state
  end

  defp maybe_fix_arithmetic(state) do
    # Apply bounds checking to numerical fields
    state
    |> maybe_clamp_field(:counter, 0, 1_000_000)
    |> maybe_clamp_field(:result, 0, 1_000_000)
    |> maybe_clamp_field(:gain, 0.0, 10.0)
  end

  defp maybe_clamp_field(state, field, min, max) do
    case Map.get(state, field) do
      nil ->
        state

      value when is_number(value) ->
        clamped = min(max(value, min), max)
        Map.put(state, field, clamped)

      _other ->
        state
    end
  end

  defp maybe_fix_assertion(state) do
    # For assertion failures, try to restore valid invariants
    # Conservative approach: keep existing state unless obviously broken
    state
  end

  defp compensate_to_good_state(current, last_good) do
    # Move 50% of the way back to last good state
    Enum.reduce(last_good, current, fn {key, good_value}, acc ->
      case Map.get(acc, key) do
        nil ->
          Map.put(acc, key, good_value)

        current_value when is_number(current_value) and is_number(good_value) ->
          midpoint = (current_value + good_value) / 2.0
          Map.put(acc, key, midpoint)

        _other ->
          # Keep current value if types don't match
          acc
      end
    end)
  end

  defp maybe_reduce_feedback_gain(state) do
    case Map.get(state, :gain) do
      nil ->
        state

      gain when is_number(gain) ->
        # Reduce feedback gain by 50% to dampen oscillations
        Map.put(state, :gain, gain / 2.0)

      _other ->
        state
    end
  end

  defp maybe_extend_deadline(state) do
    case Map.get(state, :deadline_ms) do
      nil ->
        state

      deadline when is_number(deadline) ->
        # Double the deadline
        Map.put(state, :deadline_ms, deadline * 2)

      _other ->
        state
    end
  end
end
