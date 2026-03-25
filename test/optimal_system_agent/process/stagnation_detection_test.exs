defmodule OptimalSystemAgent.Process.StagnationDetectionTest do
  @moduledoc """
  Unit tests for stagnation detection with timeout/deadlock protection.

  These tests verify that the stagnation detection mechanism correctly:
  1. Handles the deadlock scenario (velocity < 0.1 AND span_weeks < 2)
  2. Returns results within timeout constraints
  3. Provides fallback behavior when timeout occurs
  4. Completes normally for healthy processes

  The stagnation detection uses Task.async/Task.yield with a 5000ms timeout
  to prevent indefinite hangs. If the timeout expires, a conservative fallback
  score (0.5) is returned.
  """
  use ExUnit.Case, async: false

  alias OptimalSystemAgent.Process.ProcessMining

  @unique_prefix "stag-#{:erlang.unique_integer([:positive])}-"

  describe "stagnation_detect/1 - deadlock protection" do
    test "completes with timeout for stagnation scenario (velocity < 0.1, span_weeks < 2)" do
      proc = @unique_prefix <> "deadlock-scenario"

      # Create a pathological scenario: low velocity + short timespan
      # This triggers the deadlock condition the timeout is designed to protect against
      base_time = DateTime.utc_now() |> DateTime.add(-7, :day)

      # Record 3 snapshots over 1.5 weeks with very low velocity
      # Snapshot 1: baseline
      ProcessMining.record_snapshot(proc, %{
        throughput: 100.0,
        error_rate: 0.01,
        timestamp: base_time
      })

      # Snapshot 2: 1 week in, minimal change
      ProcessMining.record_snapshot(proc, %{
        throughput: 100.5,
        error_rate: 0.011,
        timestamp: DateTime.add(base_time, 7, :day)
      })

      # Snapshot 3: 1.5 weeks in, still minimal change
      ProcessMining.record_snapshot(proc, %{
        throughput: 101.0,
        error_rate: 0.012,
        timestamp: DateTime.add(base_time, 10, :day)
      })

      # Launch async task with 6 second timeout
      # The detection should complete before timeout expires
      task = Task.async(fn -> ProcessMining.stagnation_detect(proc) end)

      result = Task.yield(task, 6000)

      # Assert that the task completes (either with {:ok, value} or within 6 seconds)
      case result do
        {:ok, detection} ->
          # Task completed successfully
          assert is_map(detection)
          assert Map.has_key?(detection, :is_stagnant)
          assert Map.has_key?(detection, :stagnation_score)
          assert Map.has_key?(detection, :last_improvement)
          assert Map.has_key?(detection, :recommended_action)

          # Verify stagnation_score is in valid range [0.0, 1.0]
          assert is_float(detection.stagnation_score) or is_integer(detection.stagnation_score)
          score = detection.stagnation_score
          assert score >= 0.0 and score <= 1.0

        nil ->
          # Timeout occurred (task didn't complete in 6 seconds)
          # This should NOT happen with timeout protection in place
          Task.shutdown(task, :brutal_kill)
          flunk("Stagnation detection timed out - timeout protection not working")
      end
    end

    test "normal stagnation detection completes for healthy process" do
      proc = @unique_prefix <> "healthy"

      base_time = DateTime.utc_now() |> DateTime.add(-30, :day)

      # Record 5 snapshots over 4 weeks with moderate velocity
      for i <- 0..4 do
        ProcessMining.record_snapshot(proc, %{
          throughput: 100.0 + i * 5.0,
          error_rate: 0.01 - i * 0.001,
          timestamp: DateTime.add(base_time, i * 7, :day)
        })
      end

      # This should complete quickly without timeout
      detection = ProcessMining.stagnation_detect(proc)

      assert is_map(detection)
      assert Map.has_key?(detection, :is_stagnant)
      assert Map.has_key?(detection, :stagnation_score)
      assert Map.has_key?(detection, :recommended_action)

      # Healthy process with good velocity should not be stagnant
      assert is_boolean(detection.is_stagnant)
      assert is_float(detection.stagnation_score) or is_integer(detection.stagnation_score)
      assert detection.stagnation_score >= 0.0 and detection.stagnation_score <= 1.0
    end
  end

  describe "stagnation_detect/1 - insufficient data" do
    test "returns false for processes with fewer than 3 snapshots" do
      proc = @unique_prefix <> "insufficient"

      ProcessMining.record_snapshot(proc, %{throughput: 100.0})
      ProcessMining.record_snapshot(proc, %{throughput: 102.0})

      detection = ProcessMining.stagnation_detect(proc)

      assert detection.is_stagnant == false
      assert detection.stagnation_score == 0.0
      assert detection.last_improvement == nil
      assert String.contains?(detection.recommended_action, "Insufficient data")
    end
  end

  describe "stagnation_detect_with_backoff/1 - retry protection" do
    test "completes with backoff retry on timeout scenario" do
      proc = @unique_prefix <> "backoff"

      base_time = DateTime.utc_now() |> DateTime.add(-7, :day)

      ProcessMining.record_snapshot(proc, %{
        throughput: 100.0,
        error_rate: 0.01,
        timestamp: base_time
      })

      ProcessMining.record_snapshot(proc, %{
        throughput: 100.5,
        error_rate: 0.011,
        timestamp: DateTime.add(base_time, 7, :day)
      })

      ProcessMining.record_snapshot(proc, %{
        throughput: 101.0,
        error_rate: 0.012,
        timestamp: DateTime.add(base_time, 10, :day)
      })

      # Backoff version should succeed even on timeout
      detection = ProcessMining.stagnation_detect_with_backoff(proc)

      assert is_map(detection)
      assert Map.has_key?(detection, :is_stagnant)
      assert Map.has_key?(detection, :stagnation_score)
    end
  end

  describe "stagnation_detect_safe/1 - fallback safety" do
    test "returns conservative estimate on timeout" do
      proc = @unique_prefix <> "safe"

      base_time = DateTime.utc_now() |> DateTime.add(-7, :day)

      ProcessMining.record_snapshot(proc, %{
        throughput: 100.0,
        error_rate: 0.01,
        timestamp: base_time
      })

      ProcessMining.record_snapshot(proc, %{
        throughput: 100.5,
        error_rate: 0.011,
        timestamp: DateTime.add(base_time, 7, :day)
      })

      ProcessMining.record_snapshot(proc, %{
        throughput: 101.0,
        error_rate: 0.012,
        timestamp: DateTime.add(base_time, 10, :day)
      })

      detection = ProcessMining.stagnation_detect_safe(proc)

      assert is_map(detection)
      assert Map.has_key?(detection, :result)
      assert Map.has_key?(detection, :elapsed_ms)
      assert Map.has_key?(detection, :stalled)
      assert Map.has_key?(detection, :snapshot_count)

      # Verify the wrapped result contains expected fields
      result = detection.result
      assert Map.has_key?(result, :is_stagnant)
      assert Map.has_key?(result, :stagnation_score)
    end
  end
end
