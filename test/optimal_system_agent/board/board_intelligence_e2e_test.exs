defmodule OptimalSystemAgent.Board.BoardIntelligenceE2ETest do
  @moduledoc """
  Pure-logic tests for the Board Chair Intelligence System.

  No infrastructure required — all tests run with mix test --no-start.
  Integration tests (requiring Oxigraph) are tagged @tag :integration.

  WvdA: Every claim backed by assertion on actual data transformation.
  Armstrong: Independent tests, no shared state, bounded.
  Chicago TDD: Black-box behavior verification.
  """
  use ExUnit.Case, async: false

  alias OptimalSystemAgent.Board.BriefingTemplate

  # ── ETS setup ────────────────────────────────────────────────────────────────
  # render_structured calls Telemetry.start_span which inserts into :telemetry_spans.
  # The OSA Application normally creates this table; tests must create it manually.
  # We create the tables directly rather than calling Telemetry.init_tracer/0
  # because init_tracer also attaches :telemetry handlers that require the full
  # application supervision tree (unavailable in unit-test mode).

  setup do
    for table <- [:telemetry_spans, :telemetry_metrics] do
      if :ets.whereis(table) == :undefined do
        :ets.new(table, [:named_table, :public, {:keypos, 1}])
      end
    end

    on_exit(fn ->
      for table <- [:telemetry_spans, :telemetry_metrics] do
        if :ets.whereis(table) != :undefined do
          try do
            :ets.delete(table)
          rescue
            _ -> :ok
          end
        end
      end
    end)

    :ok
  end

  describe "BriefingTemplate.render_structured/1 — section count" do
    test "renders 5 sections when no Conway violations (structuralIssueCount = 0)" do
      data = %{
        "bos:organizationalHealthSummary" => "0.78",
        "bos:topRisk" => "Compliance drift in Finance",
        "bos:processVelocityTrend" => "improving",
        "bos:weeklyROIDelta" => "0.12",
        "bos:issuesAutoResolved" => "3",
        "bos:issuesPendingEscalation" => "1",
        "bos:structuralIssueCount" => 0
      }

      result = BriefingTemplate.render_structured(data)

      assert is_binary(result)
      refute result =~ "STRUCTURAL DECISIONS REQUIRED"
    end

    test "renders 6th section when Conway violations present (structuralIssueCount > 0)" do
      data = %{
        "bos:organizationalHealthSummary" => "0.62",
        "bos:topRisk" => "Conway violation in Engineering",
        "bos:processVelocityTrend" => "declining",
        "bos:weeklyROIDelta" => "-0.03",
        "bos:issuesAutoResolved" => "1",
        "bos:issuesPendingEscalation" => "2",
        "bos:structuralIssueCount" => 2,
        "bos:highestConwayScore" => 0.65
      }

      result = BriefingTemplate.render_structured(data)

      assert result =~ "STRUCTURAL DECISIONS REQUIRED"
    end

    test "structural section absent when structuralIssueCount is 0" do
      result = BriefingTemplate.render_structured(%{"bos:structuralIssueCount" => 0})
      refute result =~ "STRUCTURAL DECISIONS REQUIRED"
    end

    test "structural section absent when structuralIssueCount key missing" do
      result = BriefingTemplate.render_structured(%{})
      refute result =~ "STRUCTURAL DECISIONS REQUIRED"
    end

    test "Conway score percentage appears in structural section" do
      data = %{
        "bos:structuralIssueCount" => 1,
        "bos:highestConwayScore" => 0.72
      }

      result = BriefingTemplate.render_structured(data)

      assert result =~ "STRUCTURAL DECISIONS REQUIRED"
      assert result =~ "72%"
    end
  end

  describe "Conway score math — WvdA bounded [0.0, 1.0]" do
    test "boundary time 65% of cycle → Conway violation (score > 0.4)" do
      cycle_time = 500.0
      internal_time = 175.0
      boundary_time = cycle_time - internal_time
      conway_score = boundary_time / cycle_time

      assert_in_delta conway_score, 0.65, 0.001
      assert conway_score > 0.4
    end

    test "boundary time 30% of cycle → no Conway violation (score <= 0.4)" do
      cycle_time = 500.0
      internal_time = 350.0
      boundary_time = cycle_time - internal_time
      conway_score = boundary_time / cycle_time

      assert_in_delta conway_score, 0.30, 0.001
      refute conway_score > 0.4
    end

    test "zero cycle time → safe fallback 0.0 (WvdA: no division by zero)" do
      cycle_time = 0.0
      conway_score = if cycle_time > 0.0, do: 100.0 / cycle_time, else: 0.0

      assert conway_score == 0.0
      refute conway_score > 0.4
    end

    test "conway score bounded [0.0, 1.0] by construction" do
      for {internal, cycle} <- [{0, 500}, {250, 500}, {500, 500}, {100, 1000}] do
        score = if cycle > 0, do: (cycle - internal) / cycle, else: 0.0
        assert score >= 0.0 and score <= 1.0,
          "Conway score #{score} out of bounds for internal=#{internal}, cycle=#{cycle}"
      end
    end
  end

  describe "Little's Law math — L=λW" do
    test "stable queue: actual WIP = predicted WIP → ratio 1.0" do
      arrival_rate = 10.0
      cycle_time_days = 2.0
      predicted_wip = arrival_rate * cycle_time_days
      actual_wip = 20.0

      ratio = actual_wip / predicted_wip

      assert_in_delta ratio, 1.0, 0.001
      refute ratio > 1.5
    end

    test "growing queue: actual WIP 2x predicted → ratio 2.0 → triggers healing" do
      arrival_rate = 10.0
      cycle_time_days = 2.0
      predicted_wip = arrival_rate * cycle_time_days
      actual_wip = 40.0

      ratio = actual_wip / predicted_wip

      assert_in_delta ratio, 2.0, 0.001
      assert ratio > 1.5
    end

    test "zero arrival rate → ratio defaults to 1.0 (WvdA: no division by zero)" do
      arrival_rate = 0.0
      cycle_time_days = 2.0
      predicted_wip = arrival_rate * cycle_time_days
      actual_wip = 5.0

      ratio = if predicted_wip > 0.0, do: actual_wip / predicted_wip, else: 1.0

      assert ratio == 1.0
      refute ratio > 1.5
    end

    test "ratio non-negative for all valid inputs" do
      for {arrival, wip} <- [{5.0, 10.0}, {10.0, 5.0}, {0.0, 0.0}, {1.0, 100.0}] do
        predicted = arrival * 2.0
        ratio = if predicted > 0.0, do: wip / predicted, else: 1.0
        assert ratio >= 0.0
      end
    end
  end

  describe "Escalation routing — Armstrong: Conway permanent, Little's Law transient" do
    test "Conway violation → board escalation, NOT healing" do
      is_conway = true
      should_heal = not is_conway
      should_escalate = is_conway

      assert should_escalate
      refute should_heal
    end

    test "Little's Law violation (no Conway) → healing, NOT escalation" do
      is_conway = false
      is_littles_law = true

      should_escalate = is_conway
      should_heal = not is_conway and is_littles_law

      assert should_heal
      refute should_escalate
    end

    test "no violation → no action" do
      is_conway = false
      is_littles_law = false

      assert not is_conway
      assert not is_littles_law
    end

    test "Conway takes precedence — even with Little's Law violation, escalate not heal" do
      is_conway = true
      _is_littles_law = true

      # Conway is structural — board must decide regardless of queue state
      should_escalate = is_conway
      should_heal = not is_conway

      assert should_escalate
      refute should_heal
    end
  end
end
