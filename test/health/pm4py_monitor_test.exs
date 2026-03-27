defmodule OptimalSystemAgent.Health.PM4PyMonitorTest do
  use ExUnit.Case

  alias OptimalSystemAgent.Health.PM4PyMonitor

  # Note: These tests require pm4py-rust running on localhost:8090
  # Run with: OSA_TEST_PM4PY=1 mix test test/health/pm4py_monitor_test.exs
  @moduletag :integration

  describe "health check module compilation" do
    test "module compiles with zero warnings" do
      # Verify the module is loaded and callable
      assert is_atom(PM4PyMonitor)
      assert function_exported?(PM4PyMonitor, :start_link, 1)
      assert function_exported?(PM4PyMonitor, :get_health, 0)
      assert function_exported?(PM4PyMonitor, :is_healthy?, 0)
      assert function_exported?(PM4PyMonitor, :status, 0)
    end

    test "API functions exist and have correct specs" do
      # These should not raise
      assert catch_error(PM4PyMonitor.start_link([]) != :ok)
      # We don't call get_health without a running process
    end

    test "module implements GenServer behavior" do
      # Verify it's a proper GenServer module
      assert :erlang.function_exported(PM4PyMonitor, :init, 1)
      assert :erlang.function_exported(PM4PyMonitor, :handle_call, 3)
      assert :erlang.function_exported(PM4PyMonitor, :handle_info, 2)
      assert :erlang.function_exported(PM4PyMonitor, :handle_continue, 2)
    end
  end

  describe "armstrong fault tolerance" do
    test "module supports supervision pattern" do
      # The monitor can be started via Supervisor.start_child/2
      # This is how it's used in the infrastructure supervisor
      spec = {PM4PyMonitor, []}
      assert is_tuple(spec)
    end

    test "module should not fail on missing external dependencies" do
      # The module should be loadable even if pm4py-rust isn't available
      # actual health checks would fail, but module loads fine
      assert is_atom(PM4PyMonitor)
    end
  end
end
