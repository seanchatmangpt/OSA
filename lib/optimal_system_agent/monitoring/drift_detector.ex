defmodule OptimalSystemAgent.Monitoring.DriftDetector do
  @moduledoc """
  Detects process model staleness by monitoring metric changes.

  Continuously monitors key process metrics (duration, error rate, success rate, throughput)
  and alerts when drift exceeds the threshold of 0.2 (20%).

  The drift score is calculated as the normalized distance between baseline and recent metrics:
  `drift = avg(abs(recent - baseline) / abs(baseline))` for all monitored metrics.

  ## Metrics Monitored

  - `:avg_duration` — Average process duration (milliseconds)
  - `:error_rate` — Proportion of failed cases (0.0–1.0)
  - `:success_rate` — Proportion of successful cases (0.0–1.0)
  - `:throughput` — Cases per minute

  ## Drift Threshold

  - Drift score > 0.2 triggers an alert signal
  - Used for continuous monitoring of process model health
  """

  @drift_threshold 0.2

  @type metrics :: %{
          avg_duration: float(),
          error_rate: float(),
          success_rate: float(),
          throughput: float()
        }

  @type drift_data :: %{
          drift_score: float(),
          baseline: metrics(),
          recent: metrics(),
          changed_metrics: [atom()],
          exceeded_threshold: boolean()
        }

  @type signal :: OptimalSystemAgent.Signal.t()

  @doc """
  Calculate drift score between baseline and recent metrics.

  Returns a float between 0.0 and 1.0 representing the normalized distance.
  """
  @spec calculate_drift(metrics(), metrics()) :: float()
  def calculate_drift(baseline, recent) when is_map(baseline) and is_map(recent) do
    metric_keys = [:avg_duration, :error_rate, :success_rate, :throughput]

    drift_values =
      Enum.map(metric_keys, fn key ->
        baseline_val = Map.get(baseline, key, 0.0)
        recent_val = Map.get(recent, key, 0.0)

        # Avoid division by zero
        if baseline_val == 0.0 do
          0.0
        else
          abs(recent_val - baseline_val) / abs(baseline_val)
        end
      end)

    # Average drift across all metrics
    Enum.sum(drift_values) / length(drift_values)
  end

  @doc """
  Identify which metrics have changed significantly.

  Returns a list of atoms for metrics where drift > 0.1.
  """
  @spec identify_changed_metrics(metrics(), metrics()) :: [atom()]
  def identify_changed_metrics(baseline, recent) when is_map(baseline) and is_map(recent) do
    metric_keys = [:avg_duration, :error_rate, :success_rate, :throughput]

    Enum.filter(metric_keys, fn key ->
      baseline_val = Map.get(baseline, key, 0.0)
      recent_val = Map.get(recent, key, 0.0)

      if baseline_val == 0.0 do
        false
      else
        abs(recent_val - baseline_val) / abs(baseline_val) > 0.1
      end
    end)
  end

  @doc """
  Encode a drift report as a Signal Theory signal S=(M,G,T,F,W).

  Signal dimensions:
  - Mode: `:analyze` — analyzing process state
  - Genre: `:inform` — informing about process health status
  - Type: `:report` — structured analysis
  - Format: `:json` — machine-parseable metrics
  - Weight: drift_score clamped to (0.0–1.0)
  """
  @spec drift_signal(String.t(), drift_data()) :: signal()
  def drift_signal(process_id, drift_data) when is_binary(process_id) and is_map(drift_data) do
    # Clamp weight to valid Signal Theory bounds (0.0-1.0)
    weight = min(drift_data.drift_score, 1.0)

    OptimalSystemAgent.Signal.new(%{
      mode: :analyze,
      genre: :inform,
      type: :report,
      format: :json,
      weight: weight,
      content: Jason.encode!(drift_data) || "",
      metadata: %{
        process_id: process_id,
        drift_score: drift_data.drift_score,
        threshold: @drift_threshold,
        exceeded: drift_data.exceeded_threshold,
        changed_metrics: drift_data.changed_metrics
      }
    })
  end

  @doc """
  Monitor a process by comparing baseline and recent metrics.

  Returns `:ok` if drift is within threshold, or `{:alert, signal}` if exceeded.
  """
  @spec monitor(String.t(), metrics(), metrics()) :: :ok | {:alert, signal()}
  def monitor(process_id, baseline, recent) when is_binary(process_id) do
    drift_score = calculate_drift(baseline, recent)
    changed_metrics = identify_changed_metrics(baseline, recent)
    exceeded = drift_score > @drift_threshold

    drift_data = %{
      drift_score: Float.round(drift_score, 4),
      baseline: baseline,
      recent: recent,
      changed_metrics: changed_metrics,
      exceeded_threshold: exceeded
    }

    if exceeded do
      signal = drift_signal(process_id, drift_data)
      {:alert, signal}
    else
      :ok
    end
  end

  @doc """
  Get the current drift threshold value.
  """
  @spec get_threshold() :: float()
  def get_threshold do
    @drift_threshold
  end
end
