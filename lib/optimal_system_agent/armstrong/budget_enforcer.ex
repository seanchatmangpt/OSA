defmodule OptimalSystemAgent.Armstrong.BudgetEnforcer do
  @moduledoc """
  Budget Enforcer Agent — enforces operation budgets per tier.

  Implements Armstrong Fault Tolerance principles with budget constraints.
  Tracks time (ms), memory (MB), and concurrency budgets per tier.

  ## Tier Hierarchy

  | Tier | Time Budget | Memory Budget | Concurrent Ops |
  |------|-------------|---------------|----------------|
  | `:critical` | 100ms | 50MB | 1 |
  | `:high` | 500ms | 200MB | 5 |
  | `:normal` | 5000ms | 500MB | 20 |
  | `:low` | 30000ms | 1000MB | 100 |

  ## Public API

  - `start_link(opts)` — GenServer entry point
  - `check_budget(operation_name, tier)` → `:ok` or `{:error, :budget_exceeded}`
  - `record_operation(operation_name, tier, duration_ms, memory_mb)` → `:ok`
  - `get_tier_status(tier)` → `{used_time, budget_time, used_memory, budget_memory}`
  - `reset_tier(tier)` → `:ok` — reset tier metrics

  ## Behavior on Budget Violation

  When a budget is exceeded:
    1. Operation is rejected with `{:error, :budget_exceeded}`
    2. Telemetry event emitted: `Bus.emit(:system_event, %{type: :budget_exceeded, ...})`
    3. Escalation to healing agent (possible resource leak or DoS)

  ## Example Usage

  ```elixir
  # Check if operation is within budget
  case BudgetEnforcer.check_budget("data_sync", :high) do
    :ok ->
      # Proceed with operation
      result = do_work()
      # Record actual usage
      BudgetEnforcer.record_operation("data_sync", :high, 250, 75)
    {:error, :budget_exceeded} ->
      # Handle budget violation (escalate, queue, reject)
      Logger.warn("data_sync exceeded high tier budget")
      {:error, :budget_exceeded}
  end
  ```
  """

  use GenServer
  require Logger

  alias OptimalSystemAgent.Events.Bus

  # ============================================================================
  # Type Definitions
  # ============================================================================

  @type tier :: :critical | :high | :normal | :low
  @type operation_name :: String.t()

  # ============================================================================
  # Public API
  # ============================================================================

  def start_link(opts \\ []) do
    {name, opts} = Keyword.pop(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Check whether an operation is within budget for the given tier.

  Returns:
    - `:ok` — operation may proceed
    - `{:error, :budget_exceeded}` — budget limit reached

  On violation, emits a telemetry event and may escalate to healing.
  """
  @spec check_budget(operation_name, tier) :: :ok | {:error, :budget_exceeded}
  def check_budget(operation_name, tier) do
    GenServer.call(__MODULE__, {:check_budget, operation_name, tier})
  end

  @doc """
  Record the completion of an operation.

  Called after operation finishes to track actual resource consumption.
  Updates tier metrics and may detect resource leaks.
  """
  @spec record_operation(operation_name, tier, non_neg_integer(), float()) :: :ok
  def record_operation(operation_name, tier, duration_ms, memory_mb) do
    GenServer.cast(__MODULE__, {:record_operation, operation_name, tier, duration_ms, memory_mb})
  end

  @doc """
  Return status of a tier: {used_time_ms, budget_time_ms, used_memory_mb, budget_memory_mb}.

  Also includes concurrency metrics: {used_concurrency, budget_concurrency}.
  """
  @spec get_tier_status(tier) ::
          {:ok, %{time: {non_neg_integer(), non_neg_integer()},
                  memory: {float(), float()},
                  concurrency: {non_neg_integer(), non_neg_integer()},
                  operations: non_neg_integer()}}
  def get_tier_status(tier) do
    GenServer.call(__MODULE__, {:get_tier_status, tier})
  end

  @doc """
  Reset metrics for a tier.

  Used for testing or manual metric reset. Should be called carefully in production.
  """
  @spec reset_tier(tier) :: :ok
  def reset_tier(tier) do
    GenServer.cast(__MODULE__, {:reset_tier, tier})
  end

  @doc """
  Return all tier budgets and current usage.
  """
  @spec get_all_status() :: {:ok, map()}
  def get_all_status do
    GenServer.call(__MODULE__, :get_all_status)
  end

  # ============================================================================
  # GenServer Callbacks
  # ============================================================================

  @impl true
  def init(opts) do
    state = %{
      # Tier definitions: {time_budget_ms, memory_budget_mb, concurrency_limit}
      tiers: %{
        critical: {100, 50, 1},
        high: {500, 200, 5},
        normal: {5000, 500, 20},
        low: {30000, 1000, 100}
      },
      # Track per-tier metrics: tier -> {time_used, memory_used, concurrent_ops, operation_count}
      metrics: %{
        critical: {0, 0.0, 0, 0},
        high: {0, 0.0, 0, 0},
        normal: {0, 0.0, 0, 0},
        low: {0, 0.0, 0, 0}
      },
      # Track in-flight operations: operation_id -> {tier, start_time_us}
      in_flight: %{},
      # Config options
      escalate_to_healing: Keyword.get(opts, :escalate_to_healing, true),
      leak_detection_threshold: Keyword.get(opts, :leak_detection_threshold, 0.8)
    }

    Logger.info("[BudgetEnforcer] started with tier limits: #{inspect(state.tiers)}")

    {:ok, state}
  end

  @impl true
  def handle_call({:check_budget, operation_name, tier}, _from, state) do
    case check_tier_budget(tier, state) do
      :ok ->
        # Record that operation is in-flight (increment concurrency)
        new_state = add_in_flight(state, operation_name, tier)
        {:reply, :ok, new_state}

      {:error, :budget_exceeded} ->
        # Emit violation event
        emit_budget_violation(operation_name, tier, state)
        {:reply, {:error, :budget_exceeded}, state}
    end
  end

  @impl true
  def handle_call({:get_tier_status, tier}, _from, state) do
    case Map.fetch(state.metrics, tier) do
      {:ok, {time_used, mem_used, concurrent, op_count}} ->
        {time_budget, mem_budget, concurrency_budget} = Map.fetch!(state.tiers, tier)
        status = %{
          time: {time_used, time_budget},
          memory: {mem_used, mem_budget},
          concurrency: {concurrent, concurrency_budget},
          operations: op_count
        }
        {:reply, {:ok, status}, state}

      :error ->
        {:reply, {:error, :invalid_tier}, state}
    end
  end

  @impl true
  def handle_call(:get_all_status, _from, state) do
    status =
      Enum.reduce(state.tiers, %{}, fn {tier, _}, acc ->
        {:ok, tier_status} = handle_call({:get_tier_status, tier}, nil, state)
        Map.put(acc, tier, tier_status)
      end)

    {:reply, {:ok, status}, state}
  end

  @impl true
  def handle_cast({:record_operation, operation_name, tier, duration_ms, memory_mb}, state) do
    # Remove from in-flight and update metrics
    new_state =
      state
      |> remove_in_flight(operation_name, tier)
      |> update_metrics(tier, duration_ms, memory_mb)

    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:reset_tier, tier}, state) do
    new_metrics = Map.put(state.metrics, tier, {0, 0.0, 0, 0})
    Logger.info("[BudgetEnforcer] Reset metrics for tier #{tier}")
    {:noreply, %{state | metrics: new_metrics}}
  end

  # ============================================================================
  # Private Helpers
  # ============================================================================

  defp check_tier_budget(tier, state) do
    case Map.fetch(state.metrics, tier) do
      {:ok, {time_used, mem_used, concurrent, _}} ->
        {time_budget, mem_budget, concurrency_budget} = Map.fetch!(state.tiers, tier)

        cond do
          time_used >= time_budget ->
            {:error, :budget_exceeded}

          mem_used >= mem_budget ->
            {:error, :budget_exceeded}

          concurrent >= concurrency_budget ->
            {:error, :budget_exceeded}

          true ->
            :ok
        end

      :error ->
        {:error, :invalid_tier}
    end
  end

  defp add_in_flight(state, operation_name, tier) do
    in_flight_key = "#{operation_name}_#{tier}_#{System.monotonic_time(:millisecond)}"
    start_time_us = System.monotonic_time(:microsecond)

    new_in_flight = Map.put(state.in_flight, in_flight_key, {tier, start_time_us})

    # Increment concurrent operation count for the tier
    {time_used, mem_used, concurrent, op_count} = Map.fetch!(state.metrics, tier)
    new_metrics = Map.put(state.metrics, tier, {time_used, mem_used, concurrent + 1, op_count})

    %{state | in_flight: new_in_flight, metrics: new_metrics}
  end

  defp remove_in_flight(state, operation_name, tier) do
    # Find and remove the in-flight entry
    in_flight_key =
      Enum.find(state.in_flight, fn {key, {t, _}} ->
        String.starts_with?(key, "#{operation_name}_#{t}_")
      end)
      |> then(fn
        {key, _} -> key
        nil -> nil
      end)

    if in_flight_key do
      new_in_flight = Map.delete(state.in_flight, in_flight_key)

      # Decrement concurrent operation count
      {time_used, mem_used, concurrent, op_count} = Map.fetch!(state.metrics, tier)
      new_metrics = Map.put(state.metrics, tier, {time_used, mem_used, max(0, concurrent - 1), op_count})

      %{state | in_flight: new_in_flight, metrics: new_metrics}
    else
      state
    end
  end

  defp update_metrics(state, tier, duration_ms, memory_mb) do
    {time_used, mem_used, concurrent, op_count} = Map.fetch!(state.metrics, tier)

    new_metrics =
      Map.put(state.metrics, tier, {
        time_used + duration_ms,
        mem_used + memory_mb,
        concurrent,
        op_count + 1
      })

    %{state | metrics: new_metrics}
  end

  defp emit_budget_violation(operation_name, tier, state) do
    {time_budget, mem_budget, concurrency_budget} = Map.fetch!(state.tiers, tier)
    {time_used, mem_used, concurrent, _} = Map.fetch!(state.metrics, tier)

    event_payload = %{
      type: :budget_exceeded,
      operation: operation_name,
      tier: tier,
      budgets: %{
        time_ms: time_budget,
        memory_mb: mem_budget,
        concurrency: concurrency_budget
      },
      usage: %{
        time_ms: time_used,
        memory_mb: mem_used,
        concurrency: concurrent
      },
      timestamp: DateTime.utc_now()
    }

    # Emit event only if Bus is available
    try do
      Bus.emit(:system_event, event_payload, source: "budget_enforcer")
    rescue
      _ -> :ok
    end

    Logger.warning(
      "[BudgetEnforcer] #{operation_name} exceeded #{tier} tier budget: " <>
        "time #{time_used}/#{time_budget}ms, memory #{mem_used}/#{mem_budget}MB, " <>
        "concurrency #{concurrent}/#{concurrency_budget}"
    )

    if state.escalate_to_healing do
      escalate_to_healing(operation_name, tier, event_payload)
    end
  end

  defp escalate_to_healing(operation_name, tier, event_payload) do
    # Fire-and-forget escalation; doesn't block the caller
    Task.start(fn ->
      Logger.info("[BudgetEnforcer] Escalating #{operation_name} to healing (tier: #{tier})")

      try do
        Bus.emit(:system_event, Map.put(event_payload, :escalated_to_healing, true),
          source: "budget_enforcer"
        )
      rescue
        _ -> :ok
      end
    end)
  end
end
