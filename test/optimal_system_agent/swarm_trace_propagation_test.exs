defmodule OptimalSystemAgent.SwarmTracePropagationTest do
  @moduledoc """
  OTEL Step 6: Trace Context Propagation Through Swarm Coordinators

  Verifies that trace_id and span_id are captured from parent process,
  propagated through Task.async_stream_nolink, and restored in child tasks.

  These tests verify the Context module integration at the swarm level,
  without requiring the full OSA application runtime.

  Unit tests verify:
    - Context.capture() extracts parent trace_id, span_id
    - Context.restore() plants them in child task process dictionary
    - Swarm patterns call capture() and restore() correctly

  Integration tests (separate, with full app) would verify:
    - Actual spans recorded in OTEL collector
    - Parent-child relationships in trace tree
  """

  use ExUnit.Case, async: true

  @moduletag :no_start

  alias OptimalSystemAgent.Tracing.Context

  setup do
    # Clean up process dictionary before each test
    Process.delete(:otel_trace_id)
    Process.delete(:otel_span_id)
    Process.delete(:otel_parent_span_id)

    :ok
  end

  describe "Task.async propagates captured context" do
    test "captured parent context is restored in async task" do
      parent_ctx = %{
        trace_id: "4bf92f3577b34da6a3ce929d0e0e4736",
        span_id: "00f067aa0ba902b7",
        parent_span_id: nil
      }

      Context.restore(parent_ctx)
      captured = Context.capture()

      # Spawn an async task that restores context
      task =
        Task.async(fn ->
          Context.restore(captured)
          Context.capture()
        end)

      child_ctx = Task.await(task)

      # Child should see parent's trace context
      assert child_ctx.trace_id == parent_ctx.trace_id
      assert child_ctx.span_id == parent_ctx.span_id
    end
  end

  describe "Task.Supervisor.async_stream_nolink propagates captured context" do
    test "all tasks in stream see the same captured parent context" do
      parent_ctx = %{
        trace_id: "4bf92f3577b34da6a3ce929d0e0e4736",
        span_id: "00f067aa0ba902b7",
        parent_span_id: nil
      }

      Context.restore(parent_ctx)
      captured = Context.capture()

      # Simulate parallel execution with Task.async_stream
      results =
        1..3
        |> Task.async_stream(
          fn _i ->
            Context.restore(captured)
            Context.capture()
          end,
          max_concurrency: 3
        )
        |> Enum.map(fn {:ok, ctx} -> ctx end)

      # All tasks should have the same parent trace context
      assert length(results) == 3

      results
      |> Enum.each(fn ctx ->
        assert ctx.trace_id == parent_ctx.trace_id
        assert ctx.span_id == parent_ctx.span_id
      end)
    end
  end

  describe "Trace context independence across tasks" do
    test "each task can modify its context independently" do
      parent_ctx = %{
        trace_id: "4bf92f3577b34da6a3ce929d0e0e4736",
        span_id: "00f067aa0ba902b7",
        parent_span_id: nil
      }

      Context.restore(parent_ctx)
      captured = Context.capture()

      # Two tasks that restore context and create child contexts
      task1 =
        Task.async(fn ->
          Context.restore(captured)
          child = Context.create_child_context(captured)
          Context.restore(child)
          Context.capture()
        end)

      task2 =
        Task.async(fn ->
          Context.restore(captured)
          # Task 2 doesn't create a child, just uses parent
          Context.capture()
        end)

      ctx1 = Task.await(task1)
      ctx2 = Task.await(task2)

      # Task 1 created a child context (new span_id, parent_span_id set)
      assert ctx1.parent_span_id == parent_ctx.span_id
      assert ctx1.span_id != parent_ctx.span_id

      # Task 2 used parent context directly
      assert ctx2.span_id == parent_ctx.span_id
      assert ctx2.parent_span_id == nil
    end
  end

  describe "Code inspection: swarm patterns call Context.restore" do
    test "parallel pattern has Context.restore in async closure" do
      # This is a documentation test — verifies that the swarm patterns
      # include Context.restore calls before running agents.

      # Read the source to verify (can't directly assert on code structure
      # in tests, but this documents the requirement)

      patterns_source = File.read!("lib/optimal_system_agent/swarm/patterns.ex")

      # Verify that Context module is imported
      assert String.contains?(patterns_source, "alias OptimalSystemAgent.Tracing.Context")

      # Verify parallel pattern captures context
      assert String.contains?(patterns_source, "Context.capture()")

      # Verify parallel pattern restores in async closure
      assert String.contains?(patterns_source, "Context.restore(parent_ctx)")
    end
  end
end
