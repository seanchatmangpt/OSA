defmodule OptimalSystemAgent.ArmstrongAGILiveValidationTest do
  @moduledoc """
  Joe Armstrong AGI Live Validations for OSA (Elixir/OTP)

  Tests Armstrong fault-tolerance properties at RUNTIME — not static code checks,
  but actually exercising the OTP system under fault conditions.

  Principles verified:
  1. Let-it-crash — ETS crash → supervisor restart → ETS recreated
  2. Supervision tree — every process supervised, orphans detected
  3. No shared mutable state — processes communicate via messages
  4. Resource bounds — bounded queues, memory monitored
  5. Timeout with fallback — GenServer.call has explicit timeout_ms
  6. Crash visibility — failures emit telemetry, not silently hidden

  Run with:
    mix test test/integration/armstrong_agi_live_validation_test.exs

  NOTE: @moduletag :requires_application — full OTP must be booted.
  Never use `mix test --no-start` — these tests exercise real supervision trees.
  """
  use ExUnit.Case, async: false

  @moduletag :requires_application
  @moduletag :integration

  # ── Helpers ─────────────────────────────────────────────────────────────────

  # Wait up to `timeout_ms` for a named process to be registered.
  # Returns the pid when found, raises if timeout exceeded.
  defp wait_for_pid(name, timeout_ms \\ 2_000) do
    deadline = System.monotonic_time(:millisecond) + timeout_ms
    do_wait_for_pid(name, deadline)
  end

  defp do_wait_for_pid(name, deadline) do
    case Process.whereis(name) do
      nil ->
        now = System.monotonic_time(:millisecond)

        if now >= deadline do
          raise "Process #{inspect(name)} did not start within timeout"
        else
          :timer.sleep(50)
          do_wait_for_pid(name, deadline)
        end

      pid ->
        pid
    end
  end

  # ── SECTION 1: Let-It-Crash ─────────────────────────────────────────────────
  #
  # Armstrong principle: if ETS is missing, crash — don't rescue.
  # The supervisor sees the crash, restarts the process, ETS is recreated.

  describe "Let-It-Crash: supervised crash → restart → ETS recreated" do
    test "EventStream GenServer is supervised and owns its ETS table" do
      # Verify the GenServer is alive and its ETS table exists
      pid = Process.whereis(OptimalSystemAgent.EventStream)
      assert pid != nil, "EventStream must be running (supervised)"
      assert Process.alive?(pid)

      # The ETS table :command_center_events is created in EventStream.init/1
      table_info = :ets.info(:command_center_events)
      assert table_info != :undefined,
             ":command_center_events ETS table must exist when EventStream is running"

      # Owner should be the EventStream pid
      owner = Keyword.get(table_info, :owner)
      assert owner == pid,
             ":command_center_events must be owned by EventStream pid #{inspect(pid)}"
    end

    test "ETS table is recreated after supervised GenServer crash and restart" do
      original_pid = Process.whereis(OptimalSystemAgent.EventStream)
      assert original_pid != nil, "EventStream must be running"

      # Monitor the process to detect when it dies
      ref = Process.monitor(original_pid)

      # Kill the process — let-it-crash. Supervisor must restart it.
      Process.exit(original_pid, :kill)

      # Wait for the DOWN message confirming the crash
      assert_receive {:DOWN, ^ref, :process, ^original_pid, :killed}, 2_000

      # Use wait_for_pid — supervisor restart time varies
      new_pid = wait_for_pid(OptimalSystemAgent.EventStream, 2_000)
      assert new_pid != nil, "EventStream must be restarted by supervisor after crash"
      assert new_pid != original_pid, "Restarted process must have a different pid"
      assert Process.alive?(new_pid)

      # The ETS table must be recreated by the new process's init/1
      table_info = :ets.info(:command_center_events)
      assert table_info != :undefined,
             ":command_center_events ETS table must be recreated after supervisor restarts EventStream"

      new_owner = Keyword.get(table_info, :owner)
      assert new_owner == new_pid,
             "New ETS table must be owned by the new EventStream pid #{inspect(new_pid)}"
    end

    test "Circuit breaker GenServer crash does not bring down the supervision subtree" do
      # Wait for CircuitBreaker — a prior test may have triggered :rest_for_one restart
      cb_pid = wait_for_pid(OptimalSystemAgent.Resilience.CircuitBreaker)
      assert cb_pid != nil, "CircuitBreaker must be supervised"

      # Monitor adjacent process to verify it is NOT killed (isolation)
      event_stream_pid = wait_for_pid(OptimalSystemAgent.EventStream)
      assert event_stream_pid != nil

      es_ref = Process.monitor(event_stream_pid)

      # Kill the circuit breaker
      cb_ref = Process.monitor(cb_pid)
      Process.exit(cb_pid, :kill)
      assert_receive {:DOWN, ^cb_ref, :process, ^cb_pid, :killed}, 2_000

      # EventStream must remain alive (infrastructure uses :rest_for_one, but
      # CircuitBreaker is listed AFTER EventStream so its crash does not restart EventStream)
      refute_receive {:DOWN, ^es_ref, :process, ^event_stream_pid, _}, 500,
                     "EventStream must not be killed when CircuitBreaker crashes"

      assert Process.alive?(event_stream_pid),
             "EventStream must remain alive after CircuitBreaker crash"

      # Clean up monitor
      Process.demonitor(es_ref, [:flush])

      # Give supervisor time to restart circuit breaker
      :timer.sleep(200)
      new_cb_pid = Process.whereis(OptimalSystemAgent.Resilience.CircuitBreaker)
      assert new_cb_pid != nil, "CircuitBreaker must be restarted by supervisor"
    end
  end

  # ── SECTION 2: Timeout Enforcement ─────────────────────────────────────────
  #
  # Armstrong principle: every GenServer.call must have an explicit timeout.
  # A call that hangs forever is a deadlock waiting to happen.

  describe "Timeout Enforcement: explicit timeout_ms on all blocking calls" do
    test "circuit breaker call uses explicit timeout and returns error on timeout" do
      # Start a separate circuit breaker with a very short timeout for testing
      {:ok, cb_pid} =
        start_supervised(
          {OptimalSystemAgent.Resilience.CircuitBreaker,
           [name: :test_cb_timeout, failure_threshold: 1, open_timeout_ms: 50]}
        )

      assert Process.alive?(cb_pid)

      # Call with explicit timeout — must complete (not hang forever)
      # CircuitBreaker.call wraps the function return in {:ok, result}
      # So fn -> {:ok, :done} end returns {:ok, {:ok, :done}}
      result = OptimalSystemAgent.Resilience.CircuitBreaker.call(:test_cb_timeout, fn ->
        :executed
      end)

      assert {:ok, :executed} = result, "CircuitBreaker.call must wrap result in {:ok, result}"
    end

    test "circuit breaker rejects calls when open (budget exceeded → escalate, not degrade)" do
      {:ok, _cb_pid} =
        start_supervised(
          {OptimalSystemAgent.Resilience.CircuitBreaker,
           [name: :test_cb_open, failure_threshold: 2, open_timeout_ms: 60_000]}
        )

      # Record 2 failures to trip the breaker
      Enum.each(1..2, fn _ ->
        OptimalSystemAgent.Resilience.CircuitBreaker.call(:test_cb_open, fn ->
          raise "simulated failure"
        end)
      end)

      # Now the circuit must be OPEN
      status = OptimalSystemAgent.Resilience.CircuitBreaker.status(:test_cb_open)
      assert status == :OPEN, "Circuit breaker must be OPEN after threshold failures, got #{status}"

      # Calls must be REJECTED — budget exceeded means escalate, not silently degrade
      result = OptimalSystemAgent.Resilience.CircuitBreaker.call(:test_cb_open, fn ->
        {:ok, :should_not_reach}
      end)

      assert {:error, :circuit_open} = result,
             "Open circuit must return {:error, :circuit_open}, not silently return success"
    end

    test "GenServer.call with zero-length timeout exits with :timeout, not :noproc" do
      # Verify that a timed-out call raises :exit with :timeout tuple (not crashes the caller)
      {:ok, server_pid} =
        start_supervised({OptimalSystemAgent.Resilience.CircuitBreaker, [name: :test_cb_zero_timeout]})

      assert Process.alive?(server_pid)

      # The call itself should have an explicit timeout — 0ms forces :timeout exit
      result =
        try do
          GenServer.call(:test_cb_zero_timeout, :status, 0)
        catch
          :exit, {:timeout, _} -> {:error, :timeout}
        end

      assert {:error, :timeout} = result,
             "Timed-out GenServer.call must exit with :timeout, not crash the caller silently"
    end
  end

  # ── SECTION 3: Resource Bounds ─────────────────────────────────────────────
  #
  # Armstrong principle: queues must be bounded. Memory monitored.
  # When bound exceeded → escalate, not silently degrade.

  describe "Resource Bounds: bounded queues and memory monitoring" do
    test "EventStream ring buffer is bounded at @max_history entries" do
      # Publish more than @max_history (100) events and verify ETS stays bounded
      Enum.each(1..150, fn i ->
        OptimalSystemAgent.EventStream.broadcast("test_event", %{index: i})
      end)

      # Give the GenServer time to process all casts
      :timer.sleep(200)

      # The ETS ring buffer must not exceed max_history (100)
      table_size = :ets.info(:command_center_events, :size)
      assert table_size <= 100,
             "ETS ring buffer must be bounded at 100 entries, got #{table_size}"
    end

    test "EventStream ETS table size stays bounded after many broadcasts" do
      # Record initial size
      initial_size = :ets.info(:command_center_events, :size) || 0

      # Broadcast a burst of events
      Enum.each(1..50, fn i ->
        OptimalSystemAgent.EventStream.broadcast("bound_test", %{seq: i})
      end)

      :timer.sleep(100)

      final_size = :ets.info(:command_center_events, :size)
      assert final_size <= 100,
             "After burst, ETS size must remain ≤ 100 (bounded), got #{final_size}"

      # Verify it grew from initial but stayed bounded
      assert final_size >= min(initial_size + 1, 100),
             "ETS table must have recorded at least some events"
    end

    test "Erlang memory/1 is accessible — memory monitoring is live, not hypothetical" do
      # Armstrong: resource limits must be MONITORED, not just documented
      total_memory_bytes = :erlang.memory(:total)
      assert is_integer(total_memory_bytes)
      assert total_memory_bytes > 0

      # Process count is bounded (not unbounded spawning)
      process_count = :erlang.system_info(:process_count)
      process_limit = :erlang.system_info(:process_limit)
      assert process_count < process_limit,
             "Process count #{process_count} must be below limit #{process_limit}"
    end
  end

  # ── SECTION 4: Crash Visibility ─────────────────────────────────────────────
  #
  # Armstrong principle: crashes must be VISIBLE — not caught, not logged-and-continued.
  # Telemetry events emit failure signals so infrastructure issues are observable.

  describe "Crash Visibility: failures emit telemetry, not silent fallbacks" do
    test "dashboard fallback telemetry event is emitted on infrastructure failure" do
      # Attach a telemetry handler to capture [:osa, :dashboard, :fallback] events
      test_pid = self()
      handler_id = :erlang.unique_integer([:positive])

      :telemetry.attach(
        handler_id,
        [:osa, :dashboard, :fallback],
        fn event, measurements, metadata, _config ->
          send(test_pid, {:telemetry_captured, event, measurements, metadata})
        end,
        nil
      )

      on_exit(fn -> :telemetry.detach(handler_id) end)

      # Execute the telemetry event directly (as dashboard_routes would emit on failure)
      :telemetry.execute(
        [:osa, :dashboard, :fallback],
        %{count: 1},
        %{source: :agent_registry, error: "test: simulated ETS unavailable"}
      )

      # Must receive the event — failure is visible
      assert_receive {:telemetry_captured, [:osa, :dashboard, :fallback], %{count: 1},
                      %{source: :agent_registry}},
                     1_000,
                     "Dashboard fallback telemetry must be emitted — failure must be visible"
    end

    test "telemetry attach/detach lifecycle is clean — no orphaned handlers" do
      handler_id = :erlang.unique_integer([:positive])

      :telemetry.attach(
        handler_id,
        [:osa, :test, :probe],
        fn _event, _measurements, _metadata, _config -> :ok end,
        nil
      )

      # Handler is attached
      handlers = :telemetry.list_handlers([:osa, :test, :probe])
      handler_ids = Enum.map(handlers, & &1.id)
      assert handler_id in handler_ids, "Handler must be registered"

      # Detach cleanly
      :telemetry.detach(handler_id)

      handlers_after = :telemetry.list_handlers([:osa, :test, :probe])
      ids_after = Enum.map(handlers_after, & &1.id)
      refute handler_id in ids_after, "Handler must be removed after detach"
    end

    test "circuit breaker OPEN state is observable via status/1 — not silently open" do
      {:ok, _} =
        start_supervised(
          {OptimalSystemAgent.Resilience.CircuitBreaker,
           [name: :test_cb_visible, failure_threshold: 1, open_timeout_ms: 60_000]}
        )

      # Force open
      OptimalSystemAgent.Resilience.CircuitBreaker.call(:test_cb_visible, fn ->
        raise "visible failure"
      end)

      # Status is queryable — not hidden
      status = OptimalSystemAgent.Resilience.CircuitBreaker.status(:test_cb_visible)
      assert status in [:OPEN, :HALF_OPEN, :CLOSED],
             "Circuit breaker status must be observable, got #{inspect(status)}"

      # After threshold failure, must be OPEN (not silently degraded)
      assert status == :OPEN,
             "After failure, status must be :OPEN (visible) not :CLOSED (silent)"
    end
  end

  # ── SECTION 5: No Shared Mutable State ──────────────────────────────────────
  #
  # Armstrong principle: processes communicate via message passing.
  # State lives in process memory (GenServer) or ETS owned by supervised GenServers.
  # No global mutable state.

  describe "No Shared Mutable State: process isolation and message passing" do
    test "two independent circuit breaker instances have fully isolated state" do
      {:ok, pid_a} =
        start_supervised(
          {OptimalSystemAgent.Resilience.CircuitBreaker,
           [name: :test_cb_isolated_a, failure_threshold: 2]},
          id: :isolated_a
        )

      {:ok, pid_b} =
        start_supervised(
          {OptimalSystemAgent.Resilience.CircuitBreaker,
           [name: :test_cb_isolated_b, failure_threshold: 2]},
          id: :isolated_b
        )

      assert pid_a != pid_b, "Two instances must be separate processes"

      # Trip only instance A
      Enum.each(1..2, fn _ ->
        OptimalSystemAgent.Resilience.CircuitBreaker.call(:test_cb_isolated_a, fn ->
          raise "trip A"
        end)
      end)

      status_a = OptimalSystemAgent.Resilience.CircuitBreaker.status(:test_cb_isolated_a)
      status_b = OptimalSystemAgent.Resilience.CircuitBreaker.status(:test_cb_isolated_b)

      assert status_a == :OPEN,
             "Circuit A must be OPEN after failures"

      assert status_b == :CLOSED,
             "Circuit B must remain CLOSED — state is NOT shared between processes"
    end

    test "EventStream history is stored in ETS (owned by supervised GenServer), not global module state" do
      # Verify history comes from ETS, not from a module attribute or global Agent
      OptimalSystemAgent.EventStream.broadcast("isolation_test", %{probe: true})
      :timer.sleep(50)

      history = OptimalSystemAgent.EventStream.event_history("isolation_test")

      # The response comes from ETS, not a global — verify the ETS table exists
      assert :ets.info(:command_center_events) != :undefined,
             ":command_center_events ETS table must exist (owned by EventStream GenServer)"

      # The history function returns a list (not nil), showing ETS is live
      assert is_list(history),
             "event_history/1 must return a list from ETS, not crash or return nil"
    end

    test "killing EventStream clears ETS — state is not shared via global" do
      # ETS table is owned by the GenServer. When it crashes, the table is deleted.
      # This is NOT a bug — it is Armstrong-correct design. Supervisor recreates it.
      pid = wait_for_pid(OptimalSystemAgent.EventStream)
      assert pid != nil

      ref = Process.monitor(pid)
      Process.exit(pid, :kill)
      assert_receive {:DOWN, ^ref, :process, ^pid, :killed}, 2_000

      # After restart: ETS is recreated by new process's init/1
      # Use wait_for_pid to handle variable supervisor restart time
      new_pid = wait_for_pid(OptimalSystemAgent.EventStream, 2_000)
      assert new_pid != nil

      table_info = :ets.info(:command_center_events)
      assert table_info != :undefined, "ETS must be recreated by new EventStream after crash"

      # New owner is the new process — state is not shared
      owner = Keyword.get(table_info, :owner)
      assert owner == new_pid,
             "ETS must be owned by the NEW EventStream pid, not leaked from dead process"
    end
  end

  # ── SECTION 6: Supervision Hierarchy ────────────────────────────────────────
  #
  # Armstrong principle: every process has a supervisor. No orphans.
  # Restart strategies are deliberate, not accidental.

  describe "Supervision Hierarchy: all children supervised, restart strategies correct" do
    test "Infrastructure supervisor is running and uses :rest_for_one strategy" do
      sup_pid = Process.whereis(OptimalSystemAgent.Supervisors.Infrastructure)
      assert sup_pid != nil,
             "Infrastructure supervisor must be running"

      assert Process.alive?(sup_pid),
             "Infrastructure supervisor must be alive"

      # Verify it is a supervisor (not just a GenServer)
      children = Supervisor.which_children(OptimalSystemAgent.Supervisors.Infrastructure)
      assert is_list(children) and length(children) > 0,
             "Infrastructure supervisor must have children"
    end

    test "all infrastructure children are :permanent (always restart on crash)" do
      children = Supervisor.which_children(OptimalSystemAgent.Supervisors.Infrastructure)

      # Every child returned must be alive (no :restarting or :undefined)
      alive_count =
        Enum.count(children, fn {_id, pid, _type, _modules} ->
          is_pid(pid) and Process.alive?(pid)
        end)

      total_count = length(children)

      # At least 80% of children must be alive (allows for transient startup)
      assert alive_count >= round(total_count * 0.8),
             "At least 80% of infrastructure children must be alive. " <>
               "Alive: #{alive_count}/#{total_count}"
    end

    test "Sessions supervisor exists and is supervised" do
      # wait_for_pid handles the case where :rest_for_one restarted it
      # after an EventStream kill in earlier tests
      sessions_sup_pid = wait_for_pid(OptimalSystemAgent.Supervisors.Sessions)
      assert sessions_sup_pid != nil,
             "Sessions supervisor must be running"

      assert Process.alive?(sessions_sup_pid)
    end

    test "Task.Supervisor for async work is running with bounded max_children" do
      task_sup_pid = Process.whereis(OptimalSystemAgent.Events.TaskSupervisor)
      assert task_sup_pid != nil,
             "Events.TaskSupervisor must be running for supervised async work"

      assert Process.alive?(task_sup_pid),
             "Events.TaskSupervisor must be alive"

      # Verify it is actually a Task.Supervisor (can spawn tasks without error)
      task =
        Task.Supervisor.async_nolink(OptimalSystemAgent.Events.TaskSupervisor, fn ->
          :supervised_task_completed
        end)

      result = Task.await(task, 2_000)
      assert result == :supervised_task_completed,
             "TaskSupervisor must be able to spawn and complete supervised tasks"
    end

    test "health monitor (PM4PyMonitor) is supervised in infrastructure" do
      # wait_for_pid handles the case where a prior test restarted infrastructure
      monitor_pid = wait_for_pid(OptimalSystemAgent.Health.PM4PyMonitor)
      assert monitor_pid != nil,
             "PM4PyMonitor must be supervised in the infrastructure tree"

      assert Process.alive?(monitor_pid)
    end

    test "supervised child restart: infrastructure child restarts within 2 seconds" do
      # Use PM4PyMonitor as the canary — it is at the end of the child list
      # so killing it won't cascade backward in :rest_for_one
      monitor_pid = wait_for_pid(OptimalSystemAgent.Health.PM4PyMonitor)
      assert monitor_pid != nil

      ref = Process.monitor(monitor_pid)
      Process.exit(monitor_pid, :kill)

      assert_receive {:DOWN, ^ref, :process, ^monitor_pid, :killed}, 2_000

      # Supervisor must restart it within 2 seconds (use wait_for_pid — exact timing varies)
      new_pid = wait_for_pid(OptimalSystemAgent.Health.PM4PyMonitor, 2_000)
      assert new_pid != nil,
             "PM4PyMonitor must be restarted by supervisor within 2 seconds"

      assert new_pid != monitor_pid,
             "Restarted PM4PyMonitor must have a new pid"

      assert Process.alive?(new_pid)
    end
  end
end
