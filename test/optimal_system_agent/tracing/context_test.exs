defmodule OptimalSystemAgent.Tracing.ContextTest do
  use ExUnit.Case, async: true

  alias OptimalSystemAgent.Tracing.Context

  describe "Context.capture/0" do
    test "captures empty context when no trace is set" do
      Process.delete(:otel_trace_id)
      Process.delete(:otel_span_id)
      Process.delete(:otel_parent_span_id)

      ctx = Context.capture()

      assert ctx == %{trace_id: nil, span_id: nil, parent_span_id: nil}
    end

    test "captures all three keys when set" do
      Process.put(:otel_trace_id, "4bf92f3577b34da6a3ce929d0e0e4736")
      Process.put(:otel_span_id, "00f067aa0ba902b7")
      Process.put(:otel_parent_span_id, "00f067aa0ba902b6")

      ctx = Context.capture()

      assert ctx.trace_id == "4bf92f3577b34da6a3ce929d0e0e4736"
      assert ctx.span_id == "00f067aa0ba902b7"
      assert ctx.parent_span_id == "00f067aa0ba902b6"
    end

    test "captures partial context" do
      Process.delete(:otel_trace_id)
      Process.delete(:otel_span_id)
      Process.delete(:otel_parent_span_id)

      Process.put(:otel_trace_id, "4bf92f3577b34da6a3ce929d0e0e4736")
      Process.put(:otel_span_id, "00f067aa0ba902b7")

      ctx = Context.capture()

      assert ctx.trace_id == "4bf92f3577b34da6a3ce929d0e0e4736"
      assert ctx.span_id == "00f067aa0ba902b7"
      assert ctx.parent_span_id == nil
    end
  end

  describe "Context.restore/1" do
    test "restores all keys from captured context" do
      Process.delete(:otel_trace_id)
      Process.delete(:otel_span_id)
      Process.delete(:otel_parent_span_id)

      ctx = %{
        trace_id: "4bf92f3577b34da6a3ce929d0e0e4736",
        span_id: "00f067aa0ba902b7",
        parent_span_id: "00f067aa0ba902b6"
      }

      :ok = Context.restore(ctx)

      assert Process.get(:otel_trace_id) == "4bf92f3577b34da6a3ce929d0e0e4736"
      assert Process.get(:otel_span_id) == "00f067aa0ba902b7"
      assert Process.get(:otel_parent_span_id) == "00f067aa0ba902b6"
    end

    test "skips nil values when restoring" do
      Process.delete(:otel_trace_id)
      Process.delete(:otel_span_id)
      Process.delete(:otel_parent_span_id)

      # Set up existing values
      Process.put(:otel_trace_id, "old_trace")
      Process.put(:otel_span_id, "old_span")

      ctx = %{
        trace_id: "new_trace",
        span_id: nil,
        parent_span_id: "new_parent"
      }

      :ok = Context.restore(ctx)

      assert Process.get(:otel_trace_id) == "new_trace"
      assert Process.get(:otel_span_id) == "old_span"  # Unchanged
      assert Process.get(:otel_parent_span_id) == "new_parent"
    end

    test "is idempotent" do
      Process.delete(:otel_trace_id)
      Process.delete(:otel_span_id)
      Process.delete(:otel_parent_span_id)

      ctx = %{
        trace_id: "4bf92f3577b34da6a3ce929d0e0e4736",
        span_id: "00f067aa0ba902b7",
        parent_span_id: nil
      }

      # Restore multiple times
      :ok = Context.restore(ctx)
      ctx1 = Context.capture()

      :ok = Context.restore(ctx)
      ctx2 = Context.capture()

      assert ctx1 == ctx2
    end
  end

  describe "Context.clear/0" do
    test "removes all trace keys from process dictionary" do
      Process.put(:otel_trace_id, "4bf92f3577b34da6a3ce929d0e0e4736")
      Process.put(:otel_span_id, "00f067aa0ba902b7")
      Process.put(:otel_parent_span_id, "00f067aa0ba902b6")

      :ok = Context.clear()

      assert Process.get(:otel_trace_id) == nil
      assert Process.get(:otel_span_id) == nil
      assert Process.get(:otel_parent_span_id) == nil
    end
  end

  describe "Context.get_or_generate_trace_id/0" do
    test "returns existing trace_id if set" do
      Process.delete(:otel_trace_id)
      Process.put(:otel_trace_id, "existing_trace_id")

      trace_id = Context.get_or_generate_trace_id()

      assert trace_id == "existing_trace_id"
    end

    test "generates a new trace_id if none exists" do
      Process.delete(:otel_trace_id)

      trace_id = Context.get_or_generate_trace_id()

      assert is_binary(trace_id)
      assert String.length(trace_id) == 32
      # Should be all hex characters
      assert Regex.match?(~r/^[0-9a-f]{32}$/, trace_id)
    end

    test "stores generated trace_id in process dictionary" do
      Process.delete(:otel_trace_id)

      trace_id1 = Context.get_or_generate_trace_id()
      trace_id2 = Context.get_or_generate_trace_id()

      # Second call should return same ID (now stored)
      assert trace_id1 == trace_id2
    end

    test "generated trace_ids are unique across processes" do
      Process.delete(:otel_trace_id)

      # Spawn another process and generate trace_id there
      {:ok, _pid} =
        Task.start(fn ->
          Process.delete(:otel_trace_id)
          trace_id = Context.get_or_generate_trace_id()
          send(self(), {:trace_id, trace_id})
          :timer.sleep(100)
        end)

      trace_id1 = Context.get_or_generate_trace_id()

      other_trace_id =
        receive do
          {:trace_id, id} -> id
        after
          1000 -> :timeout
        end

      # Two independent processes should generate different trace_ids
      assert trace_id1 != other_trace_id
    end
  end

  describe "Context.generate_span_id/0" do
    test "generates a valid span_id" do
      span_id = Context.generate_span_id()

      assert is_binary(span_id)
      assert String.length(span_id) == 16
      assert Regex.match?(~r/^[0-9a-f]{16}$/, span_id)
    end

    test "generates unique span_ids" do
      span_id1 = Context.generate_span_id()
      span_id2 = Context.generate_span_id()

      assert span_id1 != span_id2
    end

    test "does not modify process dictionary" do
      Process.delete(:otel_span_id)

      _span_id = Context.generate_span_id()

      # Should not be stored
      assert Process.get(:otel_span_id) == nil
    end
  end

  describe "Context.create_child_context/1" do
    test "promotes parent span_id to parent_span_id in child" do
      parent_ctx = %{
        trace_id: "4bf92f3577b34da6a3ce929d0e0e4736",
        span_id: "00f067aa0ba902b7",
        parent_span_id: nil
      }

      child_ctx = Context.create_child_context(parent_ctx)

      assert child_ctx.trace_id == parent_ctx.trace_id
      assert child_ctx.parent_span_id == parent_ctx.span_id
      assert child_ctx.span_id != parent_ctx.span_id
      assert is_binary(child_ctx.span_id)
      assert String.length(child_ctx.span_id) == 16
    end

    test "preserves trace_id through child creation chain" do
      grandparent_ctx = %{
        trace_id: "4bf92f3577b34da6a3ce929d0e0e4736",
        span_id: "00f067aa0ba902b7",
        parent_span_id: nil
      }

      parent_ctx = Context.create_child_context(grandparent_ctx)
      child_ctx = Context.create_child_context(parent_ctx)

      assert child_ctx.trace_id == grandparent_ctx.trace_id
      assert child_ctx.parent_span_id == parent_ctx.span_id
    end

    test "handles nil trace_id gracefully" do
      parent_ctx = %{
        trace_id: nil,
        span_id: "00f067aa0ba902b7",
        parent_span_id: nil
      }

      child_ctx = Context.create_child_context(parent_ctx)

      assert child_ctx.trace_id == nil
      assert child_ctx.parent_span_id == parent_ctx.span_id
    end
  end

  describe "Context.format_for_logging/1" do
    test "formats context with valid trace and span" do
      ctx = %{
        trace_id: "4bf92f3577b34da6a3ce929d0e0e4736",
        span_id: "00f067aa0ba902b7",
        parent_span_id: nil
      }

      formatted = Context.format_for_logging(ctx)

      assert formatted == "trace=4bf92f35 span=00f067aa"
    end

    test "formats context with missing trace_id" do
      ctx = %{
        trace_id: nil,
        span_id: "00f067aa0ba902b7",
        parent_span_id: nil
      }

      formatted = Context.format_for_logging(ctx)

      assert formatted == "trace=none"
    end

    test "formats context with missing span_id" do
      ctx = %{
        trace_id: "4bf92f3577b34da6a3ce929d0e0e4736",
        span_id: nil,
        parent_span_id: nil
      }

      formatted = Context.format_for_logging(ctx)

      assert formatted == "trace=none"
    end

    test "truncates long IDs to 8 characters" do
      ctx = %{
        trace_id: String.duplicate("a", 100),
        span_id: String.duplicate("b", 100),
        parent_span_id: nil
      }

      formatted = Context.format_for_logging(ctx)

      assert formatted == "trace=aaaaaaaa span=bbbbbbbb"
    end
  end

  describe "Integration: capture -> restore cycle" do
    test "captures and restores context completely" do
      Process.delete(:otel_trace_id)
      Process.delete(:otel_span_id)
      Process.delete(:otel_parent_span_id)

      # Set up initial context
      original_ctx = %{
        trace_id: "4bf92f3577b34da6a3ce929d0e0e4736",
        span_id: "00f067aa0ba902b7",
        parent_span_id: "00f067aa0ba902b6"
      }

      :ok = Context.restore(original_ctx)

      # Capture in another context
      captured_ctx = Context.capture()

      # Clear process dict
      :ok = Context.clear()

      # Verify it's cleared
      empty_ctx = Context.capture()
      assert empty_ctx == %{trace_id: nil, span_id: nil, parent_span_id: nil}

      # Restore captured context
      :ok = Context.restore(captured_ctx)

      # Verify restoration
      restored_ctx = Context.capture()
      assert restored_ctx == original_ctx
    end
  end

  describe "Integration: Task spawning preserves context" do
    test "context persists through Task.async" do
      Process.delete(:otel_trace_id)
      Process.delete(:otel_span_id)

      # Set up parent context
      parent_ctx = %{
        trace_id: "4bf92f3577b34da6a3ce929d0e0e4736",
        span_id: "00f067aa0ba902b7",
        parent_span_id: nil
      }

      :ok = Context.restore(parent_ctx)

      # Capture parent context
      captured_ctx = Context.capture()

      # Spawn a task that restores context and captures it
      task =
        Task.async(fn ->
          Context.restore(captured_ctx)
          Context.capture()
        end)

      child_ctx = Task.await(task)

      # Child should see the parent's trace context
      assert child_ctx.trace_id == parent_ctx.trace_id
      assert child_ctx.span_id == parent_ctx.span_id
    end

    test "each Task gets independent context copy" do
      Process.delete(:otel_trace_id)
      Process.delete(:otel_span_id)

      parent_ctx = %{
        trace_id: "4bf92f3577b34da6a3ce929d0e0e4736",
        span_id: "00f067aa0ba902b7",
        parent_span_id: nil
      }

      :ok = Context.restore(parent_ctx)
      captured_ctx = Context.capture()

      # Spawn two tasks that modify context independently
      task1 =
        Task.async(fn ->
          Context.restore(captured_ctx)
          Process.put(:otel_span_id, "modified_span_1")
          Context.capture()
        end)

      task2 =
        Task.async(fn ->
          Context.restore(captured_ctx)
          Process.put(:otel_span_id, "modified_span_2")
          Context.capture()
        end)

      ctx1 = Task.await(task1)
      ctx2 = Task.await(task2)

      # Each task should have its own context
      assert ctx1.span_id == "modified_span_1"
      assert ctx2.span_id == "modified_span_2"

      # Parent context should be unchanged
      parent_after = Context.capture()
      assert parent_after.span_id == "00f067aa0ba902b7"
    end
  end
end
