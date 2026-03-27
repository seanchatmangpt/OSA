defmodule OptimalSystemAgent.ContextMesh.RegistryTest do
  @moduledoc """
  Unit tests for Registry module.

  Tests ETS-backed registry of active ContextMesh Keepers.
  """

  use ExUnit.Case, async: false


  alias OptimalSystemAgent.ContextMesh.Registry

  @moduletag :capture_log

  setup do
    # Initialize ETS table for tests
    Registry.init_table()

    # Clean up ETS table after each test
    on_exit(fn ->
      :ets.delete_all_objects(:osa_context_mesh_keepers)
    end)

    :ok
  end

  describe "init_table/0" do
    test "creates ETS table" do
      assert :ok = Registry.init_table()
      # Verify table exists
      assert :ets.whereis(:osa_context_mesh_keepers) != :undefined
    end

    test "idempotent - can be called multiple times" do
      assert :ok = Registry.init_table()
      assert :ok = Registry.init_table()
    end
  end

  describe "register/3" do
    test "registers a new keeper with defaults" do
      assert :ok = Registry.register("team1", "keeper1")

      meta = Registry.lookup("team1", "keeper1")
      assert meta != nil
      assert meta.team_id == "team1"
      assert meta.keeper_id == "keeper1"
      assert meta.token_count == 0
      assert meta.staleness == 0
      assert meta.created_at != nil
      assert meta.last_accessed != nil
    end

    test "registers a keeper with custom metadata" do
      now = DateTime.utc_now()
      meta = %{
        token_count: 1000,
        staleness: 50,
        created_at: now,
        last_accessed: now
      }

      assert :ok = Registry.register("team1", "keeper1", meta)

      result = Registry.lookup("team1", "keeper1")
      assert result.token_count == 1000
      assert result.staleness == 50
    end

    test "overwrites existing keeper with same team_id and keeper_id" do
      Registry.register("team1", "keeper1", %{token_count: 100})
      Registry.register("team1", "keeper1", %{token_count: 200})

      meta = Registry.lookup("team1", "keeper1")
      assert meta.token_count == 200
    end
  end

  describe "unregister/2" do
    test "removes keeper from registry" do
      Registry.register("team1", "keeper1")

      assert :ok = Registry.unregister("team1", "keeper1")

      assert Registry.lookup("team1", "keeper1") == nil
    end

    test "returns :ok for non-existent keeper" do
      assert :ok = Registry.unregister("nonexistent", "keeper")
    end
  end

  describe "lookup/2" do
    test "returns metadata for registered keeper" do
      Registry.register("team1", "keeper1", %{token_count: 500})

      meta = Registry.lookup("team1", "keeper1")
      assert meta != nil
      assert meta.team_id == "team1"
      assert meta.keeper_id == "keeper1"
      assert meta.token_count == 500
    end

    test "returns nil for non-existent keeper" do
      assert Registry.lookup("nonexistent", "keeper") == nil
    end

    test "returns nil for wrong team_id" do
      Registry.register("team1", "keeper1")
      assert Registry.lookup("team2", "keeper1") == nil
    end
  end

  describe "list_by_team/1" do
    test "returns all keepers for a team" do
      Registry.register("team1", "keeper1")
      Registry.register("team1", "keeper2")
      Registry.register("team2", "keeper1")

      team1_keepers = Registry.list_by_team("team1")
      assert length(team1_keepers) == 2

      keeper_ids = Enum.map(team1_keepers, & &1.keeper_id)
      assert "keeper1" in keeper_ids
      assert "keeper2" in keeper_ids
    end

    test "returns empty list for team with no keepers" do
      assert Registry.list_by_team("nonexistent") == []
    end

    test "sorts results by created_at" do
      Registry.register("team1", "keeper1")
      Process.sleep(10)
      Registry.register("team1", "keeper2")

      keepers = Registry.list_by_team("team1")
      assert length(keepers) == 2
      assert Enum.at(keepers, 0).keeper_id == "keeper1"
      assert Enum.at(keepers, 1).keeper_id == "keeper2"
    end
  end

  describe "list_all/0" do
    test "returns all keepers across all teams" do
      Registry.register("team1", "keeper1")
      Registry.register("team1", "keeper2")
      Registry.register("team2", "keeper1")

      all_keepers = Registry.list_all()
      assert length(all_keepers) == 3
    end

    test "returns empty list when no keepers registered" do
      assert Registry.list_all() == []
    end

    test "sorts results by created_at" do
      Registry.register("team1", "keeper1")
      Process.sleep(10)
      Registry.register("team2", "keeper1")

      keepers = Registry.list_all()
      assert length(keepers) == 2
      assert Enum.at(keepers, 0).team_id == "team1"
      assert Enum.at(keepers, 1).team_id == "team2"
    end
  end

  describe "update/3" do
    test "updates metadata fields for existing keeper" do
      Registry.register("team1", "keeper1", %{token_count: 100})

      assert :ok = Registry.update("team1", "keeper1", %{token_count: 200})

      meta = Registry.lookup("team1", "keeper1")
      assert meta.token_count == 200
    end

    test "returns :ok for non-existent keeper" do
      assert :ok = Registry.update("nonexistent", "keeper", %{token_count: 100})
    end

    test "merges updates with existing metadata" do
      Registry.register("team1", "keeper1", %{
        token_count: 100,
        staleness: 50
      })

      Registry.update("team1", "keeper1", %{token_count: 200})

      meta = Registry.lookup("team1", "keeper1")
      assert meta.token_count == 200
      assert meta.staleness == 50  # Unchanged
    end
  end

  describe "refresh_from_stats/3" do
    test "updates token_count and staleness from stats map" do
      Registry.register("team1", "keeper1", %{token_count: 100})

      stats = %{
        token_count: 500,
        created_at: DateTime.utc_now(),
        last_accessed_at: DateTime.utc_now(),
        relevance_score: 0.8,
        access_patterns: %{{"agent1", :smart} => 5}
      }

      assert :ok = Registry.refresh_from_stats("team1", "keeper1", stats)

      meta = Registry.lookup("team1", "keeper1")
      assert meta.token_count == 500
      assert meta.staleness >= 0
      assert is_integer(meta.staleness)
    end

    test "uses defaults for missing stats fields" do
      Registry.register("team1", "keeper1")

      assert :ok = Registry.refresh_from_stats("team1", "keeper1", %{})

      meta = Registry.lookup("team1", "keeper1")
      assert meta.token_count == 0
      assert meta.staleness >= 0
    end
  end

  describe "integration - full lifecycle" do
    test "register, lookup, update, unregister" do
      # Register
      Registry.register("team1", "keeper1", %{token_count: 100})

      # Lookup
      meta = Registry.lookup("team1", "keeper1")
      assert meta.token_count == 100

      # Update
      Registry.update("team1", "keeper1", %{token_count: 200})
      meta = Registry.lookup("team1", "keeper1")
      assert meta.token_count == 200

      # Unregister
      Registry.unregister("team1", "keeper1")
      assert Registry.lookup("team1", "keeper1") == nil
    end

    test "multiple teams with multiple keepers" do
      # Team 1
      Registry.register("team1", "keeper1")
      Registry.register("team1", "keeper2")

      # Team 2
      Registry.register("team2", "keeper1")
      Registry.register("team2", "keeper2")

      assert length(Registry.list_by_team("team1")) == 2
      assert length(Registry.list_by_team("team2")) == 2
      assert length(Registry.list_all()) == 4
    end
  end
end
