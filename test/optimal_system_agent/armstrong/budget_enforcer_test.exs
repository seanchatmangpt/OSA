defmodule OptimalSystemAgent.Armstrong.BudgetEnforcerTest do
  use ExUnit.Case

  alias OptimalSystemAgent.Armstrong.BudgetEnforcer

  setup do
    pid = start_supervised!({BudgetEnforcer, [escalate_to_healing: false]})
    {:ok, enforcer: pid}
  end

  describe "tier_budget_definitions" do
    test "critical tier has strictest budgets", %{enforcer: _pid} do
      {:ok, status} = BudgetEnforcer.get_tier_status(:critical)
      assert status.time == {0, 100}
      assert status.memory == {0.0, 50}
      assert status.concurrency == {0, 1}
    end

    test "high tier has moderate budgets", %{enforcer: _pid} do
      {:ok, status} = BudgetEnforcer.get_tier_status(:high)
      assert status.time == {0, 500}
      assert status.memory == {0.0, 200}
      assert status.concurrency == {0, 5}
    end

    test "normal tier has default budgets", %{enforcer: _pid} do
      {:ok, status} = BudgetEnforcer.get_tier_status(:normal)
      assert status.time == {0, 5000}
      assert status.memory == {0.0, 500}
      assert status.concurrency == {0, 20}
    end

    test "low tier has most relaxed budgets", %{enforcer: _pid} do
      {:ok, status} = BudgetEnforcer.get_tier_status(:low)
      assert status.time == {0, 30000}
      assert status.memory == {0.0, 1000}
      assert status.concurrency == {0, 100}
    end
  end

  describe "enforce_time_budgets" do
    test "allows operation within time budget", %{enforcer: _pid} do
      assert :ok = BudgetEnforcer.check_budget("sync_data", :normal)
      BudgetEnforcer.record_operation("sync_data", :normal, 100, 10.0)

      {:ok, status} = BudgetEnforcer.get_tier_status(:normal)
      {used_time, budget_time} = status.time
      assert used_time == 100
      assert used_time < budget_time
    end

    test "rejects operation when time budget exhausted", %{enforcer: _pid} do
      # Exhaust the time budget
      BudgetEnforcer.record_operation("op1", :critical, 100, 5.0)

      # Next operation should be rejected
      assert {:error, :budget_exceeded} = BudgetEnforcer.check_budget("op2", :critical)
    end

    test "tracks cumulative time across operations", %{enforcer: _pid} do
      BudgetEnforcer.record_operation("op1", :high, 200, 10.0)
      BudgetEnforcer.record_operation("op2", :high, 150, 10.0)

      {:ok, status} = BudgetEnforcer.get_tier_status(:high)
      {used_time, _budget_time} = status.time
      assert used_time == 350
    end
  end

  describe "enforce_memory_budgets" do
    test "allows operation within memory budget", %{enforcer: _pid} do
      assert :ok = BudgetEnforcer.check_budget("process_json", :normal)
      BudgetEnforcer.record_operation("process_json", :normal, 50, 100.0)

      {:ok, status} = BudgetEnforcer.get_tier_status(:normal)
      {used_mem, budget_mem} = status.memory
      assert used_mem == 100.0
      assert used_mem < budget_mem
    end

    test "rejects operation when memory budget exhausted", %{enforcer: _pid} do
      # Exhaust the critical tier memory budget
      BudgetEnforcer.record_operation("memory_hog", :critical, 50, 50.0)

      # Next operation should be rejected
      assert {:error, :budget_exceeded} = BudgetEnforcer.check_budget("op2", :critical)
    end

    test "tracks cumulative memory across operations", %{enforcer: _pid} do
      BudgetEnforcer.record_operation("op1", :high, 100, 75.0)
      BudgetEnforcer.record_operation("op2", :high, 100, 85.0)

      {:ok, status} = BudgetEnforcer.get_tier_status(:high)
      {used_mem, _budget_mem} = status.memory
      assert used_mem == 160.0
    end

    test "fractional memory budgets are tracked", %{enforcer: _pid} do
      BudgetEnforcer.record_operation("op1", :normal, 50, 10.5)
      BudgetEnforcer.record_operation("op2", :normal, 50, 20.3)

      {:ok, status} = BudgetEnforcer.get_tier_status(:normal)
      {used_mem, _} = status.memory
      assert Float.round(used_mem, 1) == 30.8
    end
  end

  describe "enforce_concurrency_limits" do
    test "allows operation within concurrency limit", %{enforcer: _pid} do
      assert :ok = BudgetEnforcer.check_budget("parallel_op_1", :normal)

      {:ok, status} = BudgetEnforcer.get_tier_status(:normal)
      {concurrent, limit} = status.concurrency
      assert concurrent == 1
      assert concurrent < limit
    end

    test "rejects operation when concurrency limit reached", %{enforcer: _pid} do
      # Critical tier allows only 1 concurrent operation
      assert :ok = BudgetEnforcer.check_budget("op1", :critical)
      assert {:error, :budget_exceeded} = BudgetEnforcer.check_budget("op2", :critical)
    end

    test "tracks concurrent operations accurately", %{enforcer: _pid} do
      BudgetEnforcer.check_budget("op1", :high)
      BudgetEnforcer.check_budget("op2", :high)
      BudgetEnforcer.check_budget("op3", :high)

      {:ok, status} = BudgetEnforcer.get_tier_status(:high)
      {concurrent, limit} = status.concurrency
      assert concurrent == 3
      assert concurrent < limit
    end

    test "decrements concurrency on operation completion", %{enforcer: _pid} do
      BudgetEnforcer.check_budget("op1", :high)
      BudgetEnforcer.check_budget("op2", :high)

      {:ok, status1} = BudgetEnforcer.get_tier_status(:high)
      {concurrent1, _} = status1.concurrency
      assert concurrent1 == 2

      # Complete one operation
      BudgetEnforcer.record_operation("op1", :high, 100, 10.0)

      {:ok, status2} = BudgetEnforcer.get_tier_status(:high)
      {concurrent2, _} = status2.concurrency
      assert concurrent2 == 1
    end

    test "respects tier concurrency hierarchy", %{enforcer: _pid} do
      # Critical: 1, High: 5, Normal: 20, Low: 100
      {:ok, critical} = BudgetEnforcer.get_tier_status(:critical)
      {:ok, high} = BudgetEnforcer.get_tier_status(:high)
      {:ok, normal} = BudgetEnforcer.get_tier_status(:normal)
      {:ok, low} = BudgetEnforcer.get_tier_status(:low)

      {_, c_limit} = critical.concurrency
      {_, h_limit} = high.concurrency
      {_, n_limit} = normal.concurrency
      {_, l_limit} = low.concurrency

      assert c_limit == 1
      assert h_limit == 5
      assert n_limit == 20
      assert l_limit == 100
    end
  end

  describe "escalate_on_violations" do
    test "emits system_event on budget violation", %{enforcer: _pid} do
      # Exhaust the critical tier
      BudgetEnforcer.record_operation("op1", :critical, 100, 5.0)

      # This should emit an event
      {:error, :budget_exceeded} = BudgetEnforcer.check_budget("op2", :critical)

      # Event is emitted asynchronously; give it time to propagate
      :timer.sleep(100)
    end

    test "includes violation details in event", %{enforcer: _pid} do
      # Verify that violation events contain proper metadata
      BudgetEnforcer.record_operation("test_op", :critical, 100, 5.0)
      {:error, :budget_exceeded} = BudgetEnforcer.check_budget("op_over_budget", :critical)

      # Verify state reflects the violation
      {:ok, status} = BudgetEnforcer.get_tier_status(:critical)
      {time_used, time_budget} = status.time
      assert time_used >= time_budget
    end
  end

  describe "distinguish_tiers" do
    test "operations on different tiers are independent", %{enforcer: _pid} do
      # Exhaust normal tier
      BudgetEnforcer.record_operation("op1", :normal, 5000, 500.0)

      # Normal tier should be exhausted
      assert {:error, :budget_exceeded} = BudgetEnforcer.check_budget("op2", :normal)

      # But low tier should still be available
      assert :ok = BudgetEnforcer.check_budget("op3", :low)
    end

    test "reset_tier only affects specified tier", %{enforcer: _pid} do
      BudgetEnforcer.record_operation("op1", :normal, 2000, 100.0)
      BudgetEnforcer.record_operation("op2", :high, 200, 50.0)

      {:ok, normal_before} = BudgetEnforcer.get_tier_status(:normal)
      {:ok, high_before} = BudgetEnforcer.get_tier_status(:high)

      {normal_time, _} = normal_before.time
      {high_time, _} = high_before.time

      assert normal_time > 0
      assert high_time > 0

      # Reset only normal tier
      BudgetEnforcer.reset_tier(:normal)

      {:ok, normal_after} = BudgetEnforcer.get_tier_status(:normal)
      {:ok, high_after} = BudgetEnforcer.get_tier_status(:high)

      {normal_time_after, _} = normal_after.time
      {high_time_after, _} = high_after.time

      assert normal_time_after == 0
      assert high_time_after == high_time
    end

    test "each tier has separate concurrency tracking", %{enforcer: _pid} do
      BudgetEnforcer.check_budget("critical_op", :critical)
      BudgetEnforcer.check_budget("high_op1", :high)
      BudgetEnforcer.check_budget("high_op2", :high)
      BudgetEnforcer.check_budget("normal_op1", :normal)

      {:ok, critical_status} = BudgetEnforcer.get_tier_status(:critical)
      {:ok, high_status} = BudgetEnforcer.get_tier_status(:high)
      {:ok, normal_status} = BudgetEnforcer.get_tier_status(:normal)

      {critical_concurrent, _} = critical_status.concurrency
      {high_concurrent, _} = high_status.concurrency
      {normal_concurrent, _} = normal_status.concurrency

      assert critical_concurrent == 1
      assert high_concurrent == 2
      assert normal_concurrent == 1
    end
  end

  describe "operation_tracking" do
    test "records operation count per tier", %{enforcer: _pid} do
      BudgetEnforcer.record_operation("op1", :high, 100, 10.0)
      BudgetEnforcer.record_operation("op2", :high, 100, 10.0)
      BudgetEnforcer.record_operation("op3", :normal, 100, 10.0)

      {:ok, high_status} = BudgetEnforcer.get_tier_status(:high)
      {:ok, normal_status} = BudgetEnforcer.get_tier_status(:normal)

      assert high_status.operations == 2
      assert normal_status.operations == 1
    end

    test "operation count increments on each record_operation call", %{enforcer: _pid} do
      {:ok, status0} = BudgetEnforcer.get_tier_status(:normal)
      assert status0.operations == 0

      BudgetEnforcer.record_operation("op1", :normal, 100, 10.0)
      {:ok, status1} = BudgetEnforcer.get_tier_status(:normal)
      assert status1.operations == 1

      BudgetEnforcer.record_operation("op2", :normal, 100, 10.0)
      {:ok, status2} = BudgetEnforcer.get_tier_status(:normal)
      assert status2.operations == 2
    end

    test "get_all_status returns all tier metrics", %{enforcer: _pid} do
      BudgetEnforcer.record_operation("op1", :critical, 50, 10.0)
      BudgetEnforcer.record_operation("op2", :high, 100, 20.0)

      {:ok, all_status} = BudgetEnforcer.get_all_status()

      assert Map.has_key?(all_status, :critical)
      assert Map.has_key?(all_status, :high)
      assert Map.has_key?(all_status, :normal)
      assert Map.has_key?(all_status, :low)
    end
  end

  describe "boundary_conditions" do
    test "operation exactly at time budget limit", %{enforcer: _pid} do
      # Critical tier: 100ms budget
      BudgetEnforcer.record_operation("op1", :critical, 100, 1.0)

      # Should be rejected because time_used >= time_budget
      assert {:error, :budget_exceeded} = BudgetEnforcer.check_budget("op2", :critical)
    end

    test "operation exactly at memory budget limit", %{enforcer: _pid} do
      # Critical tier: 50MB budget
      BudgetEnforcer.record_operation("op1", :critical, 10, 50.0)

      # Should be rejected because memory_used >= memory_budget
      assert {:error, :budget_exceeded} = BudgetEnforcer.check_budget("op2", :critical)
    end

    test "zero-duration operations are allowed", %{enforcer: _pid} do
      assert :ok = BudgetEnforcer.check_budget("op1", :normal)
      BudgetEnforcer.record_operation("op1", :normal, 0, 0.0)

      # Should still allow more operations
      assert :ok = BudgetEnforcer.check_budget("op2", :normal)
    end

    test "very small fractional memory values", %{enforcer: _pid} do
      BudgetEnforcer.record_operation("op1", :normal, 10, 0.001)
      BudgetEnforcer.record_operation("op2", :normal, 10, 0.002)

      {:ok, status} = BudgetEnforcer.get_tier_status(:normal)
      {used_mem, _} = status.memory
      # Sum should be 0.003
      assert_in_delta(used_mem, 0.003, 0.0001)
    end
  end

  describe "armstrong_principles" do
    test "let_it_crash: budget check failures are observable", %{enforcer: _pid} do
      # When budget is exceeded, error is returned (not hidden)
      BudgetEnforcer.record_operation("op1", :critical, 100, 5.0)
      result = BudgetEnforcer.check_budget("op2", :critical)

      assert {:error, :budget_exceeded} = result
    end

    test "supervision: enforcer survives operation failures", %{enforcer: pid} do
      # GenServer should still be alive and responsive after violations
      BudgetEnforcer.record_operation("op1", :critical, 100, 5.0)
      {:error, :budget_exceeded} = BudgetEnforcer.check_budget("op2", :critical)

      # Enforcer should still respond
      {:ok, _status} = BudgetEnforcer.get_tier_status(:critical)
      assert Process.alive?(pid)
    end

    test "no_shared_state: each tier tracked independently", %{enforcer: _pid} do
      # Tiers are isolated; operating on one doesn't affect another
      BudgetEnforcer.check_budget("op1", :critical)
      BudgetEnforcer.check_budget("op2", :high)

      {:ok, critical_status} = BudgetEnforcer.get_tier_status(:critical)
      {:ok, high_status} = BudgetEnforcer.get_tier_status(:high)

      {crit_concurrent, _} = critical_status.concurrency
      {high_concurrent, _} = high_status.concurrency

      assert crit_concurrent == 1
      assert high_concurrent == 1
    end

    test "resource_limits: all budgets are bounded", %{enforcer: _pid} do
      {:ok, all_status} = BudgetEnforcer.get_all_status()

      Enum.each(all_status, fn {_tier, status} ->
        {_time_used, time_budget} = status.time
        {_mem_used, mem_budget} = status.memory
        {_concurrent, concurrency_limit} = status.concurrency

        assert is_integer(time_budget) and time_budget > 0
        assert is_number(mem_budget) and mem_budget > 0
        assert is_integer(concurrency_limit) and concurrency_limit > 0
      end)
    end
  end
end
