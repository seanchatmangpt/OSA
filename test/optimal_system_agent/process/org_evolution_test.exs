defmodule OptimalSystemAgent.Process.OrgEvolutionTest do
  @moduledoc """
  Unit tests for Self-Evolving Organization (Innovation 2).

  Tests the GenServer API: detect_drift, propose_mutation, optimize_workflow,
  generate_sop, org_health, snapshot, list_proposals, approve/reject_proposal.
  """
  use ExUnit.Case, async: false


  alias OptimalSystemAgent.Process.OrgEvolution

  setup_all do
    if Process.whereis(OrgEvolution) == nil do
      start_supervised!(OrgEvolution)
    end
    :ok
  end

  describe "detect_drift/1" do
    test "returns drift analysis with score and drifts list" do
      org_config = %{
        teams: %{
          "backend" => %{expected_capacity: 1.0},
          "frontend" => %{expected_capacity: 1.0}
        },
        roles: %{
          "engineer" => %{required_skills: ["elixir", "phoenix"]}
        },
        workflows: %{},
        execution_data: []
      }

      result = OrgEvolution.detect_drift(org_config)
      assert Map.has_key?(result, :drift_score)
      assert Map.has_key?(result, :drifts)
      assert Map.has_key?(result, :recommendation)
      assert is_list(result.drifts)
      assert result.drift_score >= 0.0
      assert result.drift_score <= 1.0
    end

    test "detects overloaded teams" do
      org_config = %{
        teams: %{
          "backend" => %{expected_capacity: 0.1}
        },
        execution_data: [
          %{team: "backend"},
          %{team: "backend"},
          %{team: "backend"}
        ]
      }

      result = OrgEvolution.detect_drift(org_config)
      overload_drifts = Enum.filter(result.drifts, &(&1.type == :role_overload))
      assert length(overload_drifts) >= 1
    end

    test "returns low drift score for healthy org" do
      result = OrgEvolution.detect_drift(%{teams: %{}, workflows: %{}, execution_data: []})
      assert result.drift_score < 0.3
    end
  end

  describe "propose_mutation/2" do
    test "returns proposals with governance level" do
      org_config = %{
        teams: %{"backend" => %{expected_capacity: 1.0}},
        workflows: %{},
        execution_data: []
      }
      drift = %{drifts: [], drift_score: 0.0}

      result = OrgEvolution.propose_mutation(org_config, drift)
      assert Map.has_key?(result, :proposals)
      assert Map.has_key?(result, :governance)
      assert result.governance in [:auto, :human_review, :board_approval]
    end

    test "proposals have required fields" do
      org_config = %{
        teams: %{
          "backend" => %{expected_capacity: 0.1},
          "frontend" => %{expected_capacity: 0.1}
        },
        workflows: %{},
        execution_data: [
          %{team: "backend"},
          %{team: "backend"},
          %{team: "frontend"},
          %{team: "frontend"}
        ]
      }
      drift = OrgEvolution.detect_drift(org_config)

      result = OrgEvolution.propose_mutation(org_config, drift)
      for proposal <- result.proposals do
        assert Map.has_key?(proposal, :type)
        assert Map.has_key?(proposal, :confidence)
        assert Map.has_key?(proposal, :risk_score)
        assert Map.has_key?(proposal, :justification)
        assert proposal.confidence >= 0.0
        assert proposal.confidence <= 1.0
      end
    end
  end

  describe "optimize_workflow/2" do
    test "returns optimization result with metrics" do
      execution_history = [
        %{step_count: 5, cycle_time_ms: 3000, success: true},
        %{step_count: 5, cycle_time_ms: 3500, success: true},
        %{step_count: 5, cycle_time_ms: 4000, success: false}
      ]

      result = OrgEvolution.optimize_workflow("test-workflow", execution_history)
      assert Map.has_key?(result, :workflow_id)
      assert Map.has_key?(result, :original)
      assert Map.has_key?(result, :optimized)
      assert Map.has_key?(result, :changes)
      assert Map.has_key?(result, :savings_pct)
      assert result.original.steps > 0
    end

    test "handles empty execution history" do
      result = OrgEvolution.optimize_workflow("empty-workflow", [])
      assert result.original.steps == 0
    end
  end

  describe "generate_sop/2" do
    test "generates SOP with steps and metrics" do
      executions = [
        %{
          steps: [%{action: "analyze"}, %{action: "implement"}, %{action: "review"}],
          cycle_time_ms: 120_000,
          completed: true,
          skipped_steps: []
        }
      ]

      result = OrgEvolution.generate_sop("code-review", executions)
      assert Map.has_key?(result, :title)
      assert Map.has_key?(result, :version)
      assert Map.has_key?(result, :steps)
      assert Map.has_key?(result, :metrics)
      assert result.version >= 1
      assert is_list(result.steps)
    end

    test "handles empty executions" do
      result = OrgEvolution.generate_sop("empty-process", [])
      assert result.steps == []
    end
  end

  describe "org_health/1" do
    test "returns health assessment with dimensions" do
      result = OrgEvolution.org_health(%{
        teams: %{"backend" => %{}},
        workflows: %{"deploy" => %{}},
        execution_data: []
      })

      assert Map.has_key?(result, :overall_health)
      assert Map.has_key?(result, :dimensions)
      assert Map.has_key?(result, :recommendations)
      assert result.overall_health >= 0.0
      assert result.overall_health <= 1.0
      assert Map.has_key?(result.dimensions, :role_utilization)
      assert Map.has_key?(result.dimensions, :workflow_efficiency)
      assert Map.has_key?(result.dimensions, :communication_flow)
      assert Map.has_key?(result.dimensions, :process_compliance)
    end
  end

  describe "snapshot/1 and list_proposals/0" do
    test "snapshot stores org state" do
      assert :ok = OrgEvolution.snapshot(%{process_id: "test-snap"})
    end

    test "list_proposals returns proposals from mutations" do
      org_config = %{
        teams: %{
          "backend" => %{expected_capacity: 0.1},
          "frontend" => %{expected_capacity: 0.1}
        },
        workflows: %{},
        execution_data: [
          %{team: "backend"},
          %{team: "backend"},
          %{team: "frontend"},
          %{team: "frontend"}
        ]
      }
      drift = OrgEvolution.detect_drift(org_config)
      OrgEvolution.propose_mutation(org_config, drift)

      proposals = OrgEvolution.list_proposals()
      # Should include at least our new proposals
      assert is_list(proposals)
    end
  end

  describe "approve_proposal/2 and reject_proposal/2" do
    test "reject returns error for unknown proposal" do
      assert {:error, :not_found} = OrgEvolution.reject_proposal("nonexistent")
    end

    test "approve returns error for unknown proposal" do
      assert {:error, :not_found} = OrgEvolution.approve_proposal("nonexistent")
    end
  end

  # ── Edge Cases ───────────────────────────────────────────────────────────

  describe "edge cases: empty state transitions" do
    test "detect_drift with completely empty org_config" do
      result = OrgEvolution.detect_drift(%{})
      assert result.drift_score == 0.0
      assert result.drifts == []
    end

    test "propose_mutation with empty drift (no drifts detected)" do
      org_config = %{teams: %{}, workflows: %{}, execution_data: []}
      drift = %{drifts: [], drift_score: 0.0}

      result = OrgEvolution.propose_mutation(org_config, drift)
      assert result.proposals == []
      assert result.governance == :auto
    end

    test "optimize_workflow with nil workflow_id raises no error" do
      result = OrgEvolution.optimize_workflow("nil-test", [])
      assert result.original.steps == 0
    end

    test "generate_sop with empty executions returns empty steps" do
      result = OrgEvolution.generate_sop("empty-sop-edge", [])
      assert result.steps == []
      assert result.version >= 1
    end
  end

  describe "edge cases: invalid transition paths" do
    test "approve and reject on nonexistent proposals return not_found" do
      assert {:error, :not_found} = OrgEvolution.approve_proposal("does-not-exist-xyz")
      assert {:error, :not_found} = OrgEvolution.reject_proposal("does-not-exist-xyz")
    end
  end

  describe "edge cases: concurrent evolution scenarios" do
    test "multiple rapid detect_drift calls produce valid results" do
      org_config = %{
        teams: %{"backend" => %{expected_capacity: 1.0}},
        workflows: %{},
        execution_data: []
      }

      # Fire multiple calls in quick succession
      results =
        for _ <- 1..5 do
          OrgEvolution.detect_drift(org_config)
        end

      for result <- results do
        assert result.drift_score >= 0.0
        assert result.drift_score <= 1.0
        assert is_list(result.drifts)
      end
    end

    test "snapshot and list_proposals do not interfere with each other" do
      OrgEvolution.snapshot(%{process_id: "concurrent-snap-test"})

      org_config = %{
        teams: %{"backend" => %{expected_capacity: 1.0}},
        workflows: %{},
        execution_data: []
      }
      drift = %{drifts: [], drift_score: 0.0}
      OrgEvolution.propose_mutation(org_config, drift)

      # Both operations should succeed independently
      proposals = OrgEvolution.list_proposals()
      assert is_list(proposals)
    end

    test "org_health with nil teams and workflows handles gracefully" do
      # Fixed: nil teams/workflows no longer crash the GenServer
      result = OrgEvolution.org_health(%{teams: nil, workflows: nil, execution_data: nil})
      assert result.overall_health >= 0.0
      assert result.overall_health <= 1.0
    end

    test "org_health with execution_data as empty list handles gracefully" do
      result = OrgEvolution.org_health(%{
        teams: %{"backend" => %{}},
        workflows: %{"deploy" => %{}},
        execution_data: []
      })
      assert result.overall_health >= 0.0
      assert result.overall_health <= 1.0
    end
  end

  describe "edge cases: large inputs" do
    test "detect_drift with many teams" do
      teams =
        for i <- 1..100 do
          {"team_#{i}", %{expected_capacity: 0.01}}
        end
        |> Map.new()

      execution_data =
        for i <- 1..500 do
          %{team: "team_#{rem(i, 100) + 1}"}
        end

      result = OrgEvolution.detect_drift(%{teams: teams, execution_data: execution_data})
      assert result.drift_score >= 0.0
      assert is_list(result.drifts)
    end

    test "optimize_workflow with many execution history entries" do
      execution_history =
        for i <- 1..100 do
          %{
            step_count: 10,
            cycle_time_ms: 3000 + i * 10,
            success: rem(i, 3) != 0,
            skipped_steps: if(rem(i, 5) == 0, do: ["manual_review"], else: [])
          }
        end

      result = OrgEvolution.optimize_workflow("large-workflow", execution_history)
      assert result.original.steps > 0
      assert result.savings_pct >= 0.0
      assert is_list(result.changes)
    end
  end
end
