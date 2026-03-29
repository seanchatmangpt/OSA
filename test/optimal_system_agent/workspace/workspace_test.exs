defmodule OptimalSystemAgent.Workspace.WorkspaceTest do
  @moduledoc """
  Unit tests for Workspace.Workspace module.

  Tests workspace GenServer lifecycle and state management.
  """

  use ExUnit.Case, async: false


  alias OptimalSystemAgent.Workspace.Workspace

  @moduletag :capture_log
  @moduletag :requires_application

  @test_name "Test Workspace"
  @test_dir "./test_workspace_gen"

  setup do
    # Ensure registry exists for this test
    {:ok, _} = Registry.start_link(keys: :unique, name: OptimalSystemAgent.Registry)

    # Clean up test directory
    File.rm_rf(@test_dir)

    on_exit(fn ->
      File.rm_rf(@test_dir)
    end)

    :ok
  end

  describe "start_link/1" do
    test "starts workspace with given workspace_id and name" do
      unique_id = "ws_start_link_#{System.unique_integer()}"
      assert {:ok, pid} = Workspace.start_link(workspace_id: unique_id, name: @test_name)
      assert is_pid(pid)
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end

    test "accepts custom project_path" do
      unique_id = "ws_custom_path_#{System.unique_integer()}"
      custom_path = "./custom_workspace_test"
      assert {:ok, pid} = Workspace.start_link(workspace_id: unique_id, name: @test_name, project_path: custom_path)
      GenServer.stop(pid)
    end
  end

  describe "init/1" do
    test "initializes workspace with empty state" do
      unique_id = "ws_init_#{System.unique_integer()}"
      {:ok, pid} = Workspace.start_link(workspace_id: unique_id, name: @test_name)
      state = :sys.get_state(pid)
      assert is_map(state)
      GenServer.stop(pid)
    end

    test "sets workspace_id in state" do
      unique_id = "ws_set_id_#{System.unique_integer()}"
      {:ok, pid} = Workspace.start_link(workspace_id: unique_id, name: @test_name)
      state = :sys.get_state(pid)
      assert state.workspace_id == unique_id
      GenServer.stop(pid)
    end
  end

  describe "get_state/1" do
    test "returns current workspace state" do
      unique_id = "ws_get_state_#{System.unique_integer()}"
      {:ok, pid} = Workspace.start_link(workspace_id: unique_id, name: @test_name)
      {:ok, state} = Workspace.get_state(unique_id)
      assert is_map(state)
      assert state.workspace_id == unique_id
      GenServer.stop(pid)
    end
  end

  describe "put_team/3" do
    test "adds team to workspace" do
      unique_id = "ws_put_team_#{System.unique_integer()}"
      {:ok, pid} = Workspace.start_link(workspace_id: unique_id, name: @test_name)
      team_state = %{name: "Test Team", members: []}

      assert :ok = Workspace.put_team(unique_id, "team_1", team_state)

      {:ok, state} = Workspace.get_state(unique_id)
      assert Map.has_key?(state.teams, "team_1")
      GenServer.stop(pid)
    end
  end

  describe "remove_team/2" do
    test "removes team from workspace" do
      unique_id = "ws_remove_team_#{System.unique_integer()}"
      {:ok, pid} = Workspace.start_link(workspace_id: unique_id, name: @test_name)
      team_state = %{name: "Test Team", members: []}

      assert :ok = Workspace.put_team(unique_id, "team_1", team_state)
      assert :ok = Workspace.remove_team(unique_id, "team_1")

      {:ok, state} = Workspace.get_state(unique_id)
      refute Map.has_key?(state.teams, "team_1")
      GenServer.stop(pid)
    end

    test "returns :ok for non-existent team" do
      unique_id = "ws_remove_nonexist_team_#{System.unique_integer()}"
      {:ok, pid} = Workspace.start_link(workspace_id: unique_id, name: @test_name)
      assert :ok = Workspace.remove_team(unique_id, "nonexistent")
      GenServer.stop(pid)
    end
  end

  describe "put_task/3" do
    test "adds task to workspace" do
      unique_id = "ws_put_task_#{System.unique_integer()}"
      {:ok, pid} = Workspace.start_link(workspace_id: unique_id, name: @test_name)
      task_state = %{name: "Test Task", status: :pending}

      assert :ok = Workspace.put_task(unique_id, "task_1", task_state)

      {:ok, state} = Workspace.get_state(unique_id)
      assert Map.has_key?(state.tasks, "task_1")
      GenServer.stop(pid)
    end
  end

  describe "remove_task/2" do
    test "removes task from workspace" do
      unique_id = "ws_remove_task_#{System.unique_integer()}"
      {:ok, pid} = Workspace.start_link(workspace_id: unique_id, name: @test_name)
      task_state = %{name: "Test Task", status: :pending}

      assert :ok = Workspace.put_task(unique_id, "task_1", task_state)
      assert :ok = Workspace.remove_task(unique_id, "task_1")

      {:ok, state} = Workspace.get_state(unique_id)
      refute Map.has_key?(state.tasks, "task_1")
      GenServer.stop(pid)
    end

    test "returns :ok for non-existent task" do
      unique_id = "ws_remove_nonexist_task_#{System.unique_integer()}"
      {:ok, pid} = Workspace.start_link(workspace_id: unique_id, name: @test_name)
      assert :ok = Workspace.remove_task(unique_id, "nonexistent")
      GenServer.stop(pid)
    end
  end

  describe "save_state/1" do
    test "persists workspace state to storage" do
      unique_id = "ws_save_state_#{System.unique_integer()}"
      {:ok, pid} = Workspace.start_link(workspace_id: unique_id, name: @test_name)
      team_state = %{name: "Test Team", members: []}
      Workspace.put_team(unique_id, "team_1", team_state)

      assert :ok = Workspace.save_state(unique_id)
      GenServer.stop(pid)
    end
  end

  describe "restore_state/1" do
    test "loads workspace state from storage" do
      unique_id = "ws_restore_state_#{System.unique_integer()}"
      # First, create and save a workspace
      {:ok, _pid} = Workspace.start_link(workspace_id: unique_id, name: @test_name)
      team_state = %{name: "Saved Team", members: []}
      Workspace.put_team(unique_id, "team_1", team_state)
      Workspace.save_state(unique_id)

      # Restore the workspace
      {:ok, state} = Workspace.restore_state(unique_id)
      assert is_map(state)
    end
  end

  describe "alive?/1" do
    test "returns true for running workspace" do
      unique_id = "ws_alive_#{System.unique_integer()}"
      {:ok, pid} = Workspace.start_link(workspace_id: unique_id, name: @test_name)
      assert Workspace.alive?(unique_id) == true
      GenServer.stop(pid)
    end

    test "returns false for non-existent workspace" do
      assert Workspace.alive?("nonexistent_workspace_#{System.unique_integer()}") == false
    end
  end

  describe "handle_info/2" do
    test "handles unknown messages gracefully" do
      unique_id = "ws_handle_info_#{System.unique_integer()}"
      {:ok, pid} = Workspace.start_link(workspace_id: unique_id, name: @test_name)
      send(pid, :unknown_message)
      Process.sleep(10)
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end
  end

  describe "terminate/2" do
    test "cleans up resources on shutdown" do
      unique_id = "ws_terminate_#{System.unique_integer()}"
      {:ok, pid} = Workspace.start_link(workspace_id: unique_id, name: @test_name)
      GenServer.stop(pid, :normal)
      # Should not crash
      assert true
    end
  end

  describe "edge cases" do
    test "handles workspace with unicode name" do
      unique_id = "test_workspace_unicode_#{System.unique_integer()}"
      unicode_name = "测试工作区"
      {:ok, pid} = Workspace.start_link(workspace_id: unique_id, name: unicode_name)
      {:ok, state} = Workspace.get_state(unique_id)
      assert state.name == unicode_name
      GenServer.stop(pid)
    end

    test "handles team with unicode ID" do
      unique_id = "test_workspace_team_unicode_#{System.unique_integer()}"
      {:ok, pid} = Workspace.start_link(workspace_id: unique_id, name: @test_name)
      team_state = %{name: "テストチーム", members: []}

      assert :ok = Workspace.put_team(unique_id, "チーム_1", team_state)
      {:ok, state} = Workspace.get_state(unique_id)
      assert Map.has_key?(state.teams, "チーム_1")
      GenServer.stop(pid)
    end

    test "handles adding many teams" do
      unique_id = "test_workspace_many_teams_#{System.unique_integer()}"
      {:ok, pid} = Workspace.start_link(workspace_id: unique_id, name: @test_name)

      for i <- 1..50 do
        team_state = %{name: "Team #{i}", members: []}
        Workspace.put_team(unique_id, "team_#{i}", team_state)
      end

      {:ok, state} = Workspace.get_state(unique_id)
      assert map_size(state.teams) == 50
      GenServer.stop(pid)
    end
  end

  describe "integration" do
    test "full workspace lifecycle" do
      unique_id = "ws_integration_#{System.unique_integer()}"
      # Create
      {:ok, pid} = Workspace.start_link(workspace_id: unique_id, name: @test_name)

      # Add teams
      team1 = %{name: "Team 1", members: []}
      team2 = %{name: "Team 2", members: []}

      assert :ok = Workspace.put_team(unique_id, "team_1", team1)
      assert :ok = Workspace.put_team(unique_id, "team_2", team2)

      # Verify teams exist
      {:ok, state} = Workspace.get_state(unique_id)
      assert map_size(state.teams) == 2

      # Add task
      task = %{name: "Task 1", status: :pending}
      assert :ok = Workspace.put_task(unique_id, "task_1", task)

      # Save
      assert :ok = Workspace.save_state(unique_id)

      # Remove team
      assert :ok = Workspace.remove_team(unique_id, "team_1")
      {:ok, state2} = Workspace.get_state(unique_id)
      assert map_size(state2.teams) == 1

      GenServer.stop(pid)
    end
  end
end
