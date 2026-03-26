defmodule OptimalSystemAgent.Tracing.ExecutionTraceTest do
  @moduledoc """
  Unit tests for ExecutionTrace schema and changeset validation.

  Tests WvdA Soundness requirements for deadlock/liveness analysis:
  - Schema field presence and validation
  - Status enum validation ("ok" or "error")
  - Timestamp and duration bounds checking
  - Optional field handling

  Pure unit tests - no database required.
  Integration tests (Repo operations) are in execution_trace_integration_test.exs.
  """

  use ExUnit.Case, async: true

  alias OptimalSystemAgent.Tracing.ExecutionTrace

  @moduletag :capture_log

  describe "changeset/2 - required fields" do
    test "validates all required fields present" do
      attrs = %{
        id: "span_#{System.unique_integer()}",
        trace_id: "4bf92f3577b34da6a3ce929d0e0e4736",
        span_id: "00f067aa0ba902b7",
        agent_id: "agent_healing_1",
        status: "ok",
        timestamp_us: 1_645_123_456_789_000
      }

      changeset = ExecutionTrace.changeset(%ExecutionTrace{}, attrs)
      assert changeset.valid?
    end

    test "requires id field" do
      attrs = %{
        trace_id: "4bf92f3577b34da6a3ce929d0e0e4736",
        span_id: "00f067aa0ba902b7",
        agent_id: "agent_healing_1",
        status: "ok",
        timestamp_us: 1_645_123_456_789_000
      }

      changeset = ExecutionTrace.changeset(%ExecutionTrace{}, attrs)
      refute changeset.valid?
      assert "id" in Enum.map(changeset.errors, &elem(&1, 0) |> to_string())
    end

    test "requires trace_id field" do
      attrs = %{
        id: "span_1",
        span_id: "00f067aa0ba902b7",
        agent_id: "agent_healing_1",
        status: "ok",
        timestamp_us: 1_645_123_456_789_000
      }

      changeset = ExecutionTrace.changeset(%ExecutionTrace{}, attrs)
      refute changeset.valid?
    end

    test "requires span_id field" do
      attrs = %{
        id: "span_1",
        trace_id: "4bf92f3577b34da6a3ce929d0e0e4736",
        agent_id: "agent_healing_1",
        status: "ok",
        timestamp_us: 1_645_123_456_789_000
      }

      changeset = ExecutionTrace.changeset(%ExecutionTrace{}, attrs)
      refute changeset.valid?
    end

    test "requires agent_id field" do
      attrs = %{
        id: "span_1",
        trace_id: "4bf92f3577b34da6a3ce929d0e0e4736",
        span_id: "00f067aa0ba902b7",
        status: "ok",
        timestamp_us: 1_645_123_456_789_000
      }

      changeset = ExecutionTrace.changeset(%ExecutionTrace{}, attrs)
      refute changeset.valid?
    end

    test "requires status field" do
      attrs = %{
        id: "span_1",
        trace_id: "4bf92f3577b34da6a3ce929d0e0e4736",
        span_id: "00f067aa0ba902b7",
        agent_id: "agent_healing_1",
        timestamp_us: 1_645_123_456_789_000
      }

      changeset = ExecutionTrace.changeset(%ExecutionTrace{}, attrs)
      refute changeset.valid?
    end

    test "requires timestamp_us field" do
      attrs = %{
        id: "span_1",
        trace_id: "4bf92f3577b34da6a3ce929d0e0e4736",
        span_id: "00f067aa0ba902b7",
        agent_id: "agent_healing_1",
        status: "ok"
      }

      changeset = ExecutionTrace.changeset(%ExecutionTrace{}, attrs)
      refute changeset.valid?
    end
  end

  describe "changeset/2 - status validation" do
    test "accepts 'ok' status" do
      attrs = %{
        id: "span_1",
        trace_id: "4bf92f3577b34da6a3ce929d0e0e4736",
        span_id: "00f067aa0ba902b7",
        agent_id: "agent_healing_1",
        status: "ok",
        timestamp_us: 1_645_123_456_789_000
      }

      changeset = ExecutionTrace.changeset(%ExecutionTrace{}, attrs)
      assert changeset.valid?
    end

    test "accepts 'error' status" do
      attrs = %{
        id: "span_1",
        trace_id: "4bf92f3577b34da6a3ce929d0e0e4736",
        span_id: "00f067aa0ba902b7",
        agent_id: "agent_healing_1",
        status: "error",
        timestamp_us: 1_645_123_456_789_000
      }

      changeset = ExecutionTrace.changeset(%ExecutionTrace{}, attrs)
      assert changeset.valid?
    end

    test "rejects invalid status values" do
      attrs = %{
        id: "span_1",
        trace_id: "4bf92f3577b34da6a3ce929d0e0e4736",
        span_id: "00f067aa0ba902b7",
        agent_id: "agent_healing_1",
        status: "pending",
        timestamp_us: 1_645_123_456_789_000
      }

      changeset = ExecutionTrace.changeset(%ExecutionTrace{}, attrs)
      refute changeset.valid?
      assert "status" in Enum.map(changeset.errors, &elem(&1, 0) |> to_string())
    end

    test "rejects status 'unknown'" do
      attrs = %{
        id: "span_1",
        trace_id: "4bf92f3577b34da6a3ce929d0e0e4736",
        span_id: "00f067aa0ba902b7",
        agent_id: "agent_healing_1",
        status: "unknown",
        timestamp_us: 1_645_123_456_789_000
      }

      changeset = ExecutionTrace.changeset(%ExecutionTrace{}, attrs)
      refute changeset.valid?
    end
  end

  describe "changeset/2 - timestamp validation (WvdA)" do
    test "validates timestamp_us is positive" do
      attrs = %{
        id: "span_1",
        trace_id: "4bf92f3577b34da6a3ce929d0e0e4736",
        span_id: "00f067aa0ba902b7",
        agent_id: "agent_healing_1",
        status: "ok",
        timestamp_us: 0
      }

      changeset = ExecutionTrace.changeset(%ExecutionTrace{}, attrs)
      refute changeset.valid?
    end

    test "accepts large timestamp values" do
      attrs = %{
        id: "span_1",
        trace_id: "4bf92f3577b34da6a3ce929d0e0e4736",
        span_id: "00f067aa0ba902b7",
        agent_id: "agent_healing_1",
        status: "ok",
        timestamp_us: 9_999_999_999_999_999
      }

      changeset = ExecutionTrace.changeset(%ExecutionTrace{}, attrs)
      assert changeset.valid?
    end

    test "accepts minimum valid timestamp" do
      attrs = %{
        id: "span_1",
        trace_id: "4bf92f3577b34da6a3ce929d0e0e4736",
        span_id: "00f067aa0ba902b7",
        agent_id: "agent_healing_1",
        status: "ok",
        timestamp_us: 1
      }

      changeset = ExecutionTrace.changeset(%ExecutionTrace{}, attrs)
      assert changeset.valid?
    end
  end

  describe "changeset/2 - duration validation" do
    test "validates duration_ms is non-negative" do
      attrs = %{
        id: "span_1",
        trace_id: "4bf92f3577b34da6a3ce929d0e0e4736",
        span_id: "00f067aa0ba902b7",
        agent_id: "agent_healing_1",
        status: "ok",
        timestamp_us: 1_645_123_456_789_000,
        duration_ms: -1
      }

      changeset = ExecutionTrace.changeset(%ExecutionTrace{}, attrs)
      refute changeset.valid?
    end

    test "accepts zero duration" do
      attrs = %{
        id: "span_1",
        trace_id: "4bf92f3577b34da6a3ce929d0e0e4736",
        span_id: "00f067aa0ba902b7",
        agent_id: "agent_healing_1",
        status: "ok",
        timestamp_us: 1_645_123_456_789_000,
        duration_ms: 0
      }

      changeset = ExecutionTrace.changeset(%ExecutionTrace{}, attrs)
      assert changeset.valid?
    end

    test "accepts large duration values" do
      attrs = %{
        id: "span_1",
        trace_id: "4bf92f3577b34da6a3ce929d0e0e4736",
        span_id: "00f067aa0ba902b7",
        agent_id: "agent_healing_1",
        status: "ok",
        timestamp_us: 1_645_123_456_789_000,
        duration_ms: 86_400_000  # 24 hours in ms
      }

      changeset = ExecutionTrace.changeset(%ExecutionTrace{}, attrs)
      assert changeset.valid?
    end
  end

  describe "changeset/2 - optional fields" do
    test "accepts all optional fields" do
      attrs = %{
        id: "span_1",
        trace_id: "4bf92f3577b34da6a3ce929d0e0e4736",
        span_id: "00f067aa0ba902b7",
        parent_span_id: "00f067aa0ba902b6",
        agent_id: "agent_healing_1",
        tool_id: "process_fingerprint",
        status: "ok",
        duration_ms: 45,
        timestamp_us: 1_645_123_456_789_000,
        error_reason: "timeout exceeded"
      }

      changeset = ExecutionTrace.changeset(%ExecutionTrace{}, attrs)
      assert changeset.valid?
    end

    test "accepts nil for optional fields" do
      attrs = %{
        id: "span_1",
        trace_id: "4bf92f3577b34da6a3ce929d0e0e4736",
        span_id: "00f067aa0ba902b7",
        agent_id: "agent_healing_1",
        status: "ok",
        timestamp_us: 1_645_123_456_789_000,
        parent_span_id: nil,
        tool_id: nil,
        duration_ms: nil,
        error_reason: nil
      }

      changeset = ExecutionTrace.changeset(%ExecutionTrace{}, attrs)
      assert changeset.valid?
    end

    test "omitting optional fields is valid" do
      attrs = %{
        id: "span_1",
        trace_id: "4bf92f3577b34da6a3ce929d0e0e4736",
        span_id: "00f067aa0ba902b7",
        agent_id: "agent_healing_1",
        status: "ok",
        timestamp_us: 1_645_123_456_789_000
      }

      changeset = ExecutionTrace.changeset(%ExecutionTrace{}, attrs)
      assert changeset.valid?
    end
  end

  describe "changeset/2 - error status with error_reason" do
    test "records error status with error_reason" do
      attrs = %{
        id: "span_1",
        trace_id: "4bf92f3577b34da6a3ce929d0e0e4736",
        span_id: "00f067aa0ba902b7",
        agent_id: "agent_healing_1",
        status: "error",
        duration_ms: 120,
        timestamp_us: 1_645_123_456_789_000,
        error_reason: "timeout exceeded"
      }

      changeset = ExecutionTrace.changeset(%ExecutionTrace{}, attrs)
      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :error_reason) == "timeout exceeded"
    end

    test "allows error status without error_reason" do
      attrs = %{
        id: "span_1",
        trace_id: "4bf92f3577b34da6a3ce929d0e0e4736",
        span_id: "00f067aa0ba902b7",
        agent_id: "agent_healing_1",
        status: "error",
        timestamp_us: 1_645_123_456_789_000
      }

      changeset = ExecutionTrace.changeset(%ExecutionTrace{}, attrs)
      assert changeset.valid?
    end
  end

  describe "struct fields" do
    test "has all required fields" do
      trace = %ExecutionTrace{
        id: "span_1",
        trace_id: "trace_1",
        span_id: "span_1",
        agent_id: "agent_1",
        status: "ok",
        timestamp_us: 1_000_000
      }

      assert trace.id == "span_1"
      assert trace.trace_id == "trace_1"
      assert trace.span_id == "span_1"
      assert trace.agent_id == "agent_1"
      assert trace.status == "ok"
      assert trace.timestamp_us == 1_000_000
    end

    test "has all optional fields" do
      trace = %ExecutionTrace{
        id: "span_1",
        trace_id: "trace_1",
        span_id: "span_1",
        parent_span_id: "span_0",
        agent_id: "agent_1",
        tool_id: "fingerprint",
        status: "ok",
        duration_ms: 50,
        timestamp_us: 1_000_000,
        error_reason: "test error"
      }

      assert trace.parent_span_id == "span_0"
      assert trace.tool_id == "fingerprint"
      assert trace.duration_ms == 50
      assert trace.error_reason == "test error"
    end
  end

  describe "changeset integration" do
    test "full changeset lifecycle with valid attrs" do
      attrs = %{
        id: "span_comprehensive",
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

      changeset = ExecutionTrace.changeset(%ExecutionTrace{}, attrs)
      assert changeset.valid?

      # Apply changeset to get struct
      trace = Ecto.Changeset.apply_changes(changeset)
      assert trace.id == "span_comprehensive"
      assert trace.trace_id == "4bf92f3577b34da6a3ce929d0e0e4736"
      assert trace.agent_id == "agent_healing_1"
      assert trace.status == "ok"
      assert trace.duration_ms == 45
    end

    test "changeset errors collected for multiple violations" do
      attrs = %{
        id: "span_1",
        trace_id: "4bf92f3577b34da6a3ce929d0e0e4736",
        # Missing span_id
        agent_id: "agent_healing_1",
        status: "invalid_status",
        timestamp_us: 0  # Invalid: must be > 0
      }

      changeset = ExecutionTrace.changeset(%ExecutionTrace{}, attrs)
      refute changeset.valid?

      error_fields = Enum.map(changeset.errors, &elem(&1, 0) |> to_string())
      assert "span_id" in error_fields
      assert "status" in error_fields
      assert "timestamp_us" in error_fields
    end
  end

  describe "edge cases" do
    test "handles unicode in string fields" do
      attrs = %{
        id: "span_unicode_测试",
        trace_id: "4bf92f3577b34da6a3ce929d0e0e4736",
        span_id: "span_unicode_🔥",
        agent_id: "agent_名前_1",
        tool_id: "tool_ツール",
        status: "ok",
        timestamp_us: 1_645_123_456_789_000,
        error_reason: "エラー: timeout exceeded"
      }

      changeset = ExecutionTrace.changeset(%ExecutionTrace{}, attrs)
      assert changeset.valid?
    end

    test "handles very long string fields" do
      long_string = String.duplicate("x", 1000)

      attrs = %{
        id: "span_1",
        trace_id: long_string,
        span_id: long_string,
        agent_id: long_string,
        status: "ok",
        timestamp_us: 1_645_123_456_789_000,
        error_reason: long_string
      }

      changeset = ExecutionTrace.changeset(%ExecutionTrace{}, attrs)
      assert changeset.valid?
    end

    test "handles maximum integer values" do
      attrs = %{
        id: "span_1",
        trace_id: "trace_1",
        span_id: "span_1",
        agent_id: "agent_1",
        status: "ok",
        timestamp_us: 9_223_372_036_854_775_807,  # Max i64
        duration_ms: 2_147_483_647  # Max i32
      }

      changeset = ExecutionTrace.changeset(%ExecutionTrace{}, attrs)
      assert changeset.valid?
    end
  end

  describe "WvdA Soundness Requirements" do
    test "schema captures deadlock detection requirements (timing)" do
      # Duration and timestamp_us fields are required for deadlock analysis
      attrs = %{
        id: "span_1",
        trace_id: "trace_1",
        span_id: "span_1",
        agent_id: "agent_healing_1",
        status: "ok",
        timestamp_us: 1_645_123_456_789_000,
        duration_ms: 500  # Timing data for deadlock detection
      }

      changeset = ExecutionTrace.changeset(%ExecutionTrace{}, attrs)
      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :duration_ms) == 500
    end

    test "schema captures liveness requirements (status)" do
      # Status field distinguishes ok vs error (liveness proof)
      ok_attrs = %{
        id: "span_ok",
        trace_id: "trace_1",
        span_id: "span_ok",
        agent_id: "agent_1",
        status: "ok",
        timestamp_us: 1_000_000
      }

      error_attrs = %{
        id: "span_error",
        trace_id: "trace_1",
        span_id: "span_error",
        agent_id: "agent_1",
        status: "error",
        timestamp_us: 1_000_000,
        error_reason: "timeout"
      }

      ok_changeset = ExecutionTrace.changeset(%ExecutionTrace{}, ok_attrs)
      error_changeset = ExecutionTrace.changeset(%ExecutionTrace{}, error_attrs)

      assert ok_changeset.valid?
      assert error_changeset.valid?
      assert Ecto.Changeset.get_change(ok_changeset, :status) == "ok"
      assert Ecto.Changeset.get_change(error_changeset, :status) == "error"
    end

    test "schema captures boundedness requirements (trace_id grouping)" do
      # trace_id allows grouping for resource limit analysis
      attrs = %{
        id: "span_1",
        trace_id: "trace_bounded_resource_1",
        span_id: "span_1",
        agent_id: "agent_1",
        status: "ok",
        timestamp_us: 1_000_000
      }

      changeset = ExecutionTrace.changeset(%ExecutionTrace{}, attrs)
      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :trace_id) == "trace_bounded_resource_1"
    end
  end
end
