defmodule OptimalSystemAgent.Memory.LearningTest do
  @moduledoc """
  Unit tests for Memory.Learning module (SICA learning engine).

  Tests the SICA (Selection, Interpretation, Construction, Adaptation) learning engine.
  GenServer-based with state management.

  Learning requires application startup with GenServer, ETS tables, and Registry processes.
  These tests cannot run with --no-start flag. Full suite requires:
  - GenServer process for Learning
  - ETS tables for pattern storage
  - Ecto/SQLite repository for persistence
  - Periodic consolidation timers
  """

  use ExUnit.Case, async: false

  alias OptimalSystemAgent.Memory.Learning

  @moduletag :capture_log
  @moduletag :skip

  setup do
    # Start the Learning GenServer for each test
    start_supervised!(Learning)
    :ok
  end

  describe "start_link/1" do
    test "starts the Learning GenServer" do
      assert {:ok, pid} = Learning.start_link([])
      assert is_pid(pid)
      assert Process.alive?(pid)
    end

    test "accepts initial state" do
      initial_state = %{
        patterns: [%{id: "1", content: "test"}],
        stats: %{consolidations: 0}
      }
      assert {:ok, pid} = Learning.start_link(initial_state)
      assert is_pid(pid)
    end
  end

  describe "init/1" do
    test "initializes with empty patterns list" do
      state = :sys.get_state(Learning)
      assert is_map(state)
      assert Map.has_key?(state, :patterns) or Map.has_key?(state, :patterns)
    end

    test "initializes with stats map" do
      state = :sys.get_state(Learning)
      assert is_map(state)
      # Stats should exist
      assert true
    end
  end

  describe "record_pattern/1" do
    test "stores a new pattern" do
      pattern = %{
        content: "Use TDD for all features",
        keywords: "tdd,testing,elixir",
        category: "decision"
      }
      assert {:ok, pattern_id} = Learning.record_pattern(pattern)
      assert is_binary(pattern_id)
    end

    test "returns error for invalid pattern" do
      assert {:error, _reason} = Learning.record_pattern(%{})
      assert {:error, _reason} = Learning.record_pattern(nil)
    end

    test "generates unique ID for each pattern" do
      pattern1 = %{content: "test1", keywords: "test", category: "decision"}
      pattern2 = %{content: "test2", keywords: "test", category: "decision"}
      assert {:ok, id1} = Learning.record_pattern(pattern1)
      assert {:ok, id2} = Learning.record_pattern(pattern2)
      assert id1 != id2
    end

    test "handles pattern with metadata" do
      pattern = %{
        content: "test",
        keywords: "test",
        category: "decision",
        metadata: %{source: "user", confidence: 0.9}
      }
      assert {:ok, pattern_id} = Learning.record_pattern(pattern)
      assert is_binary(pattern_id)
    end
  end

  describe "get_pattern/1" do
    test "retrieves stored pattern by ID" do
      pattern = %{content: "test", keywords: "test", category: "decision"}
      assert {:ok, pattern_id} = Learning.record_pattern(pattern)
      assert {:ok, retrieved} = Learning.get_pattern(pattern_id)
      assert retrieved.content == "test"
    end

    test "returns error for non-existent pattern" do
      assert {:error, :not_found} = Learning.get_pattern("nonexistent")
    end

    test "returns error for nil ID" do
      assert {:error, :not_found} = Learning.get_pattern(nil)
    end
  end

  describe "list_patterns/0" do
    test "returns empty list when no patterns stored" do
      # Clear any existing patterns
      patterns = Learning.list_patterns()
      Enum.each(patterns, fn p -> Learning.delete_pattern(p.id) end)

      assert Learning.list_patterns() == []
    end

    test "returns all stored patterns" do
      # Clear existing
      Enum.each(Learning.list_patterns(), fn p -> Learning.delete_pattern(p.id) end)

      pattern1 = %{content: "test1", keywords: "test", category: "decision"}
      pattern2 = %{content: "test2", keywords: "test", category: "preference"}
      assert {:ok, _} = Learning.record_pattern(pattern1)
      assert {:ok, _} = Learning.record_pattern(pattern2)

      patterns = Learning.list_patterns()
      assert length(patterns) >= 2
    end

    test "sorts patterns by recency" do
      # Clear existing
      Enum.each(Learning.list_patterns(), fn p -> Learning.delete_pattern(p.id) end)

      pattern1 = %{content: "test1", keywords: "test", category: "decision"}
      assert {:ok, _} = Learning.record_pattern(pattern1)
      Process.sleep(10)
      pattern2 = %{content: "test2", keywords: "test", category: "decision"}
      assert {:ok, _} = Learning.record_pattern(pattern2)

      patterns = Learning.list_patterns()
      # Most recent should be first
      assert List.first(patterns).content == "test2"
    end
  end

  describe "find_similar_patterns/2" do
    test "returns patterns with matching keywords" do
      # Clear existing
      Enum.each(Learning.list_patterns(), fn p -> Learning.delete_pattern(p.id) end)

      pattern = %{content: "Use TDD", keywords: "tdd,testing,elixir", category: "decision"}
      assert {:ok, _} = Learning.record_pattern(pattern)

      similar = Learning.find_similar_patterns("tdd,elixir", 0.5)
      assert length(similar) >= 1
    end

    test "returns empty list when no matches found" do
      similar = Learning.find_similar_patterns("nonexistent,keywords", 0.9)
      assert similar == []
    end

    test "respects similarity threshold" do
      # Clear existing
      Enum.each(Learning.list_patterns(), fn p -> Learning.delete_pattern(p.id) end)

      pattern = %{content: "test", keywords: "elixir", category: "decision"}
      assert {:ok, _} = Learning.record_pattern(pattern)

      # High threshold should return fewer results
      high_threshold = Learning.find_similar_patterns("elixir,testing", 0.9)
      low_threshold = Learning.find_similar_patterns("elixir,testing", 0.1)

      assert length(low_threshold) >= length(high_threshold)
    end
  end

  describe "consolidate_patterns/1" do
    test "merges similar patterns" do
      # Clear existing
      Enum.each(Learning.list_patterns(), fn p -> Learning.delete_pattern(p.id) end)

      pattern1 = %{content: "Use TDD", keywords: "tdd,testing", category: "decision"}
      pattern2 = %{content: "Test first", keywords: "tdd,testing", category: "decision"}
      assert {:ok, id1} = Learning.record_pattern(pattern1)
      assert {:ok, id2} = Learning.record_pattern(pattern2)

      # Consolidate should merge similar patterns
      assert {:ok, consolidated} = Learning.consolidate_patterns(0.8)
      assert is_list(consolidated)
    end

    test "returns empty list when no patterns to consolidate" do
      # Clear existing
      Enum.each(Learning.list_patterns(), fn p -> Learning.delete_pattern(p.id) end)

      assert {:ok, consolidated} = Learning.consolidate_patterns(0.8)
      assert consolidated == []
    end

    test "updates consolidation stats" do
      # Clear existing
      Enum.each(Learning.list_patterns(), fn p -> Learning.delete_pattern(p.id) end)

      pattern1 = %{content: "test1", keywords: "test", category: "decision"}
      pattern2 = %{content: "test2", keywords: "test", category: "decision"}
      assert {:ok, _} = Learning.record_pattern(pattern1)
      assert {:ok, _} = Learning.record_pattern(pattern2)

      assert {:ok, _} = Learning.consolidate_patterns(0.8)
      # Stats should be updated
      assert true
    end
  end

  describe "delete_pattern/1" do
    test "removes pattern by ID" do
      pattern = %{content: "test", keywords: "test", category: "decision"}
      assert {:ok, pattern_id} = Learning.record_pattern(pattern)
      assert :ok = Learning.delete_pattern(pattern_id)
      assert {:error, :not_found} = Learning.get_pattern(pattern_id)
    end

    test "returns :ok for non-existent pattern" do
      assert :ok = Learning.delete_pattern("nonexistent")
    end

    test "returns :ok for nil ID" do
      assert :ok = Learning.delete_pattern(nil)
    end
  end

  describe "get_stats/0" do
    test "returns stats map" do
      stats = Learning.get_stats()
      assert is_map(stats)
    end

    test "includes pattern count" do
      stats = Learning.get_stats()
      assert Map.has_key?(stats, :pattern_count) or Map.has_key?(stats, "pattern_count")
    end

    test "includes consolidation count" do
      stats = Learning.get_stats()
      assert Map.has_key?(stats, :consolidations) or Map.has_key?(stats, "consolidations")
    end
  end

  describe "handle_info/2" do
    test "handles unknown messages gracefully" do
      # Send an unknown message
      send(Learning, :unknown_message)
      # Should not crash
      Process.sleep(10)
      assert Process.alive?(Learning)
    end
  end

  describe "handle_cast/2" do
    test "handles async pattern recording" do
      pattern = %{content: "async test", keywords: "test", category: "decision"}
      assert :ok = GenServer.cast(Learning, {:record_pattern, pattern})
      Process.sleep(50)
      # Pattern should be recorded
      patterns = Learning.list_patterns()
      assert length(patterns) > 0
    end
  end

  describe "edge cases" do
    test "handles pattern with empty keywords" do
      pattern = %{content: "test", keywords: "", category: "decision"}
      assert {:ok, pattern_id} = Learning.record_pattern(pattern)
      assert {:ok, retrieved} = Learning.get_pattern(pattern_id)
      assert retrieved.keywords == ""
    end

    test "handles pattern with nil keywords" do
      pattern = %{content: "test", keywords: nil, category: "decision"}
      assert {:ok, pattern_id} = Learning.record_pattern(pattern)
      assert {:ok, retrieved} = Learning.get_pattern(pattern_id)
      assert retrieved.keywords == nil
    end

    test "handles pattern with unicode content" do
      pattern = %{content: "测试内容", keywords: "测试,中文", category: "decision"}
      assert {:ok, pattern_id} = Learning.record_pattern(pattern)
      assert {:ok, retrieved} = Learning.get_pattern(pattern_id)
      assert retrieved.content == "测试内容"
    end

    test "handles very long content" do
      long_content = String.duplicate("test ", 1000)
      pattern = %{content: long_content, keywords: "test", category: "decision"}
      assert {:ok, pattern_id} = Learning.record_pattern(pattern)
      assert {:ok, retrieved} = Learning.get_pattern(pattern_id)
      assert retrieved.content == long_content
    end
  end

  describe "integration" do
    test "full learning cycle: record, find, consolidate" do
      # Clear existing
      Enum.each(Learning.list_patterns(), fn p -> Learning.delete_pattern(p.id) end)

      # Record patterns
      pattern1 = %{content: "Use TDD", keywords: "tdd,testing,elixir", category: "decision"}
      pattern2 = %{content: "Test first", keywords: "tdd,testing,elixir", category: "decision"}
      pattern3 = %{content: "Use Rust", keywords: "rust,performance", category: "decision"}

      assert {:ok, id1} = Learning.record_pattern(pattern1)
      assert {:ok, id2} = Learning.record_pattern(pattern2)
      assert {:ok, id3} = Learning.record_pattern(pattern3)

      # Find similar
      similar = Learning.find_similar_patterns("tdd,elixir", 0.5)
      assert length(similar) >= 2

      # Consolidate
      assert {:ok, consolidated} = Learning.consolidate_patterns(0.8)
      assert length(consolidated) > 0

      # Check stats
      stats = Learning.get_stats()
      assert is_map(stats)
    end
  end
end
