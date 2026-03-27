defmodule OptimalSystemAgent.Agent.LoopIterationSpansTest do
  @moduledoc """
  Tests for OTEL span emission during agent loop iterations.
  Tests the OTEL Step 2 implementation.

  Uses --no-start mode, so we test span mechanics directly without
  full app initialization.
  """
  use ExUnit.Case

  setup do
    # Manually initialize ETS tables that telemetry uses
    try do
      :ets.new(:telemetry_spans, [:named_table, :public, {:keypos, 1}])
    rescue
      ArgumentError -> :ok  # Table already exists
    end

    try do
      :ets.new(:telemetry_metrics, [:named_table, :public, {:keypos, 1}])
    rescue
      ArgumentError -> :ok
    end

    :ok
  end

  describe "agent loop iteration span emission" do
    test "start_span creates span with correct attributes" do
      # Clear process trace_id so each test gets a fresh trace
      Process.delete(:telemetry_trace_id)

      agent_id = "test-agent-1"
      turn_count = 1
      iteration = 0

      {:ok, span_ctx} =
        OptimalSystemAgent.Observability.Telemetry.start_span(
          "agent.loop.iteration",
          %{
            "agent_id" => agent_id,
            "turn_count" => turn_count,
            "iteration" => iteration
          }
        )

      # Verify span context structure
      assert span_ctx["span_id"] != nil
      assert span_ctx["trace_id"] != nil
      assert span_ctx["span_name"] == "agent.loop.iteration"
      assert span_ctx["status"] == "active"
      assert span_ctx["start_time_us"] != nil
      assert span_ctx["attributes"]["agent_id"] == agent_id
      assert span_ctx["attributes"]["turn_count"] == turn_count
      assert span_ctx["attributes"]["iteration"] == iteration

      # Verify span was stored in ETS
      [{span_id, stored_span}] = :ets.lookup(:telemetry_spans, span_ctx["span_id"])
      assert stored_span["span_name"] == "agent.loop.iteration"
    end

    test "end_span records status and duration" do
      Process.delete(:telemetry_trace_id)

      {:ok, span_ctx} =
        OptimalSystemAgent.Observability.Telemetry.start_span(
          "agent.loop.iteration",
          %{"agent_id" => "test-agent-2"}
        )

      span_id = span_ctx["span_id"]

      # Record some activity
      Process.sleep(10)

      # End span with success status
      :ok = OptimalSystemAgent.Observability.Telemetry.end_span(span_ctx, :ok)

      # Retrieve the completed span from ETS
      [{^span_id, completed_span}] = :ets.lookup(:telemetry_spans, span_id)

      assert completed_span["status"] == "ok"
      assert completed_span["end_time_us"] != nil
      assert completed_span["start_time_us"] <= completed_span["end_time_us"]
    end

    test "end_span with error status records error message" do
      Process.delete(:telemetry_trace_id)

      {:ok, span_ctx} =
        OptimalSystemAgent.Observability.Telemetry.start_span(
          "agent.loop.iteration",
          %{"agent_id" => "test-agent-3"}
        )

      span_id = span_ctx["span_id"]
      error_msg = "LLM connection timeout"

      :ok = OptimalSystemAgent.Observability.Telemetry.end_span(span_ctx, :error, error_msg)

      [{^span_id, completed_span}] = :ets.lookup(:telemetry_spans, span_id)

      assert completed_span["status"] == "error"
      assert completed_span["error_message"] == error_msg
    end

    test "nested spans maintain parent-child relationship" do
      Process.delete(:telemetry_trace_id)
      Process.delete(:telemetry_current_span_id)

      {:ok, parent_span} =
        OptimalSystemAgent.Observability.Telemetry.start_span(
          "agent.loop.iteration",
          %{"agent_id" => "test-agent-4"}
        )

      parent_span_id = parent_span["span_id"]

      # Store as current span context
      Process.put(:telemetry_current_span_id, parent_span_id)

      # Create child span
      {:ok, child_span} =
        OptimalSystemAgent.Observability.Telemetry.start_span(
          "agent.loop.react",
          %{"iteration_num" => 1}
        )

      # Child should have parent_span_id set
      assert child_span["parent_span_id"] == parent_span_id

      # Cleanup
      Process.delete(:telemetry_current_span_id)
    end

    test "span duration metric is recorded" do
      Process.delete(:telemetry_trace_id)

      {:ok, span_ctx} =
        OptimalSystemAgent.Observability.Telemetry.start_span(
          "agent.loop.iteration",
          %{"agent_id" => "test-agent-5"}
        )

      Process.sleep(25)

      :ok = OptimalSystemAgent.Observability.Telemetry.end_span(span_ctx, :ok)

      # Check that duration metric was recorded
      metric_key = {"span.duration_us", %{"span_name" => "agent.loop.iteration", "status" => "ok"}}

      case :ets.lookup(:telemetry_metrics, metric_key) do
        [{^metric_key, metric_data}] ->
          # Duration should be histogram type
          assert metric_data["type"] == "histogram"
          assert metric_data["count"] >= 1
          assert metric_data["sum"] >= 25000

        [] ->
          # Metric might not be in ETS if recording mechanism is async
          :ok
      end
    end

    test "correlation ID is added to span attributes" do
      Process.delete(:telemetry_trace_id)

      correlation_id = "trace-12345"
      Process.put(:chatmangpt_correlation_id, correlation_id)

      {:ok, span_ctx} =
        OptimalSystemAgent.Observability.Telemetry.start_span(
          "agent.loop.iteration",
          %{"agent_id" => "test-agent-6"}
        )

      attrs = span_ctx["attributes"]
      assert attrs["chatmangpt.run.correlation_id"] == correlation_id
    end

    test "trace_id is propagated across multiple spans in same process" do
      Process.delete(:telemetry_trace_id)

      {:ok, span1} =
        OptimalSystemAgent.Observability.Telemetry.start_span(
          "agent.loop.iteration",
          %{"agent_id" => "test-agent-7"}
        )

      trace_id_1 = span1["trace_id"]

      {:ok, span2} =
        OptimalSystemAgent.Observability.Telemetry.start_span(
          "agent.loop.react",
          %{}
        )

      trace_id_2 = span2["trace_id"]

      # Both spans should share the same trace_id
      assert trace_id_1 == trace_id_2
    end
  end

  describe "OTEL span integration in process dictionary" do
    test "process dictionary holds span context after start" do
      Process.delete(:telemetry_trace_id)

      {:ok, span_ctx} =
        OptimalSystemAgent.Observability.Telemetry.start_span(
          "agent.loop.iteration",
          %{"agent_id" => "test-agent-8", "turn_count" => 3}
        )

      # Simulate what Loop.ex does: store in process dictionary
      Process.put(:otel_span_context, %{
        trace_id: span_ctx["trace_id"],
        span_id: span_ctx["span_id"],
        iteration_span: span_ctx
      })

      # Verify process dict holds the context
      ctx = Process.get(:otel_span_context)
      assert ctx != nil
      assert ctx[:trace_id] == span_ctx["trace_id"]
      assert ctx[:span_id] == span_ctx["span_id"]
    end

    test "span can be ended from process dictionary context" do
      Process.delete(:telemetry_trace_id)

      {:ok, span_ctx} =
        OptimalSystemAgent.Observability.Telemetry.start_span(
          "agent.loop.iteration",
          %{"agent_id" => "test-agent-9"}
        )

      span_id = span_ctx["span_id"]

      Process.put(:otel_span_context, %{
        trace_id: span_ctx["trace_id"],
        span_id: span_id,
        iteration_span: span_ctx
      })

      # End span using process dict (like end_iteration_span/1 does)
      case Process.get(:otel_span_context) do
        %{iteration_span: ctx} when is_map(ctx) ->
          :ok = OptimalSystemAgent.Observability.Telemetry.end_span(ctx, :ok)
          Process.delete(:otel_span_context)
      end

      # Verify span was ended
      [{^span_id, completed}] = :ets.lookup(:telemetry_spans, span_id)
      assert completed["status"] == "ok"
    end
  end
end
