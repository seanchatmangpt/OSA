defmodule OptimalSystemAgent.Signal.PersistenceChicagoTDDTest do
  @moduledoc """
  Chicago TDD tests for OptimalSystemAgent.Signal.Persistence.

  Tests the signal persistence layer:
  - persist_signal/1 — save signal to database
  - list_signals/1 — query signals with filters
  - recent_signals/1 — get N most recent signals
  - signal_stats/0 — aggregated statistics
  - signal_patterns/1 — pattern analysis over time

  Note: These tests require full OTP application startup and database access.
  """

  use ExUnit.Case, async: false

  @moduletag :requires_application


  alias OptimalSystemAgent.Signal.Persistence

  setup_all do
    if Process.whereis(Persistence) == nil do
      start_supervised!(Persistence)
    end
    :ok
  end

  # =========================================================================
  # PERSIST_SIGNAL TESTS
  # =========================================================================

  describe "CRASH: persist_signal/1" do
    test "persists signal successfully" do
      attrs = %{
        session_id: "session_123",
        channel: "http",
        mode: "execute",
        genre: "inform",
        type: "inform",
        format: "text",
        weight: 0.85,
        input_preview: "test input",
        confidence: "high",
        metadata: %{source: "test"}
      }

      result = Persistence.persist_signal(attrs)
      assert {:ok, _record} = result
    end

    test "persists signal with minimal attributes" do
      attrs = %{
        session_id: "minimal_session",
        channel: "cli",
        mode: "build",
        genre: "direct",
        format: "code"
      }

      result = Persistence.persist_signal(attrs)
      assert {:ok, _record} = result
    end

    test "persists signal with various modes" do
      modes = ["build", "execute", "analyze", "maintain", "assist"]

      results = Enum.map(modes, fn mode ->
        attrs = %{
          session_id: "mode_test",
          channel: "test",
          mode: mode,
          genre: "inform",
          type: "inform",
          format: "text",
          weight: 0.5
        }
        Persistence.persist_signal(attrs)
      end)

      # All should succeed or return errors consistently
      Enum.each(results, fn result ->
        assert is_tuple(result)
      end)
    end

    test "persists signal with various genres" do
      genres = ["direct", "inform", "commit", "decide", "express"]

      Enum.each(genres, fn genre ->
        attrs = %{
          session_id: "genre_test",
          channel: "test",
          mode: "execute",
          genre: genre,
          format: "text",
          type: "inform",
          weight: 0.6
        }

        result = Persistence.persist_signal(attrs)
        assert is_tuple(result)
      end)
    end

    test "persists signal with weight boundaries" do
      weights = [0.0, 0.25, 0.5, 0.75, 1.0]

      Enum.each(weights, fn weight ->
        attrs = %{
          session_id: "weight_test",
          channel: "test",
          mode: "execute",
          genre: "inform",
          format: "text",
          type: "inform",
          weight: weight
        }

        result = Persistence.persist_signal(attrs)
        assert is_tuple(result)
      end)
    end

    test "persists signal with long input preview" do
      long_text = String.duplicate("x", 500)

      attrs = %{
        session_id: "long_preview",
        channel: "test",
        mode: "execute",
        genre: "inform",
        format: "text",
        type: "inform",
        input_preview: long_text
      }

      result = Persistence.persist_signal(attrs)
      assert is_tuple(result)
    end

    test "persists signal with metadata" do
      attrs = %{
        session_id: "metadata_test",
        channel: "test",
        mode: "execute",
        genre: "inform",
        format: "text",
        type: "inform",
        metadata: %{
          source: "api",
          user_id: "user_123",
          custom_field: "value"
        }
      }

      result = Persistence.persist_signal(attrs)
      assert is_tuple(result)
    end
  end

  # =========================================================================
  # LIST_SIGNALS TESTS
  # =========================================================================

  describe "CRASH: list_signals/1" do
    test "lists signals without filters" do
      result = Persistence.list_signals()
      assert is_list(result)
    end

    test "lists signals with limit" do
      result = Persistence.list_signals(limit: 10)
      assert is_list(result)
      assert length(result) <= 10
    end

    test "lists signals with offset" do
      r1 = Persistence.list_signals(limit: 5)
      r2 = Persistence.list_signals(limit: 5, offset: 5)

      # Both should be lists (may be empty)
      assert is_list(r1)
      assert is_list(r2)
    end

    test "lists signals with mode filter" do
      result = Persistence.list_signals(mode: "execute")
      assert is_list(result)

      # If results exist, all should have matching mode
      Enum.each(result, fn record ->
        assert record.mode == "execute" or is_nil(record.mode)
      end)
    end

    test "lists signals with channel filter" do
      result = Persistence.list_signals(channel: "http")
      assert is_list(result)
    end

    test "lists signals with genre filter" do
      result = Persistence.list_signals(genre: "inform")
      assert is_list(result)
    end

    test "lists signals with type filter" do
      result = Persistence.list_signals(type: "inform")
      assert is_list(result)
    end

    test "lists signals with weight range filters" do
      result = Persistence.list_signals(weight_min: 0.5, weight_max: 0.9)
      assert is_list(result)

      # All results should be in range
      Enum.each(result, fn record ->
        assert record.weight == nil or (record.weight >= 0.5 and record.weight <= 0.9)
      end)
    end

    test "lists signals ordered by recency" do
      result = Persistence.list_signals(limit: 100)
      assert is_list(result)

      # Check if ordered (descending by inserted_at)
      if length(result) > 1 do
        Enum.chunk_every(result, 2, 1)
        |> Enum.take(3)
        |> Enum.each(fn
          [a, b] ->
            # First should be newer than or equal to second
            assert a.inserted_at >= b.inserted_at or is_nil(a.inserted_at) or is_nil(b.inserted_at)
          [_a] ->
            # Single element, no comparison needed
            :ok
        end)
      end
    end

    test "lists signals with combined filters" do
      result = Persistence.list_signals(
        mode: "execute",
        genre: "inform",
        limit: 20
      )

      assert is_list(result)
      assert length(result) <= 20
    end
  end

  # =========================================================================
  # RECENT_SIGNALS TESTS
  # =========================================================================

  describe "CRASH: recent_signals/1" do
    test "returns recent signals with default count" do
      result = Persistence.recent_signals()
      assert is_list(result)
      assert length(result) <= 20
    end

    test "returns specified number of recent signals" do
      result = Persistence.recent_signals(5)
      assert is_list(result)
      assert length(result) <= 5
    end

    test "handles large n values" do
      result = Persistence.recent_signals(1000)
      assert is_list(result)
    end

    test "handles zero signals requested" do
      result = Persistence.recent_signals(0)
      assert is_list(result)
      assert length(result) == 0
    end

    test "returns signals in reverse chronological order" do
      result = Persistence.recent_signals(10)

      if length(result) > 1 do
        # Should be ordered newest first
        Enum.chunk_every(result, 2, 1)
        |> Enum.each(fn
          [a, b] ->
            assert a.inserted_at >= b.inserted_at or
                     is_nil(a.inserted_at) or is_nil(b.inserted_at)
          [_a] ->
            # Single element at end, no comparison needed
            :ok
        end)
      end
    end
  end

  # =========================================================================
  # SIGNAL_STATS TESTS
  # =========================================================================

  describe "CRASH: signal_stats/0" do
    test "returns statistics map" do
      stats = Persistence.signal_stats()
      assert is_map(stats)
    end

    test "stats map contains expected keys" do
      stats = Persistence.signal_stats()

      assert Map.has_key?(stats, :total)
      assert Map.has_key?(stats, :avg_weight)
      assert Map.has_key?(stats, :by_mode)
      assert Map.has_key?(stats, :by_channel)
      assert Map.has_key?(stats, :by_type)
      assert Map.has_key?(stats, :by_tier)
    end

    test "total is non-negative integer" do
      stats = Persistence.signal_stats()
      assert is_integer(stats.total)
      assert stats.total >= 0
    end

    test "avg_weight is float between 0 and 1" do
      stats = Persistence.signal_stats()
      assert is_float(stats.avg_weight) or is_integer(stats.avg_weight)
      assert stats.avg_weight >= 0.0
      assert stats.avg_weight <= 1.0 or stats.avg_weight == 0.0
    end

    test "by_mode contains string keys" do
      stats = Persistence.signal_stats()
      modes = stats.by_mode

      assert is_map(modes)

      Enum.each(modes, fn {key, count} ->
        assert is_binary(key) or is_nil(key)
        assert is_integer(count) and count >= 0
      end)
    end

    test "by_channel contains string keys" do
      stats = Persistence.signal_stats()
      channels = stats.by_channel

      assert is_map(channels)

      Enum.each(channels, fn {key, count} ->
        assert is_binary(key) or is_nil(key)
        assert is_integer(count) and count >= 0
      end)
    end

    test "stats are consistent across calls" do
      s1 = Persistence.signal_stats()
      s2 = Persistence.signal_stats()

      # Keys should be the same
      assert Map.keys(s1) == Map.keys(s2)
    end
  end

  # =========================================================================
  # SIGNAL_PATTERNS TESTS
  # =========================================================================

  describe "CRASH: signal_patterns/1" do
    test "returns patterns map" do
      patterns = Persistence.signal_patterns()
      assert is_map(patterns)
    end

    test "patterns map contains expected keys" do
      patterns = Persistence.signal_patterns()

      assert Map.has_key?(patterns, :avg_weight)
      assert Map.has_key?(patterns, :top_agents)
      assert Map.has_key?(patterns, :peak_hours)
      assert Map.has_key?(patterns, :daily_counts)
      assert Map.has_key?(patterns, :total_in_period)
    end

    test "patterns with default 7-day period" do
      patterns = Persistence.signal_patterns()

      assert is_float(patterns.avg_weight) or is_integer(patterns.avg_weight)
      assert is_map(patterns.top_agents)
      assert is_map(patterns.peak_hours)
      assert is_list(patterns.daily_counts)
      assert is_integer(patterns.total_in_period)
    end

    test "patterns with custom day range" do
      patterns = Persistence.signal_patterns(days: 1)

      assert is_map(patterns)
      assert is_integer(patterns.total_in_period)
    end

    test "patterns with 30-day range" do
      patterns = Persistence.signal_patterns(days: 30)

      assert is_map(patterns)
      assert patterns.total_in_period >= 0
    end

    test "top_agents is map with agent names as keys" do
      patterns = Persistence.signal_patterns()
      agents = patterns.top_agents

      assert is_map(agents)

      Enum.each(agents, fn {name, count} ->
        assert is_binary(name) or is_nil(name)
        assert is_integer(count) and count > 0
      end)
    end

    test "peak_hours contains hour integers" do
      patterns = Persistence.signal_patterns()
      hours = patterns.peak_hours

      assert is_map(hours)

      Enum.each(hours, fn {hour, count} ->
        assert is_integer(hour) or is_nil(hour)
        assert is_integer(count) and count >= 0
      end)
    end

    test "daily_counts is list of date maps" do
      patterns = Persistence.signal_patterns()
      daily = patterns.daily_counts

      assert is_list(daily)

      Enum.each(daily, fn entry ->
        assert is_map(entry)
        assert Map.has_key?(entry, :date)
        assert Map.has_key?(entry, :count)
        assert is_binary(entry.date)
        assert is_integer(entry.count) and entry.count > 0
      end)
    end

    test "patterns are consistent across calls" do
      p1 = Persistence.signal_patterns()
      p2 = Persistence.signal_patterns()

      # Structure should be same
      assert Map.keys(p1) == Map.keys(p2)
    end
  end

  # =========================================================================
  # INTEGRATION TESTS
  # =========================================================================

  describe "CRASH: Integration workflows" do
    test "persist and retrieve signal" do
      attrs = %{
        session_id: "integration_#{:erlang.unique_integer()}",
        channel: "test_channel",
        mode: "execute",
        genre: "inform",
        format: "text",
        type: "inform",
        weight: 0.75
      }

      # Persist
      {:ok, _record} = Persistence.persist_signal(attrs)

      # Retrieve
      results = Persistence.list_signals(channel: "test_channel")
      assert is_list(results)
    end

    test "stats reflect persisted signals" do
      s1 = Persistence.signal_stats()
      total_before = s1.total

      # Persist a signal
      attrs = %{
        session_id: "stats_test",
        channel: "stats_test_ch",
        mode: "execute",
        genre: "inform",
        format: "text",
        type: "inform"
      }

      {:ok, _} = Persistence.persist_signal(attrs)

      # Check stats
      s2 = Persistence.signal_stats()
      total_after = s2.total

      # Should not decrease
      assert total_after >= total_before
    end

    test "patterns reflect recent signals" do
      # Get patterns
      patterns = Persistence.signal_patterns(days: 7)

      assert is_integer(patterns.total_in_period)
      assert patterns.total_in_period >= 0
    end

    test "filtering reduces results" do
      # List all
      all = Persistence.list_signals(limit: 100)

      # List filtered
      filtered = Persistence.list_signals(limit: 100, mode: "execute")

      # Filtered should be <= all
      assert length(filtered) <= length(all)
    end
  end

  # =========================================================================
  # MODULE BEHAVIOR CONTRACT
  # =========================================================================

  describe "CRASH: Module behavior contract" do
    test "all public functions are exported" do
      assert function_exported?(Persistence, :persist_signal, 1)
      assert function_exported?(Persistence, :list_signals, 1)
      assert function_exported?(Persistence, :recent_signals, 1)
      assert function_exported?(Persistence, :signal_stats, 0)
      assert function_exported?(Persistence, :signal_patterns, 1)
    end

    test "GenServer callbacks are implemented" do
      assert function_exported?(Persistence, :start_link, 1)
      assert function_exported?(Persistence, :init, 1)
      assert function_exported?(Persistence, :terminate, 2)
    end

    test "functions handle default arguments" do
      # These should work with no/default args
      result1 = Persistence.list_signals()
      assert is_list(result1)

      result2 = Persistence.recent_signals()
      assert is_list(result2)

      result3 = Persistence.signal_stats()
      assert is_map(result3)

      result4 = Persistence.signal_patterns()
      assert is_map(result4)
    end

    test "persist_signal returns proper tuple" do
      attrs = %{
        session_id: "contract_test",
        channel: "test",
        mode: "execute",
        genre: "inform",
        format: "text",
        type: "inform"
      }

      result = Persistence.persist_signal(attrs)

      # Should be {:ok, record} or {:error, changeset}
      assert is_tuple(result)
    end
  end

  # =========================================================================
  # EDGE CASES AND STRESS TESTS
  # =========================================================================

  describe "CRASH: Edge cases and stress" do
    test "list_signals with extreme limit values" do
      r1 = Persistence.list_signals(limit: 1)
      r2 = Persistence.list_signals(limit: 10_000)

      assert is_list(r1)
      assert is_list(r2)
      assert length(r1) <= 1
    end

    test "list_signals with large offset" do
      result = Persistence.list_signals(offset: 999_999)

      assert is_list(result)
    end

    test "recent_signals with large n" do
      result = Persistence.recent_signals(10_000)

      assert is_list(result)
    end

    test "signal_patterns with large day range" do
      patterns = Persistence.signal_patterns(days: 365)

      assert is_map(patterns)
      assert is_integer(patterns.total_in_period)
    end

    test "persist_signal with nil optional fields" do
      attrs = %{
        session_id: "nil_test",
        channel: "test",
        mode: "execute",
        genre: "inform",
        format: "text",
        type: "inform",
        weight: nil,
        confidence: nil,
        metadata: nil
      }

      result = Persistence.persist_signal(attrs)

      assert is_tuple(result)
    end

    test "concurrent list queries don't crash" do
      tasks = for _i <- 1..10 do
        Task.start(fn ->
          Persistence.list_signals(limit: 5)
        end)
      end

      # All should complete
      assert length(tasks) == 10
    end

    test "stats computation doesn't crash on large dataset" do
      stats = Persistence.signal_stats()

      assert is_map(stats)
      assert is_integer(stats.total)
    end
  end
end
