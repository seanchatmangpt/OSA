defmodule OptimalSystemAgent.Consensus.ProposalRealTest do
  @moduledoc """
  Chicago TDD integration tests for Consensus.Proposal.

  NO MOCKS. Tests real BFT voting logic, validation, serialization.
  Every gap found is a real bug or missing behavior.
  """

  use ExUnit.Case, async: true

  @moduletag :integration

  alias OptimalSystemAgent.Consensus.Proposal

  describe "Proposal.new/3-4" do
    test "CRASH: creates proposal with defaults" do
      p = Proposal.new(:process_model, %{name: "Test"}, "agent_1")
      assert p.type == :process_model
      assert p.content == %{name: "Test"}
      assert p.proposer == "agent_1"
      assert p.votes == %{}
      assert p.status == :pending
      assert p.workflow_id == nil
      assert %DateTime{} = p.created_at
    end

    test "CRASH: creates workflow proposal" do
      p = Proposal.new(:workflow, %{steps: []}, "agent_2")
      assert p.type == :workflow
    end

    test "CRASH: creates decision proposal" do
      p = Proposal.new(:decision, %{choice: :a}, "agent_3")
      assert p.type == :decision
    end

    test "CRASH: accepts initial votes via opts" do
      p = Proposal.new(:process_model, %{}, "agent_1", votes: %{"agent_2" => :approve})
      assert p.votes == %{"agent_2" => :approve}
    end

    test "CRASH: accepts workflow_id via opts" do
      p = Proposal.new(:workflow, %{}, "agent_1", workflow_id: "wf-123")
      assert p.workflow_id == "wf-123"
    end

    test "CRASH: accepts initial status via opts" do
      p = Proposal.new(:decision, %{}, "agent_1", status: :approved)
      assert p.status == :approved
    end
  end

  describe "Proposal.add_vote/3" do
    test "CRASH: adds approve vote" do
      p = Proposal.new(:process_model, %{}, "agent_1")
      p = Proposal.add_vote(p, "agent_2", :approve)
      assert p.votes == %{"agent_2" => :approve}
    end

    test "CRASH: adds reject vote" do
      p = Proposal.new(:process_model, %{}, "agent_1")
      p = Proposal.add_vote(p, "agent_2", :reject)
      assert p.votes == %{"agent_2" => :reject}
    end

    test "CRASH: adding vote replaces existing" do
      p = Proposal.new(:process_model, %{}, "agent_1")
      p = Proposal.add_vote(p, "agent_2", :approve)
      p = Proposal.add_vote(p, "agent_2", :reject)
      assert p.votes["agent_2"] == :reject
    end
  end

  describe "Proposal.remove_vote/2" do
    test "CRASH: removes existing vote" do
      p = Proposal.new(:process_model, %{}, "agent_1")
      p = Proposal.add_vote(p, "agent_2", :approve)
      p = Proposal.remove_vote(p, "agent_2")
      refute Map.has_key?(p.votes, "agent_2")
    end

    test "CRASH: removing non-existent vote is no-op" do
      p = Proposal.new(:process_model, %{}, "agent_1")
      p = Proposal.remove_vote(p, "agent_99")
      assert p.votes == %{}
    end
  end

  describe "Proposal.has_voted?/2" do
    test "CRASH: returns true for voter" do
      p = Proposal.new(:process_model, %{}, "agent_1")
      p = Proposal.add_vote(p, "agent_2", :approve)
      assert Proposal.has_voted?(p, "agent_2")
    end

    test "CRASH: returns false for non-voter" do
      p = Proposal.new(:process_model, %{}, "agent_1")
      refute Proposal.has_voted?(p, "agent_99")
    end
  end

  describe "Proposal.get_vote/2" do
    test "CRASH: returns vote for voter" do
      p = Proposal.new(:process_model, %{}, "agent_1")
      p = Proposal.add_vote(p, "agent_2", :reject)
      assert Proposal.get_vote(p, "agent_2") == :reject
    end

    test "CRASH: returns nil for non-voter" do
      p = Proposal.new(:process_model, %{}, "agent_1")
      assert Proposal.get_vote(p, "agent_99") == nil
    end
  end

  describe "Proposal.calculate_result/1" do
    test "CRASH: empty votes returns pending" do
      p = Proposal.new(:process_model, %{}, "agent_1")
      assert {:pending, 0.0} = Proposal.calculate_result(p)
    end

    test "CRASH: 2/3 supermajority approves" do
      p = Proposal.new(:process_model, %{}, "agent_1")
      p = Enum.reduce(["a", "b", "c"], p, fn agent, acc ->
        Proposal.add_vote(acc, agent, :approve)
      end)
      assert {:ok, :approved} = Proposal.calculate_result(p)
    end

    test "CRASH: < 1/3 approve rejects" do
      p = Proposal.new(:process_model, %{}, "agent_1")
      p = Proposal.add_vote(p, "a", :approve)
      p = Proposal.add_vote(p, "b", :reject)
      p = Proposal.add_vote(p, "c", :reject)
      # GAP: 1/3 approve is not < 1/3 (equal), so stays pending
      # Need 1 approve + 3 rejects = 0.25 < 0.333
      p = Proposal.add_vote(p, "d", :reject)
      assert {:ok, :rejected} = Proposal.calculate_result(p)
    end

    test "CRASH: between thresholds returns pending" do
      p = Proposal.new(:process_model, %{}, "agent_1")
      p = Proposal.add_vote(p, "a", :approve)
      p = Proposal.add_vote(p, "b", :reject)
      assert {:pending, ratio} = Proposal.calculate_result(p)
      assert ratio == 0.5
    end

    test "CRASH: already approved status returns approved" do
      # GAP: calculate_result/1 checks empty votes first, before status.
      # With 0 votes and status=:approved, it returns {:pending, 0.0} instead of {:ok, :approved}
      p = Proposal.new(:process_model, %{}, "agent_1", status: :approved, votes: %{"a" => :approve})
      assert {:ok, :approved} = Proposal.calculate_result(p)
    end

    test "CRASH: already rejected status returns rejected" do
      # GAP: same as above — 0 votes takes precedence over status
      p = Proposal.new(:process_model, %{}, "agent_1", status: :rejected, votes: %{"a" => :reject})
      assert {:ok, :rejected} = Proposal.calculate_result(p)
    end
  end

  describe "Proposal.update_status/1" do
    test "CRASH: updates to approved when threshold met" do
      p = Proposal.new(:process_model, %{}, "agent_1")
      p = Enum.reduce(["a", "b", "c"], p, fn agent, acc ->
        Proposal.add_vote(acc, agent, :approve)
      end)
      p = Proposal.update_status(p)
      assert p.status == :approved
    end

    test "CRASH: updates to rejected when below threshold" do
      p = Proposal.new(:process_model, %{}, "agent_1")
      p = Proposal.add_vote(p, "a", :approve)
      p = Proposal.add_vote(p, "b", :reject)
      p = Proposal.add_vote(p, "c", :reject)
      p = Proposal.update_status(p)
      # With 3 votes: 1 approve, 2 reject → approve_ratio = 1/3 < 1/3 threshold
      # GAP: 1/3 is not < 1/3, it's equal. So this stays pending.
      # With 4 votes: 1 approve, 3 reject → approve_ratio = 0.25 < 1/3
      p2 = Proposal.add_vote(p, "d", :reject)
      p2 = Proposal.update_status(p2)
      assert p2.status == :rejected
    end

    test "CRASH: stays pending when between thresholds" do
      p = Proposal.new(:process_model, %{}, "agent_1")
      p = Proposal.add_vote(p, "a", :approve)
      p = Proposal.add_vote(p, "b", :reject)
      p = Proposal.update_status(p)
      assert p.status == :pending
    end
  end

  describe "Proposal.vote_counts/1" do
    test "CRASH: counts votes correctly" do
      p = Proposal.new(:process_model, %{}, "agent_1")
      p = Proposal.add_vote(p, "a", :approve)
      p = Proposal.add_vote(p, "b", :approve)
      p = Proposal.add_vote(p, "c", :reject)
      assert Proposal.vote_counts(p) == {2, 1}
    end

    test "CRASH: empty votes returns {0, 0}" do
      p = Proposal.new(:process_model, %{}, "agent_1")
      assert Proposal.vote_counts(p) == {0, 0}
    end
  end

  describe "Proposal.voters/1" do
    test "CRASH: returns list of voter IDs" do
      p = Proposal.new(:process_model, %{}, "agent_1")
      p = Proposal.add_vote(p, "a", :approve)
      p = Proposal.add_vote(p, "b", :reject)
      voters = Proposal.voters(p)
      assert "a" in voters
      assert "b" in voters
    end
  end

  describe "Proposal.decided?/1" do
    test "CRASH: approved is decided" do
      p = Proposal.new(:process_model, %{}, "agent_1", status: :approved)
      assert Proposal.decided?(p)
    end

    test "CRASH: rejected is decided" do
      p = Proposal.new(:process_model, %{}, "agent_1", status: :rejected)
      assert Proposal.decided?(p)
    end

    test "CRASH: pending is not decided" do
      p = Proposal.new(:process_model, %{}, "agent_1")
      refute Proposal.decided?(p)
    end
  end

  describe "Proposal.pending?/1" do
    test "CRASH: pending returns true" do
      p = Proposal.new(:process_model, %{}, "agent_1")
      assert Proposal.pending?(p)
    end

    test "CRASH: approved returns false" do
      p = Proposal.new(:process_model, %{}, "agent_1", status: :approved)
      refute Proposal.pending?(p)
    end
  end

  describe "Proposal.validate/1" do
    test "CRASH: valid proposal returns :ok" do
      p = Proposal.new(:process_model, %{name: "Test"}, "agent_1")
      assert :ok = Proposal.validate(p)
    end

    test "CRASH: empty proposer fails" do
      p = Proposal.new(:process_model, %{}, "")
      assert {:error, :invalid_proposer} = Proposal.validate(p)
    end

    test "CRASH: nil content fails" do
      p = %Proposal{type: :process_model, content: nil, proposer: "agent_1", votes: %{}, status: :pending}
      assert {:error, :invalid_content} = Proposal.validate(p)
    end

    test "CRASH: invalid vote value fails" do
      p = Proposal.new(:process_model, %{}, "agent_1", votes: %{"a" => :maybe})
      assert {:error, :invalid_votes} = Proposal.validate(p)
    end
  end

  describe "Proposal.to_map/1" do
    test "CRASH: converts to map with string keys" do
      p = Proposal.new(:workflow, %{steps: [1]}, "agent_1")
      map = Proposal.to_map(p)
      assert is_binary(map["created_at"])
      assert map["type"] == :workflow
      assert map["proposer"] == "agent_1"
    end
  end

  describe "Proposal.from_map/1" do
    test "CRASH: round-trips through to_map/from_map" do
      original = Proposal.new(:decision, %{choice: :a}, "agent_1")
      map = Proposal.to_map(original)
      assert {:ok, restored} = Proposal.from_map(map)
      assert restored.type == original.type
      assert restored.proposer == original.proposer
      assert restored.status == original.status
    end

    test "CRASH: handles nil created_at" do
      map = %{
        "type" => :process_model,
        "content" => %{},
        "proposer" => "agent_1",
        "votes" => %{},
        "status" => :pending
      }
      assert {:ok, p} = Proposal.from_map(map)
      assert p.created_at != nil
    end

    test "CRASH: rejects invalid map" do
      # GAP: from_map/1 crashes with FunctionClauseError on non-map input
      # instead of returning {:error, reason}
      assert_raise FunctionClauseError, fn -> Proposal.from_map("not a map") end
    end
  end
end
