defmodule OptimalSystemAgent.Store.DecisionEdgeTest do
  @moduledoc """
  Unit tests for Store.DecisionEdge module.

  Tests Ecto schema for decision graph edges.
  Real Ecto changesets, no mocks.
  """

  use ExUnit.Case, async: true

  alias OptimalSystemAgent.Store.DecisionEdge

  @moduletag :capture_log

  @valid_types ~w(leads_to chosen rejected requires blocks enables supersedes supports revises summarizes)

  describe "changeset/2" do
    test "validates required fields" do
      attrs = %{
        id: "edge_1",
        source_id: "node_a",
        target_id: "node_b",
        type: "leads_to"
      }
      changeset = DecisionEdge.changeset(%DecisionEdge{}, attrs)
      assert changeset.valid?
    end

    test "requires id field" do
      attrs = %{
        source_id: "node_a",
        target_id: "node_b",
        type: "leads_to"
      }
      changeset = DecisionEdge.changeset(%DecisionEdge{}, attrs)
      refute changeset.valid?
    end

    test "requires source_id field" do
      attrs = %{
        id: "edge_1",
        target_id: "node_b",
        type: "leads_to"
      }
      changeset = DecisionEdge.changeset(%DecisionEdge{}, attrs)
      refute changeset.valid?
    end

    test "requires target_id field" do
      attrs = %{
        id: "edge_1",
        source_id: "node_a",
        type: "leads_to"
      }
      changeset = DecisionEdge.changeset(%DecisionEdge{}, attrs)
      refute changeset.valid?
    end

    test "requires type field" do
      attrs = %{
        id: "edge_1",
        source_id: "node_a",
        target_id: "node_b"
      }
      changeset = DecisionEdge.changeset(%DecisionEdge{}, attrs)
      refute changeset.valid?
    end

    test "validates type is in allowed list" do
      for type <- @valid_types do
        attrs = %{
          id: "edge_#{type}",
          source_id: "node_a",
          target_id: "node_b",
          type: type
        }
        changeset = DecisionEdge.changeset(%DecisionEdge{}, attrs)
        assert changeset.valid?, "Type #{type} should be valid"
      end
    end

    test "rejects invalid type" do
      attrs = %{
        id: "edge_1",
        source_id: "node_a",
        target_id: "node_b",
        type: "invalid_type"
      }
      changeset = DecisionEdge.changeset(%DecisionEdge{}, attrs)
      refute changeset.valid?
    end

    test "validates weight is between 0.0 and 1.0" do
      attrs = %{
        id: "edge_1",
        source_id: "node_a",
        target_id: "node_b",
        type: "leads_to",
        weight: 0.5
      }
      changeset = DecisionEdge.changeset(%DecisionEdge{}, attrs)
      assert changeset.valid?
    end

    test "rejects weight greater than 1.0" do
      attrs = %{
        id: "edge_1",
        source_id: "node_a",
        target_id: "node_b",
        type: "leads_to",
        weight: 1.5
      }
      changeset = DecisionEdge.changeset(%DecisionEdge{}, attrs)
      refute changeset.valid?
    end

    test "rejects negative weight" do
      attrs = %{
        id: "edge_1",
        source_id: "node_a",
        target_id: "node_b",
        type: "leads_to",
        weight: -0.1
      }
      changeset = DecisionEdge.changeset(%DecisionEdge{}, attrs)
      refute changeset.valid?
    end

    test "accepts weight of 0.0" do
      attrs = %{
        id: "edge_1",
        source_id: "node_a",
        target_id: "node_b",
        type: "leads_to",
        weight: 0.0
      }
      changeset = DecisionEdge.changeset(%DecisionEdge{}, attrs)
      assert changeset.valid?
    end

    test "accepts weight of 1.0" do
      attrs = %{
        id: "edge_1",
        source_id: "node_a",
        target_id: "node_b",
        type: "leads_to",
        weight: 1.0
      }
      changeset = DecisionEdge.changeset(%DecisionEdge{}, attrs)
      assert changeset.valid?
    end

    test "defaults weight to 1.0" do
      attrs = %{
        id: "edge_1",
        source_id: "node_a",
        target_id: "node_b",
        type: "leads_to"
      }
      changeset = DecisionEdge.changeset(%DecisionEdge{}, attrs)
      assert Ecto.Changeset.get_change(changeset, :weight) == 1.0
    end
  end

  describe "struct fields" do
    test "has id field" do
      edge = %DecisionEdge{id: "test", source_id: "a", target_id: "b", type: "leads_to"}
      assert edge.id == "test"
    end

    test "has source_id field" do
      edge = %DecisionEdge{id: "test", source_id: "a", target_id: "b", type: "leads_to"}
      assert edge.source_id == "a"
    end

    test "has target_id field" do
      edge = %DecisionEdge{id: "test", source_id: "a", target_id: "b", type: "leads_to"}
      assert edge.target_id == "b"
    end

    test "has type field" do
      edge = %DecisionEdge{id: "test", source_id: "a", target_id: "b", type: "leads_to"}
      assert edge.type == "leads_to"
    end

    test "has weight field" do
      edge = %DecisionEdge{id: "test", source_id: "a", target_id: "b", type: "leads_to", weight: 0.5}
      assert edge.weight == 0.5
    end

    test "has rationale field" do
      edge = %DecisionEdge{id: "test", source_id: "a", target_id: "b", type: "leads_to", rationale: "test rationale"}
      assert edge.rationale == "test rationale"
    end

    test "has inserted_at field" do
      edge = %DecisionEdge{id: "test", source_id: "a", target_id: "b", type: "leads_to", inserted_at: NaiveDateTime.utc_now()}
      assert %NaiveDateTime{} = edge.inserted_at
    end
  end

  describe "type values" do
    test "accepts leads_to type" do
      attrs = %{id: "e1", source_id: "a", target_id: "b", type: "leads_to"}
      changeset = DecisionEdge.changeset(%DecisionEdge{}, attrs)
      assert changeset.valid?
    end

    test "accepts chosen type" do
      attrs = %{id: "e1", source_id: "a", target_id: "b", type: "chosen"}
      changeset = DecisionEdge.changeset(%DecisionEdge{}, attrs)
      assert changeset.valid?
    end

    test "accepts rejected type" do
      attrs = %{id: "e1", source_id: "a", target_id: "b", type: "rejected"}
      changeset = DecisionEdge.changeset(%DecisionEdge{}, attrs)
      assert changeset.valid?
    end

    test "accepts requires type" do
      attrs = %{id: "e1", source_id: "a", target_id: "b", type: "requires"}
      changeset = DecisionEdge.changeset(%DecisionEdge{}, attrs)
      assert changeset.valid?
    end

    test "accepts blocks type" do
      attrs = %{id: "e1", source_id: "a", target_id: "b", type: "blocks"}
      changeset = DecisionEdge.changeset(%DecisionEdge{}, attrs)
      assert changeset.valid?
    end

    test "accepts enables type" do
      attrs = %{id: "e1", source_id: "a", target_id: "b", type: "enables"}
      changeset = DecisionEdge.changeset(%DecisionEdge{}, attrs)
      assert changeset.valid?
    end

    test "accepts supersedes type" do
      attrs = %{id: "e1", source_id: "a", target_id: "b", type: "supersedes"}
      changeset = DecisionEdge.changeset(%DecisionEdge{}, attrs)
      assert changeset.valid?
    end

    test "accepts supports type" do
      attrs = %{id: "e1", source_id: "a", target_id: "b", type: "supports"}
      changeset = DecisionEdge.changeset(%DecisionEdge{}, attrs)
      assert changeset.valid?
    end

    test "accepts revises type" do
      attrs = %{id: "e1", source_id: "a", target_id: "b", type: "revises"}
      changeset = DecisionEdge.changeset(%DecisionEdge{}, attrs)
      assert changeset.valid?
    end

    test "accepts summarizes type" do
      attrs = %{id: "e1", source_id: "a", target_id: "b", type: "summarizes"}
      changeset = DecisionEdge.changeset(%DecisionEdge{}, attrs)
      assert changeset.valid?
    end
  end

  describe "edge cases" do
    # Note: "handles empty string ids" test removed - Ecto's validate_required DOES reject
    # empty strings with "can't be blank". The original test comment was incorrect.

    test "handles unicode in ids" do
      attrs = %{id: "边_1", source_id: "节点_a", target_id: "节点_b", type: "leads_to"}
      changeset = DecisionEdge.changeset(%DecisionEdge{}, attrs)
      assert changeset.valid?
    end

    test "handles unicode in rationale" do
      attrs = %{
        id: "edge_1",
        source_id: "node_a",
        target_id: "node_b",
        type: "leads_to",
        rationale: "这是理由"
      }
      changeset = DecisionEdge.changeset(%DecisionEdge{}, attrs)
      assert changeset.valid?
    end

    test "handles very long ids" do
      long_id = String.duplicate("a", 1000)
      attrs = %{id: long_id, source_id: long_id, target_id: long_id, type: "leads_to"}
      changeset = DecisionEdge.changeset(%DecisionEdge{}, attrs)
      assert changeset.valid?
    end

    test "handles nil rationale" do
      attrs = %{
        id: "edge_1",
        source_id: "node_a",
        target_id: "node_b",
        type: "leads_to",
        rationale: nil
      }
      changeset = DecisionEdge.changeset(%DecisionEdge{}, attrs)
      assert changeset.valid?
    end
  end

  describe "integration" do
    test "full edge changeset lifecycle" do
      attrs = %{
        id: "edge_1",
        source_id: "node_a",
        target_id: "node_b",
        type: "leads_to",
        weight: 0.8,
        rationale: "Test rationale"
      }
      changeset = DecisionEdge.changeset(%DecisionEdge{}, attrs)
      assert changeset.valid?

      # Apply changeset
      edge = Ecto.Changeset.apply_changes(changeset)
      assert edge.id == "edge_1"
      assert edge.source_id == "node_a"
      assert edge.target_id == "node_b"
      assert edge.type == "leads_to"
      assert edge.weight == 0.8
      assert edge.rationale == "Test rationale"
    end
  end
end
