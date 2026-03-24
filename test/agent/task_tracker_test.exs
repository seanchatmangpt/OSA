defmodule OptimalSystemAgent.Agent.TaskTrackerTest do
  @moduledoc """
  Chicago TDD unit tests for TaskTracker module.

  Tests task management, dependency tracking, and auto-extraction.

  Note: TaskTracker is a singleton - tests use unique session IDs to avoid conflicts.
  """

  use ExUnit.Case, async: false

  alias OptimalSystemAgent.Agent.TaskTracker

  @moduletag :capture_log

  setup do
    # Set unique OSA_HOME for each test to isolate persistence
    test_id = System.unique_integer([:positive])
    temp_home = System.tmp_dir!() |> Path.join("osa_test_#{test_id}")
    System.put_env("OSA_HOME", temp_home)

    # Ensure TaskTracker is started for tests
    unless Process.whereis(TaskTracker) do
      _pid = start_supervised!(TaskTracker)
    end

    # Reset GenServer state to clear any previous test sessions
    TaskTracker.reset_state()

    # Generate unique session ID for each test to avoid conflicts
    session_id = "test-session-#{test_id}"

    # Clean up temp directory after test
    on_exit(fn ->
      File.rm_rf!(temp_home)
    end)

    %{session_id: session_id}
  end

  describe "add_task/3" do
    test "adds a new task", %{session_id: session_id} do
      assert {:ok, task_id} = TaskTracker.add_task(session_id, "Test task")

      assert is_binary(task_id)
      assert String.length(task_id) > 0

      tasks = TaskTracker.get_tasks(session_id)
      assert length(tasks) == 1
      task = hd(tasks)
      assert task.id == task_id
      assert task.title == "Test task"
      assert task.status == :pending
    end

    test "adds task with opts", %{session_id: session_id} do
      opts = %{
        description: "Task description",
        owner: "test-agent",
        blocked_by: ["other-id"],
        metadata: %{"key" => "value"}
      }

      assert {:ok, _task_id} = TaskTracker.add_task(session_id, "Test task", opts)

      [task] = TaskTracker.get_tasks(session_id)
      assert task.description == "Task description"
      assert task.owner == "test-agent"
      assert task.blocked_by == ["other-id"]
      assert task.metadata == %{"key" => "value"}
    end
  end

  describe "add_tasks/2" do
    test "adds multiple tasks", %{session_id: session_id} do
      titles = ["Task 1", "Task 2", "Task 3"]

      assert {:ok, ids} = TaskTracker.add_tasks(session_id, titles)
      assert length(ids) == 3

      tasks = TaskTracker.get_tasks(session_id)
      assert length(tasks) == 3
    end
  end

  describe "start_task/2" do
    test "transitions task to in_progress", %{session_id: session_id} do
      {:ok, task_id} = TaskTracker.add_task(session_id, "Test task")

      assert :ok = TaskTracker.start_task(session_id, task_id)

      [task] = TaskTracker.get_tasks(session_id)
      assert task.status == :in_progress
      assert task.started_at != nil
    end

    test "returns error for unknown task", %{session_id: session_id} do
      assert {:error, :not_found} = TaskTracker.start_task(session_id, "unknown")
    end
  end

  describe "complete_task/2" do
    test "transitions task to completed", %{session_id: session_id} do
      {:ok, task_id} = TaskTracker.add_task(session_id, "Test task")

      assert :ok = TaskTracker.complete_task(session_id, task_id)

      [task] = TaskTracker.get_tasks(session_id)
      assert task.status == :completed
      assert task.completed_at != nil
    end
  end

  describe "fail_task/3" do
    test "transitions task to failed with reason", %{session_id: session_id} do
      {:ok, task_id} = TaskTracker.add_task(session_id, "Test task")

      assert :ok = TaskTracker.fail_task(session_id, task_id, "Test failure")

      [task] = TaskTracker.get_tasks(session_id)
      assert task.status == :failed
      assert task.reason == "Test failure"
      assert task.completed_at != nil
    end
  end

  describe "update_task_fields/3" do
    test "updates allowed fields", %{session_id: session_id} do
      {:ok, task_id} = TaskTracker.add_task(session_id, "Test task")

      updates = %{
        description: "New description",
        owner: "new-owner",
        metadata: %{"new" => "data"}
      }

      assert :ok = TaskTracker.update_task_fields(session_id, task_id, updates)

      [task] = TaskTracker.get_tasks(session_id)
      assert task.description == "New description"
      assert task.owner == "new-owner"
      assert task.metadata == %{"new" => "data"}
    end
  end

  describe "add_dependency/3" do
    test "adds blocker to task", %{session_id: session_id} do
      {:ok, id1} = TaskTracker.add_task(session_id, "Task 1")
      {:ok, id2} = TaskTracker.add_task(session_id, "Task 2")

      assert :ok = TaskTracker.add_dependency(session_id, id2, id1)

      tasks = TaskTracker.get_tasks(session_id)
      task2 = Enum.find(tasks, fn t -> t.id == id2 end)
      assert id1 in task2.blocked_by
    end

    test "returns error for unknown blocker", %{session_id: session_id} do
      {:ok, task_id} = TaskTracker.add_task(session_id, "Task 1")

      assert {:error, :blocker_not_found} =
               TaskTracker.add_dependency(session_id, task_id, "unknown")
    end
  end

  describe "remove_dependency/3" do
    test "removes blocker from task", %{session_id: session_id} do
      {:ok, id1} = TaskTracker.add_task(session_id, "Task 1")
      {:ok, id2} = TaskTracker.add_task(session_id, "Task 2")

      # Add dependency
      TaskTracker.add_dependency(session_id, id2, id1)

      # Remove it
      assert :ok = TaskTracker.remove_dependency(session_id, id2, id1)

      tasks = TaskTracker.get_tasks(session_id)
      task2 = Enum.find(tasks, fn t -> t.id == id2 end)
      assert id1 not in task2.blocked_by
    end
  end

  describe "get_next_task/1" do
    test "returns first unblocked pending task", %{session_id: session_id} do
      {:ok, id1} = TaskTracker.add_task(session_id, "Task 1")
      {:ok, id2} = TaskTracker.add_task(session_id, "Task 2")
      {:ok, _id3} = TaskTracker.add_task(session_id, "Task 3")

      # Block task 2
      TaskTracker.add_dependency(session_id, id2, id1)

      assert {:ok, next} = TaskTracker.get_next_task(session_id)
      # Task 1 is unblocked, should be returned
      assert next.id == id1
    end

    test "skips blocked tasks", %{session_id: session_id} do
      {:ok, id1} = TaskTracker.add_task(session_id, "Task 1")
      {:ok, id2} = TaskTracker.add_task(session_id, "Task 2")

      # Block task 1
      TaskTracker.add_dependency(session_id, id1, id2)

      assert {:ok, next} = TaskTracker.get_next_task(session_id)
      # Task 2 is unblocked, should be returned
      assert next.id == id2
    end
  end

  describe "clear_tasks/1" do
    test "removes all tasks for session", %{session_id: session_id} do
      {:ok, _id1} = TaskTracker.add_task(session_id, "Task 1")
      {:ok, _id2} = TaskTracker.add_task(session_id, "Task 2")

      assert :ok = TaskTracker.clear_tasks(session_id)

      tasks = TaskTracker.get_tasks(session_id)
      assert tasks == []
    end
  end

  describe "extract_tasks_from_response/1" do
    test "extracts numbered list items" do
      text = """
      Plan:
      1. First task to do
      2. Second task here
      3. Third task also
      """

      tasks = TaskTracker.extract_tasks_from_response(text)

      assert length(tasks) == 3
      assert "First task to do" in tasks
      assert "Second task here" in tasks
      assert "Third task also" in tasks
    end

    test "extracts markdown checkboxes" do
      text = """
      Tasks:
      - [ ] Task one here
      - [ ] Task two there
      - [x] Already done
      """

      tasks = TaskTracker.extract_tasks_from_response(text)

      assert length(tasks) == 3
      assert "Task one here" in tasks
      assert "Task two there" in tasks
      assert "Already done" in tasks
    end

    test "filters by length (5-120 chars)" do
      # Task 1: 4 chars - too short (filtered out)
      # Task 2: valid length
      # Task 3: way too long (filtered out)
      text = """
      1. Hi
      2. This is a valid task title that meets the minimum length requirement
      3. #{String.duplicate("word ", 50)}
      """

      tasks = TaskTracker.extract_tasks_from_response(text)

      # Only the middle task should pass the filter
      assert length(tasks) == 1
      assert String.contains?(hd(tasks), "valid task title")
    end

    test "caps at 20 tasks" do
      lines = Enum.map(1..30, fn i -> "#{i}. Task #{i}" end) |> Enum.join("\n")

      tasks = TaskTracker.extract_tasks_from_response(lines)

      assert length(tasks) == 20
    end

    test "removes duplicates" do
      text = """
      1. Do the thing
      2. Do the thing
      3. Something else
      """

      tasks = TaskTracker.extract_tasks_from_response(text)

      assert length(tasks) == 2
      assert Enum.count(tasks, &(&1 == "Do the thing")) == 1
    end
  end
end
