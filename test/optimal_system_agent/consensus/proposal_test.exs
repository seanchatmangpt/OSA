defmodule OptimalSystemAgent.Consensus.ProposalTest do
  use ExUnit.Case
  doctest OptimalSystemAgent.Consensus.Proposal

  alias OptimalSystemAgent.Consensus.Proposal

  describe "new/3" do
    test "creates a new proposal with defaults" do
      proposal = Proposal.new(:process_model, %{name: "Test"}, "agent_1")

      assert proposal.type == :process_model
      assert proposal.content == %{name: "Test"}
      assert proposal.proposer == "agent_1"
      assert proposal.votes == %{}
      assert proposal.status == :pending
      assert %DateTime{} = proposal.created_at
    end

    test "creates a new proposal with custom options" do
      proposal =
        Proposal.new(:workflow, %{steps: []}, "agent_1",
          votes: %{"agent_2" => :approve},
          status: :approved
        )

      assert proposal.type == :workflow
      assert proposal.votes == %{"agent_2" => :approve}
      assert proposal.status == :approved
    end

    test "validates proposal types" do
      assert_raise FunctionClauseError, fn ->
        Proposal.new(:invalid_type, %{}, "agent_1")
      end
    end
  end

  describe "add_vote/3" do
    test "adds an approve vote" do
      proposal = Proposal.new(:process_model, %{}, "agent_1")
      proposal = Proposal.add_vote(proposal, "agent_2", :approve)

      assert proposal.votes == %{"agent_2" => :approve}
    end

    test "adds a reject vote" do
      proposal = Proposal.new(:process_model, %{}, "agent_1")
      proposal = Proposal.add_vote(proposal, "agent_2", :reject)

      assert proposal.votes == %{"agent_2" => :reject}
    end

    test "overwrites existing vote" do
      proposal =
        Proposal.new(:process_model, %{}, "agent_1")
        |> Proposal.add_vote("agent_2", :approve)
        |> Proposal.add_vote("agent_2", :reject)

      assert proposal.votes == %{"agent_2" => :reject}
    end
  end

  describe "calculate_result/1" do
    test "returns pending for empty votes" do
      proposal = Proposal.new(:process_model, %{}, "agent_1")

      assert Proposal.calculate_result(proposal) == {:pending, 0.0}
    end

    test "approves when > 2/3 votes are approve" do
      proposal =
        Proposal.new(:process_model, %{}, "agent_1")
        |> Proposal.add_vote("agent_2", :approve)
        |> Proposal.add_vote("agent_3", :approve)
        |> Proposal.add_vote("agent_4", :approve)

      assert Proposal.calculate_result(proposal) == {:ok, :approved}
    end

    test "approves when exactly 2/3 votes are approve" do
      proposal =
        Proposal.new(:process_model, %{}, "agent_1")
        |> Proposal.add_vote("agent_2", :approve)
        |> Proposal.add_vote("agent_3", :approve)

      assert Proposal.calculate_result(proposal) == {:ok, :approved}
    end

    test "returns pending when votes are between 1/3 and 2/3" do
      proposal =
        Proposal.new(:process_model, %{}, "agent_1")
        |> Proposal.add_vote("agent_2", :approve)
        |> Proposal.add_vote("agent_3", :approve)
        |> Proposal.add_vote("agent_4", :reject)
        |> Proposal.add_vote("agent_5", :reject)

      assert {:pending, ratio} = Proposal.calculate_result(proposal)
      assert ratio == 0.5
    end

    test "rejects when < 1/3 votes are approve" do
      proposal =
        Proposal.new(:process_model, %{}, "agent_1")
        |> Proposal.add_vote("agent_2", :reject)
        |> Proposal.add_vote("agent_3", :reject)
        |> Proposal.add_vote("agent_4", :approve)

      assert Proposal.calculate_result(proposal) == {:ok, :rejected}
    end

    test "returns current status if already decided" do
      proposal =
        Proposal.new(:process_model, %{}, "agent_1", status: :approved)
        |> Proposal.add_vote("agent_2", :reject)

      assert Proposal.calculate_result(proposal) == {:ok, :approved}
    end
  end

  describe "update_status/1" do
    test "updates status to approved when threshold reached" do
      proposal =
        Proposal.new(:process_model, %{}, "agent_1")
        |> Proposal.add_vote("agent_2", :approve)
        |> Proposal.add_vote("agent_3", :approve)
        |> Proposal.update_status()

      assert proposal.status == :approved
    end

    test "updates status to rejected when threshold reached" do
      proposal =
        Proposal.new(:process_model, %{}, "agent_1")
        |> Proposal.add_vote("agent_2", :reject)
        |> Proposal.add_vote("agent_3", :reject)
        |> Proposal.add_vote("agent_4", :approve)
        |> Proposal.update_status()

      assert proposal.status == :rejected
    end

    test "keeps pending status when threshold not reached" do
      proposal =
        Proposal.new(:process_model, %{}, "agent_1")
        |> Proposal.add_vote("agent_2", :approve)
        |> Proposal.add_vote("agent_3", :reject)
        |> Proposal.update_status()

      assert proposal.status == :pending
    end
  end

  describe "vote_counts/1" do
    test "returns correct counts" do
      proposal =
        Proposal.new(:process_model, %{}, "agent_1")
        |> Proposal.add_vote("agent_2", :approve)
        |> Proposal.add_vote("agent_3", :approve)
        |> Proposal.add_vote("agent_4", :reject)

      assert Proposal.vote_counts(proposal) == {2, 1}
    end
  end

  describe "validate/1" do
    test "validates correct proposal" do
      proposal = Proposal.new(:process_model, %{name: "Test"}, "agent_1")

      assert Proposal.validate(proposal) == :ok
    end

    test "rejects invalid proposer" do
      proposal = %{Proposal.new(:process_model, %{}, "") | proposer: nil}

      assert Proposal.validate(proposal) == {:error, :invalid_proposer}
    end

    test "rejects invalid type" do
      proposal = %{Proposal.new(:process_model, %{}, "agent_1") | type: :invalid}

      assert Proposal.validate(proposal) == {:error, :invalid_type}
    end

    test "rejects nil content" do
      proposal = %{Proposal.new(:process_model, %{}, "agent_1") | content: nil}

      assert Proposal.validate(proposal) == {:error, :invalid_content}
    end

    test "rejects invalid status" do
      proposal = %{Proposal.new(:process_model, %{}, "agent_1") | status: :invalid}

      assert Proposal.validate(proposal) == {:error, :invalid_status}
    end

    test "rejects invalid votes" do
      proposal = %{Proposal.new(:process_model, %{}, "agent_1") | votes: %{"agent_2" => :invalid}}

      assert Proposal.validate(proposal) == {:error, :invalid_votes}
    end
  end

  describe "to_map/1 and from_map/1" do
    test "serializes and deserializes proposal" do
      original =
        Proposal.new(:process_model, %{name: "Test"}, "agent_1")
        |> Proposal.add_vote("agent_2", :approve)
        |> Proposal.add_vote("agent_3", :reject)

      map = Proposal.to_map(original)
      assert map["type"] == :process_model
      assert map["content"] == %{name: "Test"}
      assert map["proposer"] == "agent_1"
      assert map["votes"] == %{"agent_2" => :approve, "agent_3" => :reject}
      assert map["status"] == :pending
      assert is_binary(map["created_at"])

      assert {:ok, restored} = Proposal.from_map(map)
      assert restored.type == original.type
      assert restored.content == original.content
      assert restored.proposer == original.proposer
      assert restored.votes == original.votes
      assert restored.status == original.status
    end

    test "handles missing created_at in from_map" do
      map = %{
        "type" => :process_model,
        "content" => %{},
        "proposer" => "agent_1",
        "votes" => %{},
        "status" => :pending
      }

      assert {:ok, proposal} = Proposal.from_map(map)
      assert %DateTime{} = proposal.created_at
    end

    test "rejects invalid map in from_map" do
      assert {:error, _} = Proposal.from_map(%{"type" => :invalid})
    end
  end
end
