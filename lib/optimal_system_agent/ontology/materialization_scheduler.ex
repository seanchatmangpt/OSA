defmodule OptimalSystemAgent.Ontology.MaterializationScheduler do
  @moduledoc """
  Materialization Scheduler — autonomous continuous refresh of CONSTRUCT levels.

  This GenServer runs permanently in the supervision tree. It schedules and
  dispatches materialization workers for all 4 CONSTRUCT levels (L0–L3) of
  the Board Chair Intelligence System.

  ## Supervision

  Registered as `:permanent` in `OptimalSystemAgent.Supervisors.AgentServices`.
  **There is no `pause/0` or `stop/0`.** Crashes are caught by the supervisor
  and the process is immediately restarted. No HTTP endpoint can disable this
  scheduler. This is by design (Armstrong Let-It-Crash, permanent restart).

  ## Schedule

    - **L0** — every 15 minutes
    - **L1** — every 30 minutes
    - **L2** — every 60 minutes
    - **L3** — daily at 06:00 UTC

  ## WvdA Soundness

    - Timers are rescheduled AFTER each run completes (no overlap)
    - L3 timer calculates exact milliseconds to next 06:00 UTC
    - All `Process.send_after/3` references stored in state for observability
    - `run_count` increments every run for liveness monitoring

  ## Armstrong Requirements

    - Workers spawn via `Task.Supervisor.start_child/2` (temporary)
    - Scheduler itself has restart: :permanent
    - No `rescue` in worker spawn path — crashes are visible
    - If Oxigraph is down, worker crashes, supervisor logs, next timer retries

  ## API Surface (minimal by design)

    - `start_link/1` — supervisor callback
    - `schedule_status/0` — returns current schedule state for monitoring
    - `force_refresh/1` — for testing only, not exposed via HTTP
  """

  use GenServer
  require Logger

  alias OptimalSystemAgent.Ontology.MaterializationWorker

  # ─────────────────────────────────────────────────────────────────────────
  # Schedule constants (WvdA: all intervals explicit, documented)
  # ─────────────────────────────────────────────────────────────────────────

  @l0_refresh_ms 15 * 60 * 1_000
  @l1_refresh_ms 30 * 60 * 1_000
  @l2_refresh_ms 60 * 60 * 1_000
  # L3 daily: computed at runtime to target next 06:00 UTC precisely
  @l3_daily_hour_utc 6

  # ─────────────────────────────────────────────────────────────────────────
  # State type
  # ─────────────────────────────────────────────────────────────────────────

  @type level :: :l0 | :l1 | :l2 | :l3

  @type t :: %{
    l0_timer: reference() | nil,
    l1_timer: reference() | nil,
    l2_timer: reference() | nil,
    l3_timer: reference() | nil,
    l0_last_run: DateTime.t() | nil,
    l1_last_run: DateTime.t() | nil,
    l2_last_run: DateTime.t() | nil,
    l3_last_run: DateTime.t() | nil,
    run_count: non_neg_integer()
  }

  # ─────────────────────────────────────────────────────────────────────────
  # Client API
  # ─────────────────────────────────────────────────────────────────────────

  @doc """
  Start the MaterializationScheduler GenServer.

  Called by `OptimalSystemAgent.Supervisors.AgentServices` as a permanent child.
  Options are passed through but currently unused (reserved for test overrides).
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Return current schedule status for all 4 levels.

  Returns a map of `level => %{last_run, next_run_in_ms, run_count}`.
  Used by monitoring dashboards and health checks.

  ## Examples

      iex> MaterializationScheduler.schedule_status()
      %{
        l0: %{last_run: ~U[2026-03-26 12:00:00Z], next_run_in_ms: 845000, run_count: 5},
        l1: %{last_run: nil, next_run_in_ms: 1800000, run_count: 0},
        ...
      }
  """
  @spec schedule_status() :: map()
  def schedule_status do
    GenServer.call(__MODULE__, :schedule_status, 5_000)
  catch
    :exit, {:timeout, _} ->
      Logger.error("[MaterializationScheduler] schedule_status timeout")
      %{}
  end

  @doc """
  Force an immediate refresh of one CONSTRUCT level.

  **For testing only.** Not exposed via any HTTP endpoint.
  Spawns a worker task immediately and reschedules the regular timer.

  ## Parameters

    - `level` — one of `:l0 | :l1 | :l2 | :l3`
  """
  @spec force_refresh(level()) :: :ok
  def force_refresh(level) when level in [:l0, :l1, :l2, :l3] do
    GenServer.call(__MODULE__, {:force_refresh, level}, 10_000)
  catch
    :exit, {:timeout, _} ->
      Logger.error("[MaterializationScheduler] force_refresh timeout level=#{level}")
      :ok
  end

  # NOTE: pause/0 is intentionally NOT implemented.
  # There is no pause. There is no stop. The scheduler runs permanently.
  # Any admin request to pause materialization must be routed through
  # a different mechanism (e.g. disabling the query at InferenceChain level).

  # ─────────────────────────────────────────────────────────────────────────
  # GenServer callbacks
  # ─────────────────────────────────────────────────────────────────────────

  @impl true
  def init(opts) do
    # Allow test overrides for timer intervals and task supervisor name
    l0_ms = Keyword.get(opts, :l0_refresh_ms, @l0_refresh_ms)
    l1_ms = Keyword.get(opts, :l1_refresh_ms, @l1_refresh_ms)
    l2_ms = Keyword.get(opts, :l2_refresh_ms, @l2_refresh_ms)
    l3_ms = Keyword.get(opts, :l3_refresh_ms, ms_until_next_l3())
    task_sup = Keyword.get(opts, :task_supervisor, OptimalSystemAgent.TaskSupervisor)

    Logger.info(
      "[MaterializationScheduler] Starting — l0=#{l0_ms}ms l1=#{l1_ms}ms " <>
        "l2=#{l2_ms}ms l3=#{l3_ms}ms (next 06:00 UTC)"
    )

    state = %{
      l0_timer: schedule_refresh(:l0, l0_ms),
      l1_timer: schedule_refresh(:l1, l1_ms),
      l2_timer: schedule_refresh(:l2, l2_ms),
      l3_timer: schedule_refresh(:l3, l3_ms),
      l0_last_run: nil,
      l1_last_run: nil,
      l2_last_run: nil,
      l3_last_run: nil,
      run_count: 0,
      # Store intervals so we can reschedule after each run
      l0_interval_ms: l0_ms,
      l1_interval_ms: l1_ms,
      l2_interval_ms: l2_ms,
      # Injectable task supervisor for testing
      task_supervisor: task_sup
    }

    {:ok, state}
  end

  @impl true
  def handle_info({:refresh, level}, state) do
    Logger.info("[MaterializationScheduler] Timer fired level=#{level}")

    # Spawn worker via Task.Supervisor (temporary, let-it-crash)
    Task.Supervisor.start_child(state.task_supervisor, fn ->
      MaterializationWorker.run(level)
    end)

    # Reschedule AFTER spawning (WvdA: timer reset after run, not before)
    next_ms = next_interval(level, state)
    new_timer = schedule_refresh(level, next_ms)

    new_state =
      state
      |> Map.put(timer_key(level), new_timer)
      |> Map.put(last_run_key(level), DateTime.utc_now())
      |> Map.update!(:run_count, &(&1 + 1))

    {:noreply, new_state}
  end

  @impl true
  def handle_call(:schedule_status, _from, state) do
    status = %{
      l0: level_status(:l0, state),
      l1: level_status(:l1, state),
      l2: level_status(:l2, state),
      l3: level_status(:l3, state)
    }

    {:reply, status, state}
  end

  @impl true
  def handle_call({:force_refresh, level}, _from, state) do
    Logger.info("[MaterializationScheduler] force_refresh level=#{level}")

    # Cancel existing timer to avoid double-fire
    existing_timer = Map.get(state, timer_key(level))
    if existing_timer, do: Process.cancel_timer(existing_timer)

    # Spawn worker immediately
    Task.Supervisor.start_child(state.task_supervisor, fn ->
      MaterializationWorker.run(level)
    end)

    # Reschedule at normal interval
    next_ms = next_interval(level, state)
    new_timer = schedule_refresh(level, next_ms)

    new_state =
      state
      |> Map.put(timer_key(level), new_timer)
      |> Map.put(last_run_key(level), DateTime.utc_now())
      |> Map.update!(:run_count, &(&1 + 1))

    {:reply, :ok, new_state}
  end

  # ─────────────────────────────────────────────────────────────────────────
  # Private helpers
  # ─────────────────────────────────────────────────────────────────────────

  @spec schedule_refresh(level(), pos_integer()) :: reference()
  defp schedule_refresh(level, delay_ms) do
    Process.send_after(self(), {:refresh, level}, delay_ms)
  end

  # WvdA: next interval after a run — L3 recalculates to next 06:00 UTC
  @spec next_interval(level(), map()) :: pos_integer()
  defp next_interval(:l3, _state), do: ms_until_next_l3()
  defp next_interval(:l0, state), do: Map.get(state, :l0_interval_ms, @l0_refresh_ms)
  defp next_interval(:l1, state), do: Map.get(state, :l1_interval_ms, @l1_refresh_ms)
  defp next_interval(:l2, state), do: Map.get(state, :l2_interval_ms, @l2_refresh_ms)

  # WvdA: exact milliseconds to next 06:00 UTC
  # If it's past 06:00 UTC today, schedules for tomorrow's 06:00 UTC.
  @spec ms_until_next_l3() :: pos_integer()
  defp ms_until_next_l3 do
    now = DateTime.utc_now()
    today_target = %{now | hour: @l3_daily_hour_utc, minute: 0, second: 0, microsecond: {0, 6}}

    target =
      if DateTime.compare(now, today_target) == :lt do
        today_target
      else
        # Already past 06:00 UTC today — schedule for tomorrow
        tomorrow = Date.add(DateTime.to_date(now), 1)
        {:ok, tomorrow_target} = DateTime.new(tomorrow, ~T[06:00:00], "Etc/UTC")
        tomorrow_target
      end

    diff_ms = DateTime.diff(target, now, :millisecond)
    # Clamp to at minimum 1 second (avoids immediate re-fire edge case)
    max(diff_ms, 1_000)
  end

  @spec level_status(level(), map()) :: map()
  defp level_status(level, state) do
    last_run = Map.get(state, last_run_key(level))
    timer_ref = Map.get(state, timer_key(level))

    next_run_in_ms =
      if is_reference(timer_ref) do
        # Process.read_timer returns ms remaining or false if expired
        case Process.read_timer(timer_ref) do
          false -> 0
          ms -> ms
        end
      else
        0
      end

    %{
      last_run: last_run,
      next_run_in_ms: next_run_in_ms,
      run_count: state.run_count
    }
  end

  @spec timer_key(level()) :: atom()
  defp timer_key(:l0), do: :l0_timer
  defp timer_key(:l1), do: :l1_timer
  defp timer_key(:l2), do: :l2_timer
  defp timer_key(:l3), do: :l3_timer

  @spec last_run_key(level()) :: atom()
  defp last_run_key(:l0), do: :l0_last_run
  defp last_run_key(:l1), do: :l1_last_run
  defp last_run_key(:l2), do: :l2_last_run
  defp last_run_key(:l3), do: :l3_last_run
end
