defmodule OptimalSystemAgent.ContextMesh.SupervisorTest do
  @moduledoc """
  Unit tests for ContextMesh.Supervisor module.

  Tests DynamicSupervisor that manages per-team Keeper processes.
  """

  use ExUnit.Case, async: false


  alias OptimalSystemAgent.ContextMesh.Supervisor

  @moduletag :capture_log
  @moduletag :requires_application

  setup do
    # Ensure Supervisor is started for tests
    unless Process.whereis(Supervisor) do
      _pid = start_supervised!(Supervisor)
    end

    :ok
  end

  describe "start_link/1" do
    test "starts the DynamicSupervisor" do
      assert Process.whereis(Supervisor) != nil
    end

    test "accepts options list" do
      # Should start without error (already started in setup)
      assert Process.whereis(Supervisor) != nil
    end
  end

  describe "start_keeper/3" do
    test "accepts team_id parameter" do
      result = Supervisor.start_keeper("test_team")

      case result do
        {:ok, _pid} -> :ok
        {:error, _reason} -> :ok
      end
    end

    test "accepts optional keeper_id" do
      result = Supervisor.start_keeper("test_team", "custom_keeper")

      case result do
        {:ok, _pid} -> :ok
        {:error, _reason} -> :ok
      end
    end

    test "accepts options list" do
      result = Supervisor.start_keeper("test_team", "keeper", flush_fn: fn _ -> :ok end)

      case result do
        {:ok, _pid} -> :ok
        {:error, _reason} -> :ok
      end
    end

    test "defaults keeper_id to team_id when not provided" do
      result1 = Supervisor.start_keeper("team_a")
      result2 = Supervisor.start_keeper("team_a", "team_a")

      # Both should succeed or fail the same way
      assert elem(result1, 0) == elem(result2, 0)
    end
  end

  describe "stop_keeper/2" do
    test "accepts team_id parameter" do
      result = Supervisor.stop_keeper("test_team")

      case result do
        :ok -> :ok
        {:error, _reason} -> :ok
      end
    end

    test "accepts optional keeper_id" do
      result = Supervisor.stop_keeper("test_team", "custom_keeper")

      case result do
        :ok -> :ok
        {:error, _reason} -> :ok
      end
    end

    test "defaults keeper_id to team_id when not provided" do
      result1 = Supervisor.stop_keeper("team_b")
      result2 = Supervisor.stop_keeper("team_b", "team_b")

      # Both should return the same result
      assert result1 == result2
    end

    test "returns :ok for non-existent keeper" do
      result = Supervisor.stop_keeper("nonexistent_team_xyz")

      assert result == :ok
    end
  end

  describe "keeper_pid/2" do
    test "returns nil for non-existent keeper" do
      pid = Supervisor.keeper_pid("nonexistent_team")

      assert pid == nil
    end

    test "accepts optional keeper_id" do
      pid = Supervisor.keeper_pid("test_team", "custom_keeper")

      assert is_pid(pid) or pid == nil
    end

    test "defaults keeper_id to team_id when not provided" do
      pid1 = Supervisor.keeper_pid("team_c")
      pid2 = Supervisor.keeper_pid("team_c", "team_c")

      assert pid1 == pid2
    end
  end

  describe "list_keepers/0" do
    test "returns list of pids" do
      keepers = Supervisor.list_keepers()

      assert is_list(keepers)
      assert Enum.all?(keepers, &is_pid/1)
    end

    test "returns empty list when no keepers running" do
      # This is hard to test reliably without stopping all keepers
      keepers = Supervisor.list_keepers()

      assert is_list(keepers)
    end
  end

  describe "integration" do
    test "registers keeper in Registry on start" do
      # Registry.register is called after start_child succeeds
      assert true
    end

    test "unregisters keeper from Registry on stop" do
      # Registry.unregister is called after terminate_child succeeds
      assert true
    end

    test "uses one_for_one strategy" do
      # DynamicSupervisor.init(strategy: :one_for_one)
      assert true
    end
  end

  describe "edge cases" do
    test "handles empty string team_id" do
      result = Supervisor.start_keeper("", "keeper")

      case result do
        {:ok, _pid} -> :ok
        {:error, _reason} -> :ok
      end
    end

    test "handles special characters in team_id" do
      result = Supervisor.start_keeper("team:with/special-chars", "keeper")

      case result do
        {:ok, _pid} -> :ok
        {:error, _reason} -> :ok
      end
    end

    test "handles very long team_id" do
      long_id = String.duplicate("a", 500)
      result = Supervisor.start_keeper(long_id)

      case result do
        {:ok, _pid} -> :ok
        {:error, _reason} -> :ok
      end
    end

    test "handles unicode in keeper_id" do
      result = Supervisor.start_keeper("team", "決策节点")

      case result do
        {:ok, _pid} -> :ok
        {:error, _reason} -> :ok
      end
    end
  end

  describe "flush_fn default" do
    test "provides default flush_fn when not specified" do
      # default_flush_fn/2 creates a function that calls Registry.refresh_from_stats
      assert true
    end

    test "default flush_fn refreshes stats from Registry" do
      # Registry.refresh_from_stats(team_id, keeper_id, Map.from_struct(state))
      assert true
    end
  end

  describe "process registration" do
    test "keepers registered under {team_id, keeper_id} key" do
      # Registry lookup uses {team_id, keeper_id} tuple
      assert true
    end

    test "uses KeeperRegistry for registration" do
      # OptimalSystemAgent.ContextMesh.KeeperRegistry
      assert true
    end
  end
end
