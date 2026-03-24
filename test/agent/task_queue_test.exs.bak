defmodule OptimalSystemAgent.Agent.TaskQueueTest do
  @moduledoc """
  Unit tests for TaskQueue module.

  Tests task enqueueing, leasing, completion, and failure handling.

  Note: TaskQueue is a singleton - tests use unique IDs to avoid conflicts.
  """

  use ExUnit.Case, async: false

  alias OptimalSystemAgent.Agent.TaskQueue

  @moduletag :capture_log
  @moduletag :skip

  setup do
    # Ensure TaskQueue is started for tests
    unless Process.whereis(TaskQueue) do
      _pid = start_supervised!(TaskQueue)
    end

    # Generate unique IDs for each test to avoid conflicts
    test_id = System.unique_integer([:positive])
    task_id = "task-#{test_id}"
    agent_id = "agent-#{test_id}"

    %{task_id: task_id, agent_id: agent_id}
  end

  describe "enqueue_sync/4" do
    test "creates a new task", %{task_id: task_id, agent_id: agent_id} do
      {:ok, task} = TaskQueue.enqueue_sync(task_id, agent_id, %{action: "test"})

      assert task.task_id == task_id
      assert task.agent_id == agent_id
      assert task.status == :pending
      assert task.payload == %{action: "test"}
      assert task.attempts == 0
    end

    test "sets max_attempts from opts", %{task_id: task_id, agent_id: agent_id} do
      {:ok, task} = TaskQueue.enqueue_sync(task_id, agent_id, %{}, max_attempts: 5)

      assert task.max_attempts == 5
    end
  end

  describe "lease/2" do
    test "leases oldest pending task for agent", %{task_id: tid1, agent_id: agent_id} do
      tid2 = tid1 <> "-2"
      {:ok, _t1} = TaskQueue.enqueue_sync(tid1, agent_id, %{})
      {:ok, _t2} = TaskQueue.enqueue_sync(tid2, agent_id, %{})

      assert {:ok, task} = TaskQueue.lease(agent_id, 5000)
      assert task.task_id == tid1
      assert task.status == :leased
      assert task.leased_by == agent_id
      assert task.leased_until != nil
    end

    test "returns empty when no tasks available" do
      assert :empty = TaskQueue.lease("nonexistent-agent", 5000)
    end

    test "only leases tasks for specific agent", %{task_id: tid1, agent_id: agent_id} do
      agent2 = agent_id <> "-2"
      agent3 = "agent-unknown"

      {:ok, _t1} = TaskQueue.enqueue_sync(tid1, agent_id, %{})
      {:ok, _t2} = TaskQueue.enqueue_sync(tid1 <> "-2", agent2, %{})

      assert :empty = TaskQueue.lease(agent3, 5000)
      assert {:ok, task} = TaskQueue.lease(agent_id, 5000)
      assert task.task_id == tid1
    end
  end

  describe "complete/2" do
    test "marks task as completed", %{task_id: task_id, agent_id: agent_id} do
      {:ok, _task} = TaskQueue.enqueue_sync(task_id, agent_id, %{})

      TaskQueue.complete(task_id, %{result: "success"})

      # Small delay for cast to process
      Process.sleep(10)

      assert {:ok, task} = TaskQueue.get_task(task_id)
      assert task.status == :completed
      assert task.result == %{result: "success"}
      assert task.completed_at != nil
    end
  end

  describe "fail/2" do
    test "retries task under max_attempts", %{task_id: task_id, agent_id: agent_id} do
      {:ok, _task} = TaskQueue.enqueue_sync(task_id, agent_id, %{}, max_attempts: 3)

      TaskQueue.fail(task_id, "temporary error")
      Process.sleep(10)

      assert {:ok, task} = TaskQueue.get_task(task_id)
      assert task.status == :pending
      assert task.attempts == 1
      assert task.error == "temporary error"
    end

    test "marks task as failed after max attempts", %{task_id: task_id, agent_id: agent_id} do
      {:ok, _task} = TaskQueue.enqueue_sync(task_id, agent_id, %{}, max_attempts: 2)

      # First fail
      TaskQueue.fail(task_id, "error 1")
      Process.sleep(10)

      # Second fail - should mark as failed
      TaskQueue.fail(task_id, "error 2")
      Process.sleep(10)

      assert {:ok, task} = TaskQueue.get_task(task_id)
      assert task.status == :failed
      assert task.attempts == 2
      assert task.error == "error 2"
    end
  end

  describe "list_tasks/1" do
    test "lists all tasks by default", %{task_id: tid1, agent_id: agent_id} do
      tid2 = tid1 <> "-2"
      agent2 = agent_id <> "-2"

      {:ok, _t1} = TaskQueue.enqueue_sync(tid1, agent_id, %{})
      {:ok, _t2} = TaskQueue.enqueue_sync(tid2, agent2, %{})

      tasks = TaskQueue.list_tasks()
      # At least our 2 tasks (may have more from other tests)
      assert length(tasks) >= 2

      # Find our tasks
      our_tasks = Enum.filter(tasks, fn t -> t.task_id in [tid1, tid2] end)
      assert length(our_tasks) == 2
    end

    test "filters by status", %{task_id: task_id, agent_id: agent_id} do
      {:ok, _t1} = TaskQueue.enqueue_sync(task_id, agent_id, %{})

      tasks = TaskQueue.list_tasks(status: :pending)
      # At least our task
      assert length(Enum.filter(tasks, fn t -> t.task_id == task_id end)) >= 1

      tasks = TaskQueue.list_tasks(status: :completed)
      assert Enum.find(tasks, fn t -> t.task_id == task_id end) == nil
    end

    test "filters by agent_id", %{task_id: tid1, agent_id: agent_id} do
      tid2 = tid1 <> "-2"
      agent2 = agent_id <> "-2"

      {:ok, _t1} = TaskQueue.enqueue_sync(tid1, agent_id, %{})
      {:ok, _t2} = TaskQueue.enqueue_sync(tid2, agent2, %{})

      tasks = TaskQueue.list_tasks(agent_id: agent_id)
      assert length(Enum.filter(tasks, fn t -> t.task_id == tid1 end)) >= 1
      assert Enum.find(tasks, fn t -> t.agent_id == agent_id end) != nil
    end
  end

  describe "get_task/1" do
    test "returns task by id", %{task_id: task_id, agent_id: agent_id} do
      {:ok, _task} = TaskQueue.enqueue_sync(task_id, agent_id, %{})

      assert {:ok, task} = TaskQueue.get_task(task_id)
      assert task.task_id == task_id
    end

    test "returns error for unknown task" do
      assert {:error, :not_found} = TaskQueue.get_task("totally-unknown-task-id")
    end
  end
end
