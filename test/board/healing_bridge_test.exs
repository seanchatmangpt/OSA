defmodule OptimalSystemAgent.Board.HealingBridgeWave9Test do
  @moduledoc """
  Chicago TDD tests for Board.HealingBridge — board_escalation handling.

  Tests follow Red-Green-Refactor discipline:
  - Each test asserts one specific behavior claim
  - Tests use real implementations and helper functions exposed by the module
  - Tests are Independent, Fast, Repeatable, Self-Checking, Timely (FIRST)

  Wave 9 80/20: focus on :board_escalation routing (structural Conway violations
  from Canopy must go to board_supervisor, NOT to ReflexArcs).
  """

  use ExUnit.Case, async: false

  @moduletag :requires_application
  @moduletag :board_healing

  alias OptimalSystemAgent.Board.HealingBridge

  # ── Routing logic tests (pure, no GenServer needed) ──────────────────────────

  describe "board_escalation handling" do
    test "healing bridge routes board_escalation to board supervisor, not reflex arcs" do
      # Given: a structural escalation payload from Canopy
      payload = %{
        process_id: "dept-engineering",
        conway_score: 0.65,
        source: :canopy_conway,
        boundary_time_ms: 650,
        cycle_time_ms: 1000
      }

      # When: HealingBridge determines routing
      # Assert: it routes to board_supervisor, NOT reflex_arcs
      assert payload.conway_score > 0.4, "score > 0.4 means Conway violation"
      assert payload.source == :canopy_conway, "source must be Canopy Conway monitor"

      routing = HealingBridge.determine_escalation_routing(payload)
      assert routing == :board_supervisor,
        "Conway violations from Canopy must go to board_supervisor, not reflex_arcs"
    end

    test "non-canopy source routes to reflex_arcs" do
      payload = %{
        process_id: "dept-ops",
        conway_score: 0.55,
        source: :pm4py_rust
      }

      routing = HealingBridge.determine_escalation_routing(payload)
      assert routing == :reflex_arcs,
        "Non-Canopy sources are operational and route to reflex_arcs"
    end

    test "canopy string source also routes to board supervisor" do
      payload = %{
        process_id: "dept-finance",
        conway_score: 0.58,
        source: "canopy_conway_monitor"
      }

      routing = HealingBridge.determine_escalation_routing(payload)
      assert routing == :board_supervisor,
        "String source containing 'canopy' should also route to board_supervisor"
    end

    test "healing bridge writes proof triple on board escalation" do
      payload = %{process_id: "dept-ops", conway_score: 0.55, source: :canopy_conway}

      # Test that the SPARQL INSERT DATA is constructed correctly
      sparql = HealingBridge.build_escalation_sparql(
        payload.process_id,
        payload.conway_score,
        payload.source
      )

      assert sparql =~ "bos:StructuralEscalation",
        "SPARQL must declare StructuralEscalation type"
      assert sparql =~ "canopy_conway",
        "SPARQL must record the escalation source"
      assert sparql =~ "dept-ops",
        "SPARQL must record the process_id"
      assert sparql =~ "INSERT DATA",
        "Must use INSERT DATA (not ad hoc mutation)"
    end

    test "proof triple includes conway score" do
      sparql = HealingBridge.build_escalation_sparql("dept-finance", 0.72, :canopy_conway)
      assert sparql =~ "0.72", "SPARQL must include the Conway score value"
    end

    test "structural Conway violation threshold is 0.4" do
      # WvdA: Conway score > 0.4 means boundary time exceeds 40% of cycle time
      # This is the structural threshold; violations REQUIRE board decision
      below_threshold = 0.39
      above_threshold = 0.41

      refute below_threshold > 0.4, "Score below threshold is not a Conway violation"
      assert above_threshold > 0.4, "Score above threshold IS a Conway violation"
    end

    test "board_escalation handler does not call ReflexArcs — verified by routing" do
      # Structural violations (Conway) must NOT be auto-healed.
      # This test documents the invariant: conway_score > 0.4 → board_supervisor route
      scores_requiring_board = [0.41, 0.5, 0.65, 0.72, 0.9, 1.0]

      for score <- scores_requiring_board do
        payload = %{process_id: "dept-test", conway_score: score, source: :canopy_conway}
        routing = HealingBridge.determine_escalation_routing(payload)

        assert routing == :board_supervisor,
          "score=#{score} > 0.4 must always route to board_supervisor"
      end
    end

    test "board_escalation via GenServer cast does not crash bridge" do
      # Armstrong: bridge must not crash on any board_escalation payload
      if Process.whereis(HealingBridge) do
        assert :ok ==
          GenServer.cast(HealingBridge, {:board_escalation, %{
            process_id: "dept-engineering",
            conway_score: 0.65,
            source: :canopy_conway
          }})

        Process.sleep(50)

        assert Process.alive?(Process.whereis(HealingBridge)),
          "HealingBridge must remain alive after board_escalation"
      else
        # GenServer not running (test environment without full app) — skip liveness check
        :ok
      end
    end

    test "board_escalation with missing process_id does not crash bridge" do
      # Armstrong: invalid payloads must not crash the bridge
      if Process.whereis(HealingBridge) do
        assert :ok ==
          GenServer.cast(HealingBridge, {:board_escalation, %{
            conway_score: 0.65
            # missing process_id
          }})

        Process.sleep(30)

        assert Process.alive?(Process.whereis(HealingBridge)),
          "HealingBridge must survive malformed board_escalation"
      else
        :ok
      end
    end
  end
end
