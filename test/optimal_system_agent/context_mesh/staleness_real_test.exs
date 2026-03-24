defmodule OptimalSystemAgent.ContextMesh.StalenessRealTest do
  @moduledoc """
  Chicago TDD integration tests for ContextMesh.Staleness.

  NO MOCKS. Tests real 4-factor staleness scoring algorithm.
  Every gap found is a real bug or missing behavior.
  """

  use ExUnit.Case, async: true

  @moduletag :integration

  alias OptimalSystemAgent.ContextMesh.Staleness

  describe "Staleness.classify/1" do
    test "CRASH: 0 = :fresh" do
      assert Staleness.classify(0) == :fresh
    end

    test "CRASH: 24 = :fresh" do
      assert Staleness.classify(24) == :fresh
    end

    test "CRASH: 25 = :warm" do
      assert Staleness.classify(25) == :warm
    end

    test "CRASH: 49 = :warm" do
      assert Staleness.classify(49) == :warm
    end

    test "CRASH: 50 = :stale" do
      assert Staleness.classify(50) == :stale
    end

    test "CRASH: 74 = :stale" do
      assert Staleness.classify(74) == :stale
    end

    test "CRASH: 75 = :expired" do
      assert Staleness.classify(75) == :expired
    end

    test "CRASH: 100 = :expired" do
      assert Staleness.classify(100) == :expired
    end

    test "CRASH: negative = :fresh" do
      assert Staleness.classify(-5) == :fresh
    end
  end

  describe "Staleness.compute_staleness/1" do
    test "CRASH: fresh keeper returns low score" do
      now = DateTime.utc_now()
      state = %{
        created_at: now,
        last_accessed_at: now,
        relevance_score: 1.0,
        access_patterns: %{{"agent_1", :smart} => 10}
      }
      {score, state_atom} = Staleness.compute_staleness(state)
      assert score < 25
      assert state_atom == :fresh
    end

    test "CRASH: never accessed adds 25 access decay" do
      now = DateTime.utc_now()
      state = %{
        created_at: now,
        last_accessed_at: nil,
        relevance_score: 1.0,
        access_patterns: %{}
      }
      {score, _state_atom} = Staleness.compute_staleness(state)
      # time_decay ~0 + access_decay 25 + relevance_decay 0 + confidence_decay 25 = ~50
      assert score >= 25
    end

    test "CRASH: zero relevance adds 25 relevance decay" do
      now = DateTime.utc_now()
      state = %{
        created_at: now,
        last_accessed_at: now,
        relevance_score: 0.0,
        access_patterns: %{{"agent_1", :smart} => 10}
      }
      {score, _state_atom} = Staleness.compute_staleness(state)
      # relevance_decay = (1.0 - 0.0) * 25 = 25
      assert score >= 25
    end

    test "CRASH: no access patterns adds 25 confidence decay" do
      now = DateTime.utc_now()
      state = %{
        created_at: now,
        last_accessed_at: now,
        relevance_score: 1.0,
        access_patterns: %{}
      }
      {score, _state_atom} = Staleness.compute_staleness(state)
      # confidence_decay = 25 (no retrievals)
      assert score >= 25
    end

    test "CRASH: old creation time increases time decay" do
      old = DateTime.add(DateTime.utc_now(), -6, :hour)
      state = %{
        created_at: old,
        last_accessed_at: DateTime.utc_now(),
        relevance_score: 1.0,
        access_patterns: %{{"agent_1", :smart} => 10}
      }
      {score, _state_atom} = Staleness.compute_staleness(state)
      # time_decay: 6 hours * 5 = 30 → capped at 25
      assert score >= 25
    end

    test "CRASH: score clamped at 100" do
      old = DateTime.add(DateTime.utc_now(), -100, :hour)
      state = %{
        created_at: old,
        last_accessed_at: nil,
        relevance_score: 0.0,
        access_patterns: %{}
      }
      {score, _state_atom} = Staleness.compute_staleness(state)
      assert score <= 100
    end

    test "CRASH: missing created_at defaults to 5 hours" do
      state = %{
        last_accessed_at: nil,
        relevance_score: 0.0,
        access_patterns: %{}
      }
      {score, _state_atom} = Staleness.compute_staleness(state)
      # time_decay: 5h * 5 = 25 + access_decay: 25 + relevance_decay: 25 + confidence_decay: 25 = 100
      assert score == 100
      assert _state_atom == :expired
    end
  end

  describe "Staleness.compute_staleness/1 — confidence decay" do
    test "CRASH: all smart retrievals has low confidence decay" do
      now = DateTime.utc_now()
      state = %{
        created_at: now,
        last_accessed_at: now,
        relevance_score: 1.0,
        access_patterns: %{{"agent_1", :smart} => 10}
      }
      {score, state_atom} = Staleness.compute_staleness(state)
      assert score < 25
      assert state_atom == :fresh
    end

    test "CRASH: keyword-only retrievals has moderate penalty" do
      now = DateTime.utc_now()
      state = %{
        created_at: now,
        last_accessed_at: now,
        relevance_score: 1.0,
        access_patterns: %{{"agent_1", :keyword} => 10}
      }
      {score, _state_atom} = Staleness.compute_staleness(state)
      # confidence_decay: 15 (retrieved but never :smart)
      assert score >= 15
    end

    test "CRASH: mixed smart/keyword computes ratio" do
      now = DateTime.utc_now()
      state = %{
        created_at: now,
        last_accessed_at: now,
        relevance_score: 1.0,
        access_patterns: %{{"a", :smart} => 5, {"b", :keyword} => 5}
      }
      {score, _state_atom} = Staleness.compute_staleness(state)
      # smart_ratio = 5/10 = 0.5, confidence_decay = (1 - 0.5) * 25 = 12.5 → 13
      assert score >= 10
      assert score < 20
    end
  end
end
