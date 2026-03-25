defmodule FingerprintBenchmark.BenchmarkEngine do
  @moduledoc """
  Benchmark Engine — Compare fingerprints against industry data.
  """

  @doc """
  Compare fingerprint against industry benchmarks.
  """
  def compare(fingerprint, opts \\ []) do
    industry = Keyword.get(opts, :industry, "all")
    size = Keyword.get(opts, :size, "all")
    process_category = Keyword.get(opts, :process_category, "all")

    # Load benchmark data
    benchmark_data = load_benchmark_data(industry, size, process_category)

    # Extract metrics from fingerprint
    your_metrics = extract_metrics(fingerprint)

    # Calculate percentiles
    percentiles = calculate_percentiles(your_metrics, benchmark_data)

    # Identify gaps
    gaps = identify_gaps(your_metrics, benchmark_data, percentiles)

    # Generate recommendations
    recommendations = generate_recommendations(gaps)

    # Build comparison result
    comparison = %{
      benchmark_id: generate_id(),
      your_fingerprint: %{
        fingerprint_id: fingerprint.fingerprint_id,
        metrics: your_metrics
      },
      industry_benchmark: benchmark_data.summary,
      comparison: %{
        percentiles: percentiles,
        overall_rank: calculate_overall_rank(percentiles),
        gaps: gaps,
        recommendations: recommendations
      },
      metadata: %{
        industry: industry,
        size: size,
        process_category: process_category,
        sample_size: benchmark_data.sample_size,
        generated_at: DateTime.utc_now() |> DateTime.to_iso8601()
      }
    }

    {:ok, comparison}
  end

  # Extract key metrics from fingerprint
  defp extract_metrics(fingerprint) do
    dna = fingerprint.process_dna

    %{
      cycle_time_days: dna.timing.median_cycle_time_hours / 24.0,
      efficiency_score: calculate_efficiency_score(dna),
      error_rate: dna.quality.error_rate,
      automation_level: dna.participants.automation_level,
      handoff_count: dna.participants.handoffs,
      step_count: dna.structure.steps
    }
  end

  defp calculate_efficiency_score(dna) do
    # Efficiency = value-added time / total time
    # Simplified: inverse of rework rate
    1.0 - min(dna.quality.rework_rate * 2, 1.0)
  end

  # Load benchmark data
  defp load_benchmark_data(industry, size, process_category) do
    # In production: Load from database
    # For now: Return synthetic benchmark data
    generate_synthetic_benchmark(industry, size, process_category)
  end

  defp generate_synthetic_benchmark(industry, size, process_category) do
    # Generate synthetic percentiles based on industry
    base_cycle_time = case industry do
      "manufacturing" -> 14.0
      "financial_services" -> 10.0
      "healthcare" -> 18.0
      "retail" -> 8.0
      "technology" -> 6.0
      _ -> 12.0
    end

    size_multiplier = case size do
      "smb" -> 1.5
      "enterprise" -> 0.8
      "fortune_500" -> 0.6
      _ -> 1.0
    end

    base_cycle_time = base_cycle_time * size_multiplier

    %{
      sample_size: 1250,
      summary: %{
        p50_cycle_time_days: base_cycle_time,
        p75_cycle_time_days: base_cycle_time * 0.75,
        p90_cycle_time_days: base_cycle_time * 0.6,
        median_efficiency: 0.68,
        median_error_rate: 0.05,
        median_automation: 0.35
      },
      percentiles: %{
        cycle_time_days: %{
          p10: base_cycle_time * 1.5,
          p25: base_cycle_time * 1.2,
          p50: base_cycle_time,
          p75: base_cycle_time * 0.75,
          p90: base_cycle_time * 0.6
        },
        efficiency: %{
          p10: 0.45,
          p25: 0.55,
          p50: 0.68,
          p75: 0.81,
          p90: 0.89
        },
        error_rate: %{
          p10: 0.10,
          p25: 0.07,
          p50: 0.05,
          p75: 0.03,
          p90: 0.01
        },
        automation: %{
          p10: 0.10,
          p25: 0.20,
          p50: 0.35,
          p75: 0.50,
          p90: 0.70
        }
      }
    }
  end

  # Calculate percentiles for each metric
  defp calculate_percentiles(your_metrics, benchmark_data) do
    %{
      cycle_time_days: calculate_percentile(
        your_metrics.cycle_time_days,
        benchmark_data.percentiles.cycle_time_days
      ),
      efficiency_score: calculate_percentile(
        your_metrics.efficiency_score,
        benchmark_data.percentiles.efficiency
      ),
      error_rate: calculate_percentile(
        your_metrics.error_rate,
        benchmark_data.percentiles.error_rate,
        :lower_is_better
      ),
      automation_level: calculate_percentile(
        your_metrics.automation_level,
        benchmark_data.percentiles.automation
      )
    }
  end

  defp calculate_percentile(value, percentiles, direction \\ :higher_is_better) do
    cond do
      value >= percentiles.p90 -> 0.90
      value >= percentiles.p75 -> 0.75
      value >= percentiles.p50 -> 0.50
      value >= percentiles.p25 -> 0.25
      value >= percentiles.p10 -> 0.10
      true -> 0.05
    end
    |> then(fn percentile ->
      case direction do
        :lower_is_better -> 1.0 - percentile
        :higher_is_better -> percentile
      end
    end)
  end

  # Identify performance gaps
  defp identify_gaps(your_metrics, benchmark_data, percentiles) do
    gaps = []

    # Cycle time gap
    if your_metrics.cycle_time_days > benchmark_data.summary.p75_cycle_time_days do
      gap_pct = trunc((your_metrics.cycle_time_days / benchmark_data.summary.p75_cycle_time_days - 1) * 100)
      gaps = gaps ++ [%{
        metric: "cycle_time",
        your_value: your_metrics.cycle_time_days,
        benchmark_value: benchmark_data.summary.p75_cycle_time_days,
        gap_percent: gap_pct,
        severity: if(gap_pct > 50, do: "high", else: "medium"),
        recommendation: "Optimize process flow, eliminate bottlenecks",
        estimated_improvement: "-#{gap_pct}% cycle time"
      }]
    end

    # Efficiency gap
    if your_metrics.efficiency_score < benchmark_data.summary.median_efficiency do
      gap_pct = trunc((benchmark_data.summary.median_efficiency - your_metrics.efficiency_score) / benchmark_data.summary.median_efficiency * 100)
      gaps = gaps ++ [%{
        metric: "efficiency",
        your_value: your_metrics.efficiency_score,
        benchmark_value: benchmark_data.summary.median_efficiency,
        gap_percent: gap_pct,
        severity: "medium",
        recommendation: "Reduce rework, streamline approvals",
        estimated_improvement: "+#{gap_pct}% efficiency"
      }]
    end

    # Automation gap
    if your_metrics.automation_level < benchmark_data.summary.p90_automation do
      gap_pct = trunc((benchmark_data.summary.p90_automation - your_metrics.automation_level) / benchmark_data.summary.p90_automation * 100)
      gaps = gaps ++ [%{
        metric: "automation",
        your_value: your_metrics.automation_level,
        benchmark_value: benchmark_data.summary.p90_automation,
        gap_percent: gap_pct,
        severity: "low",
        recommendation: "Automate manual tasks, implement RPA",
        estimated_improvement: "+#{gap_pct}% automation"
      }]
    end

    gaps
  end

  # Generate recommendations from gaps
  defp generate_recommendations(gaps) do
    Enum.map(gaps, fn gap ->
      %{
        priority: gap.severity,
        metric: gap.metric,
        recommendation: gap.recommendation,
        expected_outcome: gap.estimated_improvement,
        effort: estimate_effort(gap.metric)
      }
    end)
    |> Enum.sort_by(fn g ->
      case g.priority do
        "high" -> 0
        "medium" -> 1
        "low" -> 2
      end
    end)
  end

  defp estimate_effort(metric) do
    case metric do
      "cycle_time" -> "medium"
      "efficiency" -> "low"
      "automation" -> "high"
      _ -> "medium"
    end
  end

  defp calculate_overall_rank(percentiles) do
    avg = (
      percentiles.cycle_time_days +
      percentiles.efficiency_score +
      percentiles.error_rate +
      percentiles.automation_level
    ) / 4.0

    cond do
      avg >= 0.75 -> "top_quartile"
      avg >= 0.50 -> "above_average"
      avg >= 0.25 -> "below_average"
      true -> "bottom_quartile"
    end
  end

  defp generate_id do
    :crypto.strong_rand_bytes(12)
    |> Base.encode16(case: :lower)
    |> then(&:binary_part(&1, 0, 12))
    |> then<>("bm-" <> &1)
  end
end
