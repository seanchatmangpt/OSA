defmodule OptimalSystemAgent.Channels.HTTP.API.MetricsRoutes do
  @moduledoc """
  Prometheus metrics endpoint — OpenMetrics text format.

  GET /api/v1/metrics returns all collected metrics in Prometheus-compatible format.
  No authentication required (standard for Prometheus scrape endpoints).

  Metrics exposed:
    - osa_tool_executions_ms (histogram)
    - osa_provider_latency_ms (histogram)
    - osa_noise_filter_total (counter)
    - osa_signal_weight_total (counter)

  Example:
    curl http://localhost:8089/api/v1/metrics | head -20
  """
  use Plug.Router
  require Logger

  alias OptimalSystemAgent.Telemetry.Metrics

  plug :match
  plug :dispatch

  # ── GET /metrics ────────────────────────────────────────────────────
  # No auth required. Prometheus-compatible OpenMetrics format.

  get "/" do
    conn
    |> put_resp_header("content-type", "text/plain; version=0.0.4")
    |> send_resp(200, render_metrics())
  end

  match _ do
    conn |> send_resp(404, "not found")
  end

  # ────────────────────────────────────────────────────────────────────
  # Rendering
  # ────────────────────────────────────────────────────────────────────

  defp render_metrics do
    metrics = Metrics.get_metrics()
    summary = Metrics.get_summary()

    IO.iodata_to_binary([
      "# HELP osa_tool_executions_ms Tool execution duration in milliseconds\n",
      "# TYPE osa_tool_executions_ms histogram\n",
      render_tool_histogram(summary[:tool_executions] || %{}),
      "\n",
      "# HELP osa_provider_latency_ms Provider API call latency in milliseconds\n",
      "# TYPE osa_provider_latency_ms histogram\n",
      render_provider_histogram(summary[:provider_latency] || %{}),
      "\n",
      "# HELP osa_noise_filter_total Noise filter outcomes (filtered, clarify, pass)\n",
      "# TYPE osa_noise_filter_total counter\n",
      render_noise_filter_counter(metrics[:noise_filter] || %{}),
      "\n",
      "# HELP osa_signal_weight_total Signal weight distribution by bucket\n",
      "# TYPE osa_signal_weight_total counter\n",
      render_signal_weight_counter(metrics[:signal_weights] || %{}),
      "\n",
      "# HELP osa_noise_filter_rate_percent Percentage of filtered/clarify outcomes\n",
      "# TYPE osa_noise_filter_rate_percent gauge\n",
      "osa_noise_filter_rate_percent ",
      to_string(summary[:noise_filter_rate] || 0.0),
      "\n",
      "\n# EOF\n"
    ])
  end

  defp render_tool_histogram(tools) when is_map(tools) do
    tools
    |> Enum.map(fn {tool_name, stats} ->
      [
        # Histogram buckets (OpenMetrics format)
        "osa_tool_executions_ms_bucket{tool=\"",
        escape_label(tool_name),
        "\",le=\"10\"} ",
        to_string(count_le(stats[:min_ms], stats[:count], 10)),
        "\n",
        "osa_tool_executions_ms_bucket{tool=\"",
        escape_label(tool_name),
        "\",le=\"50\"} ",
        to_string(count_le(stats[:min_ms], stats[:count], 50)),
        "\n",
        "osa_tool_executions_ms_bucket{tool=\"",
        escape_label(tool_name),
        "\",le=\"100\"} ",
        to_string(count_le(stats[:min_ms], stats[:count], 100)),
        "\n",
        "osa_tool_executions_ms_bucket{tool=\"",
        escape_label(tool_name),
        "\",le=\"500\"} ",
        to_string(count_le(stats[:min_ms], stats[:count], 500)),
        "\n",
        "osa_tool_executions_ms_bucket{tool=\"",
        escape_label(tool_name),
        "\",le=\"+Inf\"} ",
        to_string(stats[:count] || 0),
        "\n",
        "osa_tool_executions_ms_sum{tool=\"",
        escape_label(tool_name),
        "\"} ",
        to_string((stats[:avg_ms] || 0.0) * (stats[:count] || 0)),
        "\n",
        "osa_tool_executions_ms_count{tool=\"",
        escape_label(tool_name),
        "\"} ",
        to_string(stats[:count] || 0),
        "\n"
      ]
    end)
  end

  defp render_provider_histogram(providers) when is_map(providers) do
    providers
    |> Enum.map(fn {provider, stats} ->
      [
        "osa_provider_latency_ms_bucket{provider=\"",
        escape_label(to_string(provider)),
        "\",le=\"500\"} ",
        to_string(count_le(stats[:min_ms], stats[:count], 500)),
        "\n",
        "osa_provider_latency_ms_bucket{provider=\"",
        escape_label(to_string(provider)),
        "\",le=\"1000\"} ",
        to_string(count_le(stats[:min_ms], stats[:count], 1000)),
        "\n",
        "osa_provider_latency_ms_bucket{provider=\"",
        escape_label(to_string(provider)),
        "\",le=\"2000\"} ",
        to_string(count_le(stats[:min_ms], stats[:count], 2000)),
        "\n",
        "osa_provider_latency_ms_bucket{provider=\"",
        escape_label(to_string(provider)),
        "\",le=\"+Inf\"} ",
        to_string(stats[:count] || 0),
        "\n",
        "osa_provider_latency_ms_sum{provider=\"",
        escape_label(to_string(provider)),
        "\"} ",
        to_string((stats[:avg_ms] || 0.0) * (stats[:count] || 0)),
        "\n",
        "osa_provider_latency_ms_count{provider=\"",
        escape_label(to_string(provider)),
        "\"} ",
        to_string(stats[:count] || 0),
        "\n"
      ]
    end)
  end

  defp render_noise_filter_counter(filter_map) when is_map(filter_map) do
    [
      "osa_noise_filter_total{outcome=\"filtered\"} ",
      to_string(filter_map[:filtered] || 0),
      "\n",
      "osa_noise_filter_total{outcome=\"clarify\"} ",
      to_string(filter_map[:clarify] || 0),
      "\n",
      "osa_noise_filter_total{outcome=\"pass\"} ",
      to_string(filter_map[:pass] || 0),
      "\n"
    ]
  end

  defp render_signal_weight_counter(weights) when is_map(weights) do
    [
      "osa_signal_weight_total{bucket=\"0.0-0.2\"} ",
      to_string(weights[:"0.0-0.2"] || 0),
      "\n",
      "osa_signal_weight_total{bucket=\"0.2-0.5\"} ",
      to_string(weights[:"0.2-0.5"] || 0),
      "\n",
      "osa_signal_weight_total{bucket=\"0.5-0.8\"} ",
      to_string(weights[:"0.5-0.8"] || 0),
      "\n",
      "osa_signal_weight_total{bucket=\"0.8-1.0\"} ",
      to_string(weights[:"0.8-1.0"] || 0),
      "\n"
    ]
  end

  # Count samples in a distribution <= threshold
  # Simple heuristic: assume uniform distribution between min and max
  defp count_le(_min, 0, _threshold), do: 0

  defp count_le(min, count, threshold) when is_number(min) and is_number(count) do
    if min >= threshold do
      0
    else
      # Rough estimate: linear interpolation
      round(count * (min(threshold, 1000.0) - min) / (1000.0 - min))
    end
  end

  # Escape Prometheus label values (double-quote escaping)
  defp escape_label(value) when is_binary(value) do
    value
    |> String.replace("\\", "\\\\")
    |> String.replace("\"", "\\\"")
    |> String.replace("\n", "\\n")
  end

  defp escape_label(value) do
    value |> to_string() |> escape_label()
  end
end
