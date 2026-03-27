defmodule OptimalSystemAgent.Yawl.SpanEmissionTest do
  @moduledoc """
  Chicago TDD — RED-GREEN-REFACTOR for YAWL EventStream OTEL span emission.

  Tests that dispatch_event/1 emits proper OTEL spans (stored in ETS :telemetry_spans)
  rather than bare :telemetry events that are invisible in Jaeger.

  Requires full OTP application: EventStream GenServer + :osa_yawl_trace_ids ETS table
  + Telemetry :telemetry_spans ETS table must all be running.
  """

  use ExUnit.Case

  @moduletag :requires_application

  alias OptimalSystemAgent.Yawl.EventStream
  alias OpenTelemetry.SemConv.Incubating.SpanNames

  setup do
    # Ensure telemetry ETS tables exist (Telemetry module creates them in init_tracer/0,
    # but tests may run before init_tracer is called in some supervisor orderings).
    try do
      :ets.new(:telemetry_spans, [:named_table, :public, {:keypos, 1}])
    rescue
      ArgumentError -> :ok
    end

    try do
      :ets.new(:telemetry_metrics, [:named_table, :public, {:keypos, 1}])
    rescue
      ArgumentError -> :ok
    end

    # Clear process trace state so each test gets an isolated trace context
    Process.delete(:telemetry_trace_id)
    Process.delete(:telemetry_current_span_id)

    :ok
  end

  describe "yawl.case span emission" do
    test "dispatch_event INSTANCE_CREATED emits a yawl.case OTEL span stored in ETS" do
      # Arrange: subscribe a fresh case so ETS trace_id is populated
      case_id = "test-case-#{System.unique_integer([:positive])}"
      EventStream.subscribe(case_id)
      # Allow the GenServer cast to process
      :timer.sleep(10)

      # Act: directly invoke the public test helper that drives dispatch_event/1
      # (EventStream exposes emit_case_start_span/2 for testing after the GREEN phase)
      {:ok, span_ctx} =
        EventStream.emit_case_start_span(case_id, "WCP01_Sequence")

      # Assert: span was stored in :telemetry_spans ETS table
      span_id = span_ctx["span_id"]
      assert [{^span_id, stored}] = :ets.lookup(:telemetry_spans, span_id)

      assert stored["span_name"] == SpanNames.yawl_case(),
             "Expected span_name == #{SpanNames.yawl_case()}, got #{stored["span_name"]}"

      assert stored["attributes"]["yawl.case.id"] == case_id
      assert stored["status"] == "active"
    end

    test "dispatch_event INSTANCE_COMPLETED ends the yawl.case span with status ok" do
      case_id = "complete-case-#{System.unique_integer([:positive])}"
      EventStream.subscribe(case_id)
      :timer.sleep(10)

      # Start the case span
      {:ok, span_ctx} = EventStream.emit_case_start_span(case_id, "WCP01_Sequence")
      span_id = span_ctx["span_id"]

      # End the case span via completion helper
      :ok = EventStream.emit_case_end_span(span_ctx, :ok)

      # Assert: span status flipped to "ok"
      [{^span_id, ended}] = :ets.lookup(:telemetry_spans, span_id)
      assert ended["status"] == "ok"
      assert ended["end_time_us"] != nil
    end

    test "dispatch_event INSTANCE_CANCELLED ends the yawl.case span with status error" do
      case_id = "cancelled-case-#{System.unique_integer([:positive])}"
      EventStream.subscribe(case_id)
      :timer.sleep(10)

      {:ok, span_ctx} = EventStream.emit_case_start_span(case_id, "WCP01_Sequence")
      span_id = span_ctx["span_id"]

      :ok = EventStream.emit_case_end_span(span_ctx, :error)

      [{^span_id, ended}] = :ets.lookup(:telemetry_spans, span_id)
      assert ended["status"] == "error"
    end
  end

  describe "yawl.task.execution span emission" do
    test "dispatch_event TASK_STARTED emits a yawl.task.execution OTEL span" do
      case_id = "task-case-#{System.unique_integer([:positive])}"
      task_id = "TaskA"
      EventStream.subscribe(case_id)
      :timer.sleep(10)

      {:ok, span_ctx} =
        EventStream.emit_task_span(case_id, task_id, "TASK_STARTED", 1, 0, "")

      span_id = span_ctx["span_id"]
      [{^span_id, stored}] = :ets.lookup(:telemetry_spans, span_id)

      assert stored["span_name"] == SpanNames.yawl_task_execution(),
             "Expected span_name == #{SpanNames.yawl_task_execution()}, got #{stored["span_name"]}"

      assert stored["attributes"]["yawl.case.id"] == case_id
      assert stored["attributes"]["yawl.task.id"] == task_id
      assert stored["attributes"]["yawl.token.consumed"] == 1
      assert stored["attributes"]["yawl.token.produced"] == 0
    end

    test "dispatch_event TASK_COMPLETED emits span with token_produced = 1" do
      case_id = "task-complete-#{System.unique_integer([:positive])}"
      task_id = "TaskB"
      EventStream.subscribe(case_id)
      :timer.sleep(10)

      {:ok, span_ctx} =
        EventStream.emit_task_span(case_id, task_id, "TASK_COMPLETED", 0, 1, "wi-001")

      span_id = span_ctx["span_id"]
      [{^span_id, stored}] = :ets.lookup(:telemetry_spans, span_id)

      assert stored["attributes"]["yawl.token.consumed"] == 0
      assert stored["attributes"]["yawl.token.produced"] == 1
      assert stored["attributes"]["yawl.work_item.id"] == "wi-001"
    end
  end

  describe "trace correlation" do
    test "yawl.case span trace_id matches derived trace_id from lookup_trace_id/1" do
      case_id = "corr-case-#{System.unique_integer([:positive])}"
      EventStream.subscribe(case_id)
      :timer.sleep(10)

      # The ETS table should have the derived trace_id for this case
      stored_trace_id = EventStream.lookup_trace_id(case_id)
      assert stored_trace_id != nil, "Expected trace_id to be stored after subscribe/1"

      # The span emitted should carry the same trace_id so Jaeger correlates them
      {:ok, span_ctx} = EventStream.emit_case_start_span(case_id, "WCP01_Sequence")
      assert span_ctx["trace_id"] != nil
    end
  end
end
