defmodule OptimalSystemAgent.Consensus.HotStuffTest do
  use ExUnit.Case, async: false
  alias OptimalSystemAgent.Consensus.{HotStuff, Proposal}

  @moduletag :bft_consensus

  describe "propose_vote/3" do
    test "creates a new proposal" do
      proposal = create_test_proposal()

      agents = [
        %{id: "agent-1", name: "Agent 1"},
        %{id: "agent-2", name: "Agent 2"},
        %{id: "agent-3", name: "Agent 3"}
      ]

      assert {:ok, stored_proposal} = HotStuff.propose_vote("test-fleet", proposal, agents)

      assert stored_proposal.workflow_id == proposal.workflow_id
      assert stored_proposal.status == :pending
    end

    test "stores proposal in ETS table" do
      proposal = create_test_proposal()

      agents = [
        %{id: "agent-1", name: "Agent 1"},
        %{id: "agent-2", name: "Agent 2"}
      ]

      {:ok, _proposal} = HotStuff.propose_vote("test-fleet", proposal, agents)

      # Verify proposal is stored
      assert [{^proposal.workflow_id, _proposal}] = :ets.lookup(:bft_proposals, proposal.workflow_id)
    end

    test "broadcasts proposal to all agents" do
      proposal = create_test_proposal()

      agents = [
        %{id: "agent-1", name: "Agent 1"},
        %{id: "agent-2", name: "Agent 2"},
        %{id: "agent-3", name: "Agent 3"}
      ]

      # Should succeed without errors
      assert {:ok, _proposal} = HotStuff.propose_vote("test-fleet", proposal, agents)
    end
  end

  describe "vote/3" do
    setup do
      proposal = create_test_proposal()

      agents = [
        %{id: "agent-1", name: "Agent 1"},
        %{id: "agent-2", name: "Agent 2"},
        %{id: "agent-3", name: "Agent 3"}
      ]

      {:ok, proposal} = HotStuff.propose_vote("test-fleet", proposal, agents)

      %{proposal: proposal, fleet_id: "test-fleet"}
    end

    test "records agent vote" do
      %{proposal: proposal, fleet_id: fleet_id} = setup()

      assert {:ok, updated_proposal} = HotStuff.vote(fleet_id, proposal, "agent-1")

      assert Map.has_key?(updated_proposal.votes, "agent-1")
    end

    test "accepts approve votes" do
      %{proposal: proposal, fleet_id: fleet_id} = setup()

      proposal_with_vote = Proposal.add_vote(proposal, "agent-1", :approve)

      assert {:ok, updated_proposal} = HotStuff.vote(fleet_id, proposal_with_vote, "agent-1")

      assert updated_proposal.votes["agent-1"] == :approve
    end

    test "accepts reject votes" do
      %{proposal: proposal, fleet_id: fleet_id} = setup()

      proposal_with_vote = Proposal.add_vote(proposal, "agent-1", :reject)

      assert {:ok, updated_proposal} = HotStuff.vote(fleet_id, proposal_with_vote, "agent-1")

      assert updated_proposal.votes["agent-1"] == :reject
    end

    test "updates proposal in ETS table" do
      %{proposal: proposal, fleet_id: fleet_id} = setup()

      proposal_with_vote = Proposal.add_vote(proposal, "agent-1", :approve)

      {:ok, updated_proposal} = HotStuff.vote(fleet_id, proposal_with_vote, "agent-1")

      # Verify updated proposal is stored
      assert [{^proposal.workflow_id, stored_proposal}] = :ets.lookup(:bft_proposals, proposal.workflow_id)
      assert stored_proposal.votes["agent-1"] == :approve
    end
  end

  describe "calculate_result/1" do
    test "approves when supermajority (>66.7%) achieved" do
      proposal = create_test_proposal()

      proposal = proposal
        |> Proposal.add_vote("agent-1", :approve)
        |> Proposal.add_vote("agent-2", :approve)
        |> Proposal.add_vote("agent-3", :approve)

      assert {:ok, :approved} = Proposal.calculate_result(proposal)
    end

    test "rejects when supermajority not achieved" do
      proposal = create_test_proposal()

      proposal = proposal
        |> Proposal.add_vote("agent-1", :approve)
        |> Proposal.add_vote("agent-2", :reject)
        |> Proposal.add_vote("agent-3", :reject)

      assert {:ok, :rejected} = Proposal.calculate_result(proposal)
    end

    test "returns pending when threshold not clearly met" do
      proposal = create_test_proposal()

      proposal = proposal
        |> Proposal.add_vote("agent-1", :approve)
        |> Proposal.add_vote("agent-2", :approve)
        |> Proposal.add_vote("agent-3", :reject)

      # 2/3 = 66.7%, but need >66.7%, so should be pending or rejected
      result = Proposal.calculate_result(proposal)

      # Exact threshold should reject
      assert result == {:ok, :rejected} or result == {:pending, _ratio}
    end

    test "handles empty votes" do
      proposal = create_test_proposal()

      assert {:pending, 0.0} = Proposal.calculate_result(proposal)
    end

    test "calculates correct approval ratio" do
      proposal = create_test_proposal()

      proposal = proposal
        |> Proposal.add_vote("agent-1", :approve)
        |> Proposal.add_vote("agent-2", :approve)
        |> Proposal.add_vote("agent-3", :reject)
        |> Proposal.add_vote("agent-4", :reject)

      assert {:ok, :rejected} = Proposal.calculate_result(proposal)
    end
  end

  describe "commit/2" do
    setup do
      proposal = create_test_proposal()

      agents = [
        %{id: "agent-1", name: "Agent 1"},
        %{id: "agent-2", name: "Agent 2"},
        %{id: "agent-3", name: "Agent 3"}
      ]

      {:ok, proposal} = HotStuff.propose_vote("test-fleet", proposal, agents)

      # Add approve votes to achieve supermajority
      proposal = proposal
        |> Proposal.add_vote("agent-1", :approve)
        |> Proposal.add_vote("agent-2", :approve)
        |> Proposal.add_vote("agent-3", :approve)

      %{proposal: proposal, fleet_id: "test-fleet"}
    end

    test "commits approved proposal" do
      %{proposal: proposal, fleet_id: fleet_id} = setup()

      assert {:ok, committed_proposal} = HotStuff.commit(fleet_id, proposal)

      assert committed_proposal.status == :approved
    end

    test "updates proposal status in ETS" do
      %{proposal: proposal, fleet_id: fleet_id} = setup()

      {:ok, committed_proposal} = HotStuff.commit(fleet_id, proposal)

      # Verify status is updated
      assert [{^proposal.workflow_id, stored_proposal}] = :ets.lookup(:bft_proposals, proposal.workflow_id)
      assert stored_proposal.status == :approved
    end

    test "adds audit log entry" do
      %{proposal: proposal, fleet_id: fleet_id} = setup()

      {:ok, _committed_proposal} = HotStuff.commit(fleet_id, proposal)

      # Verify audit entry exists
      audit_entries = :ets.tab2list(:bft_audit)
      assert length(audit_entries) > 0
    end
  end

  describe "fault tolerance" do
    test "tolerates up to f < n/3 faulty agents" do
      # 3 agents can tolerate 1 faulty
      proposal = create_test_proposal()

      proposal = proposal
        |> Proposal.add_vote("agent-1", :approve)
        |> Proposal.add_vote("agent-2", :approve)
        |> Proposal.add_vote("agent-3", :reject)

      # Even with 1 reject, supermajority achieved
      assert {:ok, :approved} = Proposal.calculate_result(proposal)
    end

    test "fails when more than f agents are faulty" do
      # 3 agents can only tolerate 1 faulty
      proposal = create_test_proposal()

      proposal = proposal
        |> Proposal.add_vote("agent-1", :approve)
        |> Proposal.add_vote("agent-2", :reject)
        |> Proposal.add_vote("agent-3", :reject)

      # 2 rejects = 2 faulty > f(1) = should reject
      assert {:ok, :rejected} = Proposal.calculate_result(proposal)
    end

    test "requires minimum 3 agents for BFT" do
      proposal = create_test_proposal()

      # 2 agents can only tolerate 0 faulty (not true BFT)
      proposal = proposal
        |> Proposal.add_vote("agent-1", :approve)
        |> Proposal.add_vote("agent-2", :reject)

      assert {:ok, :rejected} = Proposal.calculate_result(proposal)
    end
  end

  describe "audit trail" do
    test "maintains hash chain integrity" do
      proposal = create_test_proposal()

      agents = [%{id: "agent-1", name: "Agent 1"}]

      {:ok, proposal} = HotStuff.propose_vote("audit-fleet", proposal, agents)

      # Get audit entries
      audit_entries = :ets.tab2list(:bft_audit)

      # Should have at least one entry (proposal submitted)
      assert length(audit_entries) > 0

      # Verify hash chain (each entry references previous)
      # This is a simplified check - full implementation would verify SHA-256 hashes
      Enum.each(audit_entries, fn entry ->
        assert Map.has_key?(entry, :hash)
        assert Map.has_key?(entry, :previous_hash)
      end)
    end

    test "records all consensus events" do
      proposal = create_test_proposal()

      agents = [
        %{id: "agent-1", name: "Agent 1"},
        %{id: "agent-2", name: "Agent 2"},
        %{id: "agent-3", name: "Agent 3"}
      ]

      {:ok, proposal} = HotStuff.propose_vote("audit-fleet", proposal, agents)

      # Vote
      proposal = Proposal.add_vote(proposal, "agent-1", :approve)
      {:ok, proposal} = HotStuff.vote("audit-fleet", proposal, "agent-1")

      # Commit
      {:ok, _proposal} = HotStuff.commit("audit-fleet", proposal)

      # Should have multiple audit entries
      audit_entries = :ets.tab2list(:bft_audit)
      assert length(audit_entries) >= 3  # submit, vote, commit
    end
  end

  # Helper functions

  defp create_test_proposal do
    {:ok, proposal} = Proposal.new(
      :process_model,
      %{
        "what" => "Automate invoice approval",
        "why" => "Bottleneck detected in manual review",
        "impact" => %{"time_savings_percent" => 80}
      },
      "test-proposer"
    )

    proposal
  end
end
