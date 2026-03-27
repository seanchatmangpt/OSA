defmodule OptimalSystemAgent.Healing.SpanEmissionTest do
  @moduledoc """
  Chicago TDD — RED-GREEN-REFACTOR for OTEL span emission in the healing domain.

  Verifies three healing spans land in the :telemetry_spans ETS table with the
  correct span names and semconv attributes defined in OtelBridge / SpanNames.

  Armstrong rule: NO try/rescue in production code around ETS calls. If the
  :telemetry_spans table is missing, the process crashes and the supervisor
  recreates it. The setup below initialises the table exactly as
  loop_iteration_spans_test.exs does — acceptable in test setup only.
  """
  use ExUnit.Case

  alias OptimalSystemAgent.Observability.Telemetry
  alias OptimalSystemAgent.Healing.Diagnosis
  alias OptimalSystemAgent.Healing.ReflexArcs

  # ---- ETS setup (mirrors loop_iteration_spans_test.exs) --------------------

  setup do
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

    # Clear any spans left over from previous tests so each test sees only its own.
    :ets.delete_all_objects(:telemetry_spans)
    :ets.delete_all_objects(:telemetry_metrics)

    # Fresh trace context for every test
    Process.delete(:telemetry_trace_id)
    Process.delete(:telemetry_current_span_id)

    :ok
  end

  # ---- helpers ---------------------------------------------------------------

  # Scan all spans in :telemetry_spans and return every span whose name matches.
  defp spans_with_name(span_name) do
    :ets.tab2list(:telemetry_spans)
    |> Enum.map(fn {_id, span} -> span end)
    |> Enum.filter(fn span -> span["span_name"] == span_name end)
  end

  # ---- Diagnosis.classify/1 span -------------------------------------------

  describe "Diagnosis.classify/1 span emission" do
    test "emits healing.diagnosis span with healing.failure_mode attribute" do
      # RED: this fails until classify/1 is added to Diagnosis and emits a span
      failure = {:error, :circular_wait}

      {:ok, result} = Diagnosis.classify(failure)

      # Span must be in ETS
      spans = spans_with_name("healing.diagnosis")
      assert length(spans) >= 1,
             "expected at least one 'healing.diagnosis' span in :telemetry_spans, got 0"

      span = List.first(spans)
      attrs = span["attributes"]

      assert attrs["healing.failure_mode"] == "deadlock",
             "expected healing.failure_mode == 'deadlock', got #{inspect(attrs["healing.failure_mode"])}"

      # Result must carry the mode and a confidence score
      assert result.failure_mode == :deadlock
      assert result.confidence >= 0.7
    end

    test "emits healing.diagnosis span for timeout failure mode" do
      {:ok, result} = Diagnosis.classify({:error, :timeout})

      spans = spans_with_name("healing.diagnosis")
      assert length(spans) >= 1

      span = List.first(spans)
      attrs = span["attributes"]

      assert attrs["healing.failure_mode"] == "timeout"
      assert result.failure_mode == :timeout
    end

    test "span is stored in ETS with status ok after successful classify" do
      {:ok, _result} = Diagnosis.classify({:error, :livelock})

      spans = spans_with_name("healing.diagnosis")
      assert length(spans) >= 1

      span = List.first(spans)
      # end_span sets status to "ok"
      assert span["status"] == "ok",
             "expected span status 'ok', got #{inspect(span["status"])}"
    end

    test "span carries healing.agent_id attribute" do
      {:ok, _result} = Diagnosis.classify(:starvation)

      spans = spans_with_name("healing.diagnosis")
      assert length(spans) >= 1

      span = List.first(spans)
      attrs = span["attributes"]

      assert attrs["healing.agent_id"] == "osa"
    end
  end

  # ---- ReflexArcs.detect_cascade/2 span ------------------------------------

  describe "ReflexArcs.detect_cascade/2 span emission" do
    test "emits healing.reflex_arc span when cascade check passes" do
      :ok = ReflexArcs.detect_cascade_with_span([], "reflex_a")

      spans = spans_with_name("healing.reflex_arc")
      assert length(spans) >= 1,
             "expected at least one 'healing.reflex_arc' span, got 0"

      span = List.first(spans)
      attrs = span["attributes"]
      assert attrs["healing.recovery_action"] == "reflex_a"
    end

    test "emits healing.reflex_arc span when cascade is detected" do
      {:error, :cascade_detected} = ReflexArcs.detect_cascade_with_span(["reflex_a"], "reflex_a")

      spans = spans_with_name("healing.reflex_arc")
      assert length(spans) >= 1

      span = List.first(spans)
      assert span["status"] in ["ok", "error"]
    end

    test "emits healing.reflex_arc span with healing.iteration attribute" do
      :ok = ReflexArcs.detect_cascade_with_span(["reflex_a", "reflex_b"], "reflex_c")

      spans = spans_with_name("healing.reflex_arc")
      assert length(spans) >= 1

      span = List.first(spans)
      attrs = span["attributes"]

      # iteration = current chain depth
      assert is_integer(attrs["healing.iteration"]) or
               is_binary(attrs["healing.iteration"]),
             "expected healing.iteration to be present in span attributes"
    end
  end

  # ---- Telemetry baseline sanity check -------------------------------------

  describe "Telemetry module baseline" do
    test "start_span / end_span round-trip stores span in ETS with ok status" do
      {:ok, span_ctx} =
        Telemetry.start_span("healing.diagnosis", %{
          "healing.failure_mode" => "deadlock",
          "healing.agent_id" => "osa"
        })

      span_id = span_ctx["span_id"]
      :ok = Telemetry.end_span(span_ctx, :ok)

      [{^span_id, stored}] = :ets.lookup(:telemetry_spans, span_id)
      assert stored["span_name"] == "healing.diagnosis"
      assert stored["status"] == "ok"
      assert stored["attributes"]["healing.failure_mode"] == "deadlock"
    end
  end
end
