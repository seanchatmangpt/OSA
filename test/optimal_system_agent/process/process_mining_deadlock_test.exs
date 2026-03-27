defmodule OptimalSystemAgent.Process.ProcessMiningDeadlockTest do
  @moduledoc """
  Regression tests for GenServer deadlock in stagnation detection.

  Tests the scenario where velocity < 0.1 AND span_weeks < 2 causes
  a deadlock in condition evaluation. The fix wraps the condition check
  in Task.async/Task.yield with a 5-second timeout.
  """
  use ExUnit.Case, async: false


  alias OptimalSystemAgent.Process.ProcessMining

  @unique_prefix "deadlock-test-#{:erlang.unique_integer([:positive])}-"

  describe "stagnation_detect deadlock regression" do
    test "stagnation_detect does not deadlock on low velocity plus short duration" do
      # Scenario: velocity < 0.1 AND span_weeks < 2
      # This should complete within 5 seconds without hanging
      proc = @unique_prefix <> "low-velocity-short-span"

      # Record 3 snapshots with minimal changes over short time period
      # to trigger velocity < 0.1 AND span_weeks < 2 condition
      for _i <- 1..3 do
        ProcessMining.record_snapshot(proc, %{throughput: 10.0})
      end

      # This call should complete within 5 seconds
      start_time = System.monotonic_time(:millisecond)

      result = ProcessMining.stagnation_detect(proc)

      elapsed = System.monotonic_time(:millisecond) - start_time

      # Verify it completed quickly (within 5 seconds)
      assert elapsed < 5000, "stagnation_detect took #{elapsed}ms, expected < 5000ms"

      # Verify the result structure is correct
      assert Map.has_key?(result, :is_stagnant)
      assert Map.has_key?(result, :stagnation_score)
      assert Map.has_key?(result, :recommended_action)
      assert is_boolean(result.is_stagnant)
      assert is_number(result.stagnation_score)
    end

    test "stagnation_detect with timeout returns fallback state" do
      # Test that even with pathological data, we get a response
      proc = @unique_prefix <> "fallback-state"

      # Record single snapshot with extreme values
      ProcessMining.record_snapshot(proc, %{
        throughput: 1.0e308,
        error_rate: 1.0e-308,
        success_rate: 0.5
      })

      start_time = System.monotonic_time(:millisecond)

      result = ProcessMining.stagnation_detect(proc)

      elapsed = System.monotonic_time(:millisecond) - start_time

      # Should still complete quickly
      assert elapsed < 5000, "stagnation_detect took #{elapsed}ms with extreme values"

      # Verify we get a valid result, even if data is insufficient
      assert is_map(result)
      assert Map.has_key?(result, :stagnation_score)
    end

    test "stagnation_detect returns expected signal structure" do
      # Verify output format and structure matches expectations
      proc = @unique_prefix <> "signal-structure"

      # Create data that has low velocity over short span
      for i <- 1..3 do
        ProcessMining.record_snapshot(proc, %{throughput: 10.0 + i * 0.01})
      end

      result = ProcessMining.stagnation_detect(proc)

      # Verify all expected fields exist
      assert Map.has_key?(result, :is_stagnant), "Missing :is_stagnant field"
      assert Map.has_key?(result, :stagnation_score), "Missing :stagnation_score field"
      assert Map.has_key?(result, :last_improvement), "Missing :last_improvement field"
      assert Map.has_key?(result, :recommended_action), "Missing :recommended_action field"

      # Verify field types
      assert is_boolean(result.is_stagnant), ":is_stagnant should be boolean"
      assert is_number(result.stagnation_score), ":stagnation_score should be number"
      assert is_binary(result.recommended_action), ":recommended_action should be string"

      # Verify stagnation_score is in valid range [0.0, 1.0]
      assert result.stagnation_score >= 0.0 and result.stagnation_score <= 1.0,
             "stagnation_score #{result.stagnation_score} outside [0.0, 1.0]"
    end

    test "stagnation_detect with zero velocity returns high stagnation score" do
      # Scenario: identical snapshots = zero velocity
      proc = @unique_prefix <> "zero-velocity"

      for _i <- 1..3 do
        ProcessMining.record_snapshot(proc, %{throughput: 10.0})
      end

      result = ProcessMining.stagnation_detect(proc)

      # Zero velocity should result in high stagnation score
      assert result.stagnation_score >= 0.5,
             "Expected high stagnation_score for zero velocity, got #{result.stagnation_score}"
    end

    test "stagnation_detect completes with minimal data" do
      # Edge case: exactly 3 snapshots (minimum for non-insufficient-data response)
      proc = @unique_prefix <> "minimal-data"

      ProcessMining.record_snapshot(proc, %{throughput: 10.0})
      ProcessMining.record_snapshot(proc, %{throughput: 10.5})
      ProcessMining.record_snapshot(proc, %{throughput: 11.0})

      start_time = System.monotonic_time(:millisecond)

      result = ProcessMining.stagnation_detect(proc)

      elapsed = System.monotonic_time(:millisecond) - start_time

      assert elapsed < 5000, "stagnation_detect with minimal data took #{elapsed}ms"
      assert is_map(result)
      assert result.stagnation_score >= 0.0 and result.stagnation_score <= 1.0
    end
  end
end
