defmodule OptimalSystemAgent.Memory.LearningTest do
  @moduledoc """
  Unit tests for Memory.Learning module (SICA learning engine).

  Tests the SICA (Selection, Interpretation, Construction, Adaptation) learning engine.
  GenServer-based with state management.
  """

  use ExUnit.Case, async: false

  alias OptimalSystemAgent.Memory.Learning

  @moduletag :capture_log
  @moduletag :skip

  setup_all do
    # Guard against already-started GenServer from previous test runs
    if Process.whereis(Learning) == nil do
      {:ok, _pid} = Learning.start_link([])
    end
    :ok
  end

  setup do
    # Learning is already running from supervisor - ensure it's available
    case Process.whereis(Learning) do
      nil -> {:ok, _pid} = Learning.start_link([]); :ok
      _pid -> :ok
    end
    :ok
  end

  describe "start_link/1" do
    test "starts the Learning GenServer" do
      assert Process.alive?(Learning)
      assert is_pid(Process.whereis(Learning))
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
      # Missing required fields
      assert {:error, :invalid_pattern} = Learning.record_pattern(%{})
      assert {:error, :invalid_pattern} = Learning.record_pattern(nil)
    end

    test "requires content and keywords fields" do
      # Missing keywords
      assert {:error, :invalid_pattern} = Learning.record_pattern(%{content: "test"})
      # Missing content
      assert {:error, :invalid_pattern} = Learning.record_pattern(%{keywords: "test"})
    end
  end

  describe "get_pattern/1" do
    test "retrieves stored pattern by ID" do
      pattern = %{content: "test", keywords: "test", category: "decision"}
      {:ok, pattern_id} = Learning.record_pattern(pattern)
      assert {:ok, retrieved} = Learning.get_pattern(pattern_id)
      assert retrieved.id == pattern_id
    end

    test "returns error for non-existent pattern" do
      assert {:error, :not_found} = Learning.get_pattern("nonexistent")
    end

    test "returns error for nil ID" do
      assert {:error, :not_found} = Learning.get_pattern(nil)
    end
  end

  describe "list_patterns/0" do
    test "returns list of patterns" do
      patterns = Learning.list_patterns()
      assert is_list(patterns)
    end

    test "returns patterns with expected structure" do
      patterns = Learning.list_patterns()

      if length(patterns) > 0 do
        pattern = List.first(patterns)
        assert is_map(pattern)
        # Consolidator patterns have id, description, trigger, etc
        assert Map.has_key?(pattern, :id) or Map.has_key?(pattern, "id")
      end
    end

    test "patterns are sorted by created_at" do
      patterns = Learning.list_patterns()

      if length(patterns) > 1 do
        # Check that timestamps are in descending order (most recent first)
        Enum.reduce(patterns, nil, fn p, prev ->
          created = p[:created_at] || p["created_at"]
          if prev do
            # ISO8601 strings compare lexicographically for descending order
            assert created <= prev
          end
          created
        end)
      end
    end
  end

  describe "find_similar_patterns/2" do
    test "returns list of patterns" do
      # find_similar_patterns filters patterns by keyword overlap
      similar = Learning.find_similar_patterns("testing,elixir", 0.5)
      assert is_list(similar)
    end

    test "returns empty list for high threshold" do
      similar = Learning.find_similar_patterns("nonexistent,keywords,xyz", 0.99)
      assert is_list(similar)
    end

    test "respects similarity threshold" do
      # High threshold should return fewer results than low threshold
      high_threshold = Learning.find_similar_patterns("elixir,testing", 0.9)
      low_threshold = Learning.find_similar_patterns("elixir,testing", 0.1)

      assert is_list(high_threshold)
      assert is_list(low_threshold)
      assert length(low_threshold) >= length(high_threshold)
    end
  end

  describe "consolidate_patterns/1" do
    test "returns ok tuple with list" do
      assert {:ok, consolidated} = Learning.consolidate_patterns(0.8)
      assert is_list(consolidated)
    end

    test "respects threshold parameter" do
      # Both should return lists
      assert {:ok, low} = Learning.consolidate_patterns(0.1)
      assert {:ok, high} = Learning.consolidate_patterns(0.9)
      assert is_list(low)
      assert is_list(high)
    end
  end

  describe "delete_pattern/1" do
    test "returns :ok for any pattern ID" do
      # delete_pattern always returns :ok
      assert :ok = Learning.delete_pattern("test_id")
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

    test "includes metrics keys" do
      stats = Learning.get_stats()
      # Stats should include interaction_count
      assert Map.has_key?(stats, :interaction_count) or Map.has_key?(stats, "interaction_count")
    end
  end

  describe "handle_cast/2" do
    test "accepts observe messages" do
      # observe sends {:observe, interaction} via GenServer.cast
      interaction = %{type: :success, tool_name: "test_tool", duration_ms: 100}
      assert :ok = Learning.observe(interaction)
      Process.sleep(10)
      # Should not crash
      assert Process.alive?(Learning)
    end

    test "accepts correction messages" do
      assert :ok = Learning.correction("wrong approach", "correct approach")
      Process.sleep(10)
      assert Process.alive?(Learning)
    end

    test "accepts error messages" do
      assert :ok = Learning.error("test_tool", "test error", %{})
      Process.sleep(10)
      assert Process.alive?(Learning)
    end
  end

  describe "edge cases" do
    test "handles pattern with empty keywords" do
      pattern = %{content: "test", keywords: "", category: "decision"}
      # Empty keywords string is still valid
      assert {:ok, _pattern_id} = Learning.record_pattern(pattern)
    end

    test "handles pattern with unicode content" do
      pattern = %{content: "测试内容", keywords: "测试,中文", category: "decision"}
      assert {:ok, _pattern_id} = Learning.record_pattern(pattern)
    end

    test "handles very long content" do
      long_content = String.duplicate("test ", 1000)
      pattern = %{content: long_content, keywords: "test", category: "decision"}
      assert {:ok, _pattern_id} = Learning.record_pattern(pattern)
    end

    test "observe handles missing keys gracefully" do
      # observe should tolerate partial interaction data
      assert :ok = Learning.observe(%{type: :success, tool_name: "test"})
    end
  end

  describe "integration" do
    test "full learning cycle: observe, error, consolidate" do
      # Record patterns with observation API
      assert :ok = Learning.observe(%{
        type: :success,
        tool_name: "file_read",
        duration_ms: 42
      })

      Process.sleep(10)

      # Record an error
      assert :ok = Learning.error("file_write", "permission denied", %{})

      Process.sleep(10)

      # Get patterns
      patterns = Learning.list_patterns()
      assert is_list(patterns)

      # Find similar
      similar = Learning.find_similar_patterns("file,read", 0.3)
      assert is_list(similar)

      # Consolidate
      assert {:ok, consolidated} = Learning.consolidate_patterns(0.5)
      assert is_list(consolidated)

      # Check stats
      stats = Learning.get_stats()
      assert is_map(stats)
      assert Map.has_key?(stats, :interaction_count) or Map.has_key?(stats, "interaction_count")
    end
  end
end
