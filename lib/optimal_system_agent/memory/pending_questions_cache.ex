defmodule OptimalSystemAgent.Memory.PendingQuestionsCache do
  @moduledoc """
  Bounded cache for pending ask_user questions with TTL and size limits.

  ETS table :osa_pending_questions stores:
    {ref_string, %{session_id, question, options, asked_at}, timestamp_ms}

  Features:
    - Max 5000 entries (auto-evict oldest when exceeded)
    - 15-minute TTL (entries expire automatically)
    - LRU eviction when size limit reached
    - Timestamp-based cleanup on startup

  Public API:
    - insert_question/3 — add pending question
    - get_questions_for_session/1 — list pending for a session
    - delete_question/1 — manual cleanup
    - cleanup_expired/0 — remove expired entries
  """
  require Logger

  @table :osa_pending_questions
  @max_questions 5000
  @eviction_target 4750
  @ttl_seconds 15 * 60

  # ── Public API ──────────────────────────────────────────────────────────

  @doc "Insert a pending question. Evicts oldest if cache is full."
  def insert_question(ref_str, question_meta) when is_binary(ref_str) and is_map(question_meta) do
    now = System.monotonic_time(:millisecond)
    size = :ets.info(@table, :size)

    # Evict if at capacity
    if size >= @max_questions do
      evict_oldest_questions()
    end

    # Insert with timestamp for TTL tracking
    :ets.insert(@table, {ref_str, question_meta, now})
    :ok
  end

  @doc "Get all pending questions for a specific session."
  def get_questions_for_session(session_id) when is_binary(session_id) do
    try do
      now = System.monotonic_time(:millisecond)
      ttl_ms = @ttl_seconds * 1000

      :ets.tab2list(@table)
      |> Enum.filter(fn {_ref, meta, timestamp_ms} ->
        # Check not expired
        not_expired = now - timestamp_ms < ttl_ms
        session_match = meta.session_id == session_id
        not_expired and session_match
      end)
      |> Enum.map(fn {ref, meta, _timestamp_ms} ->
        %{
          ref: ref,
          question: meta.question,
          options: meta.options,
          asked_at: meta.asked_at
        }
      end)
    rescue
      _ -> []
    end
  end

  @doc "Delete a specific pending question by ref."
  def delete_question(ref_str) when is_binary(ref_str) do
    :ets.delete(@table, ref_str)
    :ok
  end

  @doc "Remove all expired questions (older than @ttl_seconds)."
  def cleanup_expired do
    try do
      now = System.monotonic_time(:millisecond)
      ttl_ms = @ttl_seconds * 1000

      expired =
        :ets.tab2list(@table)
        |> Enum.filter(fn {_ref, _meta, timestamp_ms} ->
          now - timestamp_ms >= ttl_ms
        end)

      Enum.each(expired, fn {ref, _meta, _ts} ->
        :ets.delete(@table, ref)
      end)

      count = length(expired)
      if count > 0 do
        Logger.debug("pending_questions_cache: cleaned up #{count} expired entries")
      end

      count
    rescue
      _ -> 0
    end
  end

  @doc "Get cache statistics (size, max, etc)."
  def stats do
    size = :ets.info(@table, :size)
    %{
      size: size,
      max_size: @max_questions,
      eviction_target: @eviction_target,
      ttl_seconds: @ttl_seconds,
      at_capacity: size >= @max_questions
    }
  end

  # ── Private helpers ────────────────────────────────────────────────────

  defp evict_oldest_questions do
    try do
      all_entries = :ets.tab2list(@table)

      entries_to_evict =
        all_entries
        |> Enum.sort_by(fn {_ref, _meta, timestamp_ms} -> timestamp_ms end)
        |> Enum.take(length(all_entries) - @eviction_target)

      Enum.each(entries_to_evict, fn {ref, _meta, _ts} ->
        :ets.delete(@table, ref)
      end)

      evicted_count = length(entries_to_evict)
      Logger.debug(
        "pending_questions_cache: evicted #{evicted_count} oldest entries (size #{length(all_entries)} -> #{@eviction_target})"
      )

      :ok
    rescue
      e ->
        Logger.error("pending_questions_cache: eviction failed: #{inspect(e)}")
        :error
    end
  end
end
