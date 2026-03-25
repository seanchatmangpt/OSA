defmodule OptimalSystemAgent.Verification.SoundnessCheckerTest do
  use ExUnit.Case

  alias OptimalSystemAgent.Verification.SoundnessChecker

  @moduledoc """
  Comprehensive Soundness Verification Tests

  Tests all four WvdA soundness properties:
  1. **Soundness (no deadlock):** No execution reaches indefinite blocking
  2. **Completeness:** All states reachable from source to sink
  3. **Fitness:** Model matches observed event logs
  4. **Precision:** Model doesn't over-generalize

  Each test verifies one critical property of the Vision 2030 system.
  """

  # ═══════════════════════════════════════════════════════════════════════════════
  # TEST 1: Soundness Verified on Simple Pipeline
  # ═══════════════════════════════════════════════════════════════════════════════

  describe "soundness verification" do
    test "test_soundness_verified_on_simple_pipeline" do
      # Simple pipeline: start → process → done
      sm = {
        :simple_pipeline,
        [:start, :process, :done],
        [
          {:start, :process},
          {:process, :done}
        ]
      }

      assert {:sound, proofs} = SoundnessChecker.verify_tree(sm)
      assert Enum.count(proofs) >= 3
      assert Enum.any?(proofs, &String.contains?(&1, "No deadlock"))
    end

    # ═══════════════════════════════════════════════════════════════════════════════
    # TEST 2: Deadlock Detected on Cyclic State
    # ═══════════════════════════════════════════════════════════════════════════════

    test "test_deadlock_detected_on_cyclic_state" do
      # Problematic: dead-end state with no outgoing transitions
      sm = {
        :cyclic_with_deadlock,
        [:start, :middle, :blocked, :done],
        [
          {:start, :middle},
          {:middle, :blocked},
          # {:blocked, ???}  -- No outgoing transition!
          {:middle, :done}
        ]
      }

      assert {:unsound, gaps} = SoundnessChecker.verify_tree(sm)
      # Either deadlock or completeness violation is acceptable
      assert Enum.any?(gaps, &String.contains?(&1, "deadlock"))
        or Enum.any?(gaps, &String.contains?(&1, "Completeness"))
    end

    # ═══════════════════════════════════════════════════════════════════════════════
    # TEST 3: Completeness Verified (All Paths Reachable)
    # ═══════════════════════════════════════════════════════════════════════════════

    test "test_completeness_verified_all_paths_reachable" do
      # All states on path from source to sink
      sm = {
        :complete_flow,
        [:initial, :validate, :process, :finalize],
        [
          {:initial, :validate},
          {:validate, :process},
          {:process, :finalize}
        ]
      }

      assert {:sound, proofs} = SoundnessChecker.verify_tree(sm)
      assert Enum.any?(proofs, &String.contains?(&1, "Completeness"))
    end

    # ═══════════════════════════════════════════════════════════════════════════════
    # TEST 4: Fitness Scored Against Event Log
    # ═══════════════════════════════════════════════════════════════════════════════

    test "test_fitness_scored_against_event_log" do
      # Model allows: A → B → C, A → C, B → C
      sm = {
        :branching_process,
        [:A, :B, :C],
        [
          {:A, :B},
          {:A, :C},
          {:B, :C}
        ]
      }

      # Observed log: A → B → C
      event_log = ["A", "B", "C"]

      fitness = SoundnessChecker.check_fitness(event_log, sm)

      # Both transitions A→B and B→C in model → fitness should be high
      assert fitness >= 0.5
    end

    # ═══════════════════════════════════════════════════════════════════════════════
    # TEST 5: Precision Checked (No Over-generalization)
    # ═══════════════════════════════════════════════════════════════════════════════

    test "test_precision_checked_no_overgeneralization" do
      # Model with minimal transitions (tight fit)
      sm = {
        :precise_model,
        [:A, :B, :C],
        [
          {:A, :B},
          {:B, :C}
        ]
      }

      # Observed log: A → B → C
      event_log = ["A", "B", "C"]

      precision = SoundnessChecker.check_precision(event_log, sm)

      # All model transitions observed → high precision
      assert precision >= 0.8
    end

    # ═══════════════════════════════════════════════════════════════════════════════
    # TEST 6: Supervision Tree Soundness Verified
    # ═══════════════════════════════════════════════════════════════════════════════

    test "test_supervision_tree_soundness_verified" do
      # Simulate a supervision tree structure
      # (In real code, this would fetch from DynamicSupervisor)
      sm = {
        :supervision_tree,
        [:root, :child_1, :child_2, :grandchild, :done],
        [
          {:root, :child_1},
          {:root, :child_2},
          {:child_1, :grandchild},
          {:child_2, :grandchild},
          {:grandchild, :done}
        ]
      }

      assert {:sound, _proofs} = SoundnessChecker.verify_tree(sm)
    end

    # ═══════════════════════════════════════════════════════════════════════════════
    # TEST 7: Timeout Behavior Prevents Deadlock
    # ═══════════════════════════════════════════════════════════════════════════════

    test "test_timeout_behavior_prevents_deadlock" do
      # Stagnation detector: normal → waiting → timeout → recovery
      sm = {
        :stagnation_with_timeout,
        [:monitoring, :stagnation_detected, :waiting, :timeout_fired, :recovery, :done],
        [
          {:monitoring, :stagnation_detected},
          {:stagnation_detected, :waiting},
          {:waiting, :timeout_fired},  # 5-second timeout transition
          {:timeout_fired, :recovery},
          {:recovery, :done},
          # Fallback: if timeout fires, always progress
          {:waiting, :done}  # Alternative path if no timeout
        ]
      }

      risk = SoundnessChecker.analyze_deadlock_potential(sm)

      # Should have low deadlock risk (timeout prevents indefinite waiting)
      assert risk < 0.3
    end

    # ═══════════════════════════════════════════════════════════════════════════════
    # TEST 8: Concurrent Agents Quorum Sound
    # ═══════════════════════════════════════════════════════════════════════════════

    test "test_concurrent_agents_quorum_sound" do
      # Byzantine consensus: propose → prevote → precommit → commit → finalized
      # Simpler model: just core happy path
      sm = {
        :byzantine_consensus,
        [
          :propose,
          :prevote,
          :precommit,
          :finalized
        ],
        [
          {:propose, :prevote},
          {:prevote, :precommit},
          {:precommit, :finalized}
        ]
      }

      # All paths should reach finalized (no deadlock)
      assert {:sound, proofs} = SoundnessChecker.verify_tree(sm)
      assert Enum.count(proofs) >= 1
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════════
  # DEADLOCK RISK ANALYSIS TESTS
  # ═══════════════════════════════════════════════════════════════════════════════

  describe "deadlock risk analysis" do
    test "low deadlock risk on simple chain" do
      sm = {
        :chain,
        [:a, :b, :c],
        [
          {:a, :b},
          {:b, :c}
        ]
      }

      risk = SoundnessChecker.analyze_deadlock_potential(sm)
      assert risk <= 0.5
    end

    test "high deadlock risk with self-loops" do
      sm = {
        :with_self_loops,
        [:a, :b, :c],
        [
          {:a, :b},
          {:b, :b},  # Self-loop
          {:b, :c}
        ]
      }

      risk = SoundnessChecker.analyze_deadlock_potential(sm)
      # Self-loops increase risk
      assert risk >= 0.3
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════════
  # FITNESS AND PRECISION TESTS
  # ═══════════════════════════════════════════════════════════════════════════════

  describe "fitness and precision metrics" do
    test "perfect fitness on exact match" do
      sm = {
        :model,
        [:A, :B, :C],
        [
          {:A, :B},
          {:B, :C}
        ]
      }

      fitness = SoundnessChecker.check_fitness(["A", "B", "C"], sm)
      assert fitness == 1.0
    end

    test "zero fitness on completely different log" do
      sm = {
        :model,
        [:X, :Y, :Z],
        [
          {:X, :Y},
          {:Y, :Z}
        ]
      }

      fitness = SoundnessChecker.check_fitness(["A", "B", "C"], sm)
      assert fitness == 0.0
    end

    test "high precision on minimal model" do
      sm = {
        :minimal,
        [:A, :B],
        [
          {:A, :B}
        ]
      }

      precision = SoundnessChecker.check_precision(["A", "B"], sm)
      # Only one transition, all observed → high precision
      assert precision >= 0.8
    end

    test "low precision on over-generalized model" do
      sm = {
        :over_general,
        [:A, :B, :C, :D],
        [
          {:A, :B},
          {:A, :C},
          {:A, :D},
          {:B, :C},
          {:B, :D},
          {:C, :D}
        ]
      }

      # Log only observes A → B
      precision = SoundnessChecker.check_precision(["A", "B"], sm)
      # Many unobserved transitions → low precision
      assert precision < 0.5
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════════
  # INTEGRATION: REAL-WORLD SCENARIOS
  # ═══════════════════════════════════════════════════════════════════════════════

  describe "real-world scenarios" do
    test "invoice processing workflow (SAP-like)" do
      sm = {
        :invoice_process,
        [:create, :validate, :approve, :pay, :archive],
        [
          {:create, :validate},
          {:validate, :approve},
          {:approve, :pay},
          {:pay, :archive}
        ]
      }

      assert {:sound, _} = SoundnessChecker.verify_tree(sm)
      fitness = SoundnessChecker.check_fitness(["create", "validate", "approve", "pay", "archive"], sm)
      assert fitness == 1.0
    end

    test "parallel branches with join" do
      sm = {
        :parallel_join,
        [:start, :branch_a, :branch_b, :join, :done],
        [
          {:start, :branch_a},
          {:start, :branch_b},
          {:branch_a, :join},
          {:branch_b, :join},
          {:join, :done}
        ]
      }

      assert {:sound, _} = SoundnessChecker.verify_tree(sm)
    end

    test "optional activity (xor split)" do
      sm = {
        :optional_activity,
        [:init, :optional, :final],
        [
          {:init, :optional},
          {:init, :final},
          {:optional, :final}
        ]
      }

      assert {:sound, _} = SoundnessChecker.verify_tree(sm)
    end
  end
end
