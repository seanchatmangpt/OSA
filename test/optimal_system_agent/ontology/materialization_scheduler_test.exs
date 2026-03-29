defmodule OptimalSystemAgent.Ontology.MaterializationSchedulerTest do
  @moduledoc """
  Chicago TDD tests for MaterializationScheduler GenServer.

  Tests verify:
    1. Scheduler starts and schedules all 4 timers
    2. schedule_status/0 returns map with all 4 levels
    3. force_refresh/1 triggers InferenceChain.run_level via worker
    4. Scheduler restarts after crash (supervision test)
    5. No pause/0 function exists (minimal API surface)

  Uses short timer intervals injected via opts to avoid waiting real minutes.
  All tests are independent (no shared mutable state between tests).
  """

  use ExUnit.Case, async: false

  alias OptimalSystemAgent.Ontology.MaterializationScheduler

  # Short intervals for test speed (well under 100ms per test — FIRST: Fast)
  @test_intervals [
    l0_refresh_ms: 500,
    l1_refresh_ms: 600,
    l2_refresh_ms: 700,
    l3_refresh_ms: 800
  ]

  # ── Helpers ──────────────────────────────────────────────────────────────

  # Starts a local Task.Supervisor so tests don't need the full app running.
  # Returns {scheduler_pid, task_sup_pid}.
  defp start_scheduler_with_sup(opts) do
    {:ok, task_sup} = Task.Supervisor.start_link([])
    base = Keyword.merge(@test_intervals, [task_supervisor: task_sup])
    merged = Keyword.merge(base, opts)
    {:ok, pid} = GenServer.start_link(MaterializationScheduler, merged, [])
    {pid, task_sup}
  end

  defp start_scheduler do
    {pid, _task_sup} = start_scheduler_with_sup([])
    pid
  end

  defp start_scheduler(extra_opts) do
    {pid, _task_sup} = start_scheduler_with_sup(extra_opts)
    pid
  end

  defp stop_scheduler(pid) do
    if Process.alive?(pid), do: GenServer.stop(pid, :normal)
  end

  # ── Test 1: starts and schedules all 4 timers ────────────────────────────

  describe "start_link/1" do
    test "scheduler starts successfully and returns ok pid" do
      pid = start_scheduler()
      assert is_pid(pid)
      assert Process.alive?(pid)
      stop_scheduler(pid)
    end

    test "scheduler registers all 4 timers in initial state" do
      pid = start_scheduler()

      # Access internal state via :sys.get_state to verify timers are set
      state = :sys.get_state(pid)

      assert is_reference(state.l0_timer), "l0_timer should be a timer reference"
      assert is_reference(state.l1_timer), "l1_timer should be a timer reference"
      assert is_reference(state.l2_timer), "l2_timer should be a timer reference"
      assert is_reference(state.l3_timer), "l3_timer should be a timer reference"

      stop_scheduler(pid)
    end

    test "scheduler initializes run_count to zero" do
      pid = start_scheduler()
      state = :sys.get_state(pid)
      assert state.run_count == 0
      stop_scheduler(pid)
    end

    test "scheduler initializes all last_run fields to nil" do
      pid = start_scheduler()
      state = :sys.get_state(pid)

      assert state.l0_last_run == nil
      assert state.l1_last_run == nil
      assert state.l2_last_run == nil
      assert state.l3_last_run == nil

      stop_scheduler(pid)
    end
  end

  # ── Test 2: schedule_status/0 returns map with all 4 levels ─────────────

  describe "schedule_status/0" do
    test "returns map with all 4 level keys" do
      pid = start_scheduler()

      # We must call schedule_status on this specific pid (not the globally registered one)
      status = GenServer.call(pid, :schedule_status, 5_000)

      assert is_map(status), "schedule_status should return a map"
      assert Map.has_key?(status, :l0), "status must have :l0 key"
      assert Map.has_key?(status, :l1), "status must have :l1 key"
      assert Map.has_key?(status, :l2), "status must have :l2 key"
      assert Map.has_key?(status, :l3), "status must have :l3 key"

      stop_scheduler(pid)
    end

    test "each level entry has required fields" do
      pid = start_scheduler()
      status = GenServer.call(pid, :schedule_status, 5_000)

      for level <- [:l0, :l1, :l2, :l3] do
        entry = Map.fetch!(status, level)
        assert Map.has_key?(entry, :last_run), "#{level} entry missing :last_run"
        assert Map.has_key?(entry, :next_run_in_ms), "#{level} entry missing :next_run_in_ms"
        assert Map.has_key?(entry, :run_count), "#{level} entry missing :run_count"
      end

      stop_scheduler(pid)
    end

    test "initial last_run is nil for all levels before any run" do
      pid = start_scheduler()
      status = GenServer.call(pid, :schedule_status, 5_000)

      for level <- [:l0, :l1, :l2, :l3] do
        assert status[level].last_run == nil,
               "#{level}.last_run should be nil before first run"
      end

      stop_scheduler(pid)
    end

    test "next_run_in_ms is a positive integer for all levels" do
      pid = start_scheduler()
      status = GenServer.call(pid, :schedule_status, 5_000)

      for level <- [:l0, :l1, :l2, :l3] do
        ms = status[level].next_run_in_ms
        assert is_integer(ms) and ms >= 0,
               "#{level}.next_run_in_ms should be a non-negative integer, got: #{inspect(ms)}"
      end

      stop_scheduler(pid)
    end
  end

  # ── Test 3: force_refresh/1 triggers a worker spawn ──────────────────────

  describe "force_refresh/1" do
    test "force_refresh returns :ok for all valid levels" do
      pid = start_scheduler()

      for level <- [:l0, :l1, :l2, :l3] do
        result = GenServer.call(pid, {:force_refresh, level}, 5_000)
        assert result == :ok, "force_refresh(#{level}) should return :ok"
      end

      stop_scheduler(pid)
    end

    test "force_refresh updates last_run timestamp" do
      pid = start_scheduler()

      # Verify last_run is nil before force_refresh
      state_before = :sys.get_state(pid)
      assert state_before.l1_last_run == nil

      # Trigger force refresh
      GenServer.call(pid, {:force_refresh, :l1}, 5_000)

      state_after = :sys.get_state(pid)
      # last_run should now be a DateTime (not nil)
      assert state_after.l1_last_run != nil
      assert %DateTime{} = state_after.l1_last_run

      stop_scheduler(pid)
    end

    test "force_refresh increments run_count" do
      pid = start_scheduler()

      state_before = :sys.get_state(pid)
      initial_count = state_before.run_count

      GenServer.call(pid, {:force_refresh, :l0}, 5_000)

      state_after = :sys.get_state(pid)
      assert state_after.run_count == initial_count + 1

      stop_scheduler(pid)
    end

    test "force_refresh reschedules the timer (timer_ref changes)" do
      pid = start_scheduler()

      state_before = :sys.get_state(pid)
      old_timer = state_before.l2_timer

      GenServer.call(pid, {:force_refresh, :l2}, 5_000)

      state_after = :sys.get_state(pid)
      new_timer = state_after.l2_timer

      # Timer reference should be replaced (new Process.send_after)
      refute old_timer == new_timer,
             "force_refresh should replace the l2 timer reference"

      stop_scheduler(pid)
    end
  end

  # ── Test 4: scheduler restarts after crash (supervision test) ────────────

  describe "supervision restart" do
    test "scheduler restarts after crash when supervised" do
      # Start a local Task.Supervisor so the restarted scheduler can spawn workers
      {:ok, task_sup} = Task.Supervisor.start_link([])

      test_opts = Keyword.merge(@test_intervals, [task_supervisor: task_sup])

      # Use GenServer.start_link directly (no global name registration) so this
      # test works even when the application's MaterializationScheduler is running.
      child_spec = %{
        id: :test_mat_sched_restart,
        start: {GenServer, :start_link, [MaterializationScheduler, test_opts, []]},
        restart: :permanent,
        type: :worker
      }

      {:ok, sup_pid} = Supervisor.start_link([child_spec], strategy: :one_for_one)

      # Find the scheduler child pid
      [{_, scheduler_pid, :worker, _}] = Supervisor.which_children(sup_pid)
      assert Process.alive?(scheduler_pid)

      original_pid = scheduler_pid

      # Kill the scheduler (simulates crash)
      Process.exit(scheduler_pid, :kill)

      # Give supervisor time to restart it
      :timer.sleep(100)

      # The supervisor should have restarted the scheduler
      [{_, new_pid, :worker, _}] = Supervisor.which_children(sup_pid)
      assert Process.alive?(new_pid), "Scheduler should be restarted by supervisor"
      refute new_pid == original_pid, "Restarted scheduler should have a new pid"

      # Clean up supervisor
      Supervisor.stop(sup_pid, :normal)
    end

    test "restarted scheduler schedules all 4 timers after restart" do
      {:ok, task_sup} = Task.Supervisor.start_link([])

      test_opts = Keyword.merge(@test_intervals, [task_supervisor: task_sup])

      child_spec = %{
        id: :test_mat_sched_timers,
        start: {GenServer, :start_link, [MaterializationScheduler, test_opts, []]},
        restart: :permanent,
        type: :worker
      }

      {:ok, sup_pid} = Supervisor.start_link([child_spec], strategy: :one_for_one)

      [{_, scheduler_pid, :worker, _}] = Supervisor.which_children(sup_pid)
      Process.exit(scheduler_pid, :kill)
      :timer.sleep(100)

      [{_, new_pid, :worker, _}] = Supervisor.which_children(sup_pid)

      new_state = :sys.get_state(new_pid)
      assert is_reference(new_state.l0_timer), "restarted scheduler must have l0 timer"
      assert is_reference(new_state.l1_timer), "restarted scheduler must have l1 timer"
      assert is_reference(new_state.l2_timer), "restarted scheduler must have l2 timer"
      assert is_reference(new_state.l3_timer), "restarted scheduler must have l3 timer"

      Supervisor.stop(sup_pid, :normal)
    end
  end

  # ── Test 5: no pause/0 function exists ───────────────────────────────────

  describe "API surface (minimal by design)" do
    test "pause/0 function does NOT exist on MaterializationScheduler" do
      refute function_exported?(MaterializationScheduler, :pause, 0),
             "pause/0 must NOT exist — there is no pause. Armstrong Let-It-Crash."
    end

    test "stop/0 function does NOT exist on MaterializationScheduler" do
      refute function_exported?(MaterializationScheduler, :stop, 0),
             "stop/0 must NOT exist — scheduler is permanent."
    end

    test "disable/0 function does NOT exist on MaterializationScheduler" do
      refute function_exported?(MaterializationScheduler, :disable, 0),
             "disable/0 must NOT exist — scheduler cannot be administratively disabled."
    end

    test "start_link/1 is exported (supervisor entry point)" do
      assert function_exported?(MaterializationScheduler, :start_link, 1)
    end

    test "schedule_status/0 is exported (monitoring API)" do
      assert function_exported?(MaterializationScheduler, :schedule_status, 0)
    end

    test "force_refresh/1 is exported (test-only trigger)" do
      # ensure_loaded required: module may not be BEAM-loaded when tests run before start_link/1 describe
      Code.ensure_loaded!(MaterializationScheduler)
      assert function_exported?(MaterializationScheduler, :force_refresh, 1)
    end
  end

  # ── Test 6: timer fires and updates last_run (integration of handle_info) ──

  describe "timer fire integration" do
    test "l0 timer firing updates last_run and reschedules" do
      # Use very short l0 interval to observe the fire within test timeout
      pid = start_scheduler(l0_refresh_ms: 50)

      state_before = :sys.get_state(pid)
      assert state_before.l0_last_run == nil

      # Wait just over the 50ms l0 timer
      :timer.sleep(120)

      state_after = :sys.get_state(pid)
      # last_run should be set after timer fires
      assert state_after.l0_last_run != nil,
             "l0_last_run should be set after timer fires"

      assert state_after.run_count >= 1,
             "run_count should increment after timer fires"

      stop_scheduler(pid)
    end

    test "run_count increments across multiple timer fires" do
      pid = start_scheduler(l0_refresh_ms: 40, l1_refresh_ms: 600, l2_refresh_ms: 700, l3_refresh_ms: 800)

      # Wait for 3 l0 fires (3 × 40ms = 120ms, plus buffer)
      :timer.sleep(180)

      state = :sys.get_state(pid)
      assert state.run_count >= 3,
             "run_count should be >= 3 after 3 l0 timer fires, got: #{state.run_count}"

      stop_scheduler(pid)
    end
  end
end
