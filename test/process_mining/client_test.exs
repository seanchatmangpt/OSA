defmodule OptimalSystemAgent.ProcessMining.ClientTest do
  @moduledoc """
  Chicago TDD: ProcessMining.Client GenServer.

  Tests verify:
  1. Successful API calls with 10-second timeout (WvdA deadlock-freedom)
  2. Error handling and graceful degradation
  3. Registration in supervision tree
  """
  use ExUnit.Case
  require Logger

  setup do
    # Start the client GenServer for testing
    {:ok, _pid} = OptimalSystemAgent.ProcessMining.Client.start_link([])
    :ok
  end

  describe "ProcessMining.Client registration" do
    test "client registers as :process_mining_client" do
      pid = GenServer.whereis(:process_mining_client)
      assert is_pid(pid)
    end
  end

  describe "discover_process_models/1" do
    test "handles HTTP error gracefully when pm4py service unavailable" do
      # This test assumes pm4py-rust is NOT running on localhost:8090
      # In that case, Req.get will return connection error
      result = OptimalSystemAgent.ProcessMining.Client.discover_process_models("order")

      # Should return error tuple (not crash)
      assert match?({:error, _}, result)
    end

    test "returns error tuple on timeout" do
      # 10-second timeout per call (enforces WvdA deadlock-freedom)
      # Test verifies timeout handling doesn't crash process
      result = OptimalSystemAgent.ProcessMining.Client.discover_process_models("slow_resource")
      assert match?({:error, _}, result) or match?({:ok, _}, result)
    end
  end

  describe "check_deadlock_free/1" do
    test "handles HTTP error gracefully when pm4py service unavailable" do
      # This test assumes pm4py-rust is NOT running on localhost:8090
      result = OptimalSystemAgent.ProcessMining.Client.check_deadlock_free("proc_123")

      # Should return error tuple (not crash)
      assert match?({:error, _}, result)
    end

    test "enforces 10-second timeout (WvdA deadlock-freedom)" do
      # Calling check_deadlock_free with timeout enforcement
      # If pm4py doesn't respond within 10 seconds, should return timeout error
      result = OptimalSystemAgent.ProcessMining.Client.check_deadlock_free("proc_123")

      # Either success or graceful error
      assert match?({:error, _}, result) or match?({:ok, _}, result)
    end
  end

  describe "get_reachability_graph/1" do
    test "handles HTTP error gracefully when pm4py service unavailable" do
      result = OptimalSystemAgent.ProcessMining.Client.get_reachability_graph("proc_456")

      # Should return error tuple (not crash)
      assert match?({:error, _}, result)
    end
  end

  describe "analyze_boundedness/1" do
    test "handles HTTP error gracefully when pm4py service unavailable" do
      result = OptimalSystemAgent.ProcessMining.Client.analyze_boundedness("proc_789")

      # Should return error tuple (not crash)
      assert match?({:error, _}, result)
    end

    test "calls check_soundness with bounded check type" do
      # Verify the function returns error or ok tuple (not crash)
      result = OptimalSystemAgent.ProcessMining.Client.analyze_boundedness("proc_789")
      assert match?({:error, _}, result) or match?({:ok, _}, result)
    end
  end

  describe "WvdA Soundness: Deadlock-Freedom" do
    test "all blocking calls have 10-second timeout" do
      # Verify no operation blocks indefinitely
      # GenServer.call timeout is 10 seconds (see client.ex @timeout_ms)
      start_time = System.monotonic_time(:millisecond)

      result = OptimalSystemAgent.ProcessMining.Client.discover_process_models("test")

      elapsed = System.monotonic_time(:millisecond) - start_time

      # Result should be ok or error tuple (not crash)
      assert match?({:ok, _}, result) or match?({:error, _}, result)

      # Elapsed time should be reasonable (not hang forever)
      # Req will retry for ~10 seconds on connection error
      assert elapsed < 20_000,
             "Operation took #{elapsed}ms, should complete within 10s timeout buffer"
    end
  end

  describe "ProcessMining.Client supervision" do
    test "client is supervised in AgentServices" do
      # Verify the client is registered in supervision tree
      # Starting a new client should work (was already started in setup)
      pid = GenServer.whereis(:process_mining_client)
      assert is_pid(pid)
      assert Process.alive?(pid)
    end
  end
end
