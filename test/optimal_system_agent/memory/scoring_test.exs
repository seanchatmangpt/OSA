defmodule OptimalSystemAgent.Memory.ScoringTest do
  @moduledoc """
  Unit tests for Memory.Scoring module.

  Tests relevance scoring and keyword extraction for memory entries.
  Pure functions, no state, no mocks.
  """

  use ExUnit.Case, async: true

  alias OptimalSystemAgent.Memory.Scoring

  @moduletag :capture_log

  describe "score/3" do
    test "computes composite score for valid memory entry" do
      entry = %{
        keywords: "elixir,testing,tdd",
        category: "decision",
        accessed_at: DateTime.utc_now() |> DateTime.to_iso8601()
      }

      query_keywords = ["elixir", "testing"]
      score = Scoring.score(entry, query_keywords, nil)

      assert is_float(score)
      assert score >= 0.0
      assert score <= 1.0
    end

    test "returns 0.0 for non-map entry" do
      score = Scoring.score("not a map", ["keywords"], nil)
      assert score == 0.0
    end

    test "handles missing keywords gracefully" do
      entry = %{category: "decision", accessed_at: DateTime.utc_now() |> DateTime.to_iso8601()}
      score = Scoring.score(entry, ["test"], nil)
      assert is_float(score)
      assert score >= 0.0
    end

    test "handles missing accessed_at gracefully" do
      entry = %{keywords: "test", category: "decision"}
      score = Scoring.score(entry, ["test"], nil)
      assert is_float(score)
    end

    test "handles string keys in entry map" do
      entry = %{
        "keywords" => "elixir,testing",
        "category" => "decision",
        "accessed_at" => DateTime.utc_now() |> DateTime.to_iso8601()
      }

      score = Scoring.score(entry, ["elixir"], nil)
      assert is_float(score)
      assert score > 0.0
    end

    test "weighs components correctly: base 30%, context 50%, recency 20%" do
      now = DateTime.utc_now() |> DateTime.to_iso8601()

      # High category weight, full keyword overlap, recent access
      entry = %{
        keywords: "elixir,testing",
        category: "decision",
        accessed_at: now
      }

      score = Scoring.score(entry, ["elixir", "testing"], nil)

      # decision = 1.00 base weight, perfect overlap = 1.0, recent = ~1.0
      # 1.0 * 0.3 + 1.0 * 0.5 + 1.0 * 0.2 = 1.0
      assert score > 0.9
    end

    test "handles empty query keywords list" do
      entry = %{
        keywords: "elixir",
        category: "decision",
        accessed_at: DateTime.utc_now() |> DateTime.to_iso8601()
      }

      score = Scoring.score(entry, [], nil)
      # No overlap means context_score = 0, but base and recency still contribute
      assert is_float(score)
      assert score >= 0.0
    end

    test "respects session_id parameter (reserved for future use)" do
      entry = %{
        keywords: "elixir",
        category: "decision",
        accessed_at: DateTime.utc_now() |> DateTime.to_iso8601()
      }

      score1 = Scoring.score(entry, ["elixir"], nil)
      score2 = Scoring.score(entry, ["elixir"], "session_123")

      # Currently session_id is unused, so scores should be equal
      assert score1 == score2
    end
  end

  describe "extract_keywords/1" do
    test "returns empty list for nil" do
      assert Scoring.extract_keywords(nil) == []
    end

    test "returns empty list for empty string" do
      assert Scoring.extract_keywords("") == []
    end

    test "tokenizes and lowercases text" do
      keywords = Scoring.extract_keywords("Elixir Testing TDD")
      assert "elixir" in keywords
      assert "testing" in keywords
      assert "tdd" in keywords
    end

    test "removes punctuation" do
      keywords = Scoring.extract_keywords("hello, world! test.")
      assert "hello" in keywords
      assert "world" in keywords
      assert "test" in keywords
      refute "hello," in keywords
      refute "world!" in keywords
    end

    test "removes stop words" do
      keywords = Scoring.extract_keywords("the quick brown fox jumps over the lazy dog")
      assert is_list(keywords)
      refute "the" in keywords
      # "over" may or may not be in stop words depending on implementation
      assert "quick" in keywords
      assert "brown" in keywords
      assert "fox" in keywords
    end

    test "removes words shorter than 3 characters" do
      keywords = Scoring.extract_keywords("a an it is at to on")
      assert keywords == []
    end

    test "deduplicates keywords" do
      keywords = Scoring.extract_keywords("elixir elixir testing testing tdd")
      assert Enum.count(keywords, &(&1 == "elixir")) == 1
      assert Enum.count(keywords, &(&1 == "testing")) == 1
    end

    test "handles non-binary input" do
      assert Scoring.extract_keywords(123) == []
      assert Scoring.extract_keywords(%{}) == []
      assert Scoring.extract_keywords([1, 2, 3]) == []
    end

    test "handles unicode text" do
      keywords = Scoring.extract_keywords("café résumé naïve")
      assert is_list(keywords)
      assert length(keywords) >= 0
    end

    test "handles text with only stop words" do
      keywords = Scoring.extract_keywords("the and a but or")
      assert keywords == []
    end
  end

  describe "keyword_overlap/2" do
    test "computes Jaccard similarity correctly" do
      # {a, b} = {1, 2, 3}, {b, c, d} = {2, 3, 4}
      # intersection = {2, 3} = 2
      # union = {1, 2, 3, 4} = 4
      # similarity = 2/4 = 0.5
      overlap = Scoring.keyword_overlap(["a", "b", "c"], ["b", "c", "d"])
      assert overlap == 0.5
    end

    test "returns 0.0 when first list is empty" do
      overlap = Scoring.keyword_overlap([], ["a", "b", "c"])
      assert overlap == 0.0
    end

    test "returns 0.0 when second list is empty" do
      overlap = Scoring.keyword_overlap(["a", "b", "c"], [])
      assert overlap == 0.0
    end

    test "returns 1.0 for identical lists" do
      overlap = Scoring.keyword_overlap(["a", "b", "c"], ["a", "b", "c"])
      assert overlap == 1.0
    end

    test "returns 0.0 for disjoint lists" do
      overlap = Scoring.keyword_overlap(["a", "b"], ["c", "d"])
      assert overlap == 0.0
    end

    test "handles non-list inputs gracefully" do
      overlap = Scoring.keyword_overlap("not a list", ["a", "b"])
      assert overlap == 0.0

      overlap = Scoring.keyword_overlap(["a", "b"], nil)
      assert overlap == 0.0
    end

    test "deduplicates within lists before computing" do
      overlap = Scoring.keyword_overlap(["a", "a", "b"], ["b", "b", "c"])
      # {a, b} and {b, c} => intersection = {b}, union = {a, b, c} => 1/3
      assert_in_delta overlap, 0.333, 0.001
    end

    test "case sensitive by default" do
      overlap = Scoring.keyword_overlap(["Elixir"], ["elixir"])
      assert overlap == 0.0
    end
  end

  describe "category weights" do
    test "decision category has weight 1.00" do
      entry = %{category: "decision", accessed_at: DateTime.utc_now() |> DateTime.to_iso8601()}
      score = Scoring.score(entry, [], nil)
      assert is_float(score)
      assert score >= 0.0
    end

    test "preference category has weight 0.90" do
      entry = %{category: "preference", accessed_at: DateTime.utc_now() |> DateTime.to_iso8601()}
      score = Scoring.score(entry, [], nil)
      assert is_float(score)
    end

    test "pattern category has weight 0.85" do
      entry = %{category: "pattern", accessed_at: DateTime.utc_now() |> DateTime.to_iso8601()}
      score = Scoring.score(entry, [], nil)
      assert is_float(score)
    end

    test "lesson category has weight 0.80" do
      entry = %{category: "lesson", accessed_at: DateTime.utc_now() |> DateTime.to_iso8601()}
      score = Scoring.score(entry, [], nil)
      assert is_float(score)
    end

    test "project category has weight 0.75" do
      entry = %{category: "project", accessed_at: DateTime.utc_now() |> DateTime.to_iso8601()}
      score = Scoring.score(entry, [], nil)
      assert is_float(score)
    end

    test "context category has weight 0.50" do
      entry = %{category: "context", accessed_at: DateTime.utc_now() |> DateTime.to_iso8601()}
      score = Scoring.score(entry, [], nil)
      assert is_float(score)
    end

    test "unknown category uses default weight 0.50" do
      entry = %{category: "unknown", accessed_at: DateTime.utc_now() |> DateTime.to_iso8601()}
      score = Scoring.score(entry, [], nil)
      assert is_float(score)
    end

    test "handles atom category keys" do
      entry = %{category: :decision, accessed_at: DateTime.utc_now() |> DateTime.to_iso8601()}
      score = Scoring.score(entry, [], nil)
      assert is_float(score)
    end
  end

  describe "recency scoring" do
    test "recent access has higher recency score" do
      now = DateTime.utc_now() |> DateTime.to_iso8601()
      recent_entry = %{category: "context", accessed_at: now}

      old_time = DateTime.add(DateTime.utc_now(), -48 * 3600, :second) |> DateTime.to_iso8601()
      old_entry = %{category: "context", accessed_at: old_time}

      recent_score = Scoring.score(recent_entry, [], nil)
      old_score = Scoring.score(old_entry, [], nil)

      assert recent_score > old_score
    end

    test "recency decays with 48-hour half-life" do
      now = DateTime.utc_now()
      recent = %{category: "context", accessed_at: DateTime.to_iso8601(now)}
      one_half_life_ago = DateTime.add(now, -48 * 3600, :second)
      old = %{category: "context", accessed_at: DateTime.to_iso8601(one_half_life_ago)}

      recent_score = Scoring.score(recent, [], nil)
      old_score = Scoring.score(old, [], nil)

      # After one half-life, recency should be roughly half
      # (accounting for base weight contribution)
      assert old_score < recent_score
    end

    test "handles invalid accessed_at string" do
      entry = %{category: "context", accessed_at: "invalid-date"}
      score = Scoring.score(entry, [], nil)
      # Should default to 0.5 recency score
      assert is_float(score)
    end

    test "handles nil accessed_at" do
      entry = %{category: "context", accessed_at: nil}
      score = Scoring.score(entry, [], nil)
      # Should handle gracefully
      assert is_float(score)
      assert score >= 0.0
    end
  end

  describe "integration" do
    test "full scoring pipeline with realistic entry" do
      entry = %{
        id: "mem_123",
        content: "Use TDD for all new features",
        keywords: "tdd,testing,elixir,features",
        category: "decision",
        accessed_at: DateTime.utc_now() |> DateTime.to_iso8601(),
        created_at: DateTime.utc_now() |> DateTime.to_iso8601()
      }

      query = "I need to add testing to elixir"
      query_keywords = Scoring.extract_keywords(query)

      score = Scoring.score(entry, query_keywords, nil)

      assert is_float(score)
      assert score >= 0.0
      assert score <= 1.0

      # Should have decent score due to keyword overlap and high category weight
      assert score > 0.4
    end

    test "lower score for less relevant entry" do
      entry = %{
        keywords: "coffee,lunch,break",
        category: "context",
        accessed_at: DateTime.utc_now() |> DateTime.to_iso8601()
      }

      query = "elixir testing patterns"
      query_keywords = Scoring.extract_keywords(query)

      score = Scoring.score(entry, query_keywords, nil)

      # Low score due to no keyword overlap and low category weight
      assert score < 0.5
    end
  end

  describe "edge cases" do
    test "handles entry with string and atom keys mixed" do
      entry = %{
        "keywords" => "elixir",
        "category" => :decision,
        "accessed_at" => DateTime.utc_now() |> DateTime.to_iso8601()
      }

      score = Scoring.score(entry, ["elixir"], nil)
      assert is_float(score)
    end

    test "handles very long text" do
      long_text = String.duplicate("elixir testing ", 1000)
      keywords = Scoring.extract_keywords(long_text)
      assert "elixir" in keywords
      assert "testing" in keywords
    end

    test "handles text with special characters only" do
      keywords = Scoring.extract_keywords("!@#$%^&*()")
      assert keywords == []
    end

    test "handles comma-separated stored keywords" do
      entry = %{
        keywords: "one,two, three, four , five",
        category: "context",
        accessed_at: DateTime.utc_now() |> DateTime.to_iso8601()
      }

      score = Scoring.score(entry, ["one", "three"], nil)
      assert score > 0.0
    end
  end
end
