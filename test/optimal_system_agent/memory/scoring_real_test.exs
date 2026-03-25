defmodule OptimalSystemAgent.Memory.ScoringRealTest do
  @moduledoc """
  Chicago TDD integration tests for Memory.Scoring.

  NO MOCKS. Tests real relevance scoring, keyword extraction, Jaccard similarity.
  Every gap found is a real bug or missing behavior.
  """

  use ExUnit.Case, async: true

  @moduletag :integration

  alias OptimalSystemAgent.Memory.Scoring

  describe "Scoring.score/3" do
    test "CRASH: returns float between 0 and 1" do
      entry = %{keywords: "elixir,otp", category: "decision", accessed_at: DateTime.utc_now() |> DateTime.to_iso8601()}
      score = Scoring.score(entry, ["elixir", "otp"])
      assert is_float(score)
      assert score >= 0.0
      assert score <= 1.0
    end

    test "CRASH: matching keywords increases score" do
      entry = %{keywords: "elixir,otp,beam", category: "decision", accessed_at: DateTime.utc_now() |> DateTime.to_iso8601()}
      match_score = Scoring.score(entry, ["elixir", "otp"])
      no_match_score = Scoring.score(entry, ["python", "django"])
      assert match_score > no_match_score
    end

    test "CRASH: non-map entry returns 0.0" do
      assert Scoring.score("not a map", ["test"]) == 0.0
    end

    test "CRASH: nil entry returns 0.0" do
      assert Scoring.score(nil, ["test"]) == 0.0
    end

    test "CRASH: decision category has higher base than context" do
      decision = %{keywords: "test", category: "decision", accessed_at: DateTime.utc_now() |> DateTime.to_iso8601()}
      context = %{keywords: "test", category: "context", accessed_at: DateTime.utc_now() |> DateTime.to_iso8601()}
      # Both have same keywords and recency, so base weight should differ
      d_score = Scoring.score(decision, ["test"])
      c_score = Scoring.score(context, ["test"])
      assert d_score > c_score
    end
  end

  describe "Scoring.extract_keywords/1" do
    test "CRASH: extracts keywords from text" do
      keywords = Scoring.extract_keywords("Elixir OTP GenServer pattern")
      assert is_list(keywords)
      assert "elixir" in keywords
      assert "otp" in keywords
      assert "genserver" in keywords
    end

    test "CRASH: removes stop words" do
      keywords = Scoring.extract_keywords("the quick brown fox")
      refute "the" in keywords
      assert "quick" in keywords
      assert "brown" in keywords
      assert "fox" in keywords
    end

    test "CRASH: downcases keywords" do
      keywords = Scoring.extract_keywords("Elixir Phoenix LiveView")
      assert "elixir" in keywords
      assert "phoenix" in keywords
      assert "liveview" in keywords
    end

    test "CRASH: removes short words (< 3 chars)" do
      keywords = Scoring.extract_keywords("a be it do go")
      assert keywords == []
    end

    test "CRASH: deduplicates keywords" do
      keywords = Scoring.extract_keywords("elixir elixir elixir")
      assert length(keywords) == 1
    end

    test "CRASH: nil returns empty list" do
      assert Scoring.extract_keywords(nil) == []
    end

    test "CRASH: empty string returns empty list" do
      assert Scoring.extract_keywords("") == []
    end

    test "CRASH: non-string returns empty list" do
      assert Scoring.extract_keywords(42) == []
    end

    test "CRASH: strips punctuation" do
      keywords = Scoring.extract_keywords("hello, world! test.")
      assert "hello" in keywords
      assert "world" in keywords
      assert "test" in keywords
    end
  end

  describe "Scoring.keyword_overlap/2" do
    test "CRASH: identical lists return 1.0" do
      assert Scoring.keyword_overlap(["a", "b", "c"], ["a", "b", "c"]) == 1.0
    end

    test "CRASH: no overlap returns 0.0" do
      assert Scoring.keyword_overlap(["a", "b"], ["c", "d"]) == 0.0
    end

    test "CRASH: partial overlap returns between 0 and 1" do
      overlap = Scoring.keyword_overlap(["a", "b", "c"], ["b", "c", "d", "e"])
      assert overlap > 0.0
      assert overlap < 1.0
    end

    test "CRASH: empty first list returns 0.0" do
      assert Scoring.keyword_overlap([], ["a", "b"]) == 0.0
    end

    test "CRASH: empty second list returns 0.0" do
      assert Scoring.keyword_overlap(["a", "b"], []) == 0.0
    end

    test "CRASH: non-list inputs return 0.0" do
      assert Scoring.keyword_overlap("a", ["b"]) == 0.0
    end

    test "CRASH: both empty returns 0.0" do
      assert Scoring.keyword_overlap([], []) == 0.0
    end

    test "CRASH: Jaccard math is correct" do
      # A={a,b,c} B={b,c,d,e} → intersection={b,c} union={a,b,c,d,e}
      # |intersection|=2, |union|=5, Jaccard=2/5=0.4
      assert Scoring.keyword_overlap(["a", "b", "c"], ["b", "c", "d", "e"]) == 0.4
    end
  end
end
