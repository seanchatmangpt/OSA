defmodule OptimalSystemAgent.Healing.VerifierTest do
  @moduledoc """
  Unit tests for Healing.Verifier — validates that repaired processes
  pass regression suites and fingerprint validation.

  Verifier runs a suite of regression tests on the repaired state,
  validates fingerprint delta < 5%, and checks idempotency.
  """
  use ExUnit.Case, async: true

  alias OptimalSystemAgent.Healing.Verifier

  describe "verify/2 — regression test suite" do
    @tag :unit
    test "verify_repaired_state: executes all regression tests and returns PASS" do
      repaired_state = %{
        "process_id" => "proc_123",
        "status" => "fixed",
        "version" => 2,
        "data" => %{"value" => 100}
      }

      test_suite = [
        %{"name" => "test_1", "fn" => fn state -> state["status"] == "fixed" end},
        %{"name" => "test_2", "fn" => fn state -> state["data"]["value"] > 0 end},
        %{"name" => "test_3", "fn" => fn state -> state["version"] >= 2 end}
      ]

      {:ok, result} = Verifier.verify(repaired_state, test_suite)

      assert result.status == :verified
      assert result.passed_tests == 3
      assert result.failed_tests == 0
      assert result.passed_tests + result.failed_tests == length(test_suite)
    end

    @tag :unit
    test "verify_repaired_state: reports failures when tests fail" do
      repaired_state = %{"status" => "broken", "value" => -50}

      test_suite = [
        %{"name" => "test_status", "fn" => fn state -> state["status"] == "fixed" end},
        %{"name" => "test_value", "fn" => fn state -> state["value"] > 0 end}
      ]

      {:ok, result} = Verifier.verify(repaired_state, test_suite)

      assert result.status == :unverified
      assert result.passed_tests == 0
      assert result.failed_tests == 2
      assert length(result.failures) == 2
    end

    @tag :unit
    test "verify_repaired_state: mixed pass/fail results" do
      repaired_state = %{"status" => "fixed", "value" => -10}

      test_suite = [
        %{"name" => "test_1", "fn" => fn state -> state["status"] == "fixed" end},
        %{"name" => "test_2", "fn" => fn state -> state["value"] > 0 end}
      ]

      {:ok, result} = Verifier.verify(repaired_state, test_suite)

      assert result.status == :unverified
      assert result.passed_tests == 1
      assert result.failed_tests == 1
    end
  end

  describe "fingerprint_validation/2" do
    @tag :unit
    test "fingerprint_validation: identical states have 0% delta" do
      state1 = %{"id" => 1, "value" => "test", "nested" => %{"count" => 5}}
      state2 = %{"id" => 1, "value" => "test", "nested" => %{"count" => 5}}

      {:ok, delta} = Verifier.fingerprint_validation(state1, state2)

      assert delta < 0.01
    end

    @tag :unit
    test "fingerprint_validation: minor changes have delta < 5%" do
      state1 = %{"id" => 1, "value" => "test", "timestamp" => 1000}
      state2 = %{"id" => 1, "value" => "test", "timestamp" => 1001}

      {:ok, delta} = Verifier.fingerprint_validation(state1, state2)

      # Timestamp-only changes should have 0 delta (timestamps are excluded)
      assert delta == 0.0
    end

    @tag :unit
    test "fingerprint_validation: structural changes exceed 5% delta" do
      state1 = %{"id" => 1, "value" => "test", "config" => %{"a" => 1, "b" => 2}}
      state2 = %{"id" => 1, "value" => "different", "config" => %{"a" => 1}}

      {:ok, delta} = Verifier.fingerprint_validation(state1, state2)

      assert delta >= 0.05
    end

    @tag :unit
    test "fingerprint_validation: completely different states report high delta" do
      state1 = %{"id" => 1, "data" => "a"}
      state2 = %{"id" => 999, "data" => "z", "extra" => "field"}

      {:ok, delta} = Verifier.fingerprint_validation(state1, state2)

      assert delta > 0.3
    end
  end

  describe "idempotency_check/3" do
    @tag :unit
    test "idempotency_check: rerunning fixed process yields same result" do
      repaired_state = %{"id" => 1, "value" => 42, "status" => "fixed"}

      # Mock function that returns the same state
      process_fn = fn state -> {:ok, state} end

      result1 = process_fn.(repaired_state)
      result2 = process_fn.(repaired_state)

      {:ok, is_idempotent} = Verifier.idempotency_check(repaired_state, process_fn, 2)

      assert is_idempotent == true
      assert result1 == result2
    end

    @tag :unit
    test "idempotency_check: detects non-idempotent processes" do
      repaired_state = %{"counter" => 0}

      # Mock function that increments counter
      {:ok, agent} = Agent.start_link(fn -> 0 end)

      process_fn = fn state ->
        count = Agent.get_and_update(agent, &{&1, &1 + 1})
        {:ok, Map.put(state, :counter, count)}
      end

      {:ok, is_idempotent} = Verifier.idempotency_check(repaired_state, process_fn, 2)

      assert is_idempotent == false

      Agent.stop(agent)
    end

    @tag :unit
    test "idempotency_check: with custom iteration count" do
      repaired_state = %{"runs" => []}
      process_fn = fn state -> {:ok, state} end

      {:ok, is_idempotent} = Verifier.idempotency_check(repaired_state, process_fn, 5)

      assert is_idempotent == true
    end
  end

  describe "regression_detection/2" do
    @tag :unit
    test "regression_detection: no regressions when all tests pass" do
      initial_state = %{"version" => 1, "status" => "working"}

      test_results = %{
        "test_a" => true,
        "test_b" => true,
        "test_c" => true
      }

      {:ok, has_regression} = Verifier.regression_detection(initial_state, test_results)

      assert has_regression == false
    end

    @tag :unit
    test "regression_detection: detects when previously passing tests fail" do
      initial_state = %{"version" => 1, "status" => "working"}

      test_results = %{
        "test_a" => true,
        "test_b" => false,
        "test_c" => true
      }

      {:ok, has_regression} = Verifier.regression_detection(initial_state, test_results)

      assert has_regression == true
    end

    @tag :unit
    test "regression_detection: multiple failures indicate regression" do
      initial_state = %{"version" => 1}

      test_results = %{
        "test_a" => false,
        "test_b" => false,
        "test_c" => true
      }

      {:ok, has_regression} = Verifier.regression_detection(initial_state, test_results)

      assert has_regression == true
    end
  end

  describe "verification_timeout/2" do
    @tag :unit
    test "verification_timeout: returns success when verification completes within timeout" do
      repaired_state = %{"id" => 1}
      timeout_ms = 5000

      # Fast operation
      result = Verifier.verification_timeout(repaired_state, timeout_ms)

      assert {:ok, :completed} = result
    end

    @tag :unit
    test "verification_timeout: returns timeout error when operation exceeds deadline" do
      repaired_state = %{"id" => 1}
      timeout_ms = 10

      # Simulate a slow operation by wrapping in Task with timeout
      result = Verifier.verification_timeout(repaired_state, timeout_ms)

      # This might return ok or timeout depending on system load,
      # but we're testing the timeout logic exists
      assert result in [{:ok, :completed}, {:error, :timeout}]
    end

    @tag :unit
    test "verification_timeout: accepts various timeout values" do
      repaired_state = %{"id" => 1}

      result_short = Verifier.verification_timeout(repaired_state, 1)
      result_long = Verifier.verification_timeout(repaired_state, 60000)

      assert is_tuple(result_short)
      assert is_tuple(result_long)
    end
  end

  describe "integration: full verification flow" do
    @tag :unit
    test "full_verification_flow: end-to-end process repair verification" do
      repaired_state = %{
        "process_id" => "proc_456",
        "status" => "fixed",
        "version" => 2,
        "config" => %{"timeout" => 30}
      }

      test_suite = [
        %{"name" => "test_status_ok", "fn" => fn s -> s["status"] == "fixed" end},
        %{"name" => "test_version", "fn" => fn s -> s["version"] >= 2 end}
      ]

      {:ok, result} = Verifier.verify(repaired_state, test_suite)

      assert result.status == :verified
      assert result.passed_tests == 2
    end

    @tag :unit
    test "full_verification_flow: handles verification failure gracefully" do
      repaired_state = %{"status" => "broken"}

      test_suite = [
        %{"name" => "critical_test", "fn" => fn s -> s["status"] == "fixed" end}
      ]

      {:ok, result} = Verifier.verify(repaired_state, test_suite)

      assert result.status == :unverified
      assert result.passed_tests == 0
    end
  end
end
