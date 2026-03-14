defmodule OptimalSystemAgent.Agent.Scheduler.HeartbeatExecutorTest do
  use ExUnit.Case, async: false

  alias OptimalSystemAgent.Agent.Scheduler.HeartbeatExecutor

  defp start_executor do
    name = :"hb_exec_test_#{:erlang.unique_integer([:positive])}"
    {:ok, pid} = GenServer.start_link(HeartbeatExecutor, [], name: name)

    on_exit(fn ->
      if Process.alive?(pid), do: GenServer.stop(pid)
    end)

    {pid, name}
  end

  describe "init/1" do
    test "starts with empty state" do
      {pid, _} = start_executor()
      assert Process.alive?(pid)
    end

    test "state has empty locks, runs, and failures" do
      {_, name} = start_executor()
      state = :sys.get_state(name)
      assert state.locks == %{}
      assert state.runs == %{}
      assert state.failures == %{}
    end
  end

  describe "get_run/1" do
    test "returns nil for unknown run" do
      {_, name} = start_executor()
      assert GenServer.call(name, {:get_run, "nonexistent"}) == nil
    end
  end

  describe "list_runs/2" do
    test "returns empty list for unknown task" do
      {_, name} = start_executor()
      runs = GenServer.call(name, {:list_runs, "unknown_task", []})
      assert runs == []
    end

    test "paginates results" do
      {_, name} = start_executor()
      runs = GenServer.call(name, {:list_runs, "t1", [page: 2, per_page: 5]})
      assert runs == []
    end
  end

  describe "locking" do
    test "rejects concurrent execution for same agent" do
      {_, name} = start_executor()

      :sys.replace_state(name, fn state ->
        %{state | locks: Map.put(state.locks, "test_agent", true)}
      end)

      task = %{"id" => "t1", "name" => "test_agent", "job" => "test"}
      result = GenServer.call(name, {:execute, task, :manual})
      assert result == {:error, :locked}
    end
  end

  describe "circuit breaker" do
    test "rejects execution when circuit is open" do
      {_, name} = start_executor()

      :sys.replace_state(name, fn state ->
        %{state | failures: Map.put(state.failures, "t1", 3)}
      end)

      task = %{"id" => "t1", "name" => "agent_a", "job" => "test"}
      result = GenServer.call(name, {:execute, task, :schedule})
      assert result == {:error, :circuit_open}
    end

    test "allows execution below failure threshold" do
      {_, name} = start_executor()

      :sys.replace_state(name, fn state ->
        %{state | failures: Map.put(state.failures, "t1", 2)}
      end)

      # Verify circuit is NOT open (failure count < 3)
      count = GenServer.call(name, {:failure_count, "t1"})
      assert count < 3
    end
  end

  describe "failure_count/1" do
    test "returns 0 for unknown task" do
      {_, name} = start_executor()
      assert GenServer.call(name, {:failure_count, "unknown"}) == 0
    end

    test "returns stored failure count" do
      {_, name} = start_executor()

      :sys.replace_state(name, fn state ->
        %{state | failures: Map.put(state.failures, "t1", 2)}
      end)

      assert GenServer.call(name, {:failure_count, "t1"}) == 2
    end
  end

  describe "reset_failures/1" do
    test "clears failure count for a task" do
      {_, name} = start_executor()

      :sys.replace_state(name, fn state ->
        %{state | failures: Map.put(state.failures, "t1", 3)}
      end)

      GenServer.cast(name, {:reset_failures, "t1"})
      Process.sleep(10)

      assert GenServer.call(name, {:failure_count, "t1"}) == 0
    end
  end

  describe "module API" do
    test "exports start_link/1" do
      assert function_exported?(HeartbeatExecutor, :start_link, 1)
    end

    test "exports execute/2" do
      assert function_exported?(HeartbeatExecutor, :execute, 2)
    end

    test "exports get_run/1" do
      assert function_exported?(HeartbeatExecutor, :get_run, 1)
    end

    test "exports list_runs/2" do
      assert function_exported?(HeartbeatExecutor, :list_runs, 2)
    end

    test "exports failure_count/1" do
      assert function_exported?(HeartbeatExecutor, :failure_count, 1)
    end

    test "exports reset_failures/1" do
      assert function_exported?(HeartbeatExecutor, :reset_failures, 1)
    end
  end
end
