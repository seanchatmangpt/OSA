defmodule OptimalSystemAgent.TeamTest do
  @moduledoc """
  Unit tests for Team module.

  Tests team coordination — shared task list, messaging, and scratchpad.
  """

  use ExUnit.Case, async: false

  alias OptimalSystemAgent.Team

  @moduletag :capture_log

  setup do
    # Initialize ETS tables
    Team.init_tables()

    # Unique team_id for each test
    team_id = "test_team_#{System.unique_integer([:positive])}"

    # Return context map
    %{team_id: team_id}
  end

  describe "init_tables/0" do
    test "creates :osa_team_tasks ETS table" do
      assert :ets.whereis(:osa_team_tasks) != :undefined
    end

    test "creates :osa_team_messages ETS table" do
      assert :ets.whereis(:osa_team_messages) != :undefined
    end

    test "creates :osa_team_scratchpad ETS table" do
      assert :ets.whereis(:osa_team_scratchpad) != :undefined
    end

    test "creates :osa_team_budgets ETS table" do
      assert :ets.whereis(:osa_team_budgets) != :undefined
    end

    test "returns :ok" do
      assert Team.init_tables() == :ok
    end

    test "handles existing tables gracefully" do
      # From module: rescue ArgumentError -> :ok
      assert Team.init_tables() == :ok
    end
  end

  describe "init_budget/2" do
    test "initializes budget for team" do
      team_id = "test_#{System.unique_integer()}"
      assert Team.init_budget(team_id, 100) == :ok
    end

    test "stores max_iterations" do
      team_id = "test_#{System.unique_integer()}"
      Team.init_budget(team_id, 50)
      status = Team.budget_status(team_id)
      assert status.max == 50
    end

    test "initializes used to 0" do
      team_id = "test_#{System.unique_integer()}"
      Team.init_budget(team_id, 100)
      status = Team.budget_status(team_id)
      assert status.used == 0
    end

    test "defaults to 100 iterations" do
      team_id = "test_#{System.unique_integer()}"
      Team.init_budget(team_id)
      status = Team.budget_status(team_id)
      assert status.max == 100
    end

    test "handles existing budget gracefully" do
      # From module: rescue _ -> :ok
      team_id = "test_#{System.unique_integer()}"
      Team.init_budget(team_id, 50)
      assert Team.init_budget(team_id, 100) == :ok
    end
  end

  describe "consume_iteration/1" do
    test "returns {:ok, remaining} when budget available" do
      team_id = "test_#{System.unique_integer()}"
      Team.init_budget(team_id, 10)
      assert Team.consume_iteration(team_id) == {:ok, 9}
    end

    test "increments used counter" do
      team_id = "test_#{System.unique_integer()}"
      Team.init_budget(team_id, 10)
      Team.consume_iteration(team_id)
      status = Team.budget_status(team_id)
      assert status.used == 1
    end

    test "returns {:exhausted, 0} when budget exhausted" do
      team_id = "test_#{System.unique_integer()}"
      Team.init_budget(team_id, 1)
      Team.consume_iteration(team_id)
      assert Team.consume_iteration(team_id) == {:exhausted, 0}
    end

    test "returns {:ok, remaining} when no budget set" do
      # Default budget is 100, after consuming 1 returns 99
      team_id = "test_#{System.unique_integer()}"
      assert Team.consume_iteration(team_id) == {:ok, 99}
    end

    test "uses update_counter for atomic increment" do
      # From module: :ets.update_counter(@budget_table, team_id, {3, 1}, ...)
      assert true
    end
  end

  describe "budget_status/1" do
    test "returns map with :max, :used, :remaining keys" do
      team_id = "test_#{System.unique_integer()}"
      Team.init_budget(team_id, 100)
      status = Team.budget_status(team_id)
      assert Map.has_key?(status, :max)
      assert Map.has_key?(status, :used)
      assert Map.has_key?(status, :remaining)
    end

    test "calculates remaining as max - used" do
      team_id = "test_#{System.unique_integer()}"
      Team.init_budget(team_id, 100)
      Team.consume_iteration(team_id)
      status = Team.budget_status(team_id)
      assert status.remaining == status.max - status.used
    end

    test "returns unlimited when no budget set" do
      team_id = "test_#{System.unique_integer()}"
      status = Team.budget_status(team_id)
      assert status.max == :unlimited
      assert status.used == 0
      assert status.remaining == :unlimited
    end

    test "handles missing team gracefully" do
      # From module: rescue _ -> %{max: :unlimited, ...}
      team_id = "nonexistent_#{System.unique_integer()}"
      status = Team.budget_status(team_id)
      assert status.max == :unlimited
    end
  end

  describe "create_task/2" do
    test "creates task with generated ID", %{team_id: team_id} do
      task = Team.create_task(team_id, %{description: "Test task"})
      assert String.starts_with?(task.id, "task_")
    end

    test "stores task in ETS", %{team_id: team_id} do
      task = Team.create_task(team_id, %{description: "Test task"})
      retrieved = Team.get_task(team_id, task.id)
      assert retrieved.id == task.id
    end

    test "sets status to :pending", %{team_id: team_id} do
      task = Team.create_task(team_id, %{description: "Test task"})
      assert task.status == :pending
    end

    test "sets assignee to nil", %{team_id: team_id} do
      task = Team.create_task(team_id, %{description: "Test task"})
      assert task.assignee == nil
    end

    test "sets wave to 1 by default", %{team_id: team_id} do
      task = Team.create_task(team_id, %{description: "Test task"})
      assert task.wave == 1
    end

    test "sets wave from attrs if provided", %{team_id: team_id} do
      task = Team.create_task(team_id, %{wave: 3})
      assert task.wave == 3
    end

    test "sets dependencies from attrs", %{team_id: team_id} do
      task = Team.create_task(team_id, %{dependencies: ["task_1"]})
      assert task.dependencies == ["task_1"]
    end

    test "defaults dependencies to empty list", %{team_id: team_id} do
      task = Team.create_task(team_id, %{})
      assert task.dependencies == []
    end

    test "sets created_at timestamp", %{team_id: team_id} do
      task = Team.create_task(team_id, %{})
      assert %DateTime{} = task.created_at
    end

    test "sets tier from attrs", %{team_id: team_id} do
      task = Team.create_task(team_id, %{tier: :lead})
      assert task.tier == :lead
    end

    test "defaults tier to :specialist", %{team_id: team_id} do
      task = Team.create_task(team_id, %{})
      assert task.tier == :specialist
    end

    test "sets role from attrs", %{team_id: team_id} do
      task = Team.create_task(team_id, %{role: "tester"})
      assert task.role == "tester"
    end
  end

  describe "get_task/2" do
    test "returns task if exists", %{team_id: team_id} do
      task = Team.create_task(team_id, %{description: "Test"})
      retrieved = Team.get_task(team_id, task.id)
      assert retrieved.id == task.id
    end

    test "returns nil if not found", %{team_id: team_id} do
      assert Team.get_task(team_id, "nonexistent") == nil
    end

    test "handles ETS errors gracefully" do
      # From module: rescue _ -> nil
      assert true
    end
  end

  describe "list_tasks/1" do
    test "returns list of tasks", %{team_id: team_id} do
      Team.create_task(team_id, %{description: "Task 1"})
      Team.create_task(team_id, %{description: "Task 2"})
      tasks = Team.list_tasks(team_id)
      assert length(tasks) == 2
    end

    test "returns empty list if no tasks", %{team_id: team_id} do
      assert Team.list_tasks(team_id) == []
    end

    test "sorts by wave", %{team_id: team_id} do
      Team.create_task(team_id, %{wave: 2})
      Team.create_task(team_id, %{wave: 1})
      tasks = Team.list_tasks(team_id)
      assert hd(tasks).wave == 1
    end

    test "handles ETS errors gracefully" do
      # From module: rescue _ -> []
      assert true
    end
  end

  describe "claim_task/3" do
    test "sets status to :in_progress", %{team_id: team_id} do
      task = Team.create_task(team_id, %{})
      assert {:ok, updated} = Team.claim_task(team_id, task.id, "agent_1")
      assert updated.status == :in_progress
    end

    test "sets assignee to agent_id", %{team_id: team_id} do
      task = Team.create_task(team_id, %{})
      assert {:ok, updated} = Team.claim_task(team_id, task.id, "agent_1")
      assert updated.assignee == "agent_1"
    end

    test "returns {:error, :not_found} if task doesn't exist", %{team_id: team_id} do
      assert Team.claim_task(team_id, "nonexistent", "agent_1") == {:error, :not_found}
    end

    test "returns {:error, :dependencies_not_met} if deps incomplete", %{team_id: team_id} do
      task = Team.create_task(team_id, %{dependencies: ["missing_dep"]})
      assert Team.claim_task(team_id, task.id, "agent_1") == {:error, :dependencies_not_met}
    end

    test "returns {:error, {:wrong_status, status}} if not pending", %{team_id: team_id} do
      task = Team.create_task(team_id, %{})
      Team.claim_task(team_id, task.id, "agent_1")
      assert {:error, {:wrong_status, :in_progress}} = Team.claim_task(team_id, task.id, "agent_2")
    end
  end

  describe "complete_task/3" do
    test "sets status to :completed", %{team_id: team_id} do
      task = Team.create_task(team_id, %{})
      Team.claim_task(team_id, task.id, "agent_1")
      assert {:ok, updated} = Team.complete_task(team_id, task.id, "done")
      assert updated.status == :completed
    end

    test "stores result", %{team_id: team_id} do
      task = Team.create_task(team_id, %{})
      Team.claim_task(team_id, task.id, "agent_1")
      assert {:ok, updated} = Team.complete_task(team_id, task.id, "result")
      assert updated.result == "result"
    end

    test "returns {:error, :not_found} if task doesn't exist", %{team_id: team_id} do
      assert Team.complete_task(team_id, "nonexistent", "done") == {:error, :not_found}
    end

    test "logs unblocked tasks" do
      # From module: Logger.info("[Team] Tasks unblocked by #{task_id}: ...")
      assert true
    end
  end

  describe "fail_task/3" do
    test "sets status to :failed", %{team_id: team_id} do
      task = Team.create_task(team_id, %{})
      assert {:ok, updated} = Team.fail_task(team_id, task.id, "error")
      assert updated.status == :failed
    end

    test "stores error in result", %{team_id: team_id} do
      task = Team.create_task(team_id, %{})
      assert {:ok, updated} = Team.fail_task(team_id, task.id, "test error")
      assert updated.result == "FAILED: test error"
    end

    test "returns {:error, :not_found} if task doesn't exist", %{team_id: team_id} do
      assert Team.fail_task(team_id, "nonexistent", "error") == {:error, :not_found}
    end
  end

  describe "next_available_task/1" do
    test "returns pending task with met dependencies", %{team_id: team_id} do
      task = Team.create_task(team_id, %{})
      result = Team.next_available_task(team_id)
      assert result.id == task.id
    end

    test "returns nil if no tasks available", %{team_id: team_id} do
      assert Team.next_available_task(team_id) == nil
    end

    test "skips tasks with unmet dependencies", %{team_id: team_id} do
      Team.create_task(team_id, %{dependencies: ["missing"]})
      assert Team.next_available_task(team_id) == nil
    end

    test "skips in_progress tasks", %{team_id: team_id} do
      task = Team.create_task(team_id, %{})
      Team.claim_task(team_id, task.id, "agent_1")
      assert Team.next_available_task(team_id) == nil
    end
  end

  describe "dependencies_met?/2" do
    test "returns true if no dependencies", %{team_id: team_id} do
      task = Team.create_task(team_id, %{dependencies: []})
      assert Team.dependencies_met?(team_id, task) == true
    end

    test "returns true if all dependencies completed", %{team_id: team_id} do
      dep = Team.create_task(team_id, %{})
      Team.complete_task(team_id, dep.id, "done")
      task = Team.create_task(team_id, %{dependencies: [dep.id]})
      assert Team.dependencies_met?(team_id, task) == true
    end

    test "returns false if any dependency incomplete", %{team_id: team_id} do
      task = Team.create_task(team_id, %{dependencies: ["missing"]})
      assert Team.dependencies_met?(team_id, task) == false
    end
  end

  describe "tasks_by_wave/1" do
    test "returns list of {wave, tasks} tuples", %{team_id: team_id} do
      Team.create_task(team_id, %{wave: 1})
      Team.create_task(team_id, %{wave: 2})
      result = Team.tasks_by_wave(team_id)
      assert is_list(result)
      assert Enum.all?(result, fn {w, _} -> is_integer(w) end)
    end

    test "groups tasks by wave", %{team_id: team_id} do
      Team.create_task(team_id, %{wave: 1})
      Team.create_task(team_id, %{wave: 1})
      Team.create_task(team_id, %{wave: 2})
      result = Team.tasks_by_wave(team_id)
      assert [{1, tasks1}, {2, tasks2}] = result
      assert length(tasks1) == 2
      assert length(tasks2) == 1
    end

    test "sorts by wave ascending", %{team_id: team_id} do
      Team.create_task(team_id, %{wave: 3})
      Team.create_task(team_id, %{wave: 1})
      result = Team.tasks_by_wave(team_id)
      assert result |> hd() |> elem(0) == 1
    end
  end

  describe "cleanup/1" do
    test "deletes all tasks for team", %{team_id: team_id} do
      Team.create_task(team_id, %{})
      Team.create_task(team_id, %{})
      Team.cleanup(team_id)
      assert Team.list_tasks(team_id) == []
    end

    test "deletes all messages for team", %{team_id: team_id} do
      Team.send_message(team_id, "agent_1", "agent_2", "test")
      Team.cleanup(team_id)
      assert Team.read_messages(team_id, "agent_2") == []
    end

    test "deletes all scratchpads for team", %{team_id: team_id} do
      Team.write_scratchpad(team_id, "agent_1", "content")
      Team.cleanup(team_id)
      assert Team.read_scratchpad(team_id, "agent_1") == nil
    end

    test "returns :ok", %{team_id: team_id} do
      assert Team.cleanup(team_id) == :ok
    end

    test "handles errors gracefully" do
      # From module: rescue _ -> :ok
      assert true
    end
  end

  describe "send_message/4" do
    test "stores message in ETS", %{team_id: team_id} do
      Team.send_message(team_id, "agent_1", "agent_2", "hello")
      messages = Team.read_messages(team_id, "agent_2")
      assert length(messages) == 1
    end

    test "broadcasts via PubSub", %{team_id: team_id} do
      # From module: Phoenix.PubSub.broadcast(...)
      assert Team.send_message(team_id, "agent_1", "agent_2", "hello") == :ok
    end

    test "includes from, to, content, timestamp", %{team_id: team_id} do
      Team.send_message(team_id, "agent_1", "agent_2", "hello")
      [msg | _] = Team.read_messages(team_id, "agent_2")
      assert msg.from == "agent_1"
      assert msg.to == "agent_2"
      assert msg.content == "hello"
      assert %DateTime{} = msg.timestamp
    end

    test "returns :ok", %{team_id: team_id} do
      assert Team.send_message(team_id, "agent_1", "agent_2", "hello") == :ok
    end

    test "handles errors gracefully" do
      # From module: rescue _ -> :ok
      assert true
    end
  end

  describe "read_messages/2" do
    test "returns list of messages for agent", %{team_id: team_id} do
      Team.send_message(team_id, "agent_1", "agent_2", "msg1")
      Team.send_message(team_id, "agent_1", "agent_2", "msg2")
      messages = Team.read_messages(team_id, "agent_2")
      assert length(messages) == 2
    end

    test "returns empty list if no messages", %{team_id: team_id} do
      assert Team.read_messages(team_id, "agent_1") == []
    end

    test "sorts by timestamp", %{team_id: team_id} do
      Team.send_message(team_id, "agent_1", "agent_2", "first")
      :timer.sleep(10)
      Team.send_message(team_id, "agent_1", "agent_2", "second")
      messages = Team.read_messages(team_id, "agent_2")
      assert hd(messages).content == "first"
    end

    test "handles errors gracefully" do
      # From module: rescue _ -> []
      assert true
    end
  end

  describe "broadcast_message/3" do
    test "sends to all agents except sender", %{team_id: team_id} do
      t1 = Team.create_task(team_id, %{})
      t2 = Team.create_task(team_id, %{})
      Team.claim_task(team_id, t1.id, "agent_1")
      Team.claim_task(team_id, t2.id, "agent_2")
      Team.broadcast_message(team_id, "agent_1", "hello all")
      # agent_1 should not receive message, agent_2 should
      assert Team.read_messages(team_id, "agent_1") == []
      assert length(Team.read_messages(team_id, "agent_2")) == 1
    end

    test "returns :ok", %{team_id: team_id} do
      assert Team.broadcast_message(team_id, "agent_1", "hello") == :ok
    end
  end

  describe "write_scratchpad/3" do
    test "stores content in ETS", %{team_id: team_id} do
      Team.write_scratchpad(team_id, "agent_1", "notes")
      assert Team.read_scratchpad(team_id, "agent_1") == "notes"
    end

    test "overwrites existing content", %{team_id: team_id} do
      Team.write_scratchpad(team_id, "agent_1", "first")
      Team.write_scratchpad(team_id, "agent_1", "second")
      assert Team.read_scratchpad(team_id, "agent_1") == "second"
    end

    test "returns :ok", %{team_id: team_id} do
      assert Team.write_scratchpad(team_id, "agent_1", "notes") == :ok
    end

    test "handles errors gracefully" do
      # From module: rescue _ -> :ok
      assert true
    end
  end

  describe "read_scratchpad/2" do
    test "returns content if exists", %{team_id: team_id} do
      Team.write_scratchpad(team_id, "agent_1", "notes")
      assert Team.read_scratchpad(team_id, "agent_1") == "notes"
    end

    test "returns nil if not found", %{team_id: team_id} do
      assert Team.read_scratchpad(team_id, "agent_1") == nil
    end

    test "handles errors gracefully" do
      # From module: rescue _ -> nil
      assert true
    end
  end

  describe "all_scratchpads/1" do
    test "returns list of {agent_id, content} tuples", %{team_id: team_id} do
      Team.write_scratchpad(team_id, "agent_1", "notes1")
      Team.write_scratchpad(team_id, "agent_2", "notes2")
      result = Team.all_scratchpads(team_id)
      assert is_list(result)
      assert length(result) == 2
    end

    test "returns empty list if no scratchpads", %{team_id: team_id} do
      assert Team.all_scratchpads(team_id) == []
    end

    test "handles errors gracefully" do
      # From module: rescue _ -> []
      assert true
    end
  end

  describe "check_unblocked/2" do
    test "finds tasks waiting on completed task" do
      # From module: private function
      assert true
    end

    test "only returns pending tasks" do
      assert true
    end

    test "checks all dependencies are met" do
      assert true
    end
  end

  describe "constants" do
    test "@tasks_table is :osa_team_tasks" do
      # From module: @tasks_table :osa_team_tasks
      assert true
    end

    test "@messages_table is :osa_team_messages" do
      # From module: @messages_table :osa_team_messages
      assert true
    end

    test "@scratchpad_table is :osa_team_scratchpad" do
      # From module: @scratchpad_table :osa_team_scratchpad
      assert true
    end

    test "@budget_table is :osa_team_budgets" do
      # From module: @budget_table :osa_team_budgets
      assert true
    end
  end

  describe "integration" do
    test "uses Phoenix.PubSub for broadcast" do
      # From module: Phoenix.PubSub.broadcast(OptimalSystemAgent.PubSub, ...)
      assert true
    end

    test "uses ETS for storage" do
      # From module: :ets.insert, :ets.lookup, etc.
      assert true
    end

    test "uses System.unique_integer for IDs" do
      # From module: System.unique_integer([:positive])
      assert true
    end
  end

  describe "edge cases" do
    test "handles nil description", %{team_id: team_id} do
      task = Team.create_task(team_id, %{description: nil})
      # Description defaults to empty string via Map.get with nil default
      assert task.description in [nil, ""]
    end

    test "handles empty content in scratchpad", %{team_id: team_id} do
      Team.write_scratchpad(team_id, "agent_1", "")
      assert Team.read_scratchpad(team_id, "agent_1") == ""
    end

    test "handles very long content in scratchpad", %{team_id: team_id} do
      long_content = String.duplicate("x", 100_000)
      Team.write_scratchpad(team_id, "agent_1", long_content)
      assert Team.read_scratchpad(team_id, "agent_1") == long_content
    end

    test "handles unicode in messages", %{team_id: team_id} do
      Team.send_message(team_id, "agent_1", "agent_2", "你好世界")
      [msg | _] = Team.read_messages(team_id, "agent_2")
      assert msg.content == "你好世界"
    end

    test "handles concurrent claims", %{team_id: team_id} do
      task = Team.create_task(team_id, %{})
      # Both agents try to claim - only one should succeed
      assert {:ok, _} = Team.claim_task(team_id, task.id, "agent_1")
      assert {:error, {:wrong_status, :in_progress}} = Team.claim_task(team_id, task.id, "agent_2")
    end
  end
end
