defmodule OptimalSystemAgent.Errors.WvdAError do
  @moduledoc """
  van der Aalst (WvdA) Soundness Violation errors.

  Every process must be **deadlock-free**, **liveness-guaranteed**, and **bounded**.
  This module provides helpful error messages for violations.

  ## Soundness Properties

  | Property | What | Example |
  |----------|------|---------|
  | **Deadlock Freedom** | No blocking operations without timeout | GenServer.call(pid, msg, 5000) |
  | **Liveness** | All loops have bounded iteration | for i <- 0..maxDepth |
  | **Boundedness** | Queues/caches have size limits | queue: %{size: 1000} |
  """

  defmodule DeadlockViolation do
    @moduledoc """
    Deadlock-free constraint violated: blocking operation without timeout_ms.

    All blocking operations (wait, receive, get) must have explicit timeout_ms
    to prevent indefinite waits.
    """
    defexception [:operation, :location, :message]

    def new(operation, location \\ "", message \\ "") do
      %__MODULE__{
        operation: operation,
        location: location,
        message:
          message ||
            "Deadlock risk: #{operation} without timeout_ms. " <>
              "All blocking ops must have explicit timeout. " <>
              "Fix: GenServer.call(pid, msg, 5000) — add timeout_ms parameter. " <>
              "Location: #{location}"
      }
    end

    def message(error) do
      error.message
    end
  end

  defmodule LivenessViolation do
    @moduledoc """
    Liveness constraint violated: infinite loop or unbounded recursion.

    All loops must have explicit exit conditions or bounded iteration.
    All recursive calls must have max recursion depth.
    """
    defexception [:loop_type, :location, :message]

    def new(loop_type, location \\ "", message \\ "") do
      hint =
        case loop_type do
          :infinite_loop ->
            "Infinite loop detected. Fix: add sleep(100) and exit condition. " <>
              "Example: while attempts < max_attempts do ... end"

          :unbounded_recursion ->
            "Unbounded recursion detected. Fix: add depth limit. " <>
              "Example: def traverse(node, depth \\\ 0) when depth < 1000 do ... end"

          :deadlock_loop ->
            "Loop waiting on condition that never happens. Fix: add timeout. " <>
              "Example: wait_timeout(condition, 5000) instead of wait(condition)"

          _ ->
            "Liveness violation: infinite execution path. Add loop bounds or exit condition."
        end

      %__MODULE__{
        loop_type: loop_type,
        location: location,
        message:
          message || hint <> " Location: #{location}"
      }
    end

    def message(error) do
      error.message
    end
  end

  defmodule BoundednessViolation do
    @moduledoc """
    Boundedness constraint violated: unbounded resource growth.

    All queues, caches, memory structures must have size limits.
    ETS tables must have write_concurrency limits.
    """
    defexception [:resource, :location, :message]

    def new(resource, location \\ "", message \\ "") do
      hint =
        case resource do
          :queue ->
            "Queue unbounded — adds exceed removals. Fix: add max_queue_size. " <>
              "Example: if length(queue) >= 1000 do drop_oldest() end"

          :cache ->
            "Cache unbounded — no TTL or eviction. Fix: add TTL and max_items. " <>
              "Example: :ets.new(:cache, [{:write_concurrency, true}])"

          :memory ->
            "Memory unbounded — list/map grows forever. Fix: add limit checks. " <>
              "Example: if byte_size(data) >= max_bytes do trim() end"

          :connections ->
            "Connection pool unbounded. Fix: add max_connections. " <>
              "Example: DBConnection.Pool with max_overflow: 10"

          _ ->
            "Boundedness violation: resource grows without limit. Add max_size or TTL."
        end

      %__MODULE__{
        resource: resource,
        location: location,
        message:
          message || hint <> " Location: #{location}"
      }
    end

    def message(error) do
      error.message
    end
  end

  # Helper: Hint for common operations
  def hint_for_operation(operation) do
    case operation do
      :genserver_call ->
        "GenServer.call always blocks until reply. Add timeout: " <>
          "GenServer.call(pid, msg, 5000) — default is :infinity (deadlock risk!)"

      :receive ->
        "receive always blocks until message. Add timeout: " <>
          "receive do msg -> ... after 5000 -> escalate() end"

      :task_await ->
        "Task.await blocks until completion. Add timeout: " <>
          "Task.await(task, 5000) instead of Task.await(task)"

      :stream_reduce ->
        "Stream.reduce processes all items. For unbounded streams, add limit: " <>
          "stream |> Stream.take(1000) |> Enum.reduce(...)"

      :ets_select ->
        "ETS select can scan huge tables. Add limit: " <>
          ":ets.select_count(table, spec) first, then paginate"

      _ ->
        "Check documentation for blocking semantics. Add explicit timeout_ms."
    end
  end

  # Helper: Hint for recovery actions
  def recovery_hint(violation_type) do
    case violation_type do
      :deadlock ->
        "Add timeout to all blocking operations. If timeout fires, " <>
          "escalate to supervisor or return error to client."

      :liveness ->
        "Add loop bounds: max_iterations, max_recursion_depth, max_wait_time. " <>
          "Use exponential backoff for retries."

      :boundedness ->
        "Add limits: max_queue_size, max_cache_items, max_memory_mb, max_connections. " <>
          "Monitor actual usage and add alerts."

      _ ->
        "Review code against WvdA soundness checklist. " <>
          "See .claude/rules/wvda-soundness.md"
    end
  end
end
