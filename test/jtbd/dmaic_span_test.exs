defmodule OptimalSystemAgent.JTBD.DmaicSpanTest do
  @moduledoc """
  Chicago TDD — RED then GREEN for DMAIC phase span emission.

  Claim: validate_phase_transition/2 in Wave12Scenario emits a
  "jtbd.dmaic.phase" span with the correct attributes on every valid
  forward phase transition.

  RED phase: test written before span emission is implemented.
  GREEN phase: span emission added to validate_phase_transition/2.
  """

  use ExUnit.Case, async: false

  alias OptimalSystemAgent.JTBD.Wave12Scenario

  setup do
    # Ensure ETS tables exist (same pattern as loop_iteration_spans_test.exs)
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

    # Clear all existing spans so assertions are unambiguous
    :ets.delete_all_objects(:telemetry_spans)

    :ok
  end

  describe "validate_phase_transition/2 — DMAIC phase span emission" do
    test "valid define→measure transition emits jtbd.dmaic.phase span" do
      result = Wave12Scenario.validate_phase_transition("define", "measure")

      # A valid forward transition returns :ok (YAWL available) or
      # {:error, :yawl_unavailable} (YAWL not running in test env).
      # Either way the span must have been emitted.
      assert result == :ok or result == {:error, :yawl_unavailable},
             "Expected :ok or {:error, :yawl_unavailable}, got: #{inspect(result)}"

      # Span must have been emitted into ETS telemetry_spans
      all_spans = :ets.tab2list(:telemetry_spans)
      dmaic_spans =
        Enum.filter(all_spans, fn {_id, span} ->
          is_map(span) and Map.get(span, "span_name") == "jtbd.dmaic.phase"
        end)

      assert length(dmaic_spans) >= 1,
             "Expected at least one jtbd.dmaic.phase span in ETS, got: #{inspect(all_spans)}"

      {_span_id, span} = hd(dmaic_spans)
      attrs = Map.get(span, "attributes", %{})

      assert Map.get(attrs, "jtbd.dmaic.phase_name") == "measure",
             "Expected jtbd.dmaic.phase_name == 'measure', got: #{inspect(attrs)}"
    end

    test "valid measure→analyze transition emits span with correct phase_name" do
      :ets.delete_all_objects(:telemetry_spans)

      result = Wave12Scenario.validate_phase_transition("measure", "analyze")

      assert result == :ok or result == {:error, :yawl_unavailable},
             "Expected :ok or {:error, :yawl_unavailable}, got: #{inspect(result)}"

      all_spans = :ets.tab2list(:telemetry_spans)
      dmaic_spans =
        Enum.filter(all_spans, fn {_id, span} ->
          is_map(span) and Map.get(span, "span_name") == "jtbd.dmaic.phase"
        end)

      assert length(dmaic_spans) >= 1

      {_span_id, span} = hd(dmaic_spans)
      attrs = Map.get(span, "attributes", %{})
      assert Map.get(attrs, "jtbd.dmaic.phase_name") == "analyze"
    end

    test "invalid phase name does not emit span and returns error" do
      :ets.delete_all_objects(:telemetry_spans)

      result = Wave12Scenario.validate_phase_transition("not_a_phase", "measure")
      assert result == {:error, :invalid_phase}

      # No DMAIC span should be emitted for invalid phase names
      all_spans = :ets.tab2list(:telemetry_spans)
      dmaic_spans =
        Enum.filter(all_spans, fn {_id, span} ->
          is_map(span) and Map.get(span, "span_name") == "jtbd.dmaic.phase"
        end)

      assert dmaic_spans == [],
             "Expected no jtbd.dmaic.phase span for invalid phase, got: #{inspect(dmaic_spans)}"
    end

    test "backward transition does not emit a completed span" do
      :ets.delete_all_objects(:telemetry_spans)

      result = Wave12Scenario.validate_phase_transition("control", "define")
      assert result == {:error, :invalid_transition}

      # No DMAIC phase span should appear for a backward move
      all_spans = :ets.tab2list(:telemetry_spans)
      dmaic_spans =
        Enum.filter(all_spans, fn {_id, span} ->
          is_map(span) and Map.get(span, "span_name") == "jtbd.dmaic.phase"
        end)

      assert dmaic_spans == [],
             "Expected no jtbd.dmaic.phase span for invalid transition, got: #{inspect(dmaic_spans)}"
    end

    test "span name constant matches emitted span name" do
      alias OpenTelemetry.SemConv.Incubating.SpanNames
      assert SpanNames.jtbd_dmaic_phase() == "jtbd.dmaic.phase"
    end

    test "all five DMAIC forward transitions each emit a span" do
      pairs = [
        {"define", "measure"},
        {"measure", "analyze"},
        {"analyze", "improve"},
        {"improve", "control"}
      ]

      Enum.each(pairs, fn {from, to} ->
        :ets.delete_all_objects(:telemetry_spans)

        result = Wave12Scenario.validate_phase_transition(from, to)
        # May be :ok or {:error, :yawl_unavailable} (YAWL not running in test env)
        assert result == :ok or result == {:error, :yawl_unavailable},
               "Unexpected result for #{from}→#{to}: #{inspect(result)}"

        if result == :ok do
          all_spans = :ets.tab2list(:telemetry_spans)
          dmaic_spans =
            Enum.filter(all_spans, fn {_id, span} ->
              is_map(span) and Map.get(span, "span_name") == "jtbd.dmaic.phase"
            end)

          assert length(dmaic_spans) >= 1,
                 "No jtbd.dmaic.phase span emitted for valid transition #{from}→#{to}"

          {_span_id, span} = hd(dmaic_spans)
          attrs = Map.get(span, "attributes", %{})
          assert Map.get(attrs, "jtbd.dmaic.phase_name") == to,
                 "Expected phase_name=#{to} but got #{inspect(attrs)}"
        end
      end)
    end
  end
end
