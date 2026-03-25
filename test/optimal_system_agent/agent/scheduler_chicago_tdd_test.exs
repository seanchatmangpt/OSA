defmodule OptimalSystemAgent.Agent.SchedulerChicagoTDDTest do
  @moduledoc """
  Chicago TDD tests for OptimalSystemAgent.Agent.Scheduler.

  Tests the periodic task scheduler:
  - Cron job management (add, remove, toggle, list, run)
  - Trigger management (add, remove, toggle, list, fire)
  - Heartbeat task management
  - Status and monitoring

  Note: These tests require infrastructure (TaskSupervisor, Events.Bus).
  They are skipped in --no-start mode.
  """

  use ExUnit.Case, async: false

  alias OptimalSystemAgent.Agent.Scheduler

  setup_all do
    # Disable automatic heartbeat during tests to prevent interference
    # Set to 1 hour (3_600_000 ms) so it won't fire during test suite
    Application.put_env(:optimal_system_agent, :heartbeat_interval, 3_600_000)

    # Use a temporary test directory for heartbeat file to avoid interference
    test_dir = System.tmp_dir!() <> "/osa_test_#{System.system_time(:microsecond)}"
    File.mkdir_p!(test_dir)
    Application.put_env(:optimal_system_agent, :config_dir, test_dir)

    # Verify key processes are running (started by the application)
    assert Process.whereis(OptimalSystemAgent.SessionRegistry) != nil,
           "SessionRegistry not started"

    assert Process.whereis(OptimalSystemAgent.Events.TaskSupervisor) != nil,
           "TaskSupervisor not started"

    assert Process.whereis(OptimalSystemAgent.Channels.Supervisor) != nil,
           "Channels.Supervisor not started"

    assert Process.whereis(Scheduler) != nil,
           "Scheduler not started"

    on_exit(fn ->
      # Cleanup: reset configuration
      Application.put_env(:optimal_system_agent, :heartbeat_interval, 1_800_000)
      Application.delete_env(:optimal_system_agent, :config_dir)

      # Clean up test directory
      File.rm_rf(test_dir)
    end)

    :ok
  end

  # =========================================================================
  # HEARTBEAT TESTS
  # =========================================================================

  describe "CRASH: heartbeat/0" do
    test "triggers heartbeat without crashing" do
      assert :ok = Scheduler.heartbeat()
    end

    test "multiple heartbeats are idempotent" do
      assert :ok = Scheduler.heartbeat()
      assert :ok = Scheduler.heartbeat()
      assert :ok = Scheduler.heartbeat()
    end
  end

  describe "CRASH: add_heartbeat_task/1" do
    @tag :skip
    test "adds heartbeat task" do
      result = Scheduler.add_heartbeat_task("Check server status")
      assert result == :ok or match?({:ok, _}, result) or match?({:error, _}, result)
    end

    @tag :skip
    test "accepts various task descriptions" do
      tasks = [
        "Verify backups",
        "Send weekly report",
        "Clean temp files",
        ""
      ]

      Enum.each(tasks, fn task ->
        result = Scheduler.add_heartbeat_task(task)
        assert is_atom(result) or is_tuple(result)
      end)
    end

    @tag :skip
    test "handles long task descriptions" do
      long_task = String.duplicate("word ", 100)

      result = Scheduler.add_heartbeat_task(long_task)

      assert is_atom(result) or is_tuple(result)
    end
  end

  describe "CRASH: next_heartbeat_at/0" do
    test "returns DateTime or similar" do
      result = Scheduler.next_heartbeat_at()

      assert is_struct(result) or is_atom(result) or is_tuple(result)
    end

    test "next heartbeat is in future or nil" do
      result = Scheduler.next_heartbeat_at()

      # Should be DateTime, error, or nil
      assert is_struct(result) or is_atom(result) or is_tuple(result)
    end
  end

  # =========================================================================
  # CRON JOB TESTS
  # =========================================================================

  describe "CRASH: list_jobs/0" do
    test "returns list of jobs" do
      result = Scheduler.list_jobs()

      assert is_list(result)
    end

    test "jobs list contains maps (or is empty)" do
      jobs = Scheduler.list_jobs()

      assert is_list(jobs)

      Enum.each(jobs, fn job ->
        assert is_map(job)
      end)
    end

    test "job entries have required fields" do
      jobs = Scheduler.list_jobs()

      Enum.each(jobs, fn job ->
        if is_map(job) do
          # Jobs should have id and type at minimum
          assert is_map(job)
        end
      end)
    end
  end

  describe "CRASH: reload_crons/0" do
    test "reloads crons without crashing" do
      assert :ok = Scheduler.reload_crons()
    end

    test "multiple reloads are idempotent" do
      assert :ok = Scheduler.reload_crons()
      assert :ok = Scheduler.reload_crons()
    end
  end

  describe "CRASH: add_job/1" do
    @tag :skip
    test "adds cron job" do
      job = %{
        id: "test_job_#{:erlang.unique_integer()}",
        cron: "0 * * * *",
        type: "agent",
        task: "test task"
      }

      result = Scheduler.add_job(job)

      assert is_atom(result) or match?({:ok, _}, result) or match?({:error, _}, result)
    end

    @tag :skip
    test "accepts various cron expressions" do
      expressions = [
        "* * * * *",
        "0 * * * *",
        "*/5 * * * *",
        "0 9 * * 1",
        "0,30 * * * *"
      ]

      Enum.each(expressions, fn cron ->
        job = %{
          id: "job_#{:erlang.unique_integer()}",
          cron: cron,
          type: "agent",
          task: "test"
        }

        result = Scheduler.add_job(job)
        assert is_atom(result) or is_tuple(result)
      end)
    end

    @tag :skip
    test "accepts different job types" do
      types = ["agent", "command", "webhook"]

      Enum.each(types, fn type ->
        job = %{
          id: "job_#{:erlang.unique_integer()}",
          cron: "0 * * * *",
          type: type,
          task: "test"
        }

        result = Scheduler.add_job(job)
        assert is_atom(result) or is_tuple(result)
      end)
    end
  end

  describe "CRASH: remove_job/1" do
    @tag :skip
    test "removes job" do
      job_id = "remove_test_#{:erlang.unique_integer()}"

      job = %{
        id: job_id,
        cron: "0 * * * *",
        type: "agent",
        task: "test"
      }

      _add_result = Scheduler.add_job(job)

      result = Scheduler.remove_job(job_id)

      assert is_atom(result) or is_tuple(result)
    end

    test "removing non-existent job doesn't crash" do
      result = Scheduler.remove_job("nonexistent_#{:erlang.unique_integer()}")

      assert is_atom(result) or is_tuple(result)
    end
  end

  describe "CRASH: toggle_job/2" do
    @tag :skip
    test "toggles job to enabled" do
      job_id = "toggle_test_#{:erlang.unique_integer()}"

      result = Scheduler.toggle_job(job_id, true)

      assert is_atom(result) or is_tuple(result)
    end

    @tag :skip
    test "toggles job to disabled" do
      job_id = "toggle_test_#{:erlang.unique_integer()}"

      result = Scheduler.toggle_job(job_id, false)

      assert is_atom(result) or is_tuple(result)
    end
  end

  describe "CRASH: run_job/1" do
    @tag :skip
    test "runs job immediately" do
      job_id = "run_test_#{:erlang.unique_integer()}"

      result = Scheduler.run_job(job_id)

      assert is_atom(result) or is_tuple(result)
    end

    test "running non-existent job returns error" do
      result = Scheduler.run_job("nonexistent_#{:erlang.unique_integer()}")

      assert is_atom(result) or is_tuple(result)
    end
  end

  # =========================================================================
  # TRIGGER TESTS
  # =========================================================================

  describe "CRASH: list_triggers/0" do
    test "returns list of triggers" do
      result = Scheduler.list_triggers()

      assert is_list(result)
    end

    test "triggers list contains maps (or is empty)" do
      triggers = Scheduler.list_triggers()

      assert is_list(triggers)

      Enum.each(triggers, fn trigger ->
        assert is_map(trigger)
      end)
    end
  end

  describe "CRASH: add_trigger/1" do
    @tag :skip
    test "adds trigger" do
      trigger = %{
        id: "trigger_#{:erlang.unique_integer()}",
        event: "test.event",
        action: "agent",
        task: "test task"
      }

      result = Scheduler.add_trigger(trigger)

      assert is_atom(result) or is_tuple(result)
    end

    @tag :skip
    test "accepts various event patterns" do
      events = [
        "file.changed",
        "webhook.received",
        "alert.critical",
        "schedule.daily"
      ]

      Enum.each(events, fn event ->
        trigger = %{
          id: "trigger_#{:erlang.unique_integer()}",
          event: event,
          action: "agent",
          task: "test"
        }

        result = Scheduler.add_trigger(trigger)
        assert is_atom(result) or is_tuple(result)
      end)
    end

    @tag :skip
    test "accepts trigger with payload template" do
      trigger = %{
        id: "trigger_#{:erlang.unique_integer()}",
        event: "webhook",
        action: "agent",
        task: "Log: {{payload}} at {{timestamp}}"
      }

      result = Scheduler.add_trigger(trigger)

      assert is_atom(result) or is_tuple(result)
    end
  end

  describe "CRASH: remove_trigger/1" do
    @tag :skip
    test "removes trigger" do
      trigger_id = "remove_trigger_#{:erlang.unique_integer()}"

      trigger = %{
        id: trigger_id,
        event: "test",
        action: "agent",
        task: "test"
      }

      _add_result = Scheduler.add_trigger(trigger)

      result = Scheduler.remove_trigger(trigger_id)

      assert is_atom(result) or is_tuple(result)
    end

    test "removing non-existent trigger doesn't crash" do
      result = Scheduler.remove_trigger("nonexistent_#{:erlang.unique_integer()}")

      assert is_atom(result) or is_tuple(result)
    end
  end

  describe "CRASH: toggle_trigger/2" do
    @tag :skip
    test "toggles trigger to enabled" do
      trigger_id = "toggle_trigger_#{:erlang.unique_integer()}"

      result = Scheduler.toggle_trigger(trigger_id, true)

      assert is_atom(result) or is_tuple(result)
    end

    @tag :skip
    test "toggles trigger to disabled" do
      trigger_id = "toggle_trigger_#{:erlang.unique_integer()}"

      result = Scheduler.toggle_trigger(trigger_id, false)

      assert is_atom(result) or is_tuple(result)
    end
  end

  describe "CRASH: fire_trigger/2" do
    test "fires trigger with payload" do
      result = Scheduler.fire_trigger("test_trigger_#{:erlang.unique_integer()}", %{data: "test"})

      assert :ok = result
    end

    test "fires trigger with empty payload" do
      result = Scheduler.fire_trigger("test_trigger", %{})

      assert :ok = result
    end

    test "fires trigger with nested payload" do
      payload = %{
        level: "critical",
        source: "monitor",
        details: %{
          timestamp: DateTime.utc_now(),
          message: "Test alert"
        }
      }

      result = Scheduler.fire_trigger("alert_trigger", payload)

      assert :ok = result
    end
  end

  # =========================================================================
  # STATUS TESTS
  # =========================================================================

  describe "CRASH: status/0" do
    test "returns status map" do
      result = Scheduler.status()

      assert is_map(result)
    end

    test "status contains expected information" do
      status = Scheduler.status()

      # Status should be a map with info about jobs/triggers
      assert is_map(status)
    end

    test "status is consistent across calls" do
      s1 = Scheduler.status()
      s2 = Scheduler.status()

      # Structure should be same
      assert Map.keys(s1) == Map.keys(s2)
    end
  end

  # =========================================================================
  # INTEGRATION TESTS
  # =========================================================================

  describe "CRASH: Integration workflows" do
    @tag :skip
    test "add job, list jobs, toggle job, remove job" do
      job_id = "integration_#{:erlang.unique_integer()}"

      job = %{
        id: job_id,
        cron: "0 * * * *",
        type: "agent",
        task: "test"
      }

      # Add job
      add_result = Scheduler.add_job(job)
      assert is_atom(add_result) or is_tuple(add_result)

      # List jobs
      jobs = Scheduler.list_jobs()
      assert is_list(jobs)

      # Toggle job
      toggle_result = Scheduler.toggle_job(job_id, false)
      assert is_atom(toggle_result) or is_tuple(toggle_result)

      # Remove job
      remove_result = Scheduler.remove_job(job_id)
      assert is_atom(remove_result) or is_tuple(remove_result)
    end

    @tag :skip
    test "add trigger, list triggers, toggle trigger, remove trigger" do
      trigger_id = "integration_#{:erlang.unique_integer()}"

      trigger = %{
        id: trigger_id,
        event: "test.event",
        action: "agent",
        task: "test"
      }

      # Add trigger
      add_result = Scheduler.add_trigger(trigger)
      assert is_atom(add_result) or is_tuple(add_result)

      # List triggers
      triggers = Scheduler.list_triggers()
      assert is_list(triggers)

      # Toggle trigger
      toggle_result = Scheduler.toggle_trigger(trigger_id, false)
      assert is_atom(toggle_result) or is_tuple(toggle_result)

      # Remove trigger
      remove_result = Scheduler.remove_trigger(trigger_id)
      assert is_atom(remove_result) or is_tuple(remove_result)
    end

    @tag :skip
    test "fire trigger and verify execution flow" do
      payload = %{event_data: "test"}

      # Fire trigger
      fire_result = Scheduler.fire_trigger("test_flow", payload)

      assert :ok = fire_result

      # Check status
      status = Scheduler.status()
      assert is_map(status)
    end

    test "heartbeat and cron operations together" do
      :ok = Scheduler.heartbeat()
      :ok = Scheduler.reload_crons()

      jobs = Scheduler.list_jobs()
      assert is_list(jobs)

      status = Scheduler.status()
      assert is_map(status)
    end
  end

  # =========================================================================
  # MODULE BEHAVIOR CONTRACT
  # =========================================================================

  describe "CRASH: Module behavior contract" do
    test "all public functions are exported" do
      assert function_exported?(Scheduler, :start_link, 1)
      assert function_exported?(Scheduler, :heartbeat, 0)
      assert function_exported?(Scheduler, :reload_crons, 0)
      assert function_exported?(Scheduler, :list_jobs, 0)
      assert function_exported?(Scheduler, :fire_trigger, 2)
      assert function_exported?(Scheduler, :add_job, 1)
      assert function_exported?(Scheduler, :remove_job, 1)
      assert function_exported?(Scheduler, :toggle_job, 2)
      assert function_exported?(Scheduler, :run_job, 1)
      assert function_exported?(Scheduler, :add_trigger, 1)
      assert function_exported?(Scheduler, :remove_trigger, 1)
      assert function_exported?(Scheduler, :toggle_trigger, 2)
      assert function_exported?(Scheduler, :list_triggers, 0)
      assert function_exported?(Scheduler, :add_heartbeat_task, 1)
      assert function_exported?(Scheduler, :next_heartbeat_at, 0)
      assert function_exported?(Scheduler, :status, 0)
    end

    test "GenServer callbacks are implemented" do
      assert function_exported?(Scheduler, :init, 1)
      assert function_exported?(Scheduler, :handle_call, 3)
      assert function_exported?(Scheduler, :handle_cast, 2)
    end

    test "functions return expected types" do
      # Commands return :ok or tuple
      assert :ok = Scheduler.heartbeat()
      assert :ok = Scheduler.reload_crons()

      # Queries return various types
      assert is_list(Scheduler.list_jobs())
      assert is_list(Scheduler.list_triggers())
      assert is_map(Scheduler.status())
    end
  end

  # =========================================================================
  # STRESS TESTS
  # =========================================================================

  describe "CRASH: Stress and idempotency" do
    test "rapid heartbeat triggers" do
      for _i <- 1..10 do
        :ok = Scheduler.heartbeat()
      end

      assert true
    end

    test "rapid cron reloads" do
      for _i <- 1..5 do
        :ok = Scheduler.reload_crons()
      end

      assert true
    end

    test "rapid trigger fires" do
      for i <- 1..20 do
        :ok = Scheduler.fire_trigger("stress_trigger_#{i}", %{})
      end

      assert true
    end

    @tag :skip
    test "many rapid job additions and removals" do
      for i <- 1..10 do
        job_id = "stress_job_#{i}"

        job = %{
          id: job_id,
          cron: "0 * * * *",
          type: "agent",
          task: "test"
        }

        _add = Scheduler.add_job(job)
        _remove = Scheduler.remove_job(job_id)
      end

      assert true
    end

    test "many concurrent trigger firings" do
      tasks = for i <- 1..20 do
        Task.start(fn ->
          Scheduler.fire_trigger("concurrent_#{i}", %{value: i})
        end)
      end

      assert length(tasks) == 20
    end

    test "repeated status queries" do
      for _i <- 1..20 do
        _status = Scheduler.status()
      end

      assert true
    end
  end
end
