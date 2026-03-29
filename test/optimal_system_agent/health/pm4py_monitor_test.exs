defmodule OptimalSystemAgent.Health.PM4PyMonitorTest do
  @moduledoc """
  Chicago TDD tests for PM4PyMonitor GenServer.

  Verifies observable behavior:
  - ping_pm4py/0 returns error tuple when pm4py-rust is unreachable
  - get_health/0 returns one of :ok | :degraded | :down
  - is_healthy?/0 returns a boolean consistent with get_health/0
  - status/0 returns a map with required diagnostic keys and numeric counters
  - is_healthy? invariant: is_healthy?() == (get_health() == :ok)
  - WvdA timeout compliance: all API calls complete within bounded time

  The GenServer is started by the application supervision tree (Infrastructure
  supervisor). Tests guard with start_supervised! when it isn't already running.

  Tests do not require pm4py-rust to be running; all error paths are tested
  with the upstream service absent.
  """
  use ExUnit.Case, async: false

  alias OptimalSystemAgent.Health.PM4PyMonitor

  setup do
    # PM4PyMonitor is started by the Infrastructure supervisor.
    # When running with mix test (full app), it's already alive.
    # When running in isolation, start it here.
    case Process.whereis(PM4PyMonitor) do
      nil ->
        start_supervised!({PM4PyMonitor, []})

      _pid ->
        :ok
    end

    :ok
  end

  # ---------------------------------------------------------------------------
  # ping_pm4py/0 — public (doc: false) function for isolation testing
  # ---------------------------------------------------------------------------

  describe "ping_pm4py/0" do
    test "returns error tuple when pm4py-rust is unreachable" do
      # pm4py-rust is not running in CI.
      # ping_pm4py/0 calls ProcessMining.Client.check_deadlock_free, which itself
      # may not be started. Either way, an {:error, _} tuple is expected.
      result = PM4PyMonitor.ping_pm4py()

      assert match?({:error, _}, result),
             "Expected {:error, _} when pm4py-rust is down, got: #{inspect(result)}"
    end

    test "always returns a 2-tuple with :ok or :error as first element" do
      result = PM4PyMonitor.ping_pm4py()

      case result do
        {:ok, latency_ms} ->
          assert is_integer(latency_ms) or is_float(latency_ms),
                 "latency_ms must be numeric on success, got: #{inspect(latency_ms)}"

        {:error, _reason} ->
          # Expected when pm4py-rust is unavailable
          :ok

        other ->
          flunk("ping_pm4py/0 must return {:ok, _} or {:error, _}, got: #{inspect(other)}")
      end
    end
  end

  # ---------------------------------------------------------------------------
  # get_health/0 — current health status
  # ---------------------------------------------------------------------------

  describe "get_health/0" do
    test "returns a valid health atom" do
      result = PM4PyMonitor.get_health()

      assert result in [:ok, :degraded, :down],
             "get_health/0 must return :ok | :degraded | :down, got: #{inspect(result)}"
    end

    test "returns an atom (not nil, not a string)" do
      result = PM4PyMonitor.get_health()
      assert is_atom(result), "get_health/0 must return an atom, got: #{inspect(result)}"
    end
  end

  # ---------------------------------------------------------------------------
  # is_healthy?/0 — boolean health predicate
  # ---------------------------------------------------------------------------

  describe "is_healthy?/0" do
    test "returns a boolean" do
      result = PM4PyMonitor.is_healthy?()
      assert is_boolean(result), "is_healthy?/0 must return a boolean, got: #{inspect(result)}"
    end

    test "is consistent with get_health/0 — invariant: is_healthy?() == (get_health() == :ok)" do
      # Sample both within microseconds to avoid a status-change race.
      # Both calls are synchronous GenServer.call — current state is consistent.
      current_status = PM4PyMonitor.get_health()
      is_healthy = PM4PyMonitor.is_healthy?()

      assert is_healthy == (current_status == :ok),
             "is_healthy?/0 (#{inspect(is_healthy)}) must equal (get_health() == :ok). " <>
               "get_health/0 returned #{inspect(current_status)}"
    end
  end

  # ---------------------------------------------------------------------------
  # status/0 — full diagnostic state map
  # ---------------------------------------------------------------------------

  describe "status/0" do
    test "returns a map with required diagnostic keys" do
      result = PM4PyMonitor.status()

      assert is_map(result), "status/0 must return a map, got: #{inspect(result)}"

      required_keys = [
        :status,
        :consecutive_errors,
        :total_errors,
        :total_pings,
        :uptime_ms,
        :error_rate
      ]

      for key <- required_keys do
        assert Map.has_key?(result, key),
               "status/0 map must contain key #{inspect(key)}, " <>
                 "got keys: #{inspect(Map.keys(result))}"
      end
    end

    test "status map contains non-negative integer counters" do
      result = PM4PyMonitor.status()

      assert is_integer(result.total_pings) and result.total_pings >= 0,
             "total_pings must be non-negative integer, got: #{inspect(result.total_pings)}"

      assert is_integer(result.total_errors) and result.total_errors >= 0,
             "total_errors must be non-negative integer, got: #{inspect(result.total_errors)}"

      assert is_integer(result.consecutive_errors) and result.consecutive_errors >= 0,
             "consecutive_errors must be non-negative integer, got: #{inspect(result.consecutive_errors)}"

      assert is_integer(result.uptime_ms) and result.uptime_ms >= 0,
             "uptime_ms must be non-negative integer, got: #{inspect(result.uptime_ms)}"
    end

    test "error_rate is a float in [0.0, 100.0]" do
      result = PM4PyMonitor.status()

      assert is_float(result.error_rate),
             "error_rate must be a float, got: #{inspect(result.error_rate)}"

      assert result.error_rate >= 0.0 and result.error_rate <= 100.0,
             "error_rate must be in [0.0, 100.0], got: #{result.error_rate}"
    end

    test "status field in map is consistent with get_health/0" do
      # Both calls hit the same GenServer; state is consistent between the two calls.
      status_map = PM4PyMonitor.status()
      health = PM4PyMonitor.get_health()

      assert status_map.status == health,
             "status/0.status (#{inspect(status_map.status)}) must match " <>
               "get_health/0 (#{inspect(health)})"
    end
  end

  # ---------------------------------------------------------------------------
  # WvdA deadlock-freedom: all API calls complete within timeout
  # ---------------------------------------------------------------------------

  describe "WvdA timeout compliance" do
    test "get_health/0 completes within 6 seconds (WvdA bounded)" do
      # GenServer.call timeout = 5_000ms; fall-through returns :down on timeout.
      start_ms = System.monotonic_time(:millisecond)
      _result = PM4PyMonitor.get_health()
      elapsed_ms = System.monotonic_time(:millisecond) - start_ms

      assert elapsed_ms < 6_000,
             "get_health/0 blocked for #{elapsed_ms}ms, exceeds WvdA 5s bound"
    end

    test "status/0 completes within 6 seconds (WvdA bounded)" do
      start_ms = System.monotonic_time(:millisecond)
      _result = PM4PyMonitor.status()
      elapsed_ms = System.monotonic_time(:millisecond) - start_ms

      assert elapsed_ms < 6_000,
             "status/0 blocked for #{elapsed_ms}ms, exceeds WvdA 5s bound"
    end
  end

  # ---------------------------------------------------------------------------
  # Module API contract
  # ---------------------------------------------------------------------------

  describe "module API contract" do
    test "all public functions are exported with correct arities" do
      exported = PM4PyMonitor.module_info(:exports)

      assert {:get_health, 0} in exported, "get_health/0 must be exported"
      assert {:is_healthy?, 0} in exported, "is_healthy?/0 must be exported"
      assert {:status, 0} in exported, "status/0 must be exported"
      assert {:ping_pm4py, 0} in exported, "ping_pm4py/0 must be exported"
    end
  end
end
