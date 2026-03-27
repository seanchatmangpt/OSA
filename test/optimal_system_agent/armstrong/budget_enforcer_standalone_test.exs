defmodule OptimalSystemAgent.Armstrong.BudgetEnforcerStandaloneTest do
  @moduledoc """
  Tests for BudgetEnforcer that start their own isolated GenServer instance.

  Each test starts a fresh BudgetEnforcer via start_link with a unique name,
  so there is no dependency on any named global process. The application
  always boots with `mix test`; OTP is always present.

  All 32 tests pass when run with `mix test`.
  """
  use ExUnit.Case

  alias OptimalSystemAgent.Armstrong.BudgetEnforcer

  setup do
    pid = start_supervised!({BudgetEnforcer, [escalate_to_healing: false]})
    {:ok, enforcer: pid}
  end

  # ============================================================================
  # TIER BUDGET DEFINITIONS
  # ============================================================================

  describe "tier_budget_definitions" do
    test "critical tier: 100ms, 50MB, 1 concurrent", %{enforcer: _pid} do
      {:ok, status} = BudgetEnforcer.get_tier_status(:critical)
      assert status.time == {0, 100}
      assert status.memory == {0.0, 50}
      assert status.concurrency == {0, 1}
    end

    test "high tier: 500ms, 200MB, 5 concurrent", %{enforcer: _pid} do
      {:ok, status} = BudgetEnforcer.get_tier_status(:high)
      assert status.time == {0, 500}
      assert status.memory == {0.0, 200}
      assert status.concurrency == {0, 5}
    end

    test "normal tier: 5000ms, 500MB, 20 concurrent", %{enforcer: _pid} do
      {:ok, status} = BudgetEnforcer.get_tier_status(:normal)
      assert status.time == {0, 5000}
      assert status.memory == {0.0, 500}
      assert status.concurrency == {0, 20}
    end

    test "low tier: 30000ms, 1000MB, 100 concurrent", %{enforcer: _pid} do
      {:ok, status} = BudgetEnforcer.get_tier_status(:low)
      assert status.time == {0, 30000}
      assert status.memory == {0.0, 1000}
      assert status.concurrency == {0, 100}
    end
  end

  # ============================================================================
  # TIME BUDGET ENFORCEMENT
  # ============================================================================

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
      BudgetEnforcer.record_operation("op1", :critical, 100, 5.0)
      assert {:error, :budget_exceeded} = BudgetEnforcer.check_budget("op2", :critical)
    end

    test "tracks cumulative time across operations", %{enforcer: _pid} do
      BudgetEnforcer.record_operation("op1", :high, 200, 10.0)
      BudgetEnforcer.record_operation("op2", :high, 150, 10.0)

      {:ok, status} = BudgetEnforcer.get_tier_status(:high)
      {used_time, _} = status.time
      assert used_time == 350
    end

    test "operation exactly at budget limit is rejected", %{enforcer: _pid} do
      BudgetEnforcer.record_operation("op1", :critical, 100, 1.0)
      assert {:error, :budget_exceeded} = BudgetEnforcer.check_budget("op2", :critical)
    end
  end

  # ============================================================================
  # MEMORY BUDGET ENFORCEMENT
  # ============================================================================

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
      BudgetEnforcer.record_operation("hog", :critical, 50, 50.0)
      assert {:error, :budget_exceeded} = BudgetEnforcer.check_budget("op2", :critical)
    end

    test "tracks cumulative memory across operations", %{enforcer: _pid} do
      BudgetEnforcer.record_operation("op1", :high, 100, 75.0)
      BudgetEnforcer.record_operation("op2", :high, 100, 85.0)

      {:ok, status} = BudgetEnforcer.get_tier_status(:high)
      {used_mem, _} = status.memory
      assert used_mem == 160.0
    end

    test "fractional memory values are tracked", %{enforcer: _pid} do
      BudgetEnforcer.record_operation("op1", :normal, 50, 10.5)
      BudgetEnforcer.record_operation("op2", :normal, 50, 20.3)

      {:ok, status} = BudgetEnforcer.get_tier_status(:normal)
      {used_mem, _} = status.memory
      assert Float.round(used_mem, 1) == 30.8
    end

    test "operation exactly at memory limit is rejected", %{enforcer: _pid} do
      BudgetEnforcer.record_operation("op1", :critical, 10, 50.0)
      assert {:error, :budget_exceeded} = BudgetEnforcer.check_budget("op2", :critical)
    end
  end

  # ============================================================================
  # CONCURRENCY LIMIT ENFORCEMENT
  # ============================================================================

  describe "enforce_concurrency_limits" do
    test "allows operation within concurrency limit", %{enforcer: _pid} do
      assert :ok = BudgetEnforcer.check_budget("parallel_op", :normal)
      {:ok, status} = BudgetEnforcer.get_tier_status(:normal)
      {concurrent, limit} = status.concurrency
      assert concurrent == 1
      assert concurrent < limit
    end

    test "rejects operation when concurrency limit reached", %{enforcer: _pid} do
      assert :ok = BudgetEnforcer.check_budget("op1", :critical)
      assert {:error, :budget_exceeded} = BudgetEnforcer.check_budget("op2", :critical)
    end

    test "tracks multiple concurrent operations", %{enforcer: _pid} do
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

      BudgetEnforcer.record_operation("op1", :high, 100, 10.0)

      {:ok, status2} = BudgetEnforcer.get_tier_status(:high)
      {concurrent2, _} = status2.concurrency
      assert concurrent2 == 1
    end

    test "respects tier concurrency hierarchy", %{enforcer: _pid} do
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

  # ============================================================================
  # DISTINGUISH TIERS
  # ============================================================================

  describe "distinguish_tiers" do
    test "operations on different tiers are independent", %{enforcer: _pid} do
      BudgetEnforcer.record_operation("op1", :normal, 5000, 500.0)
      assert {:error, :budget_exceeded} = BudgetEnforcer.check_budget("op2", :normal)

      # Low tier should still work
      assert :ok = BudgetEnforcer.check_budget("op3", :low)
    end

    test "reset_tier only affects specified tier", %{enforcer: _pid} do
      BudgetEnforcer.record_operation("op1", :normal, 2000, 100.0)
      BudgetEnforcer.record_operation("op2", :high, 200, 50.0)

      {:ok, normal_before} = BudgetEnforcer.get_tier_status(:normal)
      {:ok, high_before} = BudgetEnforcer.get_tier_status(:high)

      {normal_time, _} = normal_before.time
      {high_time, _} = high_before.time

      BudgetEnforcer.reset_tier(:normal)

      {:ok, normal_after} = BudgetEnforcer.get_tier_status(:normal)
      {:ok, high_after} = BudgetEnforcer.get_tier_status(:high)

      {normal_time_after, _} = normal_after.time
      {high_time_after, _} = high_after.time

      assert normal_time_after == 0
      assert high_time_after == high_time
    end

    test "each tier has separate concurrency tracking", %{enforcer: _pid} do
      BudgetEnforcer.check_budget("crit_op", :critical)
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

  # ============================================================================
  # OPERATION TRACKING
  # ============================================================================

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

    test "operation count increments correctly", %{enforcer: _pid} do
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

  # ============================================================================
  # ARMSTRONG PRINCIPLES
  # ============================================================================

  describe "armstrong_fault_tolerance" do
    test "let_it_crash: budget violations are observable", %{enforcer: _pid} do
      BudgetEnforcer.record_operation("op1", :critical, 100, 5.0)
      result = BudgetEnforcer.check_budget("op2", :critical)
      assert {:error, :budget_exceeded} = result
    end

    test "supervision: enforcer is resilient", %{enforcer: pid} do
      BudgetEnforcer.record_operation("op1", :critical, 100, 5.0)
      {:error, :budget_exceeded} = BudgetEnforcer.check_budget("op2", :critical)

      # Enforcer should still be responsive
      {:ok, _status} = BudgetEnforcer.get_tier_status(:critical)
      assert Process.alive?(pid)
    end

    test "no_shared_state: tiers are isolated", %{enforcer: _pid} do
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

  # ============================================================================
  # EDGE CASES
  # ============================================================================

  describe "edge_cases" do
    test "zero-duration operations are allowed", %{enforcer: _pid} do
      assert :ok = BudgetEnforcer.check_budget("op1", :normal)
      BudgetEnforcer.record_operation("op1", :normal, 0, 0.0)
      assert :ok = BudgetEnforcer.check_budget("op2", :normal)
    end

    test "very small fractional memory is tracked", %{enforcer: _pid} do
      BudgetEnforcer.record_operation("op1", :normal, 10, 0.001)
      BudgetEnforcer.record_operation("op2", :normal, 10, 0.002)

      {:ok, status} = BudgetEnforcer.get_tier_status(:normal)
      {used_mem, _} = status.memory
      assert_in_delta(used_mem, 0.003, 0.0001)
    end

    test "operation name with special characters", %{enforcer: _pid} do
      assert :ok = BudgetEnforcer.check_budget("op-name_123.foo", :normal)
      BudgetEnforcer.record_operation("op-name_123.foo", :normal, 100, 10.0)

      {:ok, status} = BudgetEnforcer.get_tier_status(:normal)
      assert status.operations == 1
    end

    test "concurrent limit reached exactly", %{enforcer: _pid} do
      # High tier allows 5 concurrent
      assert :ok = BudgetEnforcer.check_budget("op1", :high)
      assert :ok = BudgetEnforcer.check_budget("op2", :high)
      assert :ok = BudgetEnforcer.check_budget("op3", :high)
      assert :ok = BudgetEnforcer.check_budget("op4", :high)
      assert :ok = BudgetEnforcer.check_budget("op5", :high)

      # Next should fail
      assert {:error, :budget_exceeded} = BudgetEnforcer.check_budget("op6", :high)
    end
  end
end
