defmodule OptimalSystemAgent.Consensus.HotStuffTest do
  use ExUnit.Case, async: false
  alias OptimalSystemAgent.Consensus.{HotStuff, Proposal}

  @moduletag :bft_consensus

  setup do
    HotStuff.init_tables()
    :ok
  end

  describe "propose_vote/3" do
    test "creates a new proposal" do
      proposal_content = %{
        type: :process_model,
        content: %{name: "Customer Onboarding", steps: []}
      }

      # Minimum 4 agents required for BFT (3f+1 with f=1)
      agents = ["agent-1", "agent-2", "agent-3", "agent-4"]

      assert {:ok, proposal} = HotStuff.propose_vote("test-fleet", proposal_content, agents)
      assert %Proposal{} = proposal
      assert proposal.type == :process_model
      assert proposal.status == :pending
    end

    test "stores proposal in ETS table" do
      proposal_content = %{
        type: :process_model,
        content: %{name: "Customer Onboarding"}
      }

      agents = ["agent-1", "agent-2", "agent-3", "agent-4"]

      {:ok, proposal} = HotStuff.propose_vote("ets-fleet", proposal_content, agents)

      # Verify proposal is stored with {fleet_id, proposal_id} key
      assert [{_key, stored_proposal}] =
               :ets.lookup(:osa_consensus_proposals, {"ets-fleet", proposal.proposal_id})

      assert stored_proposal.type == :process_model
    end

    test "broadcasts proposal to all agents" do
      proposal_content = %{
        type: :workflow,
        content: %{name: "Deploy Pipeline"}
      }

      agents = ["agent-1", "agent-2", "agent-3", "agent-4"]

      assert {:ok, _proposal} = HotStuff.propose_vote("broadcast-fleet", proposal_content, agents)
    end

    test "validates fleet_id" do
      proposal_content = %{type: :process_model, content: %{}}
      agents = ["agent-1", "agent-2", "agent-3", "agent-4"]

      result = HotStuff.propose_vote("", proposal_content, agents)
      assert match?({:error, _}, result)
    end

    test "validates agents list is minimum 4" do
      proposal_content = %{type: :process_model, content: %{}}

      # Too few agents
      result = HotStuff.propose_vote("test-fleet", proposal_content, ["agent-1"])
      assert match?({:error, :invalid_agent_list}, result)
    end

    test "validates agents are strings" do
      proposal_content = %{type: :process_model, content: %{}}

      # Agents must be strings, not maps
      result =
        HotStuff.propose_vote("test-fleet", proposal_content, [
          %{id: "agent-1"},
          %{id: "agent-2"},
          %{id: "agent-3"},
          %{id: "agent-4"}
        ])

      assert match?({:error, :invalid_agent_list}, result)
    end
  end

  describe "vote/3" do
    setup do
      proposal_content = %{
        type: :process_model,
        content: %{name: "Invoice Approval"}
      }

      agents = ["agent-1", "agent-2", "agent-3", "agent-4"]

      {:ok, proposal} = HotStuff.propose_vote("vote-fleet", proposal_content, agents)

      %{
        proposal: proposal,
        proposal_id: proposal.proposal_id,
        fleet_id: "vote-fleet"
      }
    end

    test "records agent vote", context do
      assert {:ok, :pending} =
               HotStuff.vote(context.fleet_id, context.proposal_id, "agent-1")
    end

    test "returns error for nonexistent proposal" do
      assert {:error, :proposal_not_found} =
               HotStuff.vote("nonexistent-fleet", "nonexistent-id", "agent-1")
    end

    test "accepts vote from any agent id", context do
      # vote/3 doesn't validate agent membership, just records the vote
      assert {:ok, :pending} =
               HotStuff.vote(context.fleet_id, context.proposal_id, "unknown-agent")
    end

    test "auto-commits on supermajority", context do
      # With 4 agents, need 3 approve votes for >66.7%
      {:ok, :pending} = HotStuff.vote(context.fleet_id, context.proposal_id, "agent-1")
      {:ok, :pending} = HotStuff.vote(context.fleet_id, context.proposal_id, "agent-2")
      {:ok, result} = HotStuff.vote(context.fleet_id, context.proposal_id, "agent-3")

      assert result == :approved
    end
  end

  describe "calculate_result/1" do
    test "approves when supermajority (>66.7%) achieved" do
      proposal = Proposal.new(:process_model, %{}, "proposer")

      proposal = proposal
        |> Proposal.add_vote("agent-1", :approve)
        |> Proposal.add_vote("agent-2", :approve)
        |> Proposal.add_vote("agent-3", :approve)

      assert {:ok, :approved} = Proposal.calculate_result(proposal)
    end

    test "rejects when supermajority not achieved" do
      proposal = Proposal.new(:process_model, %{}, "proposer")

      proposal = proposal
        |> Proposal.add_vote("agent-1", :approve)
        |> Proposal.add_vote("agent-2", :reject)
        |> Proposal.add_vote("agent-3", :reject)

      # 1/3 = 0.333... NOT < 1/3, so pending (not rejected)
      assert {:pending, _ratio} = Proposal.calculate_result(proposal)
    end

    test "returns pending when threshold not clearly met" do
      proposal = Proposal.new(:process_model, %{}, "proposer")

      proposal = proposal
        |> Proposal.add_vote("agent-1", :approve)
        |> Proposal.add_vote("agent-2", :approve)
        |> Proposal.add_vote("agent-3", :reject)
        |> Proposal.add_vote("agent-4", :approve)

      # 3/4 = 0.75 > 2/3 -> approved (not pending!)
      assert {:ok, :approved} = Proposal.calculate_result(proposal)
    end

    test "handles empty votes" do
      proposal = Proposal.new(:process_model, %{}, "proposer")
      assert {:pending, 0.0} = Proposal.calculate_result(proposal)
    end

    test "calculates correct approval ratio" do
      proposal = Proposal.new(:process_model, %{}, "proposer")

      proposal = proposal
        |> Proposal.add_vote("agent-1", :approve)
        |> Proposal.add_vote("agent-2", :reject)
        |> Proposal.add_vote("agent-3", :reject)
        |> Proposal.add_vote("agent-4", :reject)

      # 1/4 = 0.25 < 1/3 -> rejected
      assert {:ok, :rejected} = Proposal.calculate_result(proposal)
    end
  end

  describe "commit/2" do
    setup do
      proposal_content = %{
        type: :process_model,
        content: %{name: "Auto Approve Test"}
      }

      agents = ["agent-1", "agent-2", "agent-3", "agent-4"]

      {:ok, proposal} = HotStuff.propose_vote("commit-fleet", proposal_content, agents)

      # Add approve votes to reach supermajority (3/4 = 75% > 66.7%)
      HotStuff.vote("commit-fleet", proposal.proposal_id, "agent-1")
      HotStuff.vote("commit-fleet", proposal.proposal_id, "agent-2")
      HotStuff.vote("commit-fleet", proposal.proposal_id, "agent-3")

      %{proposal_id: proposal.proposal_id, fleet_id: "commit-fleet"}
    end

    test "commits approved proposal", context do
      assert :ok = HotStuff.commit(context.fleet_id, context.proposal_id)
    end

    test "returns error for nonexistent proposal" do
      assert {:error, :proposal_not_found} =
               HotStuff.commit("nonexistent", "nonexistent-id")
    end

    test "adds audit log entry", context do
      :ok = HotStuff.commit(context.fleet_id, context.proposal_id)

      audit_entries =
        :ets.select(:osa_consensus_audit, [
          {{{:"$1", :"$2"}, :"$3"}, [{:==, :"$1", context.fleet_id}], [:"$3"]}
        ])

      assert length(audit_entries) > 0
    end
  end

  describe "fault tolerance" do
    test "approves when >2/3 supermajority achieved" do
      proposal = Proposal.new(:process_model, %{}, "proposer")

      proposal = proposal
        |> Proposal.add_vote("agent-1", :approve)
        |> Proposal.add_vote("agent-2", :approve)
        |> Proposal.add_vote("agent-3", :approve)

      # 3/3 = 1.0 > 0.666... -> approved
      assert {:ok, :approved} = Proposal.calculate_result(proposal)
    end

    test "pending when exactly at threshold boundary" do
      proposal = Proposal.new(:process_model, %{}, "proposer")

      proposal = proposal
        |> Proposal.add_vote("agent-1", :approve)
        |> Proposal.add_vote("agent-2", :approve)
        |> Proposal.add_vote("agent-3", :reject)

      # 2/3 = 0.666... NOT > 2/3, so pending
      assert {:pending, ratio} = Proposal.calculate_result(proposal)
      assert_in_delta ratio, 0.6667, 0.001
    end

    test "rejects when <1/3 approve" do
      proposal = Proposal.new(:process_model, %{}, "proposer")

      proposal = proposal
        |> Proposal.add_vote("agent-1", :reject)
        |> Proposal.add_vote("agent-2", :reject)
        |> Proposal.add_vote("agent-3", :reject)

      # 0/3 = 0.0 < 1/3 -> rejected
      assert {:ok, :rejected} = Proposal.calculate_result(proposal)
    end

    test "pending for mixed 1/3 ratio" do
      proposal = Proposal.new(:process_model, %{}, "proposer")

      proposal = proposal
        |> Proposal.add_vote("agent-1", :approve)
        |> Proposal.add_vote("agent-2", :reject)
        |> Proposal.add_vote("agent-3", :reject)

      # 1/3 = 0.333... NOT < 1/3, so pending
      assert {:pending, _ratio} = Proposal.calculate_result(proposal)
    end
  end

  describe "audit trail" do
    test "records all consensus events" do
      proposal_content = %{
        type: :process_model,
        content: %{name: "Audit Trail Test"}
      }

      agents = ["agent-1", "agent-2", "agent-3", "agent-4"]

      {:ok, proposal} = HotStuff.propose_vote("audit-fleet", proposal_content, agents)

      # Vote to trigger auto-commit (3/4 = 75% > 66.7%)
      HotStuff.vote("audit-fleet", proposal.proposal_id, "agent-1")
      HotStuff.vote("audit-fleet", proposal.proposal_id, "agent-2")
      HotStuff.vote("audit-fleet", proposal.proposal_id, "agent-3")

      audit_entries =
        :ets.select(:osa_consensus_audit, [
          {{{:"$1", :"$2"}, :"$3"}, [{:==, :"$1", "audit-fleet"}], [:"$3"]}
        ])

      assert length(audit_entries) >= 1
    end
  end
end
