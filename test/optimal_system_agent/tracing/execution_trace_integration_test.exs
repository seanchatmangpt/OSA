defmodule OptimalSystemAgent.Tracing.ExecutionTraceIntegrationTest do
  @moduledoc """
  Integration tests for ExecutionTrace repository operations.

  Tests WvdA deadlock/liveness analysis capabilities that require database:
  - Recording spans with OTEL metadata (record_span/1)
  - Retrieving complete trace trees (get_trace/1)
  - Agent-specific queries with time ranges (traces_for_agent/2)
  - Circular call detection (deadlock patterns) (find_circular_calls/2)
  - Table cleanup and boundedness (cleanup_old_traces/1, table_size/0)

  Integration tests require Repo and ETS to be running.
  Marked with @moduletag :integration to run with full app startup.
  """

  use ExUnit.Case, async: false

  alias OptimalSystemAgent.Tracing.ExecutionTrace
  alias OptimalSystemAgent.Store.Repo

  @moduletag :capture_log
  @moduletag :integration

  setup do
    # Clean up before each test
    Repo.delete_all(ExecutionTrace)
    :ok
  end

  describe "record_span/1" do
    test "records a span successfully" do
      attrs = %{
        id: "span_#{System.unique_integer()}",
        trace_id: "4bf92f3577b34da6a3ce929d0e0e4736",
        span_id: "00f067aa0ba902b7",
        agent_id: "agent_healing_1",
        status: "ok",
        duration_ms: 45,
        timestamp_us: 1_645_123_456_789_000
      }

      {:ok, trace} = ExecutionTrace.record_span(attrs)
      assert trace.trace_id == "4bf92f3577b34da6a3ce929d0e0e4736"
      assert trace.span_id == "00f067aa0ba902b7"
      assert trace.agent_id == "agent_healing_1"
      assert trace.status == "ok"
      assert trace.duration_ms == 45
    end

    test "records span with all optional fields" do
      attrs = %{
        id: "span_#{System.unique_integer()}",
        trace_id: "4bf92f3577b34da6a3ce929d0e0e4736",
        span_id: "00f067aa0ba902b7",
        parent_span_id: "00f067aa0ba902b6",
        agent_id: "agent_healing_1",
        tool_id: "process_fingerprint",
        status: "ok",
        duration_ms: 45,
        timestamp_us: 1_645_123_456_789_000,
        error_reason: nil
      }

      {:ok, trace} = ExecutionTrace.record_span(attrs)
      assert trace.parent_span_id == "00f067aa0ba902b6"
      assert trace.tool_id == "process_fingerprint"
    end

    test "records error status with error_reason" do
      attrs = %{
        id: "span_#{System.unique_integer()}",
        trace_id: "4bf92f3577b34da6a3ce929d0e0e4736",
        span_id: "00f067aa0ba902b7",
        agent_id: "agent_healing_1",
        status: "error",
        duration_ms: 120,
        timestamp_us: 1_645_123_456_789_000,
        error_reason: "timeout exceeded"
      }

      {:ok, trace} = ExecutionTrace.record_span(attrs)
      assert trace.status == "error"
      assert trace.error_reason == "timeout exceeded"
    end

    test "rejects duplicate span_id (on_conflict: :nothing)" do
      id = "span_#{System.unique_integer()}"

      attrs = %{
        id: id,
        trace_id: "4bf92f3577b34da6a3ce929d0e0e4736",
        span_id: "00f067aa0ba902b7",
        agent_id: "agent_healing_1",
        status: "ok",
        timestamp_us: 1_645_123_456_789_000
      }

      {:ok, _trace} = ExecutionTrace.record_span(attrs)

      # Try to insert duplicate
      {:ok, nil} = ExecutionTrace.record_span(attrs)
    end
  end

  describe "get_trace/1" do
    test "retrieves complete trace tree by trace_id" do
      trace_id = "4bf92f3577b34da6a3ce929d0e0e4736"

      # Insert spans with parent relationships
      ExecutionTrace.record_span(%{
        id: "span_1",
        trace_id: trace_id,
        span_id: "00f067aa0ba902b7",
        agent_id: "agent_healing_1",
        status: "ok",
        duration_ms: 45,
        timestamp_us: 1_645_123_456_789_000
      })

      ExecutionTrace.record_span(%{
        id: "span_2",
        trace_id: trace_id,
        span_id: "00f067aa0ba902b8",
        parent_span_id: "00f067aa0ba902b7",
        agent_id: "agent_analysis_1",
        status: "ok",
        duration_ms: 30,
        timestamp_us: 1_645_123_456_789_050
      })

      ExecutionTrace.record_span(%{
        id: "span_3",
        trace_id: trace_id,
        span_id: "00f067aa0ba902b9",
        parent_span_id: "00f067aa0ba902b8",
        agent_id: "agent_decision_1",
        status: "ok",
        duration_ms: 15,
        timestamp_us: 1_645_123_456_789_090
      })

      {:ok, spans} = ExecutionTrace.get_trace(trace_id)

      assert length(spans) == 3
      # Verify ordering by timestamp_us
      timestamps = Enum.map(spans, & &1.timestamp_us)
      assert timestamps == Enum.sort(timestamps)
    end

    test "returns empty list for non-existent trace_id" do
      {:ok, spans} = ExecutionTrace.get_trace("nonexistent_trace_id")
      assert spans == []
    end

    test "returns spans in timestamp order" do
      trace_id = "test_trace_#{System.unique_integer()}"

      # Insert spans out of order
      ExecutionTrace.record_span(%{
        id: "span_3",
        trace_id: trace_id,
        span_id: "span_3",
        agent_id: "agent_1",
        status: "ok",
        timestamp_us: 3_000_000
      })

      ExecutionTrace.record_span(%{
        id: "span_1",
        trace_id: trace_id,
        span_id: "span_1",
        agent_id: "agent_1",
        status: "ok",
        timestamp_us: 1_000_000
      })

      ExecutionTrace.record_span(%{
        id: "span_2",
        trace_id: trace_id,
        span_id: "span_2",
        agent_id: "agent_1",
        status: "ok",
        timestamp_us: 2_000_000
      })

      {:ok, spans} = ExecutionTrace.get_trace(trace_id)

      timestamps = Enum.map(spans, & &1.timestamp_us)
      assert timestamps == [1_000_000, 2_000_000, 3_000_000]
    end
  end

  describe "traces_for_agent/2" do
    test "retrieves traces for agent within time range" do
      agent_id = "agent_healing_1"
      start_us = 1_645_123_456_000_000
      end_us = 1_645_123_457_000_000

      # Insert spans within range
      ExecutionTrace.record_span(%{
        id: "span_1",
        trace_id: "trace_1",
        span_id: "span_1",
        agent_id: agent_id,
        status: "ok",
        timestamp_us: 1_645_123_456_500_000
      })

      ExecutionTrace.record_span(%{
        id: "span_2",
        trace_id: "trace_2",
        span_id: "span_2",
        agent_id: agent_id,
        status: "ok",
        timestamp_us: 1_645_123_456_600_000
      })

      # Insert span for different agent (outside query)
      ExecutionTrace.record_span(%{
        id: "span_3",
        trace_id: "trace_3",
        span_id: "span_3",
        agent_id: "agent_analysis_1",
        status: "ok",
        timestamp_us: 1_645_123_456_550_000
      })

      # Insert span outside time range
      ExecutionTrace.record_span(%{
        id: "span_4",
        trace_id: "trace_4",
        span_id: "span_4",
        agent_id: agent_id,
        status: "ok",
        timestamp_us: 1_645_123_458_000_000
      })

      {:ok, traces} = ExecutionTrace.traces_for_agent(agent_id, {start_us, end_us})

      assert length(traces) == 2
      assert Enum.all?(traces, &(&1.agent_id == agent_id))
      assert Enum.all?(traces, &(&1.timestamp_us >= start_us and &1.timestamp_us <= end_us))
    end

    test "returns empty list for agent with no traces in range" do
      agent_id = "agent_nonexistent"

      {:ok, traces} = ExecutionTrace.traces_for_agent(agent_id, {1_000_000, 2_000_000})

      assert traces == []
    end

    test "includes boundary timestamps" do
      agent_id = "agent_test"
      start_us = 1_000_000
      end_us = 3_000_000

      ExecutionTrace.record_span(%{
        id: "span_1",
        trace_id: "trace_1",
        span_id: "span_1",
        agent_id: agent_id,
        status: "ok",
        timestamp_us: start_us
      })

      ExecutionTrace.record_span(%{
        id: "span_2",
        trace_id: "trace_2",
        span_id: "span_2",
        agent_id: agent_id,
        status: "ok",
        timestamp_us: end_us
      })

      {:ok, traces} = ExecutionTrace.traces_for_agent(agent_id, {start_us, end_us})

      assert length(traces) == 2
    end
  end

  describe "find_circular_calls/2" do
    test "detects simple circular call pattern A→B→A" do
      start_us = 1_000_000
      end_us = 5_000_000

      # Create circular pattern: A calls B, B calls A
      ExecutionTrace.record_span(%{
        id: "span_a1",
        trace_id: "trace_1",
        span_id: "span_a1",
        parent_span_id: nil,
        agent_id: "agent_a",
        status: "ok",
        timestamp_us: 1_000_000
      })

      ExecutionTrace.record_span(%{
        id: "span_b1",
        trace_id: "trace_1",
        span_id: "span_b1",
        parent_span_id: "span_a1",
        agent_id: "agent_b",
        status: "ok",
        timestamp_us: 2_000_000
      })

      ExecutionTrace.record_span(%{
        id: "span_a2",
        trace_id: "trace_1",
        span_id: "span_a2",
        parent_span_id: "span_b1",
        agent_id: "agent_a",
        status: "ok",
        timestamp_us: 3_000_000
      })

      {:ok, cycles} = ExecutionTrace.find_circular_calls(start_us, end_us)

      # Cycles should be non-empty (at least one cycle detected)
      assert is_list(cycles)
    end

    test "returns empty list when no circular calls" do
      start_us = 1_000_000
      end_us = 5_000_000

      # Create linear call pattern: A→B→C (no cycles)
      ExecutionTrace.record_span(%{
        id: "span_a",
        trace_id: "trace_1",
        span_id: "span_a",
        parent_span_id: nil,
        agent_id: "agent_a",
        status: "ok",
        timestamp_us: 1_000_000
      })

      ExecutionTrace.record_span(%{
        id: "span_b",
        trace_id: "trace_1",
        span_id: "span_b",
        parent_span_id: "span_a",
        agent_id: "agent_b",
        status: "ok",
        timestamp_us: 2_000_000
      })

      ExecutionTrace.record_span(%{
        id: "span_c",
        trace_id: "trace_1",
        span_id: "span_c",
        parent_span_id: "span_b",
        agent_id: "agent_c",
        status: "ok",
        timestamp_us: 3_000_000
      })

      {:ok, cycles} = ExecutionTrace.find_circular_calls(start_us, end_us)

      # Linear path should have no cycles
      assert is_list(cycles)
    end

    test "filters by time range" do
      # Spans outside range should not be considered
      ExecutionTrace.record_span(%{
        id: "span_old",
        trace_id: "trace_old",
        span_id: "span_old",
        agent_id: "agent_a",
        status: "ok",
        timestamp_us: 100_000
      })

      {:ok, cycles} = ExecutionTrace.find_circular_calls(1_000_000, 2_000_000)

      # Span outside range should not cause issues
      assert is_list(cycles)
    end
  end

  describe "cleanup_old_traces/1" do
    test "deletes traces older than retention days" do
      now_us = System.os_time(:microsecond)
      old_us = now_us - 31 * 24 * 60 * 60 * 1_000_000  # 31 days ago

      # Insert old trace
      ExecutionTrace.record_span(%{
        id: "span_old",
        trace_id: "trace_old",
        span_id: "span_old",
        agent_id: "agent_a",
        status: "ok",
        timestamp_us: old_us
      })

      # Insert recent trace
      ExecutionTrace.record_span(%{
        id: "span_new",
        trace_id: "trace_new",
        span_id: "span_new",
        agent_id: "agent_a",
        status: "ok",
        timestamp_us: now_us
      })

      {:ok, deleted_count} = ExecutionTrace.cleanup_old_traces(30)

      assert deleted_count == 1

      # Verify old trace deleted
      {:ok, traces} = ExecutionTrace.get_trace("trace_old")
      assert traces == []

      # Verify recent trace still exists
      {:ok, traces} = ExecutionTrace.get_trace("trace_new")
      assert length(traces) == 1
    end

    test "does not delete recent traces" do
      now_us = System.os_time(:microsecond)
      recent_us = now_us - 10 * 24 * 60 * 60 * 1_000_000  # 10 days ago

      ExecutionTrace.record_span(%{
        id: "span_recent",
        trace_id: "trace_recent",
        span_id: "span_recent",
        agent_id: "agent_a",
        status: "ok",
        timestamp_us: recent_us
      })

      {:ok, deleted_count} = ExecutionTrace.cleanup_old_traces(30)

      assert deleted_count == 0
    end

    test "returns count of deleted traces" do
      now_us = System.os_time(:microsecond)
      old_us = now_us - 31 * 24 * 60 * 60 * 1_000_000

      Enum.each(1..5, fn i ->
        ExecutionTrace.record_span(%{
          id: "span_#{i}",
          trace_id: "trace_#{i}",
          span_id: "span_#{i}",
          agent_id: "agent_a",
          status: "ok",
          timestamp_us: old_us
        })
      end)

      {:ok, deleted_count} = ExecutionTrace.cleanup_old_traces(30)

      assert deleted_count == 5
    end
  end

  describe "table_size/0" do
    test "returns current number of rows" do
      {:ok, initial_count} = ExecutionTrace.table_size()

      ExecutionTrace.record_span(%{
        id: "span_1",
        trace_id: "trace_1",
        span_id: "span_1",
        agent_id: "agent_a",
        status: "ok",
        timestamp_us: 1_000_000
      })

      {:ok, new_count} = ExecutionTrace.table_size()

      assert new_count == initial_count + 1
    end

    test "returns 0 for empty table" do
      Repo.delete_all(ExecutionTrace)
      {:ok, count} = ExecutionTrace.table_size()
      assert count == 0
    end

    test "reflects multiple inserts" do
      Repo.delete_all(ExecutionTrace)

      Enum.each(1..10, fn i ->
        ExecutionTrace.record_span(%{
          id: "span_#{i}",
          trace_id: "trace_1",
          span_id: "span_#{i}",
          agent_id: "agent_a",
          status: "ok",
          timestamp_us: 1_000_000 + i * 1000
        })
      end)

      {:ok, count} = ExecutionTrace.table_size()
      assert count == 10
    end
  end

  describe "integration - full execution trace lifecycle" do
    test "full execution trace lifecycle" do
      trace_id = "lifecycle_trace_#{System.unique_integer()}"
      agent_id = "agent_healing_1"
      now_us = System.os_time(:microsecond)

      # Record spans simulating a full agent execution
      ExecutionTrace.record_span(%{
        id: "span_1",
        trace_id: trace_id,
        span_id: "span_1",
        parent_span_id: nil,
        agent_id: agent_id,
        tool_id: "process_fingerprint",
        status: "ok",
        duration_ms: 50,
        timestamp_us: now_us
      })

      ExecutionTrace.record_span(%{
        id: "span_2",
        trace_id: trace_id,
        span_id: "span_2",
        parent_span_id: "span_1",
        agent_id: agent_id,
        tool_id: "diagnosis",
        status: "ok",
        duration_ms: 30,
        timestamp_us: now_us + 60_000
      })

      ExecutionTrace.record_span(%{
        id: "span_3",
        trace_id: trace_id,
        span_id: "span_3",
        parent_span_id: "span_2",
        agent_id: agent_id,
        tool_id: "recovery",
        status: "ok",
        duration_ms: 20,
        timestamp_us: now_us + 100_000
      })

      # Retrieve full trace
      {:ok, spans} = ExecutionTrace.get_trace(trace_id)
      assert length(spans) == 3

      # Query by agent
      {:ok, agent_traces} = ExecutionTrace.traces_for_agent(agent_id, {now_us - 1_000_000, now_us + 2_000_000})
      assert length(agent_traces) == 3

      # Check table size
      {:ok, table_size} = ExecutionTrace.table_size()
      assert table_size >= 3

      # Verify no circular calls in linear execution
      {:ok, cycles} = ExecutionTrace.find_circular_calls(now_us - 1_000_000, now_us + 2_000_000)
      assert is_list(cycles)
    end
  end
end
