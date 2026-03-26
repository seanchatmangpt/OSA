defmodule OSA.Test.Helpers.BudgetEnforcer do
  @moduledoc """
  Armstrong Budget Constraints Helper.

  Enforces that operations complete within time and memory budgets.
  Prevents unbounded resource consumption and runaway processes.

  ## Usage

      test "operation respects time budget" do
        assert_within_budget(time_ms: 5000, fn ->
          expensive_operation()
        end)
      end

      test "memory usage stays bounded" do
        assert_within_budget(memory_mb: 100, time_ms: 10000, fn ->
          build_large_list()
        end)
      end

      test "operation exceeding budget is caught" do
        assert_raises AssertionError, fn ->
          assert_within_budget(time_ms: 100, fn ->
            :timer.sleep(500)
          end)
        end
      end
  """

  @spec assert_within_budget(keyword, (() -> any)) :: any
  def assert_within_budget(opts, operation) when is_list(opts) and is_function(operation, 0) do
    time_budget_ms = Keyword.get(opts, :time_ms, :infinity)
    memory_budget_mb = Keyword.get(opts, :memory_mb, :infinity)

    start_time = System.monotonic_time(:millisecond)
    start_memory = get_memory_mb()

    result = operation.()

    elapsed_ms = System.monotonic_time(:millisecond) - start_time
    memory_used = get_memory_mb() - start_memory

    if time_budget_ms != :infinity and elapsed_ms > time_budget_ms do
      raise AssertionError,
        message:
          "Operation exceeded time budget: #{elapsed_ms}ms > #{time_budget_ms}ms (tier: #{tier_name(time_budget_ms)})"
    end

    if memory_budget_mb != :infinity and memory_used > memory_budget_mb do
      raise AssertionError,
        message:
          "Operation exceeded memory budget: #{memory_used}mb > #{memory_budget_mb}mb"
    end

    result
  end

  @spec budget_tiers :: map
  def budget_tiers do
    %{
      critical: %{time_ms: 100, memory_mb: 50},
      high: %{time_ms: 500, memory_mb: 200},
      normal: %{time_ms: 5000, memory_mb: 1000},
      low: %{time_ms: 30000, memory_mb: 5000}
    }
  end

  @spec assert_tier_compliant(:critical | :high | :normal | :low, (() -> any)) :: any
  def assert_tier_compliant(tier, operation) when is_atom(tier) and is_function(operation, 0) do
    tiers = budget_tiers()

    unless Map.has_key?(tiers, tier) do
      raise ArgumentError, "Unknown tier: #{inspect(tier)}"
    end

    budget = tiers[tier]
    assert_within_budget(budget, operation)
  end

  defp get_memory_mb do
    case :erlang.memory(:total) do
      memory when is_integer(memory) -> memory / 1_000_000
      _ -> 0
    end
  end

  defp tier_name(ms) when ms <= 100, do: "critical"
  defp tier_name(ms) when ms <= 500, do: "high"
  defp tier_name(ms) when ms <= 5000, do: "normal"
  defp tier_name(_ms), do: "low"
end
