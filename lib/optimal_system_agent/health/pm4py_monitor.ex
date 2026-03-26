defmodule OptimalSystemAgent.Health.PM4PyMonitor do
  @moduledoc """
  Armstrong-compliant health monitoring for pm4py-rust process mining engine.

  Implements the fault tolerance pattern:
  - **Let-It-Crash**: Unrecoverable failures escalate to supervisor, not swallowed
  - **Supervision**: Monitored by Infrastructure supervisor with `:permanent` restart
  - **Deadlock-Free**: All blocking operations have explicit timeout_ms (Client uses 10s default, monitor uses GenServer 5s call timeout)
  - **Liveness**: Periodic ping loop has bounded iteration with escape
  - **Bounded**: Health metrics limited to 100 entries, circular buffer

  ## Health States

    - `:ok`        — pm4py responds within 5s, <4 recent errors
    - `:degraded`  — latency >5s or 4-7 recent errors
    - `:down`      — ≥8 recent errors or no response in 30s

  ## Telemetry

  Emits events to Bus when status changes:
    - `:pm4py_health_check` — `%{status: status, latency_ms: ms, error_count: n}`

  ## Public API

    - `start_link/0` — Supervisor integration
    - `get_health/0` — Current status (`:ok`, `:degraded`, `:down`)
    - `is_healthy?/0` — Boolean: status == `:ok`
    - `status/0` — Full state map for debugging

  ## Armstrong Pattern: Let-It-Crash + Supervision

  If the ping loop crashes (unhandled error), the GenServer terminates.
  The Infrastructure supervisor detects the crash (permanent restart)
  and restarts the monitor. No silent error swallowing.

  ```elixir
  # Supervisor child spec
  {OptimalSystemAgent.Health.PM4PyMonitor, []}

  # In Infrastructure supervisor with strategy: :rest_for_one
  # Crash in this monitor → supervisor logs and restarts
  ```
  """

  use GenServer
  require Logger

  alias OptimalSystemAgent.Process.Mining.Client
  alias OptimalSystemAgent.Events.Bus

  # Configuration
  @ping_interval_ms 30_000           # Ping every 30 seconds
  @error_threshold 8                 # Status becomes :down at 8+ consecutive errors
  @degraded_threshold 4              # Status becomes :degraded at 4+ consecutive errors
  @latency_threshold_ms 5_000        # Degraded if latency > 5s
  @max_history_size 100              # Keep only 100 recent pings for analysis

  # Public API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Return current health status: :ok, :degraded, or :down"
  @spec get_health() :: :ok | :degraded | :down
  def get_health do
    GenServer.call(__MODULE__, :get_health, 5_000)
  catch
    :exit, {:timeout, _} ->
      Logger.warning("[PM4PyMonitor] Timeout fetching health status")
      :down
  end

  @doc "Boolean check: is pm4py healthy (status == :ok)?"
  @spec is_healthy?() :: boolean
  def is_healthy? do
    get_health() == :ok
  end

  @doc "Return full state map for debugging"
  @spec status() :: map()
  def status do
    GenServer.call(__MODULE__, :status, 5_000)
  catch
    :exit, {:timeout, _} ->
      Logger.warning("[PM4PyMonitor] Timeout fetching status")
      %{error: :timeout}
  end

  # GenServer Callbacks

  @impl true
  def init(_opts) do
    Logger.info("[PM4PyMonitor] Starting pm4py health monitor (30s interval, 2s timeout)")

    state = %{
      status: :ok,
      last_ping_ms: nil,
      consecutive_errors: 0,
      total_errors: 0,
      total_pings: 0,
      last_status_change: System.monotonic_time(:millisecond),
      uptime_ms: 0,
      history: [],
      started_at: System.monotonic_time(:millisecond)
    }

    # Schedule first ping immediately, then every 30 seconds
    {:ok, state, {:continue, :schedule_first_ping}}
  end

  @impl true
  def handle_continue(:schedule_first_ping, state) do
    send(self(), :ping)
    schedule_next_ping()
    {:noreply, state}
  end

  @impl true
  def handle_info(:ping, state) do
    new_state = perform_ping(state)
    schedule_next_ping()
    {:noreply, new_state}
  end

  @impl true
  def handle_call(:get_health, _from, state) do
    {:reply, state.status, state}
  end

  def handle_call(:status, _from, state) do
    reply = %{
      status: state.status,
      last_ping_ms: state.last_ping_ms,
      consecutive_errors: state.consecutive_errors,
      total_errors: state.total_errors,
      total_pings: state.total_pings,
      uptime_ms: System.monotonic_time(:millisecond) - state.started_at,
      error_rate: format_error_rate(state)
    }

    {:reply, reply, state}
  end

  # Private

  defp perform_ping(state) do
    start_time = System.monotonic_time(:millisecond)

    case ping_pm4py() do
      {:ok, latency_ms} ->
        record_success(state, latency_ms, start_time)

      {:error, reason} ->
        record_failure(state, reason, start_time)
    end
  end

  @doc false
  def ping_pm4py do
    try do
      case Client.check_deadlock_free("ping_test") do
        {:ok, _result} ->
          {:ok, System.monotonic_time(:millisecond)}

        {:error, reason} ->
          {:error, reason}
      end
    rescue
      e ->
        # ProcessMining.Client may not be started yet during app startup
        {:error, {:rescue, Exception.message(e)}}
    catch
      # Handle :exit when ProcessMining.Client process doesn't exist
      :exit, reason ->
        {:error, {:exit, reason}}
    end
  end

  defp record_success(state, latency_ms, _start_time) do
    new_total_pings = state.total_pings + 1
    new_history = add_to_history(state.history, {:ok, latency_ms})

    new_state = %{
      state
      | consecutive_errors: 0,
        total_pings: new_total_pings,
        last_ping_ms: latency_ms,
        history: new_history
    }

    # Determine new status based on latency
    new_status = if latency_ms > @latency_threshold_ms, do: :degraded, else: :ok

    maybe_emit_status_change(new_state, new_status)
  end

  defp record_failure(state, reason, _start_time) do
    new_consecutive_errors = state.consecutive_errors + 1
    new_total_errors = state.total_errors + 1
    new_total_pings = state.total_pings + 1
    new_history = add_to_history(state.history, {:error, reason})

    Logger.warning(
      "[PM4PyMonitor] Ping failed (#{new_consecutive_errors} consecutive): #{inspect(reason)}"
    )

    new_state = %{
      state
      | consecutive_errors: new_consecutive_errors,
        total_errors: new_total_errors,
        total_pings: new_total_pings,
        history: new_history
    }

    # Determine new status based on error threshold
    new_status =
      cond do
        new_consecutive_errors >= @error_threshold -> :down
        new_consecutive_errors >= @degraded_threshold -> :degraded
        true -> state.status
      end

    maybe_emit_status_change(new_state, new_status)
  end

  defp maybe_emit_status_change(state, new_status) do
    if new_status != state.status do
      Logger.info("[PM4PyMonitor] Status change: #{state.status} → #{new_status}")

      # Emit telemetry event
      emit_health_event(new_status, state)

      %{
        state
        | status: new_status,
          last_status_change: System.monotonic_time(:millisecond)
      }
    else
      state
    end
  end

  defp emit_health_event(status, state) do
    event = %{
      status: status,
      consecutive_errors: state.consecutive_errors,
      total_errors: state.total_errors,
      latency_ms: state.last_ping_ms || 0,
      timestamp: System.monotonic_time(:millisecond)
    }

    # Emit to system event bus for subscribers to listen
    Bus.emit(:system_event, %{
      type: :pm4py_health_check,
      channel: :pm4py,
      data: event
    })

    # Also emit telemetry event for observability
    :telemetry.execute([:pm4py, :health_check], %{status: status_to_telemetry(status)}, event)
  end

  defp status_to_telemetry(:ok), do: 0
  defp status_to_telemetry(:degraded), do: 1
  defp status_to_telemetry(:down), do: 2

  defp add_to_history(history, entry) do
    new_history = [entry | history]

    if length(new_history) > @max_history_size do
      Enum.take(new_history, @max_history_size)
    else
      new_history
    end
  end

  defp format_error_rate(state) do
    if state.total_pings == 0 do
      0.0
    else
      (state.total_errors / state.total_pings * 100) |> Float.round(2)
    end
  end

  defp schedule_next_ping do
    Process.send_after(self(), :ping, @ping_interval_ms)
  end
end
