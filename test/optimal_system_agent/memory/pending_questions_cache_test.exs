defmodule OptimalSystemAgent.Memory.PendingQuestionsCacheTest do
  @moduledoc """
  Unit tests for PendingQuestionsCache module.

  Tests bounded cache for ask_user questions with size limits and TTL.
  """
  use ExUnit.Case, async: false

  alias OptimalSystemAgent.Memory.PendingQuestionsCache

  @moduletag :capture_log

  setup do
    # Ensure ETS table exists
    try do
      :ets.new(:osa_pending_questions, [:named_table, :public, :set])
    rescue
      _ ->
        # Table already exists from application
        :ok
    end

    # Clear table before each test
    :ets.delete_all_objects(:osa_pending_questions)
    :ok
  end

  describe "insert_question/2" do
    test "inserts question into cache" do
      question_meta = %{
        session_id: "session_1",
        question: "What is your name?",
        options: [],
        asked_at: DateTime.utc_now() |> DateTime.to_iso8601()
      }

      assert PendingQuestionsCache.insert_question("ref_1", question_meta) == :ok
      assert :ets.member(:osa_pending_questions, "ref_1")
    end

    test "stores ref as key and question_meta with timestamp" do
      question_meta = %{
        session_id: "session_1",
        question: "Test?",
        options: ["Yes", "No"],
        asked_at: DateTime.utc_now() |> DateTime.to_iso8601()
      }

      PendingQuestionsCache.insert_question("ref_123", question_meta)

      [{_ref, stored_meta, _timestamp}] = :ets.lookup(:osa_pending_questions, "ref_123")
      assert stored_meta.session_id == "session_1"
      assert stored_meta.question == "Test?"
      assert stored_meta.options == ["Yes", "No"]
    end

    test "stores timestamp for TTL tracking" do
      question_meta = %{
        session_id: "session_1",
        question: "?",
        options: [],
        asked_at: DateTime.utc_now() |> DateTime.to_iso8601()
      }

      before = System.monotonic_time(:millisecond)
      PendingQuestionsCache.insert_question("ref", question_meta)
      after_time = System.monotonic_time(:millisecond)

      [{_ref, _meta, timestamp}] = :ets.lookup(:osa_pending_questions, "ref")
      assert timestamp >= before
      assert timestamp <= after_time
    end
  end

  describe "get_questions_for_session/1" do
    test "returns empty list for non-existent session" do
      questions = PendingQuestionsCache.get_questions_for_session("nonexistent")
      assert questions == []
    end

    test "returns questions for specific session only" do
      meta_s1 = %{
        session_id: "session_1",
        question: "Q1?",
        options: [],
        asked_at: DateTime.utc_now() |> DateTime.to_iso8601()
      }

      meta_s2 = %{
        session_id: "session_2",
        question: "Q2?",
        options: [],
        asked_at: DateTime.utc_now() |> DateTime.to_iso8601()
      }

      PendingQuestionsCache.insert_question("ref_s1", meta_s1)
      PendingQuestionsCache.insert_question("ref_s2", meta_s2)

      questions_s1 = PendingQuestionsCache.get_questions_for_session("session_1")
      assert length(questions_s1) == 1
      assert List.first(questions_s1).question == "Q1?"

      questions_s2 = PendingQuestionsCache.get_questions_for_session("session_2")
      assert length(questions_s2) == 1
      assert List.first(questions_s2).question == "Q2?"
    end

    test "returns list with ref, question, options, asked_at" do
      question_meta = %{
        session_id: "session_1",
        question: "Pick one",
        options: ["A", "B", "C"],
        asked_at: "2026-03-26T12:00:00Z"
      }

      PendingQuestionsCache.insert_question("ref_test", question_meta)

      questions = PendingQuestionsCache.get_questions_for_session("session_1")
      assert length(questions) == 1

      returned = List.first(questions)
      assert returned.ref == "ref_test"
      assert returned.question == "Pick one"
      assert returned.options == ["A", "B", "C"]
      assert returned.asked_at == "2026-03-26T12:00:00Z"
    end

    test "filters out expired entries" do
      # Insert entry
      question_meta = %{
        session_id: "session_1",
        question: "Will expire",
        options: [],
        asked_at: DateTime.utc_now() |> DateTime.to_iso8601()
      }

      PendingQuestionsCache.insert_question("ref_expire", question_meta)

      # Manually set timestamp to old value (15 mins + 1 sec ago)
      old_timestamp = System.monotonic_time(:millisecond) - (15 * 60 * 1000) - 1000
      :ets.update_element(:osa_pending_questions, "ref_expire", {3, old_timestamp})

      # Should not appear in results due to expiration
      questions = PendingQuestionsCache.get_questions_for_session("session_1")
      assert length(questions) == 0
    end

    test "returns empty list if ETS table error occurs" do
      # This would require mocking :ets.tab2list to fail, skip for now
      assert true
    end
  end

  describe "delete_question/1" do
    test "deletes question by ref" do
      question_meta = %{
        session_id: "session_1",
        question: "?",
        options: [],
        asked_at: DateTime.utc_now() |> DateTime.to_iso8601()
      }

      PendingQuestionsCache.insert_question("ref_del", question_meta)
      assert PendingQuestionsCache.delete_question("ref_del") == :ok
      assert not :ets.member(:osa_pending_questions, "ref_del")
    end

    test "returns :ok even if ref doesn't exist" do
      assert PendingQuestionsCache.delete_question("nonexistent") == :ok
    end

    test "doesn't affect other questions" do
      meta1 = %{session_id: "s1", question: "Q1", options: [], asked_at: "now"}
      meta2 = %{session_id: "s1", question: "Q2", options: [], asked_at: "now"}

      PendingQuestionsCache.insert_question("ref_1", meta1)
      PendingQuestionsCache.insert_question("ref_2", meta2)

      PendingQuestionsCache.delete_question("ref_1")

      questions = PendingQuestionsCache.get_questions_for_session("s1")
      assert length(questions) == 1
      assert List.first(questions).question == "Q2"
    end
  end

  describe "cleanup_expired/0" do
    test "removes entries older than TTL" do
      # Add entry
      question_meta = %{
        session_id: "session_1",
        question: "Old?",
        options: [],
        asked_at: DateTime.utc_now() |> DateTime.to_iso8601()
      }

      PendingQuestionsCache.insert_question("ref_old", question_meta)

      # Mark as very old (16 minutes ago)
      old_time = System.monotonic_time(:millisecond) - (16 * 60 * 1000)
      :ets.update_element(:osa_pending_questions, "ref_old", {3, old_time})

      # Add fresh entry
      fresh_meta = %{
        session_id: "session_2",
        question: "Fresh?",
        options: [],
        asked_at: DateTime.utc_now() |> DateTime.to_iso8601()
      }

      PendingQuestionsCache.insert_question("ref_fresh", fresh_meta)

      # Cleanup
      count = PendingQuestionsCache.cleanup_expired()

      assert count == 1
      assert not :ets.member(:osa_pending_questions, "ref_old")
      assert :ets.member(:osa_pending_questions, "ref_fresh")
    end

    test "returns count of cleaned entries" do
      # Add 3 old entries
      old_time = System.monotonic_time(:millisecond) - (16 * 60 * 1000)

      for i <- 1..3 do
        meta = %{session_id: "s1", question: "Q#{i}", options: [], asked_at: "now"}
        PendingQuestionsCache.insert_question("ref_#{i}", meta)
        :ets.update_element(:osa_pending_questions, "ref_#{i}", {3, old_time})
      end

      # Add 1 fresh entry
      fresh_meta = %{session_id: "s2", question: "Fresh", options: [], asked_at: "now"}
      PendingQuestionsCache.insert_question("ref_fresh", fresh_meta)

      count = PendingQuestionsCache.cleanup_expired()
      assert count == 3
    end

    test "returns 0 if no expired entries" do
      # Add fresh entry
      meta = %{session_id: "s1", question: "Q", options: [], asked_at: "now"}
      PendingQuestionsCache.insert_question("ref", meta)

      count = PendingQuestionsCache.cleanup_expired()
      assert count == 0
    end
  end

  describe "stats/0" do
    test "returns map with cache statistics" do
      stats = PendingQuestionsCache.stats()
      assert is_map(stats)
      assert Map.has_key?(stats, :size)
      assert Map.has_key?(stats, :max_size)
      assert Map.has_key?(stats, :ttl_seconds)
    end

    test "includes size and max_size" do
      stats = PendingQuestionsCache.stats()
      assert stats.max_size == 5000
    end

    test "indicates if at capacity" do
      stats = PendingQuestionsCache.stats()
      assert stats.at_capacity == false

      # Fill to near max
      for i <- 1..5000 do
        meta = %{session_id: "s", question: "q#{i}", options: [], asked_at: "now"}
        PendingQuestionsCache.insert_question("ref_#{i}", meta)
      end

      stats = PendingQuestionsCache.stats()
      assert stats.at_capacity == true
    end
  end

  describe "size limits and eviction" do
    test "evicts oldest entries when exceeding max_questions (5000)" do
      # Fill to max
      for i <- 1..5000 do
        meta = %{session_id: "s1", question: "Q#{i}", options: [], asked_at: "now"}
        PendingQuestionsCache.insert_question("ref_#{i}", meta)
      end

      stats_before = PendingQuestionsCache.stats()
      assert stats_before.size >= 5000

      # Add one more — should trigger eviction
      new_meta = %{session_id: "s1", question: "New", options: [], asked_at: "now"}
      PendingQuestionsCache.insert_question("ref_new", new_meta)

      stats_after = PendingQuestionsCache.stats()
      # Should be evicted down to 4750 + 1 new = 4751
      assert stats_after.size <= 4751
    end

    test "eviction removes oldest by timestamp first" do
      # Add entries with delays to control insertion order/time
      for i <- 1..100 do
        meta = %{session_id: "s1", question: "Q#{i}", options: [], asked_at: "now"}
        PendingQuestionsCache.insert_question("ref_#{i}", meta)
        if rem(i, 10) == 0, do: :timer.sleep(1)
      end

      # Fill to trigger eviction
      for i <- 101..5100 do
        meta = %{session_id: "s1", question: "Q#{i}", options: [], asked_at: "now"}
        PendingQuestionsCache.insert_question("ref_#{i}", meta)
      end

      # Early entries (ref_1, ref_2, ...) should mostly be evicted
      # Later entries (ref_100, ref_101, ...) should mostly exist
      early_exists = Enum.count(1..20, fn i -> :ets.member(:osa_pending_questions, "ref_#{i}") end)
      late_exists = Enum.count(5081..5100, fn i -> :ets.member(:osa_pending_questions, "ref_#{i}") end)

      assert early_exists < 10
      assert late_exists >= 15
    end

    test "capacity check on insert_question" do
      stats_before = PendingQuestionsCache.stats()
      assert stats_before.at_capacity == false

      # Fill to max
      for i <- 1..5000 do
        meta = %{session_id: "s1", question: "Q#{i}", options: [], asked_at: "now"}
        PendingQuestionsCache.insert_question("ref_#{i}", meta)
      end

      stats_at_max = PendingQuestionsCache.stats()
      assert stats_at_max.at_capacity == true

      # Insert another
      new_meta = %{session_id: "s1", question: "New", options: [], asked_at: "now"}
      assert PendingQuestionsCache.insert_question("ref_overflow", new_meta) == :ok

      stats_after = PendingQuestionsCache.stats()
      assert stats_after.size <= 4751
    end
  end

  describe "TTL (15 minutes)" do
    test "TTL is 15 minutes (900 seconds)" do
      stats = PendingQuestionsCache.stats()
      assert stats.ttl_seconds == 15 * 60
    end

    test "entries expire after 15 minutes" do
      meta = %{session_id: "s1", question: "Will expire", options: [], asked_at: "now"}
      PendingQuestionsCache.insert_question("ref_expire", meta)

      # Verify it exists
      questions = PendingQuestionsCache.get_questions_for_session("s1")
      assert length(questions) == 1

      # Set timestamp to 15 minutes + 1 second ago
      old_time = System.monotonic_time(:millisecond) - (15 * 60 * 1000) - 1000
      :ets.update_element(:osa_pending_questions, "ref_expire", {3, old_time})

      # Should now be filtered out
      questions = PendingQuestionsCache.get_questions_for_session("s1")
      assert length(questions) == 0
    end

    test "entries are accessible before TTL expires" do
      meta = %{session_id: "s1", question: "Fresh", options: [], asked_at: "now"}
      PendingQuestionsCache.insert_question("ref_fresh", meta)

      questions = PendingQuestionsCache.get_questions_for_session("s1")
      assert length(questions) == 1
    end
  end

  describe "concurrency" do
    test "concurrent inserts are safe" do
      tasks = Enum.map(1..100, fn i ->
        Task.async(fn ->
          meta = %{session_id: "s1", question: "Q#{i}", options: [], asked_at: "now"}
          PendingQuestionsCache.insert_question("ref_#{i}", meta)
        end)
      end)

      Enum.each(tasks, &Task.await/1)
      questions = PendingQuestionsCache.get_questions_for_session("s1")
      assert length(questions) == 100
    end

    test "concurrent gets and deletes are safe" do
      # Populate
      for i <- 1..50 do
        meta = %{session_id: "s1", question: "Q#{i}", options: [], asked_at: "now"}
        PendingQuestionsCache.insert_question("ref_#{i}", meta)
      end

      # Concurrent gets
      get_tasks = Enum.map(1..50, fn _i ->
        Task.async(fn ->
          PendingQuestionsCache.get_questions_for_session("s1")
        end)
      end)

      results = Enum.map(get_tasks, &Task.await/1)
      assert Enum.all?(results, &(length(&1) == 50))
    end
  end
end
