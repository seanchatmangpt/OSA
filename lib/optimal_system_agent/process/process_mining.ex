defmodule OptimalSystemAgent.Process.ProcessMining do
  @moduledoc """
  Temporal Process Mining -- Innovation 7.

  NOTE: Module renamed from Process.Temporal to Process.ProcessMining to avoid
  confusion with Temporal IO workflow engine used in Phase 2.

  Tracks the velocity and trajectory of process change over time. Goes beyond
  static process mining by answering "what's changing?" and "what will happen?"
  rather than just "what happened?".

  ## Storage

  Snapshots are stored in ETS `:osa_temporal_snapshots` (bag, keyed by
  `{process_id, timestamp}`). Each process retains at most `@max_snapshots`
  entries (ring-buffer eviction on insert).

  ## Time-series helpers

  All statistical helpers (linear regression, exponential smoothing, trend
  detection) are zero-dependency implementations suitable for the small data
  windows typical of process telemetry.

  ## Public API

  - `record_snapshot/2`        -- persist a metric snapshot
  - `process_velocity/1`       -- rate of process evolution
  - `predict_state/2`          -- forecasted future metrics
  - `early_warning/1`          -- pre-KPI degradation detection
  - `stagnation_detect/1`      -- identify stalled processes
  - `optimal_intervention_window/1` -- best time to intervene
  """

  use GenServer
  require Logger

  @table :osa_temporal_snapshots
  @max_snapshots 1_000

  # Stagnation threshold: velocity < 0.1 changes/week for > 2 weeks
  @stagnation_velocity_threshold 0.1
  @stagnation_duration_weeks 2

  # Exponential smoothing defaults
  @default_alpha 0.3

  # Early-warning sensitivity thresholds
  @error_rate_rise_threshold 0.05
  @duration_increase_threshold 0.1
  @success_rate_drop_threshold 0.05

  # ---------------------------------------------------------------------------
  # Snapshot struct
  # ---------------------------------------------------------------------------

  defmodule Snapshot do
    @moduledoc false
    @derive Jason.Encoder
    defstruct [
      :process_id,
      :timestamp,
      :metrics,
      :pattern_hash
    ]
  end

  # ---------------------------------------------------------------------------
  # State
  # ---------------------------------------------------------------------------

  defstruct []

  # ---------------------------------------------------------------------------
  # ETS bootstrap (called from Application)
  # ---------------------------------------------------------------------------

  @doc "Create the ETS table. Safe to call more than once (idempotent)."
  @spec init_table() :: :ok
  def init_table do
    :ets.new(@table, [
      :named_table,
      :public,
      :bag,
      read_concurrency: true,
      write_concurrency: true
    ])

    :ok
  rescue
    ArgumentError -> :ok
  end

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc "Start the Temporal GenServer."
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Record a time-series snapshot for a process.

  `metrics` is a map of numeric values such as `%{avg_duration_ms: 320, error_rate: 0.02, success_rate: 0.98}`.
  """
  @spec record_snapshot(String.t(), map()) :: :ok
  def record_snapshot(process_id, metrics) when is_binary(process_id) and is_map(metrics) do
    timestamp = DateTime.utc_now()
    pattern_hash = compute_pattern_hash(metrics)

    snapshot = %Snapshot{
      process_id: process_id,
      timestamp: timestamp,
      metrics: normalize_metrics(metrics),
      pattern_hash: pattern_hash
    }

    :ets.insert(@table, {{process_id, timestamp}, snapshot})
    evict_overflow(process_id)

    Logger.debug("[Temporal] recorded snapshot for process=#{process_id} metrics=#{inspect(Map.keys(metrics))}")

    :ok
  rescue
    e ->
      Logger.warning("[Temporal] record_snapshot error: #{Exception.message(e)}")
      :ok
  end

  @doc """
  Compute how fast a process is evolving.

  Returns velocity metrics including per-metric slopes, a composite velocity
  score, and a trend classification.
  """
  @spec process_velocity(String.t()) :: map()
  def process_velocity(process_id) do
    snapshots = get_snapshots(process_id)

    if length(snapshots) < 3 do
      %{
        pattern_velocity: 0.0,
        metric_velocity: %{},
        overall_velocity: 0.0,
        trend: :stable,
        data_points: length(snapshots)
      }
    else
      sorted = Enum.sort_by(snapshots, & &1.timestamp)
      {pattern_velocity, pattern_trend} = compute_pattern_velocity(sorted)

      metric_velocity =
        sorted
        |> extract_metric_series()
        |> Enum.map(fn {metric_key, points} ->
          {slope, _intercept, _r2} = linear_regression(points)
          {metric_key, slope}
        end)
        |> Map.new()

      overall_velocity = compute_overall_velocity(pattern_velocity, metric_velocity)
      trend = classify_trend(overall_velocity, pattern_trend)

      %{
        pattern_velocity: Float.round(pattern_velocity, 2),
        metric_velocity: Map.new(metric_velocity, fn {k, v} -> {k, Float.round(v, 4)} end),
        overall_velocity: Float.round(overall_velocity, 2),
        trend: trend,
        data_points: length(snapshots)
      }
    end
  end

  @doc """
  Predict the future state of a process.

  Uses linear regression by default; switches to exponential smoothing when
  data shows high variance.
  """
  @spec predict_state(String.t(), number()) :: map()
  def predict_state(process_id, weeks_ahead) when is_binary(process_id) and is_number(weeks_ahead) do
    snapshots = get_snapshots(process_id)

    if length(snapshots) < 3 do
      %{
        predicted_at: DateTime.add(DateTime.utc_now(), weeks_to_seconds(weeks_ahead), :second),
        metrics: %{},
        confidence: 0.0,
        method: :insufficient_data,
        warning_threshold: false
      }
    else
      sorted = Enum.sort_by(snapshots, & &1.timestamp)

      {method, predictions, confidence} =
        if length(sorted) >= 10 and variance_of_values(Enum.map(sorted, & &1.timestamp)) > 0 do
          predict_exponential(sorted, weeks_ahead)
        else
          predict_linear(sorted, weeks_ahead)
        end

      predicted_at =
        DateTime.add(DateTime.utc_now(), weeks_to_seconds(weeks_ahead), :second)

      # Check if any predicted metric breaches warning thresholds
      current_metrics = List.last(sorted).metrics
      warning_threshold = check_prediction_warnings(current_metrics, predictions)

      %{
        predicted_at: predicted_at,
        metrics: Map.new(predictions, fn {k, v} -> {k, Float.round(v, 4)} end),
        confidence: Float.round(confidence, 2),
        method: method,
        warning_threshold: warning_threshold
      }
    end
  end

  @doc """
  Detect degradation signals before they impact KPIs.

  Analyzes velocity and trend direction for each metric to produce a list of
  warnings and an overall health score.
  """
  @spec early_warning(String.t()) :: map()
  def early_warning(process_id) do
    snapshots = get_snapshots(process_id)

    if length(snapshots) < 5 do
      %{
        warnings: [],
        health_score: 1.0,
        risk_level: :healthy,
        data_points: length(snapshots)
      }
    else
      sorted = Enum.sort_by(snapshots, & &1.timestamp)
      metric_series = extract_metric_series(sorted)

      warnings =
        metric_series
        |> Enum.flat_map(fn {metric_key, points} ->
          detect_metric_warnings(metric_key, points)
        end)
        |> Enum.sort_by(& &1.severity, fn a, b ->
          severity_rank(a) >= severity_rank(b)
        end)

      health_score = compute_health_score(warnings, length(metric_series))
      risk_level = classify_risk(health_score)

      %{
        warnings: warnings,
        health_score: Float.round(health_score, 2),
        risk_level: risk_level,
        data_points: length(snapshots)
      }
    end
  end

  @doc """
  Identify processes that are not evolving.

  Stagnation is defined as velocity < #{@stagnation_velocity_threshold} changes/week
  for > #{@stagnation_duration_weeks} weeks. Stagnant processes carry high risk
  of decay.
  """
  @spec stagnation_detect(String.t()) :: map()
  def stagnation_detect(process_id) do
    snapshots = get_snapshots(process_id)

    if length(snapshots) < 3 do
      %{
        is_stagnant: false,
        stagnation_score: 0.0,
        last_improvement: nil,
        recommended_action: "Insufficient data -- record more snapshots before assessing"
      }
    else
      sorted = Enum.sort_by(snapshots, & &1.timestamp)
      {velocity, _trend} = compute_pattern_velocity(sorted)

      oldest = List.first(sorted).timestamp
      newest = List.last(sorted).timestamp
      span_weeks = datetime_diff_weeks(oldest, newest)

      is_stagnant =
        velocity < @stagnation_velocity_threshold and span_weeks >= @stagnation_duration_weeks

      # Find the last time a meaningful improvement occurred
      last_improvement = find_last_improvement(sorted)

      # Stagnation score: 0.0 (evolving) to 1.0 (fully stagnant)
      stagnation_score =
        cond do
          velocity <= 0.0 -> 1.0
          velocity < @stagnation_velocity_threshold -> 0.7 + 0.3 * (1.0 - velocity / @stagnation_velocity_threshold)
          velocity < 0.5 -> 0.3 * (1.0 - velocity / 0.5)
          true -> 0.0
        end

      recommended_action =
        cond do
          is_stagnant ->
            "Schedule process improvement -- low change velocity (#{Float.round(velocity, 2)}/wk) indicates decay risk"

          velocity < 0.5 ->
            "Monitor closely -- change velocity is declining (#{Float.round(velocity, 2)}/wk)"

          true ->
            "Process is evolving normally -- no intervention needed"
        end

      %{
        is_stagnant: is_stagnant,
        stagnation_score: Float.round(stagnation_score, 2),
        last_improvement: last_improvement,
        recommended_action: recommended_action
      }
    end
  end

  @doc """
  Find the optimal time window to make changes to a process.

  Low-velocity periods are safer for interventions; high-velocity periods
  carry higher risk of disrupting active evolution.
  """
  @spec optimal_intervention_window(String.t()) :: map()
  def optimal_intervention_window(process_id) do
    snapshots = get_snapshots(process_id)

    if length(snapshots) < 3 do
      now = DateTime.utc_now()
      window_end = DateTime.add(now, 7 * 24 * 3600, :second)

      %{
        recommended_window: %{start: now, end: window_end},
        reasoning: "Insufficient data -- defaulting to next 7 days",
        current_velocity: 0.0,
        risk_of_change: :unknown
      }
    else
      sorted = Enum.sort_by(snapshots, & &1.timestamp)
      {velocity, _trend} = compute_pattern_velocity(sorted)

      # Find the lowest-velocity window in recent history
      {window_start, window_end} = find_low_velocity_window(sorted)

      risk_of_change =
        cond do
          velocity > 2.0 -> :high
          velocity > 0.5 -> :medium
          true -> :low
        end

      reasoning =
        cond do
          velocity < @stagnation_velocity_threshold ->
            "Low change velocity period detected -- ideal for process changes"

          velocity > 1.0 ->
            "High activity period -- consider waiting for velocity to decrease"

          true ->
            "Moderate change velocity -- acceptable window with standard precautions"
        end

      %{
        recommended_window: %{start: window_start, end: window_end},
        reasoning: reasoning,
        current_velocity: Float.round(velocity, 2),
        risk_of_change: risk_of_change
      }
    end
  end

  # ---------------------------------------------------------------------------
  # Time-series helpers (public for testing / reuse)
  # ---------------------------------------------------------------------------

  @doc """
  Simple linear regression over a list of `{x, y}` points.

  Returns `{slope, intercept, r_squared}` where `r_squared` is the coefficient
  of determination (0.0 = no fit, 1.0 = perfect fit).
  """
  @spec linear_regression([{number(), number()}]) :: {float(), float(), float()}
  def linear_regression([]), do: {0.0, 0.0, 0.0}
  def linear_regression([{_x, y}]), do: {0.0, y * 1.0, 0.0}

  def linear_regression(points) when is_list(points) and length(points) >= 2 do
    n = length(points)

    {sum_x, sum_y, sum_xy, sum_x2, _sum_y2} =
      Enum.reduce(points, {0.0, 0.0, 0.0, 0.0, 0.0}, fn {x, y}, {sx, sy, sxy, sx2, sy2} ->
        x_f = x * 1.0
        y_f = y * 1.0
        {sx + x_f, sy + y_f, sxy + x_f * y_f, sx2 + x_f * x_f, sy2 + y_f * y_f}
      end)

    denominator = n * sum_x2 - sum_x * sum_x

    if abs(denominator) < 1.0e-10 do
      {0.0, sum_y / n, 0.0}
    else
      slope = (n * sum_xy - sum_x * sum_y) / denominator
      intercept = (sum_y - slope * sum_x) / n

      # R-squared
      mean_y = sum_y / n

      ss_tot =
        Enum.reduce(points, 0.0, fn {_x, y}, acc ->
          acc + :math.pow(y - mean_y, 2)
        end)

      ss_res =
        Enum.reduce(points, 0.0, fn {x, y}, acc ->
          predicted = slope * x + intercept
          acc + :math.pow(y - predicted, 2)
        end)

      r_squared =
        if ss_tot > 1.0e-10 do
          1.0 - ss_res / ss_tot
        else
          0.0
        end

      {slope, intercept, max(0.0, min(1.0, r_squared))}
    end
  end

  @doc """
  Exponential smoothing over a list of numeric values.

  Returns a smoothed list of the same length. Alpha controls smoothing
  sensitivity: higher alpha = more responsive to recent changes.
  """
  @spec exponential_smoothing([number()], float()) :: [float()]
  def exponential_smoothing([], _alpha), do: []

  def exponential_smoothing([first | rest], alpha) when is_number(alpha) and alpha > 0 and alpha <= 1.0 do
    alpha = alpha * 1.0

    Enum.reduce(rest, [first * 1.0], fn value, [prev | _] = smoothed ->
      next = alpha * (value * 1.0) + (1.0 - alpha) * prev
      [next | smoothed]
    end)
    |> Enum.reverse()
  end

  @doc """
  Detect the trend direction of a numeric series.

  Uses exponential smoothing followed by slope analysis to classify the
  trend as `:increasing`, `:decreasing`, or `:stable`.
  """
  @spec detect_trend([number()]) :: :increasing | :decreasing | :stable
  def detect_trend([]), do: :stable
  def detect_trend([_]), do: :stable

  def detect_trend(values) when is_list(values) do
    smoothed = exponential_smoothing(values, @default_alpha)
    n = length(smoothed)

    if n < 2 do
      :stable
    else
      points = Enum.with_index(smoothed) |> Enum.map(fn {v, i} -> {i * 1.0, v} end)
      {slope, _intercept, _r2} = linear_regression(points)

      cond do
        slope > 0.05 -> :increasing
        slope < -0.05 -> :decreasing
        true -> :stable
      end
    end
  end

  # ---------------------------------------------------------------------------
  # GenServer callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(_opts) do
    Logger.info("[Temporal] Temporal Process Mining started")
    {:ok, %__MODULE__{}}
  end

  # ---------------------------------------------------------------------------
  # Private -- snapshot storage
  # ---------------------------------------------------------------------------

  defp get_snapshots(process_id) do
    :ets.match_object(@table, {{process_id, :_}, :_})
    |> Enum.map(fn {_, snapshot} -> snapshot end)
    |> Enum.sort_by(& &1.timestamp)
  rescue
    _ -> []
  end

  defp evict_overflow(process_id) do
    count =
      :ets.match_object(@table, {{process_id, :_}, :_})
      |> length()

    if count > @max_snapshots do
      # Delete the oldest entries to stay within the ring buffer
      snapshots =
        :ets.match_object(@table, {{process_id, :_}, :_})
        |> Enum.map(fn {key, _} -> key end)
        |> Enum.sort_by(fn {_, ts} -> ts end)

      to_delete = Enum.take(snapshots, count - @max_snapshots)

      Enum.each(to_delete, fn key ->
        :ets.delete_object(@table, {key, :_})
      end)
    end
  rescue
    _ -> :ok
  end

  defp normalize_metrics(metrics) do
    metrics
    |> Enum.map(fn {k, v} ->
      key = to_string(k)
      value = if is_number(v), do: v * 1.0, else: 0.0
      {key, value}
    end)
    |> Map.new()
  end

  defp compute_pattern_hash(metrics) do
    :crypto.hash(:sha256, :erlang.term_to_binary(metrics))
    |> Base.encode16(case: :lower)
    |> String.slice(0, 16)
  end

  # ---------------------------------------------------------------------------
  # Private -- velocity computation
  # ---------------------------------------------------------------------------

  defp compute_pattern_velocity(sorted_snapshots) do
    # Count pattern hash changes over time
    hashes = Enum.map(sorted_snapshots, & &1.pattern_hash)

    # Count transitions (how many times the hash changes)
    changes =
      hashes
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.count(fn [a, b] -> a != b end)

    oldest = List.first(sorted_snapshots).timestamp
    newest = List.last(sorted_snapshots).timestamp
    span_weeks = datetime_diff_weeks(oldest, newest)

    velocity = if span_weeks > 0, do: changes / span_weeks, else: 0.0
    trend = detect_velocity_trend(sorted_snapshots)

    {velocity, trend}
  end

  defp detect_velocity_trend(sorted_snapshots) do
    # Compute rolling window velocity over the series
    window_size = max(3, div(length(sorted_snapshots), 4))

    rolling_velocities =
      sorted_snapshots
      |> Enum.chunk_every(window_size, 1, :discard)
      |> Enum.map(fn window ->
        hashes = Enum.map(window, & &1.pattern_hash)
        changes = count_hash_changes(hashes)
        oldest = List.first(window).timestamp
        newest = List.last(window).timestamp
        span_weeks = datetime_diff_weeks(oldest, newest)

        if span_weeks > 0, do: changes / span_weeks, else: 0.0
      end)

    case rolling_velocities do
      [] -> :stable
      velocities -> detect_trend(velocities)
    end
  end

  defp count_hash_changes(hashes) do
    hashes
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.count(fn [a, b] -> a != b end)
  end

  defp compute_overall_velocity(pattern_velocity, metric_velocity) do
    metric_magnitudes =
      metric_velocity
      |> Map.values()
      |> Enum.map(&abs/1)

    avg_metric_velocity =
      if metric_magnitudes == [] do
        0.0
      else
        Enum.sum(metric_magnitudes) / length(metric_magnitudes)
      end

    # Weighted composite: 40% pattern velocity, 60% average metric velocity
    0.4 * abs(pattern_velocity) + 0.6 * avg_metric_velocity
  end

  defp classify_trend(overall_velocity, pattern_trend) do
    cond do
      overall_velocity > 1.0 and pattern_trend == :increasing -> :accelerating
      overall_velocity < 0.1 and pattern_trend == :decreasing -> :decelerating
      true -> :stable
    end
  end

  # ---------------------------------------------------------------------------
  # Private -- metric series extraction
  # ---------------------------------------------------------------------------

  defp extract_metric_series(sorted_snapshots) do
    # Get all metric keys from the first snapshot
    all_keys =
      sorted_snapshots
      |> Enum.flat_map(fn s -> Map.keys(s.metrics) end)
      |> Enum.uniq()

    # Build time-series for each metric: {metric_key, [{timestamp_index, value}]}
    all_keys
    |> Enum.map(fn key ->
      points =
        sorted_snapshots
        |> Enum.with_index()
        |> Enum.map(fn {snapshot, idx} ->
          {idx * 1.0, Map.get(snapshot.metrics, key, 0.0)}
        end)

      {key, points}
    end)
  end

  # ---------------------------------------------------------------------------
  # Private -- prediction
  # ---------------------------------------------------------------------------

  defp predict_linear(sorted, weeks_ahead) do
    metric_series = extract_metric_series(sorted)

    predictions =
      metric_series
      |> Enum.map(fn {key, points} ->
        {slope, intercept, _r2} = linear_regression(points)
        last_idx = length(points) - 1
        projected = slope * (last_idx + weeks_ahead) + intercept
        {key, projected}
      end)
      |> Map.new()

    # Average R-squared as confidence
    r2_values =
      metric_series
      |> Enum.map(fn {_key, points} ->
        {_slope, _intercept, r2} = linear_regression(points)
        r2
      end)

    avg_r2 =
      if r2_values == [] do
        0.0
      else
        Enum.sum(r2_values) / length(r2_values)
      end

    # Penalize confidence for longer projections
    confidence = avg_r2 * max(0.1, 1.0 - weeks_ahead * 0.1)

    {:linear_regression, predictions, confidence}
  end

  defp predict_exponential(sorted, weeks_ahead) do
    metric_series = extract_metric_series(sorted)

    predictions =
      metric_series
      |> Enum.map(fn {key, points} ->
        values = Enum.map(points, fn {_x, y} -> y end)
        smoothed = exponential_smoothing(values, @default_alpha)

        # Extrapolate from the smoothed trend
        last_smoothed = List.last(smoothed)

        # Use the average recent change for projection
        recent_changes =
          smoothed
          |> Enum.take(-5)
          |> Enum.chunk_every(2, 1, :discard)
          |> Enum.map(fn [a, b] -> b - a end)

        avg_change =
          if recent_changes == [] do
            0.0
          else
            Enum.sum(recent_changes) / length(recent_changes)
          end

        projected = last_smoothed + avg_change * weeks_ahead
        {key, projected}
      end)
      |> Map.new()

    # Exponential smoothing confidence based on recent variance
    avg_variance =
      metric_series
      |> Enum.map(fn {_key, points} ->
        values = Enum.map(points, fn {_x, y} -> y end)
        variance_of_values(values)
      end)

    avg_var =
      if avg_variance == [] do
        1.0
      else
        Enum.sum(avg_variance) / length(avg_variance)
      end

    # Higher variance = lower confidence
    confidence = max(0.1, 1.0 - min(0.8, avg_var)) * max(0.1, 1.0 - weeks_ahead * 0.08)

    {:exponential_smoothing, predictions, confidence}
  end

  defp check_prediction_warnings(current_metrics, predictions) do
    Enum.any?(predictions, fn {key, predicted} ->
      current = Map.get(current_metrics, key, 0.0)

      cond do
        # Error rate rising
        String.contains?(key, "error") and predicted > current * 1.5 -> true
        # Success rate dropping
        String.contains?(key, "success") and predicted < current * 0.9 -> true
        # Duration increasing significantly
        String.contains?(key, "duration") and predicted > current * 1.3 -> true
        true -> false
      end
    end)
  end

  # ---------------------------------------------------------------------------
  # Private -- early warning
  # ---------------------------------------------------------------------------

  defp detect_metric_warnings(metric_key, points) do
    if length(points) < 3 do
      []
    else
      {slope, _intercept, r2} = linear_regression(points)
      values = Enum.map(points, fn {_x, y} -> y end)
      latest = List.last(values)
      smoothed = exponential_smoothing(values, @default_alpha)
      trend = detect_trend(values)

      warnings = []

      # Error rate detection
      warnings =
        if String.contains?(metric_key, "error") and slope > @error_rate_rise_threshold and r2 > 0.3 do
          projected_weeks =
            if slope > 0 do
              # Estimate weeks until error rate doubles
              target = latest * 2.0
              remaining = max(0, target - latest)
              round(remaining / slope)
            else
              99
            end

          severity = if slope > 0.15, do: :high, else: :medium

          [
            %{
              type: :error_rate_rising,
              severity: severity,
              message: "Error rate '#{metric_key}' trending upward (slope: #{Float.round(slope, 4)}/tick)",
              projected_impact: "#{projected_weeks} weeks",
              current_value: Float.round(latest, 4),
              r_squared: Float.round(r2, 2)
            }
            | warnings
          ]
        else
          warnings
        end

      # Duration increase detection
      warnings =
        if String.contains?(metric_key, "duration") and slope > @duration_increase_threshold and r2 > 0.3 do
          projected_weeks =
            if slope > 0 do
              target = latest * 1.5
              remaining = max(0, target - latest)
              round(remaining / slope)
            else
              99
            end

          severity = if slope > 0.3, do: :high, else: :low

          [
            %{
              type: :duration_increasing,
              severity: severity,
              message: "Duration '#{metric_key}' increasing (slope: #{Float.round(slope, 4)}/tick)",
              projected_impact: "#{projected_weeks} weeks",
              current_value: Float.round(latest, 4),
              r_squared: Float.round(r2, 2)
            }
            | warnings
          ]
        else
          warnings
        end

      # Success rate dropping
      warnings =
        if String.contains?(metric_key, "success") and slope < -@success_rate_drop_threshold and r2 > 0.3 do
          projected_weeks =
            if slope < 0 do
              target = latest * 0.8
              remaining = max(0, latest - target)
              round(remaining / abs(slope))
            else
              99
            end

          severity = if slope < -0.15, do: :high, else: :medium

          [
            %{
              type: :success_rate_declining,
              severity: severity,
              message: "Success rate '#{metric_key}' declining (slope: #{Float.round(slope, 4)}/tick)",
              projected_impact: "#{projected_weeks} weeks",
              current_value: Float.round(latest, 4),
              r_squared: Float.round(r2, 2)
            }
            | warnings
          ]
        else
          warnings
        end

      # General trend warning
      warnings =
        if trend == :decreasing and not String.contains?(metric_key, "error") and
             not String.contains?(metric_key, "duration") do
          [
            %{
              type: :metric_declining,
              severity: :low,
              message: "Metric '#{metric_key}' showing declining trend",
              projected_impact: "monitoring",
              current_value: Float.round(latest, 4),
              smoothed: Float.round(List.last(smoothed), 4)
            }
            | warnings
          ]
        else
          warnings
        end

      Enum.reverse(warnings)
    end
  end

  defp compute_health_score(warnings, _metric_count) do
    if warnings == [] do
      1.0
    else
      # Start at 1.0, deduct based on severity
      deductions =
        warnings
        |> Enum.map(fn w ->
          case w.severity do
            :high -> 0.3
            :medium -> 0.15
            :low -> 0.05
          end
        end)

      total_deduction = Enum.sum(deductions)
      max(0.0, 1.0 - total_deduction)
    end
  end

  defp classify_risk(health_score) do
    cond do
      health_score >= 0.8 -> :healthy
      health_score >= 0.5 -> :moderate
      health_score >= 0.3 -> :at_risk
      true -> :critical
    end
  end

  defp severity_rank(%{severity: :high}), do: 3
  defp severity_rank(%{severity: :medium}), do: 2
  defp severity_rank(%{severity: :low}), do: 1

  # ---------------------------------------------------------------------------
  # Private -- stagnation
  # ---------------------------------------------------------------------------

  defp find_last_improvement(sorted_snapshots) do
    # Look for the last snapshot where a key metric improved
    sorted_snapshots
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.filter(fn [prev, curr] ->
      prev_improvement?(prev.metrics, curr.metrics)
    end)
    |> List.last()
    |> case do
      [_prev, curr] -> curr.timestamp
      nil -> nil
    end
  end

  defp prev_improvement?(prev_metrics, curr_metrics) do
    # Check if any metric that should increase did, or any that should decrease did
    Enum.any?(curr_metrics, fn {key, curr_val} ->
      prev_val = Map.get(prev_metrics, key, 0.0)

      cond do
        String.contains?(key, "error") -> curr_val < prev_val
        String.contains?(key, "duration") -> curr_val < prev_val
        String.contains?(key, "success") -> curr_val > prev_val
        String.contains?(key, "throughput") -> curr_val > prev_val
        true -> abs(curr_val - prev_val) > 0.01
      end
    end)
  end

  # ---------------------------------------------------------------------------
  # Private -- intervention window
  # ---------------------------------------------------------------------------

  defp find_low_velocity_window(sorted_snapshots) do
    now = DateTime.utc_now()
    window_start = now
    window_end = DateTime.add(now, 7 * 24 * 3600, :second)

    # If we have enough data, look at recent velocity patterns
    if length(sorted_snapshots) >= 5 do
      # Compute weekly velocity for the last few weeks
      recent = Enum.take(sorted_snapshots, -20)

      if length(recent) >= 5 do
        _oldest = List.first(recent).timestamp
        newest = List.last(recent).timestamp

        # The period immediately after the most recent snapshot tends to have
        # lower velocity, so recommend starting 1 day after last snapshot
        window_start = DateTime.add(newest, 24 * 3600, :second)
        window_end = DateTime.add(window_start, 7 * 24 * 3600, :second)

        {window_start, window_end}
      else
        {window_start, window_end}
      end
    else
      {window_start, window_end}
    end
  end

  # ---------------------------------------------------------------------------
  # Private -- math utilities
  # ---------------------------------------------------------------------------

  defp datetime_diff_weeks(dt1, dt2) do
    diff_seconds = DateTime.diff(dt2, dt1, :second)
    diff_seconds / (7 * 24 * 3600)
  end

  defp weeks_to_seconds(weeks), do: round(weeks * 7 * 24 * 3600)

  defp variance_of_values([]), do: 0.0
  defp variance_of_values([_]), do: 0.0

  defp variance_of_values(values) do
    n = length(values)
    mean = Enum.sum(values) / n

    sum_sq_diff =
      Enum.reduce(values, 0.0, fn v, acc ->
        acc + :math.pow(v - mean, 2)
      end)

    sum_sq_diff / n
  end
end
