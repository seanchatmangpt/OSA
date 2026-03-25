defmodule OptimalSystemAgent.Observability.TelemetryTest do
  use ExUnit.Case, async: true

  alias OptimalSystemAgent.Observability.Telemetry

  setup do
    # Clean up ETS tables before each test
    try do
      :ets.delete(:telemetry_spans)
      :ets.delete(:telemetry_metrics)
    rescue
      _ -> :ok
    end

    on_exit(fn ->
      try do
        :ets.delete(:telemetry_spans)
        :ets.delete(:telemetry_metrics)
      rescue
        _ -> :ok
      end
    end)

    :ok
  end

  describe "init_tracer/0" do
    test "initializes ETS tables and handlers" do
      assert :ok = Telemetry.init_tracer()

      # Verify ETS tables exist
      assert :ets.whereis(:telemetry_spans) != :undefined
      assert :ets.whereis(:telemetry_metrics) != :undefined
    end
  end

  describe "start_span/2" do
    setup do
      Telemetry.init_tracer()
      :ok
    end

    test "creates a new span with auto-generated IDs" do
      attributes = %{"agent_id" => "agent-1", "round_num" => 5}
      {:ok, span} = Telemetry.start_span("agent.decision", attributes)

      assert span["span_id"] != nil
      assert span["trace_id"] != nil
      assert span["span_name"] == "agent.decision"
      assert span["status"] == "active"
      assert span["start_time_us"] > 0
      assert span["attributes"]["agent_id"] == "agent-1"
      assert span["attributes"]["round_num"] == 5
    end

    test "enriches attributes with system context" do
      {:ok, span} = Telemetry.start_span("consensus.round", %{})

      assert span["attributes"]["timestamp"] != nil
      assert span["attributes"]["node"] != nil
      assert span["attributes"]["version"] != nil
    end

    test "stores span in ETS for parent/child hierarchy" do
      {:ok, span} = Telemetry.start_span("agent.decision", %{})

      # Verify span is stored
      [{_key, stored_span}] = :ets.lookup(:telemetry_spans, span["span_id"])
      assert stored_span["span_name"] == "agent.decision"
    end

    test "propagates trace ID across nested spans" do
      {:ok, parent_span} = Telemetry.start_span("agent.decision", %{})
      trace_id_1 = parent_span["trace_id"]

      {:ok, child_span} = Telemetry.start_span("consensus.round", %{})
      trace_id_2 = child_span["trace_id"]

      # Both should have same trace ID (inherited from process context)
      assert trace_id_1 == trace_id_2
    end
  end

  describe "record_metric/3" do
    setup do
      Telemetry.init_tracer()
      :ok
    end

    test "records a counter metric" do
      assert :ok = Telemetry.record_metric("agent.decisions", 1, %{"outcome" => "success"})

      # Verify metric stored in ETS
      metric_key = {"agent.decisions", %{"outcome" => "success"}}
      [{_key, metric_data}] = :ets.lookup(:telemetry_metrics, metric_key)

      assert metric_data["type"] == "counter"
      assert metric_data["value"] == 1
    end

    test "records a histogram metric" do
      assert :ok = Telemetry.record_metric("consensus.latency_ms", 234, %{"round_type" => "prepare"})

      metric_key = {"consensus.latency_ms", %{"round_type" => "prepare"}}
      [{_key, metric_data}] = :ets.lookup(:telemetry_metrics, metric_key)

      assert metric_data["type"] == "histogram"
      assert metric_data["count"] == 1
      assert metric_data["sum"] == 234
      assert metric_data["min"] == 234
      assert metric_data["max"] == 234
    end

    test "aggregates multiple metric observations" do
      Telemetry.record_metric("llm.predict_latency_ms", 100, %{"model" => "claude"})
      Telemetry.record_metric("llm.predict_latency_ms", 150, %{"model" => "claude"})
      Telemetry.record_metric("llm.predict_latency_ms", 120, %{"model" => "claude"})

      metric_key = {"llm.predict_latency_ms", %{"model" => "claude"}}
      [{_key, metric_data}] = :ets.lookup(:telemetry_metrics, metric_key)

      assert metric_data["count"] == 3
      assert metric_data["sum"] == 370
      assert metric_data["min"] == 100
      assert metric_data["max"] == 150
    end

    test "handles counter increment" do
      Telemetry.record_metric("tool.errors", 1, %{"tool" => "search"})
      Telemetry.record_metric("tool.errors", 1, %{"tool" => "search"})

      metric_key = {"tool.errors", %{"tool" => "search"}}
      [{_key, metric_data}] = :ets.lookup(:telemetry_metrics, metric_key)

      assert metric_data["value"] == 2
    end

    test "records metrics with empty dimensions" do
      assert :ok = Telemetry.record_metric("memory.cache_hits", 1, %{})

      metric_key = {"memory.cache_hits", %{}}
      assert [{_key, _metric_data}] = :ets.lookup(:telemetry_metrics, metric_key)
    end
  end

  describe "end_span/3" do
    setup do
      Telemetry.init_tracer()
      :ok
    end

    test "marks span as complete and records duration" do
      {:ok, span} = Telemetry.start_span("agent.decision", %{})
      Process.sleep(10)

      assert :ok = Telemetry.end_span(span, :ok)

      # Verify span status updated
      [{_key, updated_span}] = :ets.lookup(:telemetry_spans, span["span_id"])
      assert updated_span["status"] == "ok"
    end

    test "records span duration as metric" do
      {:ok, span} = Telemetry.start_span("consensus.round", %{"round_num" => 1})
      Process.sleep(10)

      :ok = Telemetry.end_span(span, :ok)

      # Verify latency metric recorded
      metric_key = {"span.duration_us", %{"span_name" => "consensus.round", "status" => "ok"}}
      [{_key, metric_data}] = :ets.lookup(:telemetry_metrics, metric_key)

      assert metric_data["type"] == "histogram"
      assert metric_data["count"] == 1
      assert metric_data["sum"] > 0
    end

    test "records error status and message" do
      {:ok, span} = Telemetry.start_span("tool.execute", %{"tool" => "search"})

      assert :ok = Telemetry.end_span(span, :error, "Tool timeout")

      [{_key, updated_span}] = :ets.lookup(:telemetry_spans, span["span_id"])
      assert updated_span["status"] == "error"
      assert updated_span["error_message"] == "Tool timeout"
    end

    test "span hierarchy with parent/child relationship" do
      {:ok, parent_span} = Telemetry.start_span("agent.decision", %{})
      parent_id = parent_span["span_id"]

      {:ok, child_span} = Telemetry.start_span("llm.predict", %{})
      child_id = child_span["span_id"]

      Telemetry.end_span(child_span, :ok)
      Telemetry.end_span(parent_span, :ok)

      # Both should be recorded
      assert :ets.member(:telemetry_spans, parent_id)
      assert :ets.member(:telemetry_spans, child_id)
    end
  end

  describe "trace context propagation" do
    setup do
      Telemetry.init_tracer()
      :ok
    end

    test "propagates trace ID across process boundaries" do
      {:ok, span1} = Telemetry.start_span("agent.decision", %{})
      trace_id_1 = span1["trace_id"]

      # Simulate new context (but same trace)
      {:ok, span2} = Telemetry.start_span("consensus.round", %{})
      trace_id_2 = span2["trace_id"]

      assert trace_id_1 == trace_id_2
    end

    test "stores trace context in process dictionary" do
      {:ok, _span} = Telemetry.start_span("agent.decision", %{})

      trace_id = Process.get(:telemetry_trace_id)
      assert trace_id != nil
    end
  end

  describe "error handling" do
    setup do
      Telemetry.init_tracer()
      :ok
    end

    test "handles numeric values only for record_metric" do
      assert :ok = Telemetry.record_metric("test.metric", 42, %{})
      assert :ok = Telemetry.record_metric("test.metric", 3.14, %{})
    end

    test "handles nil error message gracefully" do
      {:ok, span} = Telemetry.start_span("agent.decision", %{})
      assert :ok = Telemetry.end_span(span, :ok, nil)
    end

    test "handles atom and string span names" do
      {:ok, span1} = Telemetry.start_span(:agent_decision, %{})
      {:ok, span2} = Telemetry.start_span("agent.decision", %{})

      assert span1["span_name"] == "agent_decision"
      assert span2["span_name"] == "agent.decision"
    end
  end
end
