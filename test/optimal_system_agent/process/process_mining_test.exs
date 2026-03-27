defmodule OptimalSystemAgent.Process.ProcessMiningTest do
  @moduledoc """
  Unit tests for Temporal Process Mining (Innovation 7).

  These tests work with the ProcessMining GenServer that's already running
  as part of the OSA supervision tree. They use unique process IDs to avoid
  collisions with other test runs.
  """
  use ExUnit.Case, async: false


  alias OptimalSystemAgent.Process.ProcessMining

  @unique_prefix "test-#{:erlang.unique_integer([:positive])}-"

  describe "record_snapshot/2" do
    test "stores a snapshot and returns :ok" do
      proc = @unique_prefix <> "record"
      assert :ok = ProcessMining.record_snapshot(proc, %{throughput: 10.0})
    end
  end

  describe "process_velocity/1" do
    test "returns stable trend for a single data point" do
      proc = @unique_prefix <> "vel"
      ProcessMining.record_snapshot(proc, %{throughput: 10.0})

      vel = ProcessMining.process_velocity(proc)
      assert vel.data_points == 1
      assert vel.trend == :stable
    end

    test "computes velocity with enough data points" do
      proc = @unique_prefix <> "trend"
      for i <- 1..5 do
        ProcessMining.record_snapshot(proc, %{throughput: 10.0 * i})
      end

      vel = ProcessMining.process_velocity(proc)
      assert vel.data_points == 5
      assert vel.overall_velocity > 0.0
    end
  end

  describe "predict_state/2" do
    test "returns prediction map for seeded process" do
      proc = @unique_prefix <> "pred"
      for i <- 1..5 do
        ProcessMining.record_snapshot(proc, %{throughput: 10.0 + i, error_rate: 0.01})
      end

      pred = ProcessMining.predict_state(proc, 2)
      assert Map.has_key?(pred, :metrics)
      assert Map.has_key?(pred, :confidence)
      assert Map.has_key?(pred, :method)
    end

    test "returns insufficient_data for too few snapshots" do
      proc = @unique_prefix <> "pred-few"
      ProcessMining.record_snapshot(proc, %{throughput: 10.0})

      pred = ProcessMining.predict_state(proc, 2)
      assert pred.method == :insufficient_data
    end
  end

  describe "early_warning/1" do
    test "returns warnings map for seeded process" do
      proc = @unique_prefix <> "warn"
      for _ <- 1..3 do
        ProcessMining.record_snapshot(proc, %{throughput: 10.0, error_rate: 0.01})
      end

      result = ProcessMining.early_warning(proc)
      assert Map.has_key?(result, :warnings)
      assert Map.has_key?(result, :health_score)
      # Fewer than 5 data points returns empty warnings
      assert is_list(result.warnings)
    end

    test "returns warnings with enough data" do
      proc = @unique_prefix <> "warn-many"
      for i <- 1..7 do
        ProcessMining.record_snapshot(proc, %{throughput: 10.0 + i * 0.5, error_rate: 0.01 * i})
      end

      result = ProcessMining.early_warning(proc)
      assert result.data_points == 7
      assert is_list(result.warnings)
    end
  end

  describe "stagnation_detect/1" do
    test "returns result with stagnation fields" do
      proc = @unique_prefix <> "stag"
      for i <- 1..5 do
        ProcessMining.record_snapshot(proc, %{throughput: 10.0 + i * 2})
      end

      result = ProcessMining.stagnation_detect(proc)
      assert Map.has_key?(result, :stagnation_score)
      assert Map.has_key?(result, :is_stagnant)
      assert Map.has_key?(result, :recommended_action)
    end
  end

  # ── Edge Cases ───────────────────────────────────────────────────────────

  describe "edge cases: empty event logs" do
    test "process_velocity with no snapshots returns stable with zero data points" do
      proc = @unique_prefix <> "vel-empty"
      vel = ProcessMining.process_velocity(proc)
      assert vel.data_points == 0
      assert vel.trend == :stable
      assert vel.overall_velocity == 0.0
    end

    test "predict_state with no snapshots returns insufficient_data" do
      proc = @unique_prefix <> "pred-empty"
      pred = ProcessMining.predict_state(proc, 2)
      assert pred.method == :insufficient_data
      assert pred.confidence == 0.0
    end

    test "early_warning with no snapshots returns healthy" do
      proc = @unique_prefix <> "warn-empty"
      result = ProcessMining.early_warning(proc)
      assert result.health_score == 1.0
      assert result.risk_level == :healthy
      assert result.warnings == []
    end

    test "stagnation_detect with no snapshots returns not stagnant" do
      proc = @unique_prefix <> "stag-empty"
      result = ProcessMining.stagnation_detect(proc)
      assert result.is_stagnant == false
      assert result.stagnation_score == 0.0
    end

    test "optimal_intervention_window with no snapshots returns default window" do
      proc = @unique_prefix <> "int-empty"
      result = ProcessMining.optimal_intervention_window(proc)
      assert Map.has_key?(result, :recommended_window)
      assert result.risk_of_change == :unknown
    end
  end

  describe "edge cases: single event processing" do
    test "process_velocity with exactly 2 data points returns stable" do
      proc = @unique_prefix <> "vel-two"
      ProcessMining.record_snapshot(proc, %{throughput: 10.0})
      ProcessMining.record_snapshot(proc, %{throughput: 12.0})

      vel = ProcessMining.process_velocity(proc)
      assert vel.data_points == 2
      assert vel.trend == :stable
    end

    test "predict_state with exactly 2 data points returns insufficient_data" do
      proc = @unique_prefix <> "pred-two"
      ProcessMining.record_snapshot(proc, %{throughput: 10.0})
      ProcessMining.record_snapshot(proc, %{throughput: 12.0})

      pred = ProcessMining.predict_state(proc, 1)
      assert pred.method == :insufficient_data
    end

    test "early_warning with exactly 4 data points returns empty warnings" do
      proc = @unique_prefix <> "warn-four"
      for i <- 1..4 do
        ProcessMining.record_snapshot(proc, %{throughput: 10.0 + i})
      end

      result = ProcessMining.early_warning(proc)
      # Fewer than 5 data points returns empty warnings
      assert result.warnings == []
    end

    test "stagnation_detect with exactly 2 data points returns insufficient data message" do
      proc = @unique_prefix <> "stag-two"
      ProcessMining.record_snapshot(proc, %{throughput: 10.0})
      ProcessMining.record_snapshot(proc, %{throughput: 10.0})

      result = ProcessMining.stagnation_detect(proc)
      assert result.is_stagnant == false
      assert result.recommended_action =~ "Insufficient data"
    end
  end

  describe "edge cases: malformed event data" do
    test "record_snapshot with empty metrics map succeeds" do
      proc = @unique_prefix <> "empty-metrics"
      assert :ok = ProcessMining.record_snapshot(proc, %{})
      vel = ProcessMining.process_velocity(proc)
      assert vel.data_points == 1
    end

    test "record_snapshot with non-numeric metric values normalizes to 0.0" do
      proc = @unique_prefix <> "bad-metrics"
      assert :ok = ProcessMining.record_snapshot(proc, %{
        throughput: "not_a_number",
        error_rate: nil,
        success_rate: :atom
      })
      vel = ProcessMining.process_velocity(proc)
      assert vel.data_points == 1
    end

    test "record_snapshot with very large numeric values succeeds" do
      proc = @unique_prefix <> "large-metrics"
      assert :ok = ProcessMining.record_snapshot(proc, %{
        throughput: 9.99e99,
        error_rate: 1.0e-99
      })
      vel = ProcessMining.process_velocity(proc)
      assert vel.data_points == 1
    end

    test "record_snapshot with negative metric values succeeds" do
      proc = @unique_prefix <> "neg-metrics"
      assert :ok = ProcessMining.record_snapshot(proc, %{
        throughput: -50.0,
        error_rate: -0.1
      })
      vel = ProcessMining.process_velocity(proc)
      assert vel.data_points == 1
    end
  end

  describe "edge cases: linear regression and time-series helpers" do
    test "linear_regression with empty list returns zero slope and intercept" do
      {slope, intercept, r2} = ProcessMining.linear_regression([])
      assert slope == 0.0
      assert intercept == 0.0
      assert r2 == 0.0
    end

    test "linear_regression with single point returns zero slope" do
      {slope, intercept, r2} = ProcessMining.linear_regression([{0, 42.0}])
      assert slope == 0.0
      assert intercept == 42.0
      assert r2 == 0.0
    end

    test "linear_regression with identical x values returns zero slope" do
      # All x values are the same -> denominator is 0
      {slope, _intercept, r2} = ProcessMining.linear_regression([{5, 1.0}, {5, 2.0}, {5, 3.0}])
      assert slope == 0.0
      assert r2 == 0.0
    end

    test "linear_regression with perfectly correlated data returns r_squared of 1.0" do
      points = [{0, 0.0}, {1, 2.0}, {2, 4.0}, {3, 6.0}]
      {_slope, _intercept, r2} = ProcessMining.linear_regression(points)
      assert r2 == 1.0
    end

    test "exponential_smoothing with empty list returns empty" do
      assert ProcessMining.exponential_smoothing([], 0.3) == []
    end

    test "exponential_smoothing with single value returns single value" do
      result = ProcessMining.exponential_smoothing([5.0], 0.3)
      assert result == [5.0]
    end

    test "detect_trend with empty list returns stable" do
      assert ProcessMining.detect_trend([]) == :stable
    end

    test "detect_trend with single value returns stable" do
      assert ProcessMining.detect_trend([42.0]) == :stable
    end

    test "detect_trend with increasing values returns increasing" do
      values = for i <- 1..20, do: i * 1.0
      assert ProcessMining.detect_trend(values) == :increasing
    end

    test "detect_trend with decreasing values returns decreasing" do
      values = for i <- 1..20, do: (20 - i) * 1.0
      assert ProcessMining.detect_trend(values) == :decreasing
    end
  end
end
