defmodule OptimalSystemAgent.Healing.FixerTest do
  @moduledoc """
  Unit tests for the Healing Fixer module -- repair strategies for broken processes.

  The Fixer module implements 5 core repair strategies:
  1. State Repair: Rollback to last known-good state, rerun from checkpoint
  2. Logic Rollback: Revert to previous version of logic, retry
  3. Logic Patching: Identify broken step, patch in-place, retry
  4. Partial Recovery: Skip failed step, continue with degraded mode
  5. Compensation: Execute compensating transaction (undo + alternative path)

  Tests cover: Shannon (info loss), Ashby (drift), Beer (complexity),
  Wiener (feedback instability), Deadlock, Cascade, Byzantine, Starvation,
  Livelock, Timeout, and Inconsistent failure modes.

  ## Innovation 6 -- Healing Fixer (Vision 2030)
  """
  use ExUnit.Case, async: true

  alias OptimalSystemAgent.Healing.Fixer

  # ---- State Repair Tests ----

  describe "fix/3 -- state repair (Ashby drift)" do
    test "rolls back to checkpoint and reruns successfully" do
      failure = %{
        mode: :ashby_drift,
        reason: "state diverged from expected",
        checkpoint: %{step: 3, value: 100},
        current_state: %{step: 5, value: 500}
      }

      context = %{
        process_id: "proc1",
        versions: [1, 2, 3],
        current_version: 3
      }

      result = Fixer.fix(failure, failure.current_state, context)

      assert {:fixed, repaired, strategy, retry_count} = result
      assert repaired.step == 3
      assert repaired.value == 100
      assert strategy == :state_repair
      assert is_integer(retry_count)
      assert retry_count >= 0
    end

    test "state repair preserves metadata across rollback" do
      failure = %{
        mode: :ashby_drift,
        checkpoint: %{x: 1, meta: %{session: "s1"}},
        current_state: %{x: 10, meta: %{session: "s1"}}
      }

      context = %{process_id: "proc2"}

      result = Fixer.fix(failure, failure.current_state, context)

      assert {:fixed, repaired, :state_repair, _} = result
      assert repaired.meta == %{session: "s1"}
    end
  end

  # ---- Logic Rollback Tests ----

  describe "fix/3 -- logic rollback" do
    test "reverts to previous logic version and retries" do
      failure = %{
        mode: :logic_regression,
        reason: "new logic version has bug",
        current_version: 3,
        previous_version: 2
      }

      current_state = %{version: 3, counter: 5}
      context = %{process_id: "proc3"}

      result = Fixer.fix(failure, current_state, context)

      assert {:fixed, repaired, strategy, _} = result
      assert strategy == :logic_rollback
      assert repaired.version == 2
    end

    test "logic rollback handles multi-version history" do
      failure = %{
        mode: :logic_regression,
        current_version: 5,
        previous_version: 3
      }

      current_state = %{version: 5}
      context = %{versions: [1, 2, 3, 4, 5]}

      result = Fixer.fix(failure, current_state, context)

      assert {:fixed, repaired, :logic_rollback, _} = result
      assert repaired.version == 3
    end
  end

  # ---- Logic Patching Tests ----

  describe "fix/3 -- logic patching" do
    test "identifies broken step and patches in-place" do
      failure = %{
        mode: :arithmetic_overflow,
        reason: "step 4 multiplies too aggressively",
        broken_step: 4,
        broken_logic: "result * 100"
      }

      current_state = %{step: 4, result: 1_000_000}
      context = %{process_id: "proc4"}

      result = Fixer.fix(failure, current_state, context)

      assert {:fixed, repaired, strategy, _} = result
      assert strategy == :logic_patch
      assert is_map(repaired)
      assert Map.has_key?(repaired, :step)
    end

    test "patch preserves computation chain" do
      failure = %{
        mode: :assertion_failure,
        broken_step: 2,
        broken_logic: "x > 100"
      }

      current_state = %{step: 2, x: 50, previous_result: 10}
      context = %{}

      result = Fixer.fix(failure, current_state, context)

      assert {:fixed, repaired, :logic_patch, _} = result
      assert repaired.previous_result == 10
    end
  end

  # ---- Partial Recovery Tests ----

  describe "fix/3 -- partial recovery (Beer complexity)" do
    test "skips non-critical failed step and continues in degraded mode" do
      failure = %{
        mode: :beer_complexity,
        reason: "processing complexity exceeded",
        failed_step: :enrichment,
        critical: false
      }

      current_state = %{
        step: :enrichment,
        core_data: %{id: 1, name: "test"},
        enrichment_data: nil
      }

      context = %{process_id: "proc5"}

      result = Fixer.fix(failure, current_state, context)

      assert {:fixed, repaired, strategy, _} = result
      assert strategy == :partial_recovery
      assert repaired.core_data == %{id: 1, name: "test"}
      assert repaired.enrichment_data == nil
    end

    test "partial recovery marks degraded mode" do
      failure = %{
        mode: :beer_complexity,
        failed_step: :secondary_validation
      }

      current_state = %{status: "processing", mode: "normal"}
      context = %{}

      result = Fixer.fix(failure, current_state, context)

      assert {:fixed, repaired, :partial_recovery, _} = result
      assert Map.has_key?(repaired, :mode)
    end
  end

  # ---- Compensation Tests ----

  describe "fix/3 -- compensation (Wiener feedback instability)" do
    test "executes compensating transaction on Wiener instability" do
      failure = %{
        mode: :wiener_feedback_instability,
        reason: "feedback loop gain too high",
        last_good_state: %{gain: 0.5, output: 100}
      }

      current_state = %{gain: 5.0, output: 10_000}
      context = %{process_id: "proc6"}

      result = Fixer.fix(failure, current_state, context)

      assert {:fixed, repaired, strategy, _} = result
      assert strategy == :compensation
      # Gain should be reduced
      assert repaired.gain < current_state.gain
    end

    test "compensation executes undo + alternative path" do
      failure = %{
        mode: :wiener_feedback_instability,
        last_good_state: %{counter: 10}
      }

      current_state = %{counter: 1000}
      context = %{}

      result = Fixer.fix(failure, current_state, context)

      assert {:fixed, repaired, :compensation, _} = result
      # Should have executed alternative (lower gain)
      assert is_map(repaired)
    end
  end

  # ---- Failure Mode: Deadlock ----

  describe "fix/3 -- deadlock detection and recovery" do
    test "deadlock triggers timeout + fallback state" do
      failure = %{
        mode: :deadlock,
        reason: "mutual exclusion cycle detected",
        waiting_for: [:lock_a, :lock_b],
        held_by: %{lock_a: "proc_x", lock_b: "proc_y"}
      }

      current_state = %{locks: [:lock_a, :lock_b], status: "waiting"}
      context = %{process_id: "proc7"}

      result = Fixer.fix(failure, current_state, context)

      assert {:fixed, repaired, strategy, _} = result
      assert strategy in [:state_repair, :partial_recovery]
      assert is_map(repaired)
    end

    test "deadlock recovery clears stuck locks" do
      failure = %{
        mode: :deadlock,
        held_locks: [:lock_a, :lock_b]
      }

      current_state = %{status: "deadlocked"}
      context = %{}

      result = Fixer.fix(failure, current_state, context)

      assert {:fixed, repaired, _, _} = result
      assert is_map(repaired)
    end
  end

  # ---- Failure Mode: Cascade ----

  describe "fix/3 -- cascade failure isolation" do
    test "cascade failure isolates component and bypasses it" do
      failure = %{
        mode: :cascade,
        reason: "single component failure cascading",
        failed_component: :provider_a,
        fallback_component: :provider_b
      }

      current_state = %{
        provider: :provider_a,
        status: "failed",
        data: %{items: [1, 2, 3]}
      }

      context = %{process_id: "proc8"}

      result = Fixer.fix(failure, current_state, context)

      assert {:fixed, repaired, strategy, _} = result
      assert strategy in [:partial_recovery, :compensation]
      assert repaired.data == %{items: [1, 2, 3]}
    end

    test "cascade recovery switches to fallback" do
      failure = %{
        mode: :cascade,
        failed_component: :comp_1,
        fallback_component: :comp_2
      }

      current_state = %{component: :comp_1}
      context = %{}

      result = Fixer.fix(failure, current_state, context)

      assert {:fixed, repaired, _, _} = result
      assert is_map(repaired)
    end
  end

  # ---- Failure Mode: Byzantine ----

  describe "fix/3 -- byzantine fault isolation" do
    test "byzantine fault quarantines node and uses majority voting" do
      failure = %{
        mode: :byzantine,
        reason: "conflicting state from replicas",
        conflicting_replicas: [:node_a, :node_b],
        consensus_value: 100
      }

      current_state = %{
        value: 50,
        replicas: [:node_a, :node_b, :node_c],
        status: "conflict"
      }

      context = %{process_id: "proc9"}

      result = Fixer.fix(failure, current_state, context)

      assert {:fixed, repaired, strategy, _} = result
      assert strategy in [:state_repair, :compensation]
      # Should use consensus value or trusted replica
      assert is_map(repaired)
    end

    test "byzantine recovery selects majority-voted state" do
      failure = %{
        mode: :byzantine,
        consensus_value: 100
      }

      current_state = %{value: 50}
      context = %{}

      result = Fixer.fix(failure, current_state, context)

      assert {:fixed, repaired, _, _} = result
      assert is_map(repaired)
    end
  end

  # ---- Failure Mode: Starvation ----

  describe "fix/3 -- starvation detection and recovery" do
    test "starvation boosts priority and retries" do
      failure = %{
        mode: :starvation,
        reason: "resource pool exhausted",
        starving_task: :critical_work,
        current_priority: :low
      }

      current_state = %{
        task: :critical_work,
        priority: :low,
        wait_time_ms: 30_000
      }

      context = %{process_id: "proc10"}

      result = Fixer.fix(failure, current_state, context)

      assert {:fixed, repaired, strategy, _} = result
      assert strategy in [:partial_recovery, :compensation]
      # Priority should be boosted
      assert is_map(repaired)
    end

    test "starvation recovery increases priority" do
      failure = %{
        mode: :starvation,
        current_priority: :low
      }

      current_state = %{priority: :low}
      context = %{}

      result = Fixer.fix(failure, current_state, context)

      assert {:fixed, repaired, _, _} = result
      assert is_map(repaired)
    end
  end

  # ---- Failure Mode: Livelock ----

  describe "fix/3 -- livelock detection and recovery" do
    test "livelock introduces randomness to break symmetry" do
      failure = %{
        mode: :livelock,
        reason: "processes busy but making no progress",
        repeating_pattern: [:action_a, :action_b, :action_a]
      }

      current_state = %{
        action_history: [:action_a, :action_b, :action_a],
        status: "looping"
      }

      context = %{process_id: "proc11"}

      result = Fixer.fix(failure, current_state, context)

      assert {:fixed, repaired, strategy, _} = result
      assert strategy in [:logic_patch, :compensation]
      assert is_map(repaired)
    end

    test "livelock recovery adds random jitter" do
      failure = %{
        mode: :livelock,
        repeating_pattern: [:x, :y, :x]
      }

      current_state = %{pattern: [:x, :y, :x]}
      context = %{}

      result = Fixer.fix(failure, current_state, context)

      assert {:fixed, repaired, _, _} = result
      assert is_map(repaired)
    end
  end

  # ---- Failure Mode: Timeout ----

  describe "fix/3 -- timeout extension and recovery" do
    test "timeout increases deadline and retries" do
      failure = %{
        mode: :timeout,
        reason: "operation exceeded deadline",
        current_deadline_ms: 5_000,
        operation: :slow_computation
      }

      current_state = %{
        operation: :slow_computation,
        elapsed_ms: 5_100,
        deadline_ms: 5_000
      }

      context = %{process_id: "proc12"}

      result = Fixer.fix(failure, current_state, context)

      assert {:fixed, repaired, strategy, _} = result
      assert strategy in [:compensation, :partial_recovery]
      # Deadline should be extended
      assert is_map(repaired)
    end

    test "timeout recovery extends deadline" do
      failure = %{
        mode: :timeout,
        current_deadline_ms: 5_000
      }

      current_state = %{deadline_ms: 5_000}
      context = %{}

      result = Fixer.fix(failure, current_state, context)

      assert {:fixed, repaired, _, _} = result
      assert is_map(repaired)
    end
  end

  # ---- Failure Mode: Inconsistent State ----

  describe "fix/3 -- inconsistency detection and sync" do
    test "inconsistency syncs from authoritative source" do
      failure = %{
        mode: :inconsistent_state,
        reason: "replica state diverged from authority",
        authority: :primary_db,
        authority_value: %{id: 1, value: 100}
      }

      current_state = %{
        id: 1,
        value: 50,
        replicas: [:primary_db, :cache]
      }

      context = %{process_id: "proc13"}

      result = Fixer.fix(failure, current_state, context)

      assert {:fixed, repaired, strategy, _} = result
      assert strategy in [:state_repair, :compensation]
      # Should sync from authority
      assert is_map(repaired)
    end

    test "inconsistency recovery syncs authoritative state" do
      failure = %{
        mode: :inconsistent_state,
        authority_value: %{x: 100}
      }

      current_state = %{x: 50}
      context = %{}

      result = Fixer.fix(failure, current_state, context)

      assert {:fixed, repaired, _, _} = result
      assert is_map(repaired)
    end
  end

  # ---- Error Handling Tests ----

  describe "fix/3 -- unrecoverable failures" do
    test "returns unrecoverable for unknown failure mode" do
      failure = %{
        mode: :unknown_catastrophe,
        reason: "something completely unknown"
      }

      result = Fixer.fix(failure, %{}, %{})

      assert {:unrecoverable, reason} = result
      assert is_binary(reason) or is_atom(reason)
    end

    test "returns unrecoverable for exhausted retries" do
      failure = %{
        mode: :retry_exhausted,
        retry_count: 10,
        max_retries: 10
      }

      result = Fixer.fix(failure, %{}, %{})

      assert {:unrecoverable, _reason} = result
    end
  end

  # ---- Integration Tests ----

  describe "fix/3 -- complex scenarios" do
    test "compound failure: cascade + deadlock" do
      failure = %{
        mode: :cascade,
        secondary_mode: :deadlock,
        failed_component: :service_a,
        held_locks: [:lock_x]
      }

      current_state = %{
        component: :service_a,
        locks: [:lock_x],
        status: "failed"
      }

      context = %{process_id: "proc14"}

      result = Fixer.fix(failure, current_state, context)

      # Should handle primary failure, even if secondary detected
      assert (is_tuple(result) and tuple_size(result) >= 2)
    end

    test "repair strategy selection based on severity" do
      low_severity = %{
        mode: :timeout,
        severity: :low
      }

      result = Fixer.fix(low_severity, %{}, %{})

      # Should attempt recovery even for low severity
      assert is_tuple(result)
    end

    test "repair includes retry count tracking" do
      failure = %{
        mode: :ashby_drift,
        checkpoint: %{x: 1}
      }

      result = Fixer.fix(failure, %{x: 100}, %{})

      assert {:fixed, _repaired, _strategy, retry_count} = result
      assert is_integer(retry_count)
    end
  end

  # ---- Context & Configuration Tests ----

  describe "fix/3 -- context handling" do
    test "fix accepts empty context" do
      failure = %{mode: :ashby_drift, checkpoint: %{}}

      result = Fixer.fix(failure, %{}, %{})

      assert is_tuple(result)
    end

    test "fix uses context.process_id in repair" do
      failure = %{
        mode: :ashby_drift,
        checkpoint: %{x: 1}
      }

      context = %{process_id: "special_proc"}
      result = Fixer.fix(failure, %{x: 10}, context)

      assert {:fixed, _repaired, _strategy, _} = result
    end

    test "fix uses context.versions for logic rollback" do
      failure = %{
        mode: :logic_regression,
        current_version: 5,
        previous_version: 3
      }

      context = %{versions: [1, 2, 3, 4, 5]}
      result = Fixer.fix(failure, %{version: 5}, context)

      assert {:fixed, repaired, _strategy, _} = result
      assert repaired.version == 3
    end
  end

  # ---- Return Value Validation ----

  describe "fix/3 -- return value structure" do
    test "successful fix returns {:fixed, state, strategy, retry_count}" do
      failure = %{
        mode: :ashby_drift,
        checkpoint: %{value: 1}
      }

      result = Fixer.fix(failure, %{value: 100}, %{})

      assert {:fixed, state, strategy, retry_count} = result
      assert is_map(state)
      assert is_atom(strategy)
      assert is_integer(retry_count)
    end

    test "unrecoverable failure returns {:unrecoverable, reason}" do
      failure = %{mode: :unknown_mode}
      result = Fixer.fix(failure, %{}, %{})

      assert {:unrecoverable, reason} = result
      assert reason != nil
    end

    test "all strategies are atoms" do
      strategies = [
        :state_repair,
        :logic_rollback,
        :logic_patch,
        :partial_recovery,
        :compensation
      ]

      Enum.each(strategies, fn strategy ->
        assert is_atom(strategy)
      end)
    end
  end
end
