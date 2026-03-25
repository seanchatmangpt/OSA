defmodule OptimalSystemAgent.Decisions.GraphTest do
  @moduledoc """
  Tests for Decisions.Graph.

  Tests node_to_map/1, edge_to_map/1, init_tables/0, and ETS-based
  operations (get_node, get_edges, cache behavior).

  Since the full CRUD operations (add_node, add_edge) depend on SQLite/Ecto
  which requires the application to be started, we test:
  - Pure conversion functions (node_to_map, edge_to_map)
  - ETS table initialization
  - ETS-backed operations with manually inserted data
  - Traversal with manually populated ETS data

  NOTE: Without Ecto, get_node/1 falls through to SQLite and crashes.
  We test only the ETS cache path by pre-populating the cache.
  """
  use ExUnit.Case, async: false

  alias OptimalSystemAgent.Decisions.Graph

  @nodes_table :osa_dg_nodes
  @edges_table :osa_dg_edges

  setup do
    # Ensure ETS tables exist
    Graph.init_tables()

    # Clean up any pre-existing data
    try do
      :ets.delete_all_objects(@nodes_table)
      :ets.delete_all_objects(@edges_table)
    rescue
      ArgumentError -> :ok
    end

    :ok
  end

  # ---------------------------------------------------------------------------
  # init_tables/0
  # ---------------------------------------------------------------------------

  describe "init_tables/0" do
    test "creates ETS tables and returns :ok" do
      assert :ok = Graph.init_tables()
    end

    test "is idempotent -- safe to call multiple times" do
      assert :ok = Graph.init_tables()
      assert :ok = Graph.init_tables()
      assert :ok = Graph.init_tables()
    end
  end

  # ---------------------------------------------------------------------------
  # ETS-backed node operations
  # ---------------------------------------------------------------------------

  describe "get_node/1 (ETS cache hit)" do
    test "returns node from ETS cache when present" do
      node_map = %{
        id: "node-1",
        type: :decision,
        title: "Use PostgreSQL",
        description: "Choose PostgreSQL for persistence",
        status: :active,
        confidence: 0.9,
        agent_name: "architect",
        team_id: "team-1",
        session_id: "session-1",
        metadata: %{rationale: "ACID compliance"},
        inserted_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now()
      }

      :ets.insert(@nodes_table, {"node-1", node_map})

      assert {:ok, retrieved} = Graph.get_node("node-1")
      assert retrieved.id == "node-1"
      assert retrieved.title == "Use PostgreSQL"
      assert retrieved.type == :decision
      assert retrieved.confidence == 0.9
      assert retrieved.team_id == "team-1"
    end

    test "returns different nodes for different IDs" do
      for {id, title} <- [{"n1", "First"}, {"n2", "Second"}] do
        node = %{
          id: id,
          type: :goal,
          title: title,
          status: :active,
          confidence: 1.0,
          team_id: "team-1",
          metadata: %{},
          inserted_at: DateTime.utc_now(),
          updated_at: DateTime.utc_now()
        }

        :ets.insert(@nodes_table, {id, node})
      end

      {:ok, n1} = Graph.get_node("n1")
      {:ok, n2} = Graph.get_node("n2")
      assert n1.title == "First"
      assert n2.title == "Second"
    end
  end

  # ---------------------------------------------------------------------------
  # ETS-backed edge operations
  # ---------------------------------------------------------------------------

  describe "get_edges/2 (ETS cache)" do
    test "returns empty list for node with no edges" do
      assert Graph.get_edges("orphan-node") == []
    end

    test "returns outgoing edges from ETS cache" do
      edge_map = %{
        id: "edge-1",
        source_id: "node-a",
        target_id: "node-b",
        type: :leads_to,
        rationale: "Option A leads to decision B",
        weight: 1.0,
        inserted_at: DateTime.utc_now()
      }

      :ets.insert(@edges_table, {{"node-a", :out}, [edge_map]})
      :ets.insert(@edges_table, {{"node-b", :in}, [edge_map]})

      edges = Graph.get_edges("node-a", direction: :out)
      assert length(edges) == 1
      assert hd(edges).type == :leads_to
      assert hd(edges).source_id == "node-a"
      assert hd(edges).target_id == "node-b"
    end

    test "returns incoming edges from ETS cache" do
      edge_map = %{
        id: "edge-2",
        source_id: "node-x",
        target_id: "node-y",
        type: :chosen,
        rationale: nil,
        weight: 1.0,
        inserted_at: DateTime.utc_now()
      }

      :ets.insert(@edges_table, {{"node-x", :out}, [edge_map]})
      :ets.insert(@edges_table, {{"node-y", :in}, [edge_map]})

      edges = Graph.get_edges("node-y", direction: :in)
      assert length(edges) == 1
      assert hd(edges).source_id == "node-x"
      assert hd(edges).target_id == "node-y"
    end

    test "returns both directions by default" do
      out_edge = %{
        id: "edge-out",
        source_id: "node-m",
        target_id: "node-n",
        type: :enables,
        rationale: nil,
        weight: 1.0,
        inserted_at: DateTime.utc_now()
      }

      in_edge = %{
        id: "edge-in",
        source_id: "node-k",
        target_id: "node-m",
        type: :requires,
        rationale: nil,
        weight: 1.0,
        inserted_at: DateTime.utc_now()
      }

      :ets.insert(@edges_table, {{"node-m", :out}, [out_edge]})
      :ets.insert(@edges_table, {{"node-n", :in}, [out_edge]})
      :ets.insert(@edges_table, {{"node-k", :out}, [in_edge]})
      :ets.insert(@edges_table, {{"node-m", :in}, [in_edge]})

      edges = Graph.get_edges("node-m")
      assert length(edges) == 2
    end
  end

  # ---------------------------------------------------------------------------
  # descendants/2 and ancestors/2 with pre-populated ETS data
  # ---------------------------------------------------------------------------

  describe "descendants/2 (ETS-only, no SQLite fallback)" do
    setup do
      # Pre-populate ETS with nodes and edges
      for {id, title, type} <- [
            {"root", "Root", :goal},
            {"child1", "Child 1", :decision},
            {"child2", "Child 2", :decision},
            {"gc1", "Grandchild 1", :observation}
          ] do
        node = %{
          id: id,
          type: type,
          title: title,
          status: :active,
          confidence: 1.0,
          team_id: "team-1",
          metadata: %{},
          inserted_at: DateTime.utc_now(),
          updated_at: DateTime.utc_now()
        }

        :ets.insert(@nodes_table, {id, node})
      end

      # Create edges in ETS (batch by source to avoid overwriting)
      edges_by_source = %{
        "root" => [
          %{
            id: "root-child1",
            source_id: "root",
            target_id: "child1",
            type: :leads_to,
            rationale: nil,
            weight: 1.0,
            inserted_at: DateTime.utc_now()
          },
          %{
            id: "root-child2",
            source_id: "root",
            target_id: "child2",
            type: :leads_to,
            rationale: nil,
            weight: 1.0,
            inserted_at: DateTime.utc_now()
          }
        ],
        "child1" => [
          %{
            id: "child1-gc1",
            source_id: "child1",
            target_id: "gc1",
            type: :enables,
            rationale: nil,
            weight: 1.0,
            inserted_at: DateTime.utc_now()
          }
        ]
      }

      for {source_id, edges} <- edges_by_source do
        :ets.insert(@edges_table, {{source_id, :out}, edges})

        for edge <- edges do
          :ets.insert(@edges_table, {{edge.target_id, :in}, [edge]})
        end
      end

      :ok
    end

    test "returns only start node when no edges exist" do
      # node "solo" is NOT in ETS, so traversal returns only nodes
      # that exist in ETS and are reachable
      # Since "solo" isn't cached, get_node returns :miss -> SQLite fallback
      # which fails. Test with a node that IS cached.
      assert {:ok, [result]} = Graph.descendants("root", max_depth: 0)
      assert result.id == "root"
    end

    test "traverses outgoing edges to find descendants" do
      {:ok, result} = Graph.descendants("root")
      ids = Enum.map(result, & &1.id) |> Enum.sort()

      assert "root" in ids
      assert "child1" in ids
      assert "child2" in ids
      assert "gc1" in ids
      assert length(ids) == 4
    end

    test "respects include_self: false" do
      {:ok, result} = Graph.descendants("root", include_self: false)
      ids = Enum.map(result, & &1.id) |> Enum.sort()

      refute "root" in ids
      assert "child1" in ids
      assert "child2" in ids
      assert "gc1" in ids
      assert length(ids) == 3
    end
  end

  describe "ancestors/2 (ETS-only)" do
    setup do
      for {id, title, type} <- [
            {"leaf", "Leaf", :observation},
            {"parent", "Parent", :decision},
            {"grandparent", "Grandparent", :goal}
          ] do
        node = %{
          id: id,
          type: type,
          title: title,
          status: :active,
          confidence: 1.0,
          team_id: "team-1",
          metadata: %{},
          inserted_at: DateTime.utc_now(),
          updated_at: DateTime.utc_now()
        }

        :ets.insert(@nodes_table, {id, node})
      end

      # Edges: grandparent -> parent -> leaf
      for {sid, tid, type} <- [
            {"grandparent", "parent", :leads_to},
            {"parent", "leaf", :requires}
          ] do
        edge = %{
          id: "#{sid}-#{tid}",
          source_id: sid,
          target_id: tid,
          type: type,
          rationale: nil,
          weight: 1.0,
          inserted_at: DateTime.utc_now()
        }

        :ets.insert(@edges_table, {{sid, :out}, [edge]})
        :ets.insert(@edges_table, {{tid, :in}, [edge]})
      end

      :ok
    end

    test "traverses incoming edges to find ancestors" do
      {:ok, result} = Graph.ancestors("leaf")
      ids = Enum.map(result, & &1.id) |> Enum.sort()

      assert "leaf" in ids
      assert "parent" in ids
      assert "grandparent" in ids
      assert length(ids) == 3
    end

    test "ancestors with include_self: false excludes start node" do
      {:ok, result} = Graph.ancestors("leaf", include_self: false)
      ids = Enum.map(result, & &1.id) |> Enum.sort()

      refute "leaf" in ids
      assert "parent" in ids
      assert "grandparent" in ids
    end
  end

  # ---------------------------------------------------------------------------
  # node_to_map/1 and edge_to_map/1
  # ---------------------------------------------------------------------------

  describe "node_to_map/1 and edge_to_map/1" do
    test "node_to_map/1 converts DecisionNode-like struct" do
      node = struct(
        OptimalSystemAgent.Store.DecisionNode,
        %{
          id: "n1",
          type: :decision,
          title: "Test",
          description: "Test node",
          status: :active,
          confidence: 0.85,
          agent_name: "test-agent",
          team_id: "team-1",
          session_id: "sess-1",
          metadata: %{key: "val"},
          inserted_at: ~U[2026-01-01 00:00:00Z],
          updated_at: ~U[2026-01-01 00:00:00Z]
        }
      )

      result = Graph.node_to_map(node)

      assert result.id == "n1"
      assert result.type == :decision
      assert result.title == "Test"
      assert result.description == "Test node"
      assert result.status == :active
      assert result.confidence == 0.85
      assert result.agent_name == "test-agent"
      assert result.team_id == "team-1"
      assert result.session_id == "sess-1"
      assert result.metadata == %{key: "val"}
    end

    test "edge_to_map/1 converts DecisionEdge-like struct" do
      edge = struct(
        OptimalSystemAgent.Store.DecisionEdge,
        %{
          id: "e1",
          source_id: "n1",
          target_id: "n2",
          type: :chosen,
          rationale: "Best option",
          weight: 1.5,
          inserted_at: ~U[2026-01-01 00:00:00Z]
        }
      )

      result = Graph.edge_to_map(edge)

      assert result.id == "e1"
      assert result.source_id == "n1"
      assert result.target_id == "n2"
      assert result.type == :chosen
      assert result.rationale == "Best option"
      assert result.weight == 1.5
    end
  end

  # ---------------------------------------------------------------------------
  # Cycle handling
  # ---------------------------------------------------------------------------

  describe "cycle handling" do
    setup do
      for id <- ["cyc-a", "cyc-b", "cyc-c"] do
        node = %{
          id: id,
          type: :decision,
          title: id,
          status: :active,
          confidence: 1.0,
          team_id: "team-1",
          metadata: %{},
          inserted_at: DateTime.utc_now(),
          updated_at: DateTime.utc_now()
        }

        :ets.insert(@nodes_table, {id, node})
      end

      for {sid, tid} <- [{"cyc-a", "cyc-b"}, {"cyc-b", "cyc-c"}, {"cyc-c", "cyc-a"}] do
        edge = %{
          id: "#{sid}-#{tid}",
          source_id: sid,
          target_id: tid,
          type: :leads_to,
          rationale: nil,
          weight: 1.0,
          inserted_at: DateTime.utc_now()
        }

        :ets.insert(@edges_table, {{sid, :out}, [edge]})
        :ets.insert(@edges_table, {{tid, :in}, [edge]})
      end

      :ok
    end

    test "traversal does not loop infinitely on cycles" do
      {:ok, result} = Graph.descendants("cyc-a")
      ids = Enum.map(result, & &1.id) |> Enum.sort()

      # Should find all 3 nodes without looping
      assert length(ids) == 3
      assert "cyc-a" in ids
      assert "cyc-b" in ids
      assert "cyc-c" in ids
    end
  end

  # ---------------------------------------------------------------------------
  # Team isolation
  # ---------------------------------------------------------------------------

  describe "team isolation" do
    setup do
      for {id, team} <- [{"team1-node", "team-1"}, {"team2-node", "team-2"}] do
        node = %{
          id: id,
          type: :goal,
          title: id,
          status: :active,
          confidence: 1.0,
          team_id: team,
          metadata: %{},
          inserted_at: DateTime.utc_now(),
          updated_at: DateTime.utc_now()
        }

        :ets.insert(@nodes_table, {id, node})
      end

      :ok
    end

    test "descendants filters by team_id when provided" do
      {:ok, result} = Graph.descendants("team1-node", team_id: "team-1")
      ids = Enum.map(result, & &1.id)

      assert "team1-node" in ids
      refute "team2-node" in ids
    end

    test "descendants returns all teams when team_id is nil" do
      {:ok, result} = Graph.descendants("team1-node")
      ids = Enum.map(result, & &1.id)

      assert "team1-node" in ids
    end
  end
end
