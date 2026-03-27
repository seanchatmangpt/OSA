defmodule OptimalSystemAgent.Integration.UnboundedCacheFixIntegrationTest do
  @moduledoc """
  Integration test for bounded cache fixes.

  Verifies that:
  1. tool_result_cache (1000 entry limit with LRU eviction)
  2. osa_pending_questions (5000 entry limit with timestamp-based eviction)

  Both caches maintain bounded memory under load without exceeding limits.
  """
  use ExUnit.Case, async: false

  alias OptimalSystemAgent.Tools.Cache
  alias OptimalSystemAgent.Memory.PendingQuestionsCache

  @moduletag :integration
  @moduletag :capture_log

  setup do
    # Ensure Cache is started
    unless Process.whereis(Cache) do
      start_supervised!(Cache)
    end

    Cache.clear()

    # Ensure pending questions table exists
    try do
      :ets.new(:osa_pending_questions, [:named_table, :public, :set])
    rescue
      _ -> :ok
    end

    :ets.delete_all_objects(:osa_pending_questions)
    :ok
  end

  describe "tool_result_cache under heavy load" do
    test "maintains max size of 1000 under repeated insertions" do
      # Simulate 5000 cache puts with TTL
      for i <- 1..5000 do
        Cache.put(:"tool_result_#{i}", "result_#{i}", 60_000)
      end

      stats = Cache.stats()
      # Size should stay at or near 1000
      assert stats.size <= 1000
      assert stats.size > 900

      # Verify evictions occurred
      assert stats.evictions > 0
    end

    test "LRU eviction removes least recently used entries" do
      # Fill cache to max
      for i <- 1..1000 do
        Cache.put(:"key_#{i}", "value_#{i}", 60_000)
      end

      # Access specific keys to mark them as "recent"
      accessed_keys = 1..50
      Enum.each(accessed_keys, fn i ->
        Cache.get(:"key_#{i}")
      end)

      # Fill beyond max to trigger eviction
      for i <- 1001..1100 do
        Cache.put(:"key_#{i}", "value_#{i}", 60_000)
      end

      # Most of the accessed keys (1-50) should still exist
      still_present = Enum.count(accessed_keys, fn i ->
        Cache.get(:"key_#{i}") == {:ok, "value_#{i}"}
      end)

      assert still_present >= 40
    end

    test "cache remains stable under concurrent load" do
      # Simulate concurrent tool usage
      tasks = Enum.map(1..50, fn task_id ->
        Task.async(fn ->
          for i <- 1..100 do
            key = :"concurrent_#{task_id}_#{i}"
            Cache.put(key, "value_#{i}", 60_000)
            Cache.get(key)
          end
        end)
      end)

      Enum.each(tasks, &Task.await/1)

      stats = Cache.stats()
      # Should never exceed 1000 even with concurrent access
      assert stats.size <= 1000
      assert stats.hits > 0
    end
  end

  describe "pending_questions_cache under heavy load" do
    test "maintains max size of 5000 under repeated insertions" do
      # Simulate 10000 questions for different sessions
      for i <- 1..10000 do
        session_id = "session_#{rem(i, 100)}"
        meta = %{
          session_id: session_id,
          question: "Question #{i}?",
          options: [],
          asked_at: DateTime.utc_now() |> DateTime.to_iso8601()
        }

        PendingQuestionsCache.insert_question("ref_#{i}", meta)
      end

      stats = PendingQuestionsCache.stats()
      # Size should stay at or near 5000
      assert stats.size <= 5000
      assert stats.size > 4700
    end

    test "retrieves questions per session correctly under load" do
      # Add questions for 10 sessions
      for i <- 1..5000 do
        session_id = "session_#{rem(i, 10)}"
        meta = %{
          session_id: session_id,
          question: "Question #{i}?",
          options: [],
          asked_at: DateTime.utc_now() |> DateTime.to_iso8601()
        }

        PendingQuestionsCache.insert_question("ref_#{i}", meta)
      end

      # Each session should have roughly 500 questions
      Enum.each(0..9, fn session_num ->
        questions = PendingQuestionsCache.get_questions_for_session("session_#{session_num}")
        assert length(questions) > 400  # Allow some variance due to eviction
        assert length(questions) <= 600
      end)
    end

    test "cleanup_expired removes old entries without affecting new ones" do
      # Add old and new entries
      old_time = System.monotonic_time(:millisecond) - (16 * 60 * 1000)

      # Insert old entries
      for i <- 1..100 do
        meta = %{
          session_id: "old_session",
          question: "Old question #{i}?",
          options: [],
          asked_at: DateTime.utc_now() |> DateTime.to_iso8601()
        }

        PendingQuestionsCache.insert_question("ref_old_#{i}", meta)
        :ets.update_element(:osa_pending_questions, "ref_old_#{i}", {3, old_time})
      end

      # Insert fresh entries
      for i <- 1..100 do
        meta = %{
          session_id: "fresh_session",
          question: "Fresh question #{i}?",
          options: [],
          asked_at: DateTime.utc_now() |> DateTime.to_iso8601()
        }

        PendingQuestionsCache.insert_question("ref_fresh_#{i}", meta)
      end

      # Cleanup
      expired_count = PendingQuestionsCache.cleanup_expired()

      assert expired_count == 100

      # Old entries should be gone
      old_questions = PendingQuestionsCache.get_questions_for_session("old_session")
      assert length(old_questions) == 0

      # Fresh entries should remain
      fresh_questions = PendingQuestionsCache.get_questions_for_session("fresh_session")
      assert length(fresh_questions) == 100
    end

    test "concurrent question insertion and retrieval" do
      # Simulate TUI and API concurrently adding questions
      insert_tasks = Enum.map(1..10, fn task_id ->
        Task.async(fn ->
          for i <- 1..100 do
            session_id = "session_#{task_id}"
            meta = %{
              session_id: session_id,
              question: "Q#{task_id}_#{i}?",
              options: [],
              asked_at: DateTime.utc_now() |> DateTime.to_iso8601()
            }

            PendingQuestionsCache.insert_question("ref_#{task_id}_#{i}", meta)
          end
        end)
      end)

      # Wait for all inserts to complete first
      Enum.each(insert_tasks, &Task.await/1)

      # Now retrieve questions
      retrieve_tasks = Enum.map(1..10, fn session_num ->
        Task.async(fn ->
          PendingQuestionsCache.get_questions_for_session("session_#{session_num}")
        end)
      end)

      results = Enum.map(retrieve_tasks, &Task.await/1)

      # Each session should have questions (some may have been evicted if > 5000 total)
      # But at least some sessions should have content
      total_questions = Enum.reduce(results, 0, fn result, acc -> acc + length(result) end)
      assert total_questions > 0
    end
  end

  describe "both caches under combined realistic load" do
    test "tool cache and question cache coexist without interference" do
      # Add tool results
      for i <- 1..500 do
        Cache.put(:"tool_#{i}", "result_#{i}", 60_000)
      end

      # Add pending questions
      for i <- 1..500 do
        meta = %{
          session_id: "session",
          question: "Q#{i}?",
          options: [],
          asked_at: DateTime.utc_now() |> DateTime.to_iso8601()
        }

        PendingQuestionsCache.insert_question("ref_#{i}", meta)
      end

      # Both caches should have their contents
      cache_stats = Cache.stats()
      question_stats = PendingQuestionsCache.stats()

      assert cache_stats.size == 500
      assert question_stats.size == 500

      # Further operations should not interfere
      Cache.put(:extra_tool, "result", 60_000)
      PendingQuestionsCache.insert_question("extra_ref", %{
        session_id: "session",
        question: "Extra?",
        options: [],
        asked_at: DateTime.utc_now() |> DateTime.to_iso8601()
      })

      assert Cache.stats().size == 501
      assert PendingQuestionsCache.stats().size == 501
    end

    test "memory stays bounded during 10-minute simulation" do
      # Simulate 10 minutes of operations (6000 operations to ensure question cache eviction)
      for i <- 1..6000 do
        # Every iteration: add tool result, add question, maybe evict old question
        Cache.put(:"tool_#{i}", "result_#{i}", 60_000)

        meta = %{
          session_id: "session_#{rem(i, 100)}",
          question: "Q#{i}?",
          options: [],
          asked_at: DateTime.utc_now() |> DateTime.to_iso8601()
        }

        PendingQuestionsCache.insert_question("ref_#{i}", meta)

        # Every 100 operations, cleanup expired
        if rem(i, 100) == 0 do
          PendingQuestionsCache.cleanup_expired()
        end
      end

      # After 6000 ops, both caches should be bounded
      cache_stats = Cache.stats()
      question_stats = PendingQuestionsCache.stats()

      # Tool cache: max 1000
      assert cache_stats.size <= 1000
      assert cache_stats.size > 900

      # Question cache: max 5000
      assert question_stats.size <= 5000
      assert question_stats.size > 4500

      # Cache should have done evictions (6000 - 1000 = 5000 entries evicted)
      assert cache_stats.evictions > 0
    end
  end
end
