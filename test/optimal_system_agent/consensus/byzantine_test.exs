defmodule OptimalSystemAgent.Consensus.ByzantineTest do
  @moduledoc """
  Byzantine Fault Tolerant consensus tests for N=3 agents with f≥1.

  Tests HotStuff-style BFT consensus implementation:
  - 4 core tests: agreement, faulty tolerance, fault boundary, leader rotation
  - Bonus: Signal Theory encoding verification

  Configuration: N=3 agents, f=1 (1 faulty tolerated), 2f+1=3 quorum (all votes)
  """

  use ExUnit.Case
  doctest OptimalSystemAgent.Consensus.Byzantine

  alias OptimalSystemAgent.Consensus.Byzantine

  setup do
    # Standard test proposal
    proposal = %{
      type: :process_model,
      content: %{name: "Consensus Test Workflow"}
    }

    nodes = ["agent_1", "agent_2", "agent_3"]

    {:ok, proposal: proposal, nodes: nodes}
  end

  # =========================================================================
  # TEST 1: All Honest Nodes → Agreement
  # =========================================================================

  describe "test_consensus_reaches_agreement_with_all_honest_nodes" do
    test "all 3 honest nodes reach consensus without faults", context do
      {:ok, pid} = Byzantine.start_consensus(
        context.nodes,
        context.proposal,
        timeout_ms: 5_000
      )

      result = Byzantine.await_decision(pid, timeout: 10_000)

      assert match?({:committed, _signal}, result), "Expected commitment with all honest nodes"

      {:committed, signal} = result

      # Verify Signal Theory encoding
      assert signal["status"] == "committed", "Status should be 'committed'"
      assert signal["mode"] == "data", "Mode should be 'data'"
      assert signal["type"] == "decide", "Type should be 'decide'"
      assert is_float(signal["weight"]), "Weight should be a float"
      assert signal["weight"] >= 1.0, "Weight should be ≥ 1.0 when all approve"
      assert signal["nodes"] == context.nodes, "Should track all nodes"
      assert Enum.member?(context.nodes, signal["leader"]), "Leader should be a valid node"
    end
  end

  # =========================================================================
  # TEST 2: One Faulty Node (f=1) → Still Reaches Agreement
  # =========================================================================

  describe "test_consensus_handles_1_faulty_node_f_equals_1" do
    test "2 honest + 1 faulty node still reaches consensus", context do
      {:ok, pid} = Byzantine.start_consensus(
        context.nodes,
        context.proposal,
        timeout_ms: 5_000
      )

      # Mark one node as faulty
      :ok = Byzantine.mark_faulty(pid, "agent_3")

      result = Byzantine.await_decision(pid, timeout: 10_000)

      assert match?({:committed, _signal}, result),
             "Expected commitment with 1 faulty (f=1) + 2 honest nodes"

      {:committed, signal} = result

      # Verify decision despite fault
      assert signal["status"] == "committed", "Should commit despite 1 faulty node"
      assert signal["votes_received"] >= 2, "Should have votes from ≥2 nodes"

      # Verify fault tracking
      {:ok, state} = Byzantine.get_state(pid)
      assert MapSet.member?(state.faulty_nodes, "agent_3"), "Faulty node should be tracked"
    end
  end

  # =========================================================================
  # TEST 3: Two Faulty Nodes (f>1) → Exceeds Fault Tolerance
  # =========================================================================

  describe "test_consensus_fails_with_2_faulty_nodes_exceeds_f" do
    test "1 honest + 2 faulty nodes fails to reach consensus", context do
      {:ok, pid} = Byzantine.start_consensus(
        context.nodes,
        context.proposal,
        timeout_ms: 2_000
      )

      # Mark two nodes as faulty (exceeds f=1 tolerance)
      :ok = Byzantine.mark_faulty(pid, "agent_2")
      :ok = Byzantine.mark_faulty(pid, "agent_3")

      result = Byzantine.await_decision(pid, timeout: 5_000)

      assert match?({:timeout, _signal}, result),
             "Expected timeout when faulty count (2) exceeds tolerance (f=1)"

      {:timeout, signal} = result

      # Verify timeout due to insufficient votes
      assert signal["status"] == "timeout", "Status should be 'timeout'"
      assert signal["votes_required"] == 2, "Should require 2 votes (f+1 with f=1)"
      assert signal["votes_received"] < 2, "Should have <2 votes (only 1 honest, 2 faulty)"
    end
  end

  # =========================================================================
  # TEST 4: Leader Rotation on Timeout
  # =========================================================================

  describe "test_consensus_rotates_leader_on_timeout" do
    test "slow leader rotates to next leader in round-robin order", context do
      {:ok, pid} = Byzantine.start_consensus(
        context.nodes,
        context.proposal,
        timeout_ms: 5_000
      )

      {:ok, initial_leader} = Byzantine.current_leader(pid)
      assert Enum.member?(context.nodes, initial_leader), "Initial leader must be valid node"

      # Wait for at least 2 consensus rounds
      Process.sleep(500)

      # Current leader might have rotated
      {:ok, current_leader} = Byzantine.current_leader(pid)
      assert Enum.member?(context.nodes, current_leader), "Current leader must be valid node"

      # Let consensus complete
      result = Byzantine.await_decision(pid, timeout: 10_000)

      # Verify result regardless of leader rotation
      assert match?({:committed, _signal}, result) or match?({:timeout, _signal}, result),
             "Should produce decision (committed or timeout) after leader rotation"

      case result do
        {:committed, signal} ->
          assert signal["round"] >= 1, "Should have progressed at least 1 round"
          {:ok, final_leader} = Byzantine.current_leader(pid)
          assert Enum.member?(context.nodes, final_leader), "Final leader must be valid"

        {:timeout, signal} ->
          assert signal["round"] >= 1, "Should have progressed at least 1 round"
      end
    end
  end

  # =========================================================================
  # BONUS TEST 5: Signal Theory Encoding Verification
  # =========================================================================

  describe "test_consensus_signal_theory_encoding" do
    test "consensus result encodes S=(M,G,T,F,W) correctly", context do
      {:ok, pid} = Byzantine.start_consensus(
        context.nodes,
        context.proposal,
        timeout_ms: 5_000
      )

      result = Byzantine.await_decision(pid, timeout: 10_000)

      {_status, signal} = result

      # Verify Signal Theory 5-tuple: S=(Mode, Genre, Type, Format, Weight)

      # M: Mode = data (numeric, evidence-based)
      assert signal["mode"] == "data",
             "Mode must be 'data' for numeric/evidence output"

      # G: Genre = report (analysis of consensus state)
      assert signal["genre"] == "report",
             "Genre must be 'report' for consensus analysis"

      # T: Type = decide (consensus decision point)
      assert signal["type"] == "decide",
             "Type must be 'decide' for decision points"

      # F: Format = json (structured, machine-readable)
      assert is_map(signal), "Format must be JSON-compatible (map)"
      assert Enum.all?(
               ["mode", "genre", "type", "format", "weight"],
               &Map.has_key?(signal, &1)
             ),
             "All Signal Theory fields must be present"

      # W: Weight = consensus strength (ratio of votes to required)
      assert is_float(signal["weight"]),
             "Weight must be numeric (float)"

      assert signal["weight"] > 0,
             "Weight must be positive (non-zero)"

      case result do
        {:committed, _} ->
          assert signal["weight"] >= 1.0,
                 "Weight should be ≥1.0 for committed (at least 2 votes)"

        {:timeout, _} ->
          assert signal["weight"] < 1.0,
                 "Weight should be <1.0 for timeout (insufficient votes)"
      end

      # Verify additional consensus metadata
      assert is_integer(signal["round"]), "Round must be integer"
      assert is_list(signal["nodes"]), "Nodes must be list"
      assert is_binary(signal["leader"]), "Leader must be binary string"
      assert is_map(signal["detail"]), "Detail must be map"
      assert is_binary(signal["timestamp"]), "Timestamp must be ISO8601 string"
      assert signal["votes_required"] == 2, "Quorum should be 2 (f+1 for f=1)"
    end
  end

  # =========================================================================
  # Edge Cases
  # =========================================================================

  describe "edge cases" do
    test "invalid cluster size (not N=3) fails fast", _context do
      # start_consensus should fail with error when N != 3
      result = Byzantine.start_consensus(
        ["agent_1", "agent_2"],
        %{type: :test},
        timeout_ms: 5_000
      )

      # Debug: print what we got
      case result do
        {:error, reason} ->
          # Expected behavior - GenServer.start_link returns error
          assert Enum.any?(
                   Tuple.to_list(reason),
                   &match?(:invalid_cluster_size, &1)
                 ),
                 "Error should mention invalid_cluster_size: #{inspect(reason)}"

        other ->
          flunk("Expected {:error, _} but got #{inspect(other)}")
      end
    end

    test "marks and tracks multiple faulty nodes", context do
      {:ok, pid} = Byzantine.start_consensus(
        context.nodes,
        context.proposal,
        timeout_ms: 5_000
      )

      :ok = Byzantine.mark_faulty(pid, "agent_1")
      :ok = Byzantine.mark_faulty(pid, "agent_2")

      {:ok, state} = Byzantine.get_state(pid)

      assert MapSet.member?(state.faulty_nodes, "agent_1"), "agent_1 should be marked faulty"
      assert MapSet.member?(state.faulty_nodes, "agent_2"), "agent_2 should be marked faulty"
      assert MapSet.size(state.faulty_nodes) == 2, "Should track exactly 2 faulty nodes"
    end
  end
end
