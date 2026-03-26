defmodule OptimalSystemAgent.Errors.ArmstrongError do
  @moduledoc """
  Armstrong Fault Tolerance violations (Joe Armstrong / Erlang/OTP principles).

  Every process must follow: **let-it-crash**, **supervision**, **no shared state**, **budgets**.
  This module provides helpful error messages for violations.

  ## Fault Tolerance Principles

  | Principle | What | Example |
  |-----------|------|---------|
  | **Let-It-Crash** | Don't catch exceptions, fail fast | no try/catch, let supervisor restart |
  | **Supervision** | Every worker has supervisor | Supervisor.init(children, strategy: :one_for_one) |
  | **No Shared State** | Message passing only | send(pid, {:msg, data}), not globals |
  | **Budgets** | Resource limits per operation | time_ms, memory_mb, calls_per_min |
  """

  defmodule SupervisionViolation do
    @moduledoc """
    Supervision violation: process spawned without supervisor.

    Every worker process must be supervised. Orphaned processes cause:
    - Crashes not visible to parent
    - No automatic restart
    - Resource leaks
    """
    defexception [:process_type, :location, :message]

    def new(process_type, location \\ "", message \\ "") do
      hint =
        case process_type do
          :task ->
            "Task spawned without supervisor. Fix: use Task.Supervisor. " <>
              "Example: Task.Supervisor.start_child(MySupervisor, fn -> ... end)"

          :genserver ->
            "GenServer spawned without supervisor. Fix: add to Supervisor children. " <>
              "Example: {MyServer, []} in Supervisor.init(children: [...])"

          :process ->
            "Process.spawn_link without supervisor. Fix: use supervised task/genserver. " <>
              "Example: use GenServer with DynamicSupervisor for dynamic children"

          _ ->
            "Process spawned without supervisor. Fix: ensure supervisor monitors it. " <>
              "All children must have defined restart strategy."
        end

      %__MODULE__{
        process_type: process_type,
        location: location,
        message:
          message || hint <> " Location: #{location}"
      }
    end

    def message(error) do
      error.message
    end
  end

  defmodule LetItCrashViolation do
    @moduledoc """
    Let-it-crash principle violated: error silently swallowed.

    Never catch exceptions and continue. This hides corruption.
    Instead: fail fast, restart cleanly, preserve invariants.
    """
    defexception [:error_handling, :location, :message]

    def new(error_handling, location \\ "", message \\ "") do
      hint =
        case error_handling do
          :bare_rescue ->
            "try/rescue swallowing error. Fix: remove rescue, let crash. " <>
              "Example: remove 'rescue e -> Logger.error(...)' — let supervisor restart"

          :or_nil ->
            "||nil returning nil on error. Fix: propagate error or crash. " <>
              "Example: {:ok, result} instead of result || nil"

          :with_error_atom ->
            "{:error, reason} caught but ignored. Fix: handle or fail. " <>
              "Example: case result do {:error, e} -> raise e end"

          :tap_without_check ->
            "Ignoring return value of error-prone call. Fix: check result. " <>
              "Example: {:ok, _} = operation() to ensure success"

          _ ->
            "Error silently handled. Fix: crash or propagate. " <>
              "Only catch errors if you can fix the root cause."
        end

      %__MODULE__{
        error_handling: error_handling,
        location: location,
        message:
          message || hint <> " Location: #{location}"
      }
    end

    def message(error) do
      error.message
    end
  end

  defmodule SharedStateViolation do
    @moduledoc """
    Shared mutable state detected: race conditions and deadlocks.

    Never share memory between processes. Use message passing only.
    """
    defexception [:state_type, :location, :message]

    def new(state_type, location \\ "", message \\ "") do
      hint =
        case state_type do
          :global_variable ->
            "Global mutable variable. Fix: use GenServer to own state. " <>
              "Example: def handle_call(:get, _from, state) do {:reply, state, state} end"

          :ets_write_concurrency ->
            "ETS table without write_concurrency. Fix: enable. " <>
              "Example: :ets.new(:table, [:named_table, {:write_concurrency, true}])"

          :process_dictionary ->
            "Process dictionary shared between processes. Fix: use message passing. " <>
              "Example: send(pid, {:set_key, key, value}) instead of Process.put(key, value)"

          :shared_agent ->
            "Agent shared between processes. Fix: GenServer with supervised access. " <>
              "Example: GenServer.call(ServerPid, {:update, fn state -> ... end})"

          :mutex_lock ->
            "Mutex lock across processes. Fix: use GenServer or ETS with write_concurrency. " <>
              "Example: protected by GenServer.call(), not by Mutex"

          _ ->
            "Shared mutable state detected. Fix: use GenServer or message passing. " <>
              "All state must be owned by single process."
        end

      %__MODULE__{
        state_type: state_type,
        location: location,
        message:
          message || hint <> " Location: #{location}"
      }
    end

    def message(error) do
      error.message
    end
  end

  defmodule BudgetExceededError do
    @moduledoc """
    Budget constraint violated: operation exceeded time/memory/call limit.

    Every operation has explicit budget: time_ms, memory_mb, calls_per_min.
    """
    defexception [:resource, :limit, :actual, :message]

    def new(resource, limit, actual, message \\ "") do
      hint =
        case resource do
          :time ->
            "Operation exceeded time budget of #{limit}ms (took #{actual}ms). " <>
              "Fix: optimize implementation or increase budget cautiously. " <>
              "Profile with :timer.tc() to find bottleneck."

          :memory ->
            "Operation exceeded memory budget of #{limit}MB (used #{actual}MB). " <>
              "Fix: check for memory leaks or reduce data size. " <>
              "Profile with erlang:memory()."

          :calls ->
            "Rate limit exceeded: #{actual} calls > #{limit} per minute. " <>
              "Fix: implement backoff or queue requests. " <>
              "Example: queued_call(fn -> work() end)"

          _ ->
            "Budget exceeded: limit=#{limit}, actual=#{actual}. " <>
              "Fix: optimize or increase budget."
        end

      %__MODULE__{
        resource: resource,
        limit: limit,
        actual: actual,
        message: message || hint
      }
    end

    def message(error) do
      error.message
    end
  end

  # Helper: Restart strategy guidance
  def restart_strategy_hint(process_type) do
    case process_type do
      :permanent ->
        "Restart on any crash (critical service). " <>
          "Use for: main loop, connection handler, worker. " <>
          "Example: {MyServer, [], restart: :permanent}"

      :transient ->
        "Restart on abnormal exit only (temporary). " <>
          "Use for: one-off task, client connection. " <>
          "Example: {ClientHandler, [], restart: :transient}"

      :temporary ->
        "Never restart (normal shutdown). " <>
          "Use for: intentional one-shot job. " <>
          "Example: {SetupTask, [], restart: :temporary}"

      _ ->
        "Choose permanent (always restart), transient (restart on crash), " <>
          "or temporary (never restart)."
    end
  end

  # Helper: Supervision strategy guidance
  def supervision_strategy_hint(strategy) do
    case strategy do
      :one_for_one ->
        "If child crashes, restart only that child (isolated). " <>
          "Use for: independent workers. " <>
          "Example: Supervisor.init(children, strategy: :one_for_one)"

      :one_for_all ->
        "If any child crashes, restart all (tightly coupled). " <>
          "Use for: dependent services (DB + cache + worker). " <>
          "Example: Supervisor.init(children, strategy: :one_for_all)"

      :rest_for_one ->
        "If child N crashes, restart N and all after N (ordered dependency). " <>
          "Use for: startup order matters (bootstrap, config, server). " <>
          "Example: Supervisor.init(children, strategy: :rest_for_one)"

      _ ->
        "Choose one_for_one (isolated), one_for_all (coupled), " <>
          "or rest_for_one (ordered)."
    end
  end

  # Helper: Hot reload guidance
  def hot_reload_hint do
    "Configuration changes: " <>
      "1. Load from external source (not hardcoded). " <>
      "2. GenServer receives {:reload_config} message. " <>
      "3. Updates state without restart. " <>
      "4. In-flight requests use old config (safe). " <>
      "Example: GenServer.cast(pid, :reload_config)"
  end
end
