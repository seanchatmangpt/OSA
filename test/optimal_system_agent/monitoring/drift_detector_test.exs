defmodule OptimalSystemAgent.Monitoring.DriftDetectorTest do
  @moduledoc """
  Unit tests for Model Drift Detection (Vision 2030 Wave 9, Task 7).

  Tests the drift calculation, signal encoding, and monitoring API.
  """
  use ExUnit.Case, async: true

  alias OptimalSystemAgent.Monitoring.DriftDetector
  alias OptimalSystemAgent.Signal

  describe "calculate_drift/2" do
    test "returns zero drift when metrics are identical" do
      baseline = %{
        avg_duration: 100.0,
        error_rate: 0.05,
        success_rate: 0.95,
        throughput: 10.0
      }

      recent = %{
        avg_duration: 100.0,
        error_rate: 0.05,
        success_rate: 0.95,
        throughput: 10.0
      }

      drift = DriftDetector.calculate_drift(baseline, recent)
      assert drift == 0.0
    end

    test "calculates drift when metrics change significantly" do
      baseline = %{
        avg_duration: 100.0,
        error_rate: 0.05,
        success_rate: 0.95,
        throughput: 10.0
      }

      recent = %{
        avg_duration: 150.0,  # 50% increase
        error_rate: 0.10,     # 100% increase
        success_rate: 0.90,   # 5.26% decrease
        throughput: 5.0       # 50% decrease
      }

      drift = DriftDetector.calculate_drift(baseline, recent)
      # drift = (0.5 + 1.0 + 0.0526 + 0.5) / 4 ≈ 0.513
      assert drift > 0.4
      assert drift < 0.6
    end

    test "handles missing metrics gracefully" do
      baseline = %{
        avg_duration: 100.0,
        error_rate: 0.05
      }

      recent = %{
        avg_duration: 100.0,
        error_rate: 0.05
      }

      drift = DriftDetector.calculate_drift(baseline, recent)
      assert drift == 0.0
    end
  end

  describe "identify_changed_metrics/2" do
    test "returns empty list when no metrics changed" do
      baseline = %{
        avg_duration: 100.0,
        error_rate: 0.05,
        success_rate: 0.95,
        throughput: 10.0
      }

      recent = %{
        avg_duration: 100.0,
        error_rate: 0.05,
        success_rate: 0.95,
        throughput: 10.0
      }

      changed = DriftDetector.identify_changed_metrics(baseline, recent)
      assert changed == []
    end

    test "identifies metrics with >10% drift" do
      baseline = %{
        avg_duration: 100.0,
        error_rate: 0.05,
        success_rate: 0.95,
        throughput: 10.0
      }

      recent = %{
        avg_duration: 150.0,  # 50% change
        error_rate: 0.10,     # 100% change
        success_rate: 0.95,   # 0% change
        throughput: 10.0      # 0% change
      }

      changed = DriftDetector.identify_changed_metrics(baseline, recent)
      assert :avg_duration in changed
      assert :error_rate in changed
      assert :success_rate not in changed
      assert :throughput not in changed
    end
  end

  describe "drift_signal/2" do
    test "encodes drift data with correct Signal Theory dimensions" do
      drift_data = %{
        drift_score: 0.35,
        baseline: %{
          avg_duration: 100.0,
          error_rate: 0.05,
          success_rate: 0.95,
          throughput: 10.0
        },
        recent: %{
          avg_duration: 135.0,
          error_rate: 0.08,
          success_rate: 0.92,
          throughput: 8.0
        },
        changed_metrics: [:avg_duration, :error_rate],
        exceeded_threshold: true
      }

      signal = DriftDetector.drift_signal("proc-001", drift_data)

      # Verify Signal Theory encoding S=(M,G,T,F,W)
      assert signal.mode == :analyze
      assert signal.genre == :inform
      assert signal.type == :report
      assert signal.format == :json
      assert signal.weight == 0.35
      assert Signal.valid?(signal)

      # Verify metadata
      assert signal.metadata.process_id == "proc-001"
      assert signal.metadata.drift_score == 0.35
      assert signal.metadata.exceeded == true
      assert signal.metadata.changed_metrics == [:avg_duration, :error_rate]
    end
  end

  describe "monitor/3" do
    test "returns :ok when drift is within threshold" do
      baseline = %{
        avg_duration: 100.0,
        error_rate: 0.05,
        success_rate: 0.95,
        throughput: 10.0
      }

      recent = %{
        avg_duration: 105.0,
        error_rate: 0.052,
        success_rate: 0.948,
        throughput: 10.2
      }

      result = DriftDetector.monitor("proc-001", baseline, recent)
      assert result == :ok
    end

    test "returns alert signal when metrics change significantly" do
      baseline = %{
        avg_duration: 100.0,
        error_rate: 0.05,
        success_rate: 0.95,
        throughput: 10.0
      }

      recent = %{
        avg_duration: 150.0,
        error_rate: 0.10,
        success_rate: 0.90,
        throughput: 5.0
      }

      result = DriftDetector.monitor("proc-001", baseline, recent)
      assert {:alert, signal} = result
      assert is_struct(signal, Signal)
      assert signal.metadata.process_id == "proc-001"
      assert signal.metadata.exceeded == true
      assert signal.metadata.drift_score > 0.2
    end

    test "report drift signal with s encoding" do
      baseline = %{
        avg_duration: 100.0,
        error_rate: 0.05,
        success_rate: 0.95,
        throughput: 10.0
      }

      recent = %{
        avg_duration: 180.0,
        error_rate: 0.15,
        success_rate: 0.85,
        throughput: 4.0
      }

      result = DriftDetector.monitor("proc-drift", baseline, recent)
      assert {:alert, signal} = result

      # Verify Signal Theory S=(M,G,T,F,W)
      assert signal.mode == :analyze, "Mode should be :analyze"
      assert signal.genre == :inform, "Genre should be :inform"
      assert signal.type == :report, "Type should be :report"
      assert signal.format == :json, "Format should be :json"
      assert is_float(signal.weight), "Weight should be a float"
      assert signal.weight > 0, "Weight should be positive"
      assert signal.weight <= 1.0, "Weight should be <= 1.0"

      # Verify content is valid JSON
      assert signal.content != ""
      {:ok, decoded} = Jason.decode(signal.content)
      assert is_map(decoded)
      assert decoded["drift_score"] > 0.2
    end
  end

  describe "get_threshold/0" do
    test "returns the drift threshold" do
      threshold = DriftDetector.get_threshold()
      assert threshold == 0.2
    end
  end

  describe "integration: detect_model_drift_when_metrics_change_significantly" do
    test "full flow from baseline to alert" do
      # Initial baseline
      baseline = %{
        avg_duration: 120.0,
        error_rate: 0.03,
        success_rate: 0.97,
        throughput: 15.0
      }

      # Process changes significantly
      recent = %{
        avg_duration: 200.0,  # +66.7% drift
        error_rate: 0.12,     # +300% drift
        success_rate: 0.88,   # -9.3% drift
        throughput: 5.0       # -66.7% drift
      }

      # Monitor the process
      result = DriftDetector.monitor("integration-test", baseline, recent)

      # Should generate alert
      assert {:alert, signal} = result

      # Alert should be valid
      assert Signal.valid?(signal)

      # Alert should contain drift metadata
      assert signal.metadata.drift_score > 0.3
      assert signal.metadata.exceeded == true

      # Changed metrics should be identified
      changed = signal.metadata.changed_metrics
      assert length(changed) >= 3
    end
  end
end
