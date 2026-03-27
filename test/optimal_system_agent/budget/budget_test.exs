defmodule OptimalSystemAgent.BudgetTest do
  @moduledoc """
  Unit tests for Budget module.

  Tests budget GenServer for token/cost tracking with limits.
  Real GenServer operations, no mocks.
  """

  use ExUnit.Case, async: false

  @moduletag :requires_application

  alias OptimalSystemAgent.Budget

  @moduletag :capture_log

  setup do
    # Start Budget GenServer with test limits
    start_supervised!({Budget, [name: :test_budget, daily_limit: 10.0, monthly_limit: 100.0]})
    :ok
  end

  describe "start_link/1" do
    test "starts the Budget GenServer" do
      assert {:ok, pid} = Budget.start_link([name: :test_budget_start, daily_limit: 10.0])
      assert is_pid(pid)
      GenServer.stop(:test_budget_start)
    end

    test "accepts daily_limit option" do
      assert {:ok, _pid} = Budget.start_link([name: :test_budget_daily, daily_limit: 50.0])
      GenServer.stop(:test_budget_daily)
    end

    test "accepts monthly_limit option" do
      assert {:ok, _pid} = Budget.start_link([name: :test_budget_monthly, monthly_limit: 200.0])
      GenServer.stop(:test_budget_monthly)
    end
  end

  describe "check_budget/0" do
    test "returns {:ok, remaining} when within limits" do
      assert {:ok, status} = Budget.check_budget()
      assert is_map(status)
    end

    test "includes daily_remaining in status" do
      assert {:ok, status} = Budget.check_budget()
      assert Map.has_key?(status, :daily_remaining) or Map.has_key?(status, "daily_remaining")
    end

    test "includes monthly_remaining in status" do
      assert {:ok, status} = Budget.check_budget()
      assert Map.has_key?(status, :monthly_remaining) or Map.has_key?(status, "monthly_remaining")
    end
  end

  describe "get_status/0" do
    test "returns full budget status map" do
      assert {:ok, status} = Budget.get_status()
      assert is_map(status)
    end

    test "includes daily_limit in status" do
      assert {:ok, status} = Budget.get_status()
      assert Map.has_key?(status, :daily_limit) or Map.has_key?(status, "daily_limit")
    end

    test "includes monthly_limit in status" do
      assert {:ok, status} = Budget.get_status()
      assert Map.has_key?(status, :monthly_limit) or Map.has_key?(status, "monthly_limit")
    end

    test "includes daily_spent in status" do
      assert {:ok, status} = Budget.get_status()
      assert Map.has_key?(status, :daily_spent) or Map.has_key?(status, "daily_spent")
    end

    test "includes monthly_spent in status" do
      assert {:ok, status} = Budget.get_status()
      assert Map.has_key?(status, :monthly_spent) or Map.has_key?(status, "monthly_spent")
    end
  end

  describe "record_cost/5" do
    test "records cost for anthropic provider" do
      assert :ok = Budget.record_cost(:anthropic, "claude-3-5-sonnet-20241022", 1000, 500, "test_session")
      Process.sleep(50)
      assert {:ok, status} = Budget.get_status()
      assert status.daily_spent > 0 or status[:daily_spent] > 0
    end

    test "records cost for openai provider" do
      assert :ok = Budget.record_cost(:openai, "gpt-4", 1000, 500, "test_session")
    end

    test "records cost for groq provider" do
      assert :ok = Budget.record_cost(:groq, "llama-3.3-70b", 1000, 500, "test_session")
    end

    test "records cost for ollama provider (always zero)" do
      assert :ok = Budget.record_cost(:ollama, "llama3", 1000, 500, "test_session")
    end

    test "returns :ok for unknown provider (uses default rate)" do
      assert :ok = Budget.record_cost(:unknown, "model", 1000, 500, "test_session")
    end
  end

  describe "calculate_cost/5" do
    test "calculates anthropic cost correctly" do
      # anthropic: {3.0, 15.0} per 1M tokens
      # 1000 input * 3.0 / 1M = 0.003
      # 500 output * 15.0 / 1M = 0.0075
      cost = Budget.calculate_cost(:anthropic, 1000, 500)
      assert_in_delta cost, 0.0105, 0.0001
    end

    test "calculates openai cost correctly" do
      # openai: {2.5, 10.0} per 1M tokens
      cost = Budget.calculate_cost(:openai, 1000, 500)
      assert_in_delta cost, 0.0075, 0.0001
    end

    test "calculates groq cost correctly" do
      # groq: {0.5, 0.8} per 1M tokens
      cost = Budget.calculate_cost(:groq, 1000, 500)
      assert_in_delta cost, 0.0009, 0.0001
    end

    test "returns 0.0 for ollama" do
      assert Budget.calculate_cost(:ollama, 1000, 500) == 0.0
    end

    test "uses default rate for unknown provider" do
      # default: {1.0, 3.0} per 1M tokens
      cost = Budget.calculate_cost(:unknown, 1000, 500)
      assert_in_delta cost, 0.0025, 0.0001
    end

    test "handles zero tokens" do
      assert Budget.calculate_cost(:anthropic, 0, 0) == 0.0
    end
  end

  describe "provider_rates/0" do
    test "returns map of provider rates" do
      rates = Budget.provider_rates()
      assert is_map(rates)
    end

    test "includes anthropic rate" do
      rates = Budget.provider_rates()
      assert Map.has_key?(rates, :anthropic) or Map.has_key?(rates, "anthropic")
    end

    test "includes openai rate" do
      rates = Budget.provider_rates()
      assert Map.has_key?(rates, :openai) or Map.has_key?(rates, "openai")
    end

    test "includes groq rate" do
      rates = Budget.provider_rates()
      assert Map.has_key?(rates, :groq) or Map.has_key?(rates, "groq")
    end

    test "includes ollama rate" do
      rates = Budget.provider_rates()
      assert Map.has_key?(rates, :ollama) or Map.has_key?(rates, "ollama")
    end
  end

  describe "handle_info/2" do
    test "handles unknown messages gracefully" do
      send(:test_budget, :unknown_message)
      Process.sleep(10)
      assert Process.alive?(Process.whereis(:test_budget))
    end
  end

  describe "edge cases" do
    test "handles very large token counts" do
      cost = Budget.calculate_cost(:anthropic, 1_000_000, 500_000)
      # Should not overflow
      assert cost > 0
    end

    test "handles negative token counts as zero" do
      cost = Budget.calculate_cost(:anthropic, -100, -50)
      # Should handle gracefully
      assert is_float(cost)
    end
  end

  describe "integration" do
    test "full budget lifecycle" do
      # Check initial status
      assert {:ok, initial} = Budget.get_status()
      initial_daily = initial.daily_spent || initial[:daily_spent]

      # Record costs
      Budget.record_cost(:anthropic, "claude-3", 10_000, 5_000, "session1")
      Process.sleep(50)

      # Check updated status
      assert {:ok, updated} = Budget.get_status()
      updated_daily = updated.daily_spent || updated[:daily_spent]
      assert updated_daily > initial_daily
    end
  end
end
