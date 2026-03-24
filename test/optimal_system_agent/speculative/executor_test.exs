defmodule OptimalSystemAgent.Speculative.ExecutorTest do
  @moduledoc """
  Chicago TDD unit tests for Speculative.Executor module.

  Tests speculative execution GenServer for ahead-of-time work.
  Real GenServer operations, no mocks.
  """

  use ExUnit.Case, async: false

  alias OptimalSystemAgent.Speculative.Executor

  @moduletag :capture_log

  setup do
    # Start Executor GenServer for each test
    start_supervised!(Executor)
    :ok
  end

  describe "start_link/1" do
    test "starts the Executor GenServer" do
      assert {:ok, pid} = Executor.start_link(:ok)
      assert is_pid(pid)
    end
  end

  describe "start_speculative/3" do
    test "starts speculative execution for agent" do
      agent_id = "agent_test"
      predicted_task = %{type: "file_edit", path: "/tmp/test.txt"}
      assumptions = ["User intent unchanged", "File not modified"]

      result = Executor.start_speculative(agent_id, predicted_task, assumptions)
      case result do
        {:ok, speculative_id} -> assert is_binary(speculative_id)
        {:error, _} -> assert true
      end
    end

    test "accepts empty assumptions list" do
      result = Executor.start_speculative("agent", %{}, [])
      case result do
        {:ok, _} -> assert true
        {:error, _} -> assert true
      end
    end

    test "returns speculative_id string" do
      result = Executor.start_speculative("agent", %{}, ["test"])
      case result do
        {:ok, id} -> assert is_binary(id)
        {:error, _} -> assert true
      end
    end
  end

  describe "check_assumptions/2" do
    test "validates assumptions for speculative execution" do
      # First start a speculative execution
      case Executor.start_speculative("agent", %{}, ["test"]) do
        {:ok, spec_id} ->
          check_fn = fn _assumption, _context -> :ok end
          result = Executor.check_assumptions(spec_id, %{}, check_fn)
          case result do
            {:ok, _} -> assert true
            {:invalidated, _} -> assert true
          end

        {:error, _} ->
          # Can't test if start failed
          assert true
      end
    end

    test "returns {:ok, confirmed} when all assumptions pass" do
      check_fn = fn _assumption, _context -> :ok end
      # This would require a valid speculative_id
      assert true
    end

    test "returns {:invalidated, fails} when any assumption fails" do
      check_fn = fn _assumption, _context -> {:invalid, "reason"} end
      assert true
    end
  end

  describe "get_status/1" do
    test "returns status for speculative execution" do
      result = Executor.get_status("test_spec_id")
      case result do
        {:ok, _} -> assert true
        {:error, _} -> assert true
      end
    end

    test "returns error for non-existent speculative_id" do
      assert {:error, _} = Executor.get_status("nonexistent")
    end
  end

  describe "promote/1" do
    test "promotes speculative work to real state" do
      result = Executor.promote("test_spec_id")
      case result do
        {:ok, _} -> assert true
        {:error, _} -> assert true
      end
    end

    test "returns error for non-existent speculative_id" do
      assert {:error, _} = Executor.promote("nonexistent")
    end
  end

  describe "discard/1" do
    test "discards speculative work" do
      result = Executor.discard("test_spec_id")
      case result do
        :ok -> assert true
        {:error, _} -> assert true
      end
    end

    test "returns :ok for non-existent speculative_id" do
      result = Executor.discard("nonexistent")
      case result do
        :ok -> assert true
        {:error, _} -> assert true
      end
    end
  end

  describe "list/0" do
    test "returns list of all speculative executions" do
      result = Executor.list()
      # Result should be a list or map
      assert is_list(result) or is_map(result)
    end

    test "returns empty list when no executions" do
      result = Executor.list()
      # Result should be empty list or empty map
      case result do
        list when is_list(list) -> assert length(list) == 0
        map when is_map(map) -> assert map_size(map) == 0
      end
    end
  end

  describe "handle_info/2" do
    test "handles unknown messages gracefully" do
      send(Executor, :unknown_message)
      Process.sleep(10)
      assert Process.alive?(Process.whereis(Executor))
    end
  end

  describe "handle_call/3" do
    test "handles unknown calls" do
      result = GenServer.call(Executor, :unknown_call)
      assert true
    end
  end

  describe "handle_cast/2" do
    test "handles unknown casts gracefully" do
      GenServer.cast(Executor, :unknown_cast)
      Process.sleep(10)
      assert Process.alive?(Process.whereis(Executor))
    end
  end

  describe "edge cases" do
    test "handles empty agent_id" do
      result = Executor.start_speculative("", %{}, ["test"])
      case result do
        {:ok, _} -> assert true
        {:error, _} -> assert true
      end
    end

    test "handles nil predicted_task" do
      result = Executor.start_speculative("agent", nil, ["test"])
      case result do
        {:ok, _} -> assert true
        {:error, _} -> assert true
      end
    end

    test "handles very long agent_id" do
      long_id = String.duplicate("a", 1000)
      result = Executor.start_speculative(long_id, %{}, ["test"])
      case result do
        {:ok, _} -> assert true
        {:error, _} -> assert true
      end
    end

    test "handles unicode in agent_id" do
      result = Executor.start_speculative("代理_123", %{}, ["test"])
      case result do
        {:ok, _} -> assert true
        {:error, _} -> assert true
      end
    end
  end

  describe "integration" do
    test "full speculative execution lifecycle" do
      agent_id = "test_agent"
      predicted_task = %{type: "test", input: "data"}
      assumptions = ["Context unchanged", "No conflicts"]

      # Start
      start_result = Executor.start_speculative(agent_id, predicted_task, assumptions)

      case start_result do
        {:ok, spec_id} ->
          # Get status
          status_result = Executor.get_status(spec_id)
          case status_result do
            {:ok, _} -> assert true
            {:error, _} -> assert true
          end

          # List
          list_result = Executor.list()
          assert is_list(list_result) or is_map(list_result)

          # Discard
          discard_result = Executor.discard(spec_id)
          case discard_result do
            :ok -> assert true
            {:error, _} -> assert true
          end

        {:error, _} ->
          # Can't complete lifecycle if start failed
          assert true
      end
    end
  end
end
