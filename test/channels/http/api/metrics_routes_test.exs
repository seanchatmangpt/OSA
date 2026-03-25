defmodule OptimalSystemAgent.Channels.HTTP.API.MetricsRoutesTest do
  use ExUnit.Case, async: true

  alias OptimalSystemAgent.Channels.HTTP.API.MetricsRoutes
  alias OptimalSystemAgent.Telemetry.Metrics

  setup do
    # Seed some metrics
    Metrics.record_tool_execution("grep_files", 245)
    Metrics.record_tool_execution("list_files", 120)
    Metrics.record_provider_call(:anthropic, 1200, true)
    Metrics.record_provider_call(:anthropic, 1500, false)
    Metrics.record_noise_filter_result(:filtered)
    Metrics.record_noise_filter_result(:pass)
    Metrics.record_signal_weight(0.5)
    Metrics.record_signal_weight(0.85)

    :ok
  end

  test "GET /metrics returns OpenMetrics format" do
    conn =
      :get
      |> Plug.Test.conn("/")
      |> MetricsRoutes.call([])

    assert conn.status == 200

    # Check content-type header (case-insensitive search)
    has_correct_type =
      Enum.any?(conn.resp_headers, fn {k, v} ->
        String.downcase(k) == "content-type" && v == "text/plain; version=0.0.4"
      end)
    assert has_correct_type, "Missing or incorrect content-type header"

    body = conn.resp_body
    assert body =~ "osa_tool_executions_ms"
    assert body =~ "osa_provider_latency_ms"
    assert body =~ "osa_noise_filter_total"
    assert body =~ "osa_signal_weight_total"
    assert body =~ "# EOF"
  end

  test "metrics output contains valid Prometheus format" do
    conn =
      :get
      |> Plug.Test.conn("/")
      |> MetricsRoutes.call([])

    body = conn.resp_body

    # Check for required Prometheus sections
    assert body =~ "# HELP osa_tool_executions_ms"
    assert body =~ "# TYPE osa_tool_executions_ms histogram"
    assert body =~ "# HELP osa_provider_latency_ms"
    assert body =~ "# TYPE osa_provider_latency_ms histogram"
    assert body =~ "# HELP osa_noise_filter_total"
    assert body =~ "# TYPE osa_noise_filter_total counter"
    assert body =~ "# HELP osa_signal_weight_total"
    assert body =~ "# TYPE osa_signal_weight_total counter"
  end

  test "metrics includes recorded tool executions" do
    conn =
      :get
      |> Plug.Test.conn("/")
      |> MetricsRoutes.call([])

    body = conn.resp_body

    # Tool names should appear in metrics
    assert body =~ "tool=\"grep_files\""
    assert body =~ "tool=\"list_files\""
  end

  test "metrics includes provider latency" do
    conn =
      :get
      |> Plug.Test.conn("/")
      |> MetricsRoutes.call([])

    body = conn.resp_body

    # Provider name should appear
    assert body =~ "provider=\"anthropic\""
  end

  test "metrics includes noise filter counters" do
    conn =
      :get
      |> Plug.Test.conn("/")
      |> MetricsRoutes.call([])

    body = conn.resp_body

    # Filter outcomes
    assert body =~ "outcome=\"filtered\""
    assert body =~ "outcome=\"pass\""
  end

  test "metrics includes signal weight distribution" do
    conn =
      :get
      |> Plug.Test.conn("/")
      |> MetricsRoutes.call([])

    body = conn.resp_body

    # Signal buckets
    assert body =~ "bucket=\"0.2-0.5\""
    assert body =~ "bucket=\"0.8-1.0\""
  end

  test "404 on non-root paths" do
    conn =
      :get
      |> Plug.Test.conn("/unknown")
      |> MetricsRoutes.call([])

    assert conn.status == 404
  end

  test "metrics endpoint is idempotent" do
    conn1 =
      :get
      |> Plug.Test.conn("/")
      |> MetricsRoutes.call([])

    conn2 =
      :get
      |> Plug.Test.conn("/")
      |> MetricsRoutes.call([])

    assert conn1.resp_body == conn2.resp_body
  end
end
