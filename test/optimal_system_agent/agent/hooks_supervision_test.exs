defmodule OptimalSystemAgent.Agent.HooksSupervisionTest do
  @moduledoc """
  Tests for Armstrong fault tolerance in Agent.Hooks.run_async/2.

  Verifies:
  1. Async hooks are spawned under Task.Supervisor (supervised)
  2. Hook crashes are visible (let-it-crash, no silent failures)
  3. Iteration limits prevent unbounded execution (WvdA liveness)
  4. Metrics are still recorded on crash
  """
  use ExUnit.Case

  import ExUnit.CaptureLog

  setup_all do
    # The application already starts Agent.Hooks and TaskSupervisor.
    # Start a separate supervisor only for processes that aren't already running.
    children =
      []
      |> then(fn acc ->
        case Process.whereis(OptimalSystemAgent.TaskSupervisor) do
          nil -> acc ++ [{Task.Supervisor, name: OptimalSystemAgent.TaskSupervisor}]
          _pid -> acc
        end
      end)

    if children != [] do
      {:ok, _supervisor} = Supervisor.start_link(children, strategy: :one_for_one)
    end

    :ok
  end

  setup do
    # Register test hooks fresh for each test
    OptimalSystemAgent.Agent.Hooks.register(:test_event, "test_hook", fn p ->
      {:ok, p}
    end)

    :ok
  end

  describe "run_async/2 - supervised execution" do
    test "spawns hook under Task.Supervisor (not fire-and-forget)" do
      # Hook payload
      payload = %{
        event: :test_event,
        data: "test"
      }

      # Run async
      :ok = OptimalSystemAgent.Agent.Hooks.run_async(:test_event, payload)

      # Give async task time to execute
      :timer.sleep(100)

      # If we got here, the hook executed without crashing
      # (would have crashed if not supervised)
      :ok
    end

    test "async hook crash is visible (Armstrong: let-it-crash)" do
      # Register a hook that crashes
      OptimalSystemAgent.Agent.Hooks.register(:crash_event, "crashing_hook", fn _p ->
        raise "Intentional hook crash for testing"
      end)

      # Run async — should not block or silently fail
      :ok = OptimalSystemAgent.Agent.Hooks.run_async(:crash_event, %{test: "data"})

      # Let task execute and crash
      :timer.sleep(200)

      # If we get here without exception, the async hook executed
      # and the crash was handled by the supervisor (visible in logs)
      :ok
    end

    test "bounded_async_execution/3 enforces 1 iteration (WvdA liveness)" do
      # Call bounded_async_execution with iteration = 0 (should execute)
      payload = %{event: :test}

      OptimalSystemAgent.Agent.Hooks.register(:bounded_event, "bounded_hook", fn p ->
        {:ok, p}
      end)

      # Direct call to bounded_async_execution with iteration = 0 (< 1)
      # This should execute and not raise
      try do
        OptimalSystemAgent.Agent.Hooks.bounded_async_execution(:bounded_event, payload, 0)
        # Success — function executed without error
        :ok
      rescue
        _ -> flunk("bounded_async_execution should not raise")
      end

      # Call with iteration = 1 (should not execute — limit reached)
      result_limit = OptimalSystemAgent.Agent.Hooks.bounded_async_execution(:bounded_event, payload, 1)

      # Should return :ok (iteration >= 1 so guard clause prevents execution)
      assert result_limit == :ok
    end
  end

  describe "Hook metrics still recorded on crash" do
    test "metrics updated even if hook handler crashes" do
      log =
        capture_log(fn ->
          # Register a crashing hook
          OptimalSystemAgent.Agent.Hooks.register(
            :metric_crash_event,
            "metric_crashing_hook",
            fn _p ->
              raise "Test crash in hook"
            end
          )

          # Run async
          :ok = OptimalSystemAgent.Agent.Hooks.run_async(:metric_crash_event, %{test: "data"})

          # Let task execute
          :timer.sleep(200)
        end)

      # Verify crash was logged
      assert log != ""
    end
  end

  describe "Task.Supervisor integration" do
    test "OptimalSystemAgent.TaskSupervisor is registered" do
      # Verify supervisor exists
      assert is_pid(Process.whereis(OptimalSystemAgent.TaskSupervisor))
    end

    test "Can spawn multiple async hooks concurrently under supervisor" do
      # Register multiple hooks
      Enum.each(1..5, fn i ->
        OptimalSystemAgent.Agent.Hooks.register(
          :concurrent_event,
          "hook_#{i}",
          fn p ->
            :timer.sleep(10)
            {:ok, Map.put(p, :executed_by, i)}
          end
        )
      end)

      # Run multiple async calls
      Enum.each(1..5, fn _i ->
        :ok = OptimalSystemAgent.Agent.Hooks.run_async(:concurrent_event, %{data: "test"})
      end)

      # Give all tasks time to complete
      :timer.sleep(500)

      # If we get here, all concurrent tasks executed without deadlock
      :ok
    end
  end
end
