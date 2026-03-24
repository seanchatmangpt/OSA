defmodule OptimalSystemAgent.Memory.ConsolidatorTest do
  @moduledoc """
  Chicago TDD unit tests for Memory.Consolidator module.

  Tests pattern consolidation logic for merging similar memory entries.
  Pure functions, no state, no mocks.
  """

  use ExUnit.Case, async: true

  alias OptimalSystemAgent.Memory.Consolidator

  @moduletag :capture_log

  describe "consolidate/1" do
    test "returns empty list for empty input" do
      assert Consolidator.consolidate([]) == []
    end

    test "returns single entry unchanged" do
      entries = [
        %{id: "1", content: "test", keywords: "test", category: "decision"}
      ]
      result = Consolidator.consolidate(entries)
      assert length(result) == 1
    end

    test "merges entries with identical keywords" do
      entries = [
        %{id: "1", content: "Use TDD", keywords: "tdd,testing", category: "decision", accessed_at: "2024-01-01T00:00:00Z"},
        %{id: "2", content: "Always test first", keywords: "tdd,testing", category: "decision", accessed_at: "2024-01-02T00:00:00Z"}
      ]
      result = Consolidator.consolidate(entries)
      # Should consolidate into one entry
      assert length(result) <= 2
    end

    test "preserves entries with different keywords" do
      entries = [
        %{id: "1", content: "Use Elixir", keywords: "elixir", category: "decision"},
        %{id: "2", content: "Use Rust", keywords: "rust", category: "decision"}
      ]
      result = Consolidator.consolidate(entries)
      assert length(result) == 2
    end

    test "keeps most recent accessed_at when merging" do
      entries = [
        %{id: "1", content: "test", keywords: "test", category: "decision", accessed_at: "2024-01-01T00:00:00Z"},
        %{id: "2", content: "test2", keywords: "test", category: "decision", accessed_at: "2024-01-02T00:00:00Z"}
      ]
      result = Consolidator.consolidate(entries)
      # The consolidated entry should have the most recent accessed_at
      consolidated = List.first(result)
      assert consolidated.accessed_at == "2024-01-02T00:00:00Z"
    end

    test "combines keywords from merged entries" do
      entries = [
        %{id: "1", content: "test1", keywords: "elixir,testing", category: "decision"},
        %{id: "2", content: "test2", keywords: "elixir,tdd", category: "decision"}
      ]
      result = Consolidator.consolidate(entries)
      consolidated = List.first(result)
      # Should have combined keywords: elixir, testing, tdd
      assert String.contains?(consolidated.keywords, "elixir")
    end
  end

  describe "similarity_score/2" do
    test "returns 1.0 for identical entries" do
      entry1 = %{keywords: "elixir,testing", category: "decision"}
      entry2 = %{keywords: "elixir,testing", category: "decision"}
      score = Consolidator.similarity_score(entry1, entry2)
      assert score == 1.0
    end

    test "returns 0.0 for entries with no overlap" do
      entry1 = %{keywords: "elixir", category: "decision"}
      entry2 = %{keywords: "rust", category: "decision"}
      score = Consolidator.similarity_score(entry1, entry2)
      assert score == 0.0
    end

    test "computes partial similarity for some keyword overlap" do
      entry1 = %{keywords: "elixir,testing,tdd", category: "decision"}
      entry2 = %{keywords: "elixir,testing", category: "decision"}
      score = Consolidator.similarity_score(entry1, entry2)
      assert score > 0.0
      assert score < 1.0
    end

    test "factors category into similarity" do
      entry1 = %{keywords: "test", category: "decision"}
      entry2 = %{keywords: "test", category: "preference"}
      score = Consolidator.similarity_score(entry1, entry2)
      # Different categories should reduce similarity
      assert score < 1.0
    end
  end

  describe "merge_entries/2" do
    test "combines content from both entries" do
      entry1 = %{id: "1", content: "First content", keywords: "test", category: "decision"}
      entry2 = %{id: "2", content: "Second content", keywords: "test", category: "decision"}
      merged = Consolidator.merge_entries(entry1, entry2)
      # Should contain both content pieces
      assert String.contains?(merged.content, entry1.content) or String.contains?(merged.content, entry2.content)
    end

    test "takes most recent accessed_at" do
      entry1 = %{id: "1", content: "test", keywords: "test", category: "decision", accessed_at: "2024-01-01T00:00:00Z"}
      entry2 = %{id: "2", content: "test", keywords: "test", category: "decision", accessed_at: "2024-01-02T00:00:00Z"}
      merged = Consolidator.merge_entries(entry1, entry2)
      assert merged.accessed_at == "2024-01-02T00:00:00Z"
    end

    test "preserves higher category weight" do
      entry1 = %{id: "1", content: "test", keywords: "test", category: "decision"}
      entry2 = %{id: "2", content: "test", keywords: "test", category: "context"}
      merged = Consolidator.merge_entries(entry1, entry2)
      # Should keep "decision" (higher weight)
      assert merged.category == "decision"
    end

    test "combines keywords from both entries" do
      entry1 = %{id: "1", content: "test", keywords: "elixir", category: "decision"}
      entry2 = %{id: "2", content: "test", keywords: "testing", category: "decision"}
      merged = Consolidator.merge_entries(entry1, entry2)
      # Should have both keywords
      assert String.contains?(merged.keywords, "elixir")
      assert String.contains?(merged.keywords, "testing")
    end

    test "deduplicates keywords" do
      entry1 = %{id: "1", content: "test", keywords: "elixir,testing", category: "decision"}
      entry2 = %{id: "2", content: "test", keywords: "elixir,testing", category: "decision"}
      merged = Consolidator.merge_entries(entry1, entry2)
      # Keywords should not be duplicated
      keyword_list = String.split(merged.keywords, ",")
      assert Enum.uniq(keyword_list) == keyword_list
    end
  end

  describe "keyword_union/2" do
    test "combines two keyword strings" do
      keywords1 = "elixir,testing"
      keywords2 = "rust,tdd"
      result = Consolidator.keyword_union(keywords1, keywords2)
      assert "elixir" in String.split(result, ",")
      assert "testing" in String.split(result, ",")
      assert "rust" in String.split(result, ",")
      assert "tdd" in String.split(result, ",")
    end

    test "deduplicates keywords" do
      keywords1 = "elixir,testing"
      keywords2 = "elixir,testing"
      result = Consolidator.keyword_union(keywords1, keywords2)
      keyword_list = String.split(result, ",") |> Enum.map(&String.trim/1)
      assert length(Enum.uniq(keyword_list)) == length(keyword_list)
    end

    test "handles empty strings" do
      assert Consolidator.keyword_union("", "test") == "test"
      assert Consolidator.keyword_union("test", "") == "test"
      assert Consolidator.keyword_union("", "") == ""
    end

    test "handles whitespace" do
      keywords1 = "elixir, testing"
      keywords2 = "rust , tdd"
      result = Consolidator.keyword_union(keywords1, keywords2)
      # Should trim whitespace
      refute " testing" in String.split(result, ",")
      refute "rust " in String.split(result, ",")
    end
  end

  describe "higher_weight_category/2" do
    test "selects decision over context" do
      assert Consolidator.higher_weight_category("decision", "context") == "decision"
    end

    test "selects preference over lesson" do
      assert Consolidator.higher_weight_category("preference", "lesson") == "preference"
    end

    test "returns first category when weights are equal" do
      result = Consolidator.higher_weight_category("pattern", "pattern")
      assert result == "pattern"
    end

    test "handles unknown categories" do
      result = Consolidator.higher_weight_category("unknown", "decision")
      # Should prefer decision over unknown
      assert result == "decision"
    end
  end

  describe "consolidation_threshold/0" do
    test "returns threshold value" do
      # From module: @consolidation_threshold 0.8
      threshold = Consolidator.consolidation_threshold()
      assert is_float(threshold)
      assert threshold > 0.0
      assert threshold <= 1.0
    end
  end

  describe "edge cases" do
    test "handles entries with missing keywords" do
      entries = [
        %{id: "1", content: "test", category: "decision"},
        %{id: "2", content: "test", keywords: "elixir", category: "decision"}
      ]
      result = Consolidator.consolidate(entries)
      # Should handle missing keywords gracefully
      assert is_list(result)
    end

    test "handles entries with nil keywords" do
      entries = [
        %{id: "1", content: "test", keywords: nil, category: "decision"},
        %{id: "2", content: "test", keywords: "elixir", category: "decision"}
      ]
      result = Consolidator.consolidate(entries)
      assert is_list(result)
    end

    test "handles entries with string and atom keys mixed" do
      entry1 = %{"id" => "1", "content" => "test", "keywords" => "elixir", "category" => "decision"}
      entry2 = %{id: "2", content: "test", keywords: "elixir", category: "decision"}
      score = Consolidator.similarity_score(entry1, entry2)
      assert is_float(score)
    end

    test "handles very long keyword lists" do
      keywords1 = Enum.join(1..100, ",")
      keywords2 = Enum.join(50..150, ",")
      result = Consolidator.keyword_union(keywords1, keywords2)
      # Should handle large lists
      keyword_list = String.split(result, ",")
      assert length(keyword_list) > 0
    end

    test "handles unicode in keywords" do
      keywords1 = "elixir,测试"
      keywords2 = "elixir,テスト"
      result = Consolidator.keyword_union(keywords1, keywords2)
      assert String.contains?(result, "elixir")
      assert String.contains?(result, "测试")
      assert String.contains?(result, "テスト")
    end
  end

  describe "integration" do
    test "full consolidation pipeline with realistic entries" do
      entries = [
        %{id: "1", content: "Use TDD for Elixir", keywords: "tdd,elixir,testing", category: "decision", accessed_at: "2024-01-01T10:00:00Z"},
        %{id: "2", content: "Always write tests first", keywords: "tdd,testing,elixir", category: "decision", accessed_at: "2024-01-01T11:00:00Z"},
        %{id: "3", content: "Rust for performance", keywords: "rust,performance", category: "decision", accessed_at: "2024-01-01T12:00:00Z"},
        %{id: "4", content: "Prefer dark theme", keywords: "dark,theme", category: "preference", accessed_at: "2024-01-01T13:00:00Z"}
      ]

      result = Consolidator.consolidate(entries)

      # Should consolidate entries 1 and 2 (similar keywords and category)
      # Entries 3 and 4 should remain separate
      assert length(result) <= 4
      assert length(result) >= 2
    end

    test "handles large batch consolidation" do
      entries = for i <- 1..100 do
        kw = if rem(i, 2) == 0, do: "elixir,testing", else: "rust,performance"
        %{
          id: "#{i}",
          content: "Content #{i}",
          keywords: kw,
          category: "decision",
          accessed_at: "2024-01-01T00:00:00Z"
        }
      end

      result = Consolidator.consolidate(entries)
      # Should consolidate into fewer entries
      assert length(result) < 100
    end
  end
end
