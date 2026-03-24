defmodule OptimalSystemAgent.ContextMesh.StalenessTest do
  @moduledoc """
  Chicago TDD unit tests for Staleness module.

  Tests 4-factor staleness scoring for ContextMesh Keepers.
  """

  use ExUnit.Case, async: true

  alias OptimalSystemAgent.ContextMesh.Staleness

  @moduletag :capture_log

  describe "compute_staleness/1" do
    test "returns score and state tuple" do
      state = %{
        created_at: DateTime.utc_now(),
        last_accessed_at: DateTime.utc_now(),
        relevance_score: 1.0,
        access_patterns: %{{"agent1", :smart} => 10}
      }

      {score, state} = Staleness.compute_staleness(state)
      assert is_integer(score)
      assert score >= 0 and score <= 100
      assert state in [:fresh, :warm, :stale, :expired]
    end

    test "clamps score at maximum 100" do
      # Very old keeper, never accessed, no relevance, no smart retrievals
      old_time = DateTime.utc_now() |> DateTime.add(-10, :hour)

      state = %{
        created_at: old_time,
        last_accessed_at: nil,
        relevance_score: 0.0,
        access_patterns: %{}
      }

      {score, _state} = Staleness.compute_staleness(state)
      assert score <= 100
    end
  end

  describe "classify/1" do
    test "classifies 0-24 as :fresh" do
      assert Staleness.classify(0) == :fresh
      assert Staleness.classify(24) == :fresh
    end

    test "classifies 25-49 as :warm" do
      assert Staleness.classify(25) == :warm
      assert Staleness.classify(49) == :warm
    end

    test "classifies 50-74 as :stale" do
      assert Staleness.classify(50) == :stale
      assert Staleness.classify(74) == :stale
    end

    test "classifies 75-100 as :expired" do
      assert Staleness.classify(75) == :expired
      assert Staleness.classify(100) == :expired
    end
  end

  describe "time decay factor" do
    test "new keeper has 0 time decay" do
      state = %{
        created_at: DateTime.utc_now(),
        last_accessed_at: DateTime.utc_now(),
        relevance_score: 1.0,
        access_patterns: %{{"agent1", :smart} => 10}
      }
      {score, _} = Staleness.compute_staleness(state)
      # Time decay should be 0 for new keeper
      assert score < 25
    end

    test "5+ hour old keeper has max time decay" do
      old_time = DateTime.utc_now() |> DateTime.add(-6, :hour)
      state = %{
        created_at: old_time,
        last_accessed_at: old_time,
        relevance_score: 1.0,
        access_patterns: %{{"agent1", :smart} => 10}
      }

      {score, _} = Staleness.compute_staleness(state)
      # Time decay should be at max (25)
      assert score >= 25
    end
  end

  describe "access decay factor" do
    test "never accessed keeper has max access decay" do
      state = %{
        created_at: DateTime.utc_now(),
        last_accessed_at: nil,
        relevance_score: 1.0,
        access_patterns: %{}
      }

      {score, _} = Staleness.compute_staleness(state)
      # Access decay should be 25 for never accessed
      assert score >= 25
    end

    test "recently accessed keeper has low access decay" do
      state = %{
        created_at: DateTime.utc_now(),
        last_accessed_at: DateTime.utc_now(),
        relevance_score: 1.0,
        access_patterns: %{{"agent1", :smart} => 10}
      }

      {score, _} = Staleness.compute_staleness(state)
      # Access decay should be minimal
      assert score < 25
    end
  end

  describe "relevance decay factor" do
    test "high relevance score has low relevance decay" do
      state = %{
        created_at: DateTime.utc_now(),
        last_accessed_at: DateTime.utc_now(),
        relevance_score: 1.0,
        access_patterns: %{{"agent1", :smart} => 10}
      }

      {score, _} = Staleness.compute_staleness(state)
      # Relevance decay should be 0 for score 1.0
      assert score < 25
    end

    test "low relevance score has high relevance decay" do
      state = %{
        created_at: DateTime.utc_now(),
        last_accessed_at: DateTime.utc_now(),
        relevance_score: 0.0,
        access_patterns: %{{"agent1", :smart} => 10}
      }

      {score, _} = Staleness.compute_staleness(state)
      # Relevance decay should be at least 25
      assert score >= 25
    end

    test "default relevance_score is 1.0" do
      state = %{
        created_at: DateTime.utc_now(),
        last_accessed_at: DateTime.utc_now(),
        access_patterns: %{{"agent1", :smart} => 10}
      }

      {score, _} = Staleness.compute_staleness(state)
      # Should default to 1.0 (no decay)
      assert score < 25
    end
  end

  describe "confidence decay factor" do
    test "never retrieved keeper has max confidence decay" do
      state = %{
        created_at: DateTime.utc_now(),
        last_accessed_at: DateTime.utc_now(),
        relevance_score: 1.0,
        access_patterns: %{}
      }

      {score, _} = Staleness.compute_staleness(state)
      # Confidence decay should be 25
      assert score >= 25
    end

    test "perfect smart hit ratio has 0 confidence decay" do
      state = %{
        created_at: DateTime.utc_now(),
        last_accessed_at: DateTime.utc_now(),
        relevance_score: 1.0,
        access_patterns: %{{"agent1", :smart} => 10}
      }

      {score, _} = Staleness.compute_staleness(state)
      # Confidence decay should be 0
      assert score < 25
    end

    test "mixed smart and keyword retrievals has partial decay" do
      state = %{
        created_at: DateTime.utc_now(),
        last_accessed_at: DateTime.utc_now(),
        relevance_score: 1.0,
        access_patterns: %{{"agent1", :smart} => 5, {"agent1", :keyword} => 5}
      }

      {score, _} = Staleness.compute_staleness(state)
      # 50% smart hit ratio = some decay
      assert score > 0 and score < 25
    end

    test "only keyword retrievals has moderate penalty" do
      state = %{
        created_at: DateTime.utc_now(),
        last_accessed_at: DateTime.utc_now(),
        relevance_score: 1.0,
        access_patterns: %{{"agent1", :keyword} => 10}
      }

      {score, _} = Staleness.compute_staleness(state)
      # 15 point penalty for no smart retrievals
      assert score >= 15
    end
  end

  describe "integration - complete scoring" do
    test "fresh keeper: new, recently accessed, high relevance, smart hits" do
      state = %{
        created_at: DateTime.utc_now(),
        last_accessed_at: DateTime.utc_now(),
        relevance_score: 1.0,
        access_patterns: %{{"agent1", :smart} => 10}
      }

      {score, staleness} = Staleness.compute_staleness(state)
      assert score < 25
      assert staleness == :fresh
    end

    test "expired keeper: old, never accessed, low relevance, no retrievals" do
      old_time = DateTime.utc_now() |> DateTime.add(-10, :hour)

      state = %{
        created_at: old_time,
        last_accessed_at: nil,
        relevance_score: 0.0,
        access_patterns: %{}
      }

      {score, staleness} = Staleness.compute_staleness(state)
      assert score >= 75
      assert staleness == :expired
    end
  end
end
