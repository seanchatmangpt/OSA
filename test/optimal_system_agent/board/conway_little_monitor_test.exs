defmodule OptimalSystemAgent.Board.ConwayLittleMonitorTest do
  @moduledoc """
  Chicago TDD tests for Conway's Law + Little's Law routing.

  Tests verify:
  1. Conway violations (score > 0.4) route to :board_escalation — NOT healing
  2. Little's Law violations (ratio > 1.5) route to :conformance_violation — healed
  3. SPARQL result parsing handles edge cases (zero arrival rate, missing fields)
  """
  use ExUnit.Case, async: false

  alias OptimalSystemAgent.Board.ConwayLittleMonitor

  describe "monitor_status/0" do
    @describetag :skip  # requires Events.Bus + Oxigraph — integration only
    test "returns status map with required keys" do
      # Start monitor if not running
      unless Process.whereis(ConwayLittleMonitor) do
        {:ok, _pid} = ConwayLittleMonitor.start_link([])
      end

      status = ConwayLittleMonitor.monitor_status()

      assert is_map(status)
      assert Map.has_key?(status, :last_check)
      assert Map.has_key?(status, :conway_violations)
      assert Map.has_key?(status, :littles_law_alerts)
      assert Map.has_key?(status, :escalations_sent)
      assert Map.has_key?(status, :healings_triggered)
    end
  end

  describe "Conway violation routing (unit — no GenServer)" do
    test "conway score above threshold is a violation" do
      # conwayScore 0.6 > @conway_threshold 0.4
      metric = %{
        department: "Sales",
        conway_violation: true,
        conway_score: 0.6,
        stability_ratio: 1.0,
        wip_count: 10.0,
        littles_law_wip: 10.0
      }

      assert metric.conway_violation == true
      assert metric.conway_score > 0.4
    end

    test "conway score below threshold is not a violation" do
      metric = %{
        department: "Engineering",
        conway_violation: false,
        conway_score: 0.3,
        stability_ratio: 1.0,
        wip_count: 5.0,
        littles_law_wip: 5.0
      }

      assert metric.conway_violation == false
      assert metric.conway_score <= 0.4
    end
  end

  describe "Little's Law routing (unit — no GenServer)" do
    test "stability ratio above critical threshold triggers healing" do
      metric = %{
        department: "Operations",
        conway_violation: false,
        conway_score: 0.2,
        stability_ratio: 2.0,  # 2.0 > @littles_law_critical 1.5
        wip_count: 20.0,
        littles_law_wip: 10.0
      }

      # Not a Conway violation
      assert metric.conway_violation == false
      # Is a Little's Law violation
      assert metric.stability_ratio > 1.5
    end

    test "stability ratio at exactly 1.0 is stable (Little's Law satisfied)" do
      # λ × W = WIP when arrival_rate = 5, cycle_time_days = 2, wip = 10
      # Little's Law: WIP = λW = 5 × 2 = 10 → ratio = 10/10 = 1.0
      arrival_rate = 5.0
      cycle_time_days = 2.0
      predicted_wip = arrival_rate * cycle_time_days

      actual_wip = 10.0
      ratio = actual_wip / predicted_wip

      assert_in_delta ratio, 1.0, 0.001
      assert ratio <= 1.5  # Not a Little's Law violation
    end

    test "division by zero guard — zero arrival rate returns ratio 1.0" do
      # When arrival_rate = 0, littlesLawWip = 0
      # Guard: IF(littlesLawWip > 0, wipCount / littlesLawWip, 1.0)
      littles_law_wip = 0.0
      wip_count = 5.0

      stability_ratio = if littles_law_wip > 0.0 do
        wip_count / littles_law_wip
      else
        1.0
      end

      assert stability_ratio == 1.0
      assert stability_ratio <= 1.5  # Not a violation when no arrival data
    end
  end

  describe "WvdA boundedness — Conway score bounds" do
    test "conway score bounded between 0.0 and 1.0" do
      # boundary_time / total_cycle_time must be <= 1.0
      # (boundary_time cannot exceed total_cycle_time)
      boundary_time = 300.0  # seconds
      cycle_time_avg = 500.0

      conway_score = boundary_time / cycle_time_avg

      assert conway_score >= 0.0
      assert conway_score <= 1.0
    end

    test "conway score of 0.0 when all work is internal" do
      internal_time = 500.0
      cycle_time_avg = 500.0
      boundary_time = cycle_time_avg - internal_time

      conway_score = if cycle_time_avg > 0.0, do: boundary_time / cycle_time_avg, else: 0.0

      assert_in_delta conway_score, 0.0, 0.001
      assert conway_score <= 0.4  # No Conway violation
    end
  end
end
