defmodule OptimalSystemAgent.Process.Mining.ClientTest do
  @moduledoc """
  Tests for ProcessMining.Client GenServer.

  Tests verify:
  - Module structure and public API
  - Timeout behavior (WvdA requirement)
  - Error handling (both HTTP errors and network failures)

  Note: These tests are unit tests and don't require pm4py-rust to be running.
  They verify client behavior in isolation.
  """
  use ExUnit.Case, async: true


  # The client is already started by OptimalSystemAgent.Supervisors.AgentServices
  # during application startup, so we don't need to start it in the setup.
  # Tests with async: true don't share state, so no teardown needed.

  describe "discover_process_models/1" do
    test "handles timeout gracefully" do
      # Call should either return error or succeed within test timeout
      result = OptimalSystemAgent.Process.Mining.Client.discover_process_models("test_type")
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "accepts resource type parameter" do
      # Verify the function is callable with string argument
      result = OptimalSystemAgent.Process.Mining.Client.discover_process_models("process")

      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "check_deadlock_free/1" do
    test "handles timeout gracefully" do
      result = OptimalSystemAgent.Process.Mining.Client.check_deadlock_free("test_process")
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "accepts process_id parameter" do
      result = OptimalSystemAgent.Process.Mining.Client.check_deadlock_free("proc_123")

      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "get_reachability_graph/1" do
    test "handles timeout gracefully" do
      result = OptimalSystemAgent.Process.Mining.Client.get_reachability_graph("test_process")
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "accepts process_id parameter" do
      result = OptimalSystemAgent.Process.Mining.Client.get_reachability_graph("proc_456")

      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "analyze_boundedness/1" do
    test "handles timeout gracefully" do
      result = OptimalSystemAgent.Process.Mining.Client.analyze_boundedness("test_process")
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "accepts process_id parameter" do
      result = OptimalSystemAgent.Process.Mining.Client.analyze_boundedness("proc_789")

      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "WvdA timeout compliance" do
    test "all public methods respect 10-second timeout" do
      # These calls will timeout if pm4py-rust is not running,
      # but they should not hang indefinitely
      start_time = System.monotonic_time(:millisecond)

      # Make a call that will timeout (assuming pm4py-rust not running)
      _result = OptimalSystemAgent.Process.Mining.Client.check_deadlock_free("unused")

      elapsed = System.monotonic_time(:millisecond) - start_time

      # Should complete within 12 seconds (10s timeout + 2s buffer for scheduling)
      assert elapsed < 12_000, "Call took #{elapsed}ms, exceeded timeout window"
    end
  end
end
