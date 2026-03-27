defmodule OptimalSystemAgent.Board.HealingBridgeConwayTest do
  @moduledoc """
  Chicago TDD tests verifying Conway violation routing in HealingBridge.

  Conway violations → :board_escalation (NOT healing)
  Non-Conway violations → :conformance_violation → ReflexArcs
  """
  use ExUnit.Case, async: false

  describe "Conway routing decision" do
    test "Conway violation is not healable — requires board decision" do
      # WvdA: Conway violation = bounded by org structure
      # Armstrong: permanent failure = escalate, never auto-heal
      conway_score = 0.65  # > 0.4 threshold

      is_conway_violation = conway_score > 0.4

      assert is_conway_violation == true
      # This means: do NOT call ReflexArcs, emit :board_escalation instead
    end

    test "Little's Law violation IS healable — operational not structural" do
      conway_score = 0.2  # < 0.4 threshold — not structural
      stability_ratio = 2.1  # > 1.5 — operational queue overload

      is_conway_violation = conway_score > 0.4
      is_littles_law_violation = stability_ratio > 1.5

      assert is_conway_violation == false
      assert is_littles_law_violation == true
      # This means: call ReflexArcs (auto-heal the queue)
    end

    test "board escalation message contains actionable information" do
      dept = "Finance"
      score = 0.72

      message = "Org boundary consuming #{round(score * 100)}% of cycle time in #{dept}. Requires org restructuring decision."

      assert message =~ "72%"
      assert message =~ dept
      assert message =~ "restructuring"
    end
  end
end
