defmodule OptimalSystemAgent.Agent.TaskTrackerOtelTest do
  @moduledoc """
  Tests for OTEL trace linking (Steps 4&5): trace_id/span_id fields and EventStream correlation.

  Verifies:
  1. Task struct accepts trace_id and span_id fields
  2. add_task can populate trace_id from options
  3. Serialization/deserialization preserves trace_id and span_id
  4. Task can be created with YAWL trace context
  """

  use ExUnit.Case, async: true
  alias OptimalSystemAgent.Agent.TaskTracker
  alias OptimalSystemAgent.Agent.TaskTracker.Task

  @test_trace_id "4bf92f3577b34da6a3ce929d0e0e4736"
  @test_span_id "00f067aa0ba902b7"

  setup do
    session_id = "test_session_#{:erlang.system_time(:millisecond)}_#{:erlang.unique_integer([:positive])}"
    server_name = :"TaskTracker_#{:erlang.unique_integer([:positive])}"
    {:ok, _pid} = TaskTracker.start_link(name: server_name)
    {:ok, session_id: session_id, server: server_name}
  end

  describe "Task struct with OTEL fields" do
    test "Task can hold trace_id and span_id", %{session_id: _session_id, server: _server} do
      task_with_trace = %Task{
        id: "t1",
        title: "Test task",
        trace_id: @test_trace_id,
        span_id: @test_span_id
      }

      assert task_with_trace.trace_id == @test_trace_id
      assert task_with_trace.span_id == @test_span_id
    end

    test "new_task accepts trace_id and span_id in opts", %{session_id: session_id, server: server} do
      # Private function tested indirectly via add_task
      {:ok, task_id} =
        TaskTracker.add_task(
          session_id,
          "YAWL workflow task",
          %{
            trace_id: @test_trace_id,
            span_id: @test_span_id,
            description: "Linked to YAWL case"
          },
          server
        )

      tasks = TaskTracker.get_tasks(session_id, server)
      task = Enum.find(tasks, &(&1.id == task_id))

      assert task.trace_id == @test_trace_id
      assert task.span_id == @test_span_id
      assert task.description == "Linked to YAWL case"
    end

    test "Task defaults trace_id and span_id to nil", %{session_id: session_id, server: server} do
      {:ok, task_id} =
        TaskTracker.add_task(
          session_id,
          "Plain task",
          %{},
          server
        )

      tasks = TaskTracker.get_tasks(session_id, server)
      task = Enum.find(tasks, &(&1.id == task_id))

      assert task.trace_id == nil
      assert task.span_id == nil
    end
  end

  describe "Serialization preserves trace_id and span_id" do
    test "Task.to_json includes trace_id and span_id", %{server: server} do
      task = %Task{
        id: "t1",
        title: "Test",
        trace_id: @test_trace_id,
        span_id: @test_span_id,
        status: :pending
      }

      json = Task.to_json(task)

      assert json["trace_id"] == @test_trace_id
      assert json["span_id"] == @test_span_id
    end

    test "Task.to_json handles nil trace_id and span_id" do
      task = %Task{
        id: "t1",
        title: "Test",
        status: :pending
      }

      json = Task.to_json(task)

      assert json["trace_id"] == nil
      assert json["span_id"] == nil
    end

    test "Persistence round-trip preserves trace_id and span_id", %{session_id: session_id, server: server} do
      # Create a task with trace_id
      {:ok, task_id} =
        TaskTracker.add_task(
          session_id,
          "YAWL work task",
          %{
            trace_id: @test_trace_id,
            span_id: @test_span_id
          },
          server
        )

      # Verify it was persisted
      tasks_before = TaskTracker.get_tasks(session_id, server)
      task_before = Enum.find(tasks_before, &(&1.id == task_id))

      assert task_before.trace_id == @test_trace_id
      assert task_before.span_id == @test_span_id

      # Reset the in-memory state to simulate reload
      TaskTracker.reset_state(server)

      # Fetch again — should load from disk with trace_id intact
      tasks_after = TaskTracker.get_tasks(session_id, server)
      task_after = Enum.find(tasks_after, &(&1.id == task_id))

      assert task_after.trace_id == @test_trace_id
      assert task_after.span_id == @test_span_id
      assert task_after.title == "YAWL work task"
    end
  end

  describe "Task correlation with YAWL cases" do
    test "add_task with YAWL trace context creates correlated task", %{session_id: session_id, server: server} do
      # Simulate YAWL case launch response with trace_id
      case_id = "1.#{:erlang.system_time(:millisecond)}"
      yawl_trace_id = "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4"
      yawl_span_id = "1234567890abcdef"

      # Create task linked to YAWL trace
      {:ok, task_id} =
        TaskTracker.add_task(
          session_id,
          "Handle YAWL work item",
          %{
            description: "Work item from case #{case_id}",
            trace_id: yawl_trace_id,
            span_id: yawl_span_id,
            metadata: %{"case_id" => case_id}
          },
          server
        )

      tasks = TaskTracker.get_tasks(session_id, server)
      task = Enum.find(tasks, &(&1.id == task_id))

      # Verify task is correlated with YAWL trace
      assert task.trace_id == yawl_trace_id
      assert task.span_id == yawl_span_id
      assert task.metadata["case_id"] == case_id
      assert String.contains?(task.description, case_id)
    end

    test "Multiple tasks can share same trace_id (same YAWL case)", %{session_id: session_id, server: server} do
      # Simulate multiple work items from same YAWL case
      shared_trace_id = "shared_trace_id_for_case_123"
      span_id_1 = "span_item_1"
      span_id_2 = "span_item_2"

      {:ok, task_id_1} =
        TaskTracker.add_task(
          session_id,
          "Task 1 from YAWL",
          %{trace_id: shared_trace_id, span_id: span_id_1},
          server
        )

      {:ok, task_id_2} =
        TaskTracker.add_task(
          session_id,
          "Task 2 from YAWL",
          %{trace_id: shared_trace_id, span_id: span_id_2},
          server
        )

      tasks = TaskTracker.get_tasks(session_id, server)

      task_1 = Enum.find(tasks, &(&1.id == task_id_1))
      task_2 = Enum.find(tasks, &(&1.id == task_id_2))

      # Both tasks have same trace_id but different span_ids
      assert task_1.trace_id == shared_trace_id
      assert task_2.trace_id == shared_trace_id
      assert task_1.span_id == span_id_1
      assert task_2.span_id == span_id_2
    end
  end

  describe "Task status transitions preserve trace context" do
    test "start_task preserves trace_id and span_id", %{session_id: session_id, server: server} do
      {:ok, task_id} =
        TaskTracker.add_task(
          session_id,
          "YAWL task to start",
          %{trace_id: @test_trace_id, span_id: @test_span_id},
          server
        )

      TaskTracker.start_task(session_id, task_id, server)

      tasks = TaskTracker.get_tasks(session_id, server)
      task = Enum.find(tasks, &(&1.id == task_id))

      assert task.status == :in_progress
      assert task.trace_id == @test_trace_id
      assert task.span_id == @test_span_id
      assert task.started_at != nil
    end

    test "complete_task preserves trace_id and span_id", %{session_id: session_id, server: server} do
      {:ok, task_id} =
        TaskTracker.add_task(
          session_id,
          "YAWL task to complete",
          %{trace_id: @test_trace_id, span_id: @test_span_id},
          server
        )

      TaskTracker.start_task(session_id, task_id, server)
      TaskTracker.complete_task(session_id, task_id, server)

      tasks = TaskTracker.get_tasks(session_id, server)
      task = Enum.find(tasks, &(&1.id == task_id))

      assert task.status == :completed
      assert task.trace_id == @test_trace_id
      assert task.span_id == @test_span_id
      assert task.completed_at != nil
    end

    test "fail_task preserves trace_id and span_id", %{session_id: session_id, server: server} do
      {:ok, task_id} =
        TaskTracker.add_task(
          session_id,
          "YAWL task that fails",
          %{trace_id: @test_trace_id, span_id: @test_span_id},
          server
        )

      TaskTracker.start_task(session_id, task_id, server)
      TaskTracker.fail_task(session_id, task_id, "Work item failed", server)

      tasks = TaskTracker.get_tasks(session_id, server)
      task = Enum.find(tasks, &(&1.id == task_id))

      assert task.status == :failed
      assert task.trace_id == @test_trace_id
      assert task.span_id == @test_span_id
      assert task.reason == "Work item failed"
    end
  end

  describe "update_task_fields preserves trace context" do
    test "update_task_fields preserves trace_id and span_id", %{session_id: session_id, server: server} do
      {:ok, task_id} =
        TaskTracker.add_task(
          session_id,
          "Task to update",
          %{trace_id: @test_trace_id, span_id: @test_span_id},
          server
        )

      TaskTracker.update_task_fields(
        session_id,
        task_id,
        %{description: "Updated description", owner: "alice"},
        server
      )

      tasks = TaskTracker.get_tasks(session_id, server)
      task = Enum.find(tasks, &(&1.id == task_id))

      assert task.description == "Updated description"
      assert task.owner == "alice"
      assert task.trace_id == @test_trace_id
      assert task.span_id == @test_span_id
    end
  end
end
