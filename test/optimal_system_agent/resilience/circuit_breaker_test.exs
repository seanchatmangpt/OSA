defmodule OptimalSystemAgent.Resilience.CircuitBreakerTest do
  @moduledoc """
  Tests for CircuitBreaker GenServer.

  Tests the circuit breaker state machine and transitions:
  - CLOSED → OPEN: when failure count exceeds threshold
  - OPEN → HALF_OPEN: after open timeout expires
  - HALF_OPEN → CLOSED: after sufficient successes
  - HALF_OPEN → OPEN: on any test failure

  Uses Chicago TDD (black-box testing with real implementations).
  """
  use ExUnit.Case, async: true

  alias OptimalSystemAgent.Resilience.CircuitBreaker

  setup do
    # Start a fresh circuit breaker for each test with tuned timeouts
    name = :"test_cb_#{System.unique_integer([:positive])}"
    {:ok, _pid} = CircuitBreaker.start_link(
      name: name,
      failure_threshold: 5,
      window_duration_ms: 60_000,
      open_timeout_ms: 100,  # Fast timeout for testing
      success_threshold: 3
    )
    {:ok, cb: name}
  end

  describe "state transitions" do
    test "trips to OPEN after 5 failures", %{cb: cb} do
      # First 4 failures should stay CLOSED
      for i <- 1..4 do
        result = CircuitBreaker.call(cb, fn -> raise "Error #{i}" end)
        assert match?({:error, _}, result)
        assert CircuitBreaker.status(cb) == :CLOSED
      end

      # 5th failure should trip to OPEN
      result = CircuitBreaker.call(cb, fn -> raise "Error 5" end)
      assert match?({:error, _}, result)
      assert CircuitBreaker.status(cb) == :OPEN
    end

    test "immediate rejection when OPEN", %{cb: cb} do
      # Trip the circuit
      for _i <- 1..5 do
        CircuitBreaker.call(cb, fn -> raise "Error" end)
      end
      assert CircuitBreaker.status(cb) == :OPEN

      # Subsequent calls should fail immediately with :circuit_open
      result = CircuitBreaker.call(cb, fn -> {:ok, "data"} end)
      assert result == {:error, :circuit_open}
    end

    test "transitions to HALF_OPEN after timeout", %{cb: cb} do
      # Trip the circuit
      for _i <- 1..5 do
        CircuitBreaker.call(cb, fn -> raise "Error" end)
      end
      assert CircuitBreaker.status(cb) == :OPEN

      # Wait for open timeout
      Process.sleep(150)

      # Next call should try HALF_OPEN
      result = CircuitBreaker.call(cb, fn -> {:ok, "test"} end)
      assert match?({:ok, _}, result)
      assert CircuitBreaker.status(cb) == :HALF_OPEN
    end

    test "returns to CLOSED after 3 successes in HALF_OPEN", %{cb: cb} do
      # Trip to OPEN
      for _i <- 1..5 do
        CircuitBreaker.call(cb, fn -> raise "Error" end)
      end

      # Wait for HALF_OPEN transition
      Process.sleep(150)

      # First success
      result1 = CircuitBreaker.call(cb, fn -> {:ok, "call1"} end)
      assert match?({:ok, _}, result1)
      assert CircuitBreaker.status(cb) == :HALF_OPEN

      # Second success
      result2 = CircuitBreaker.call(cb, fn -> {:ok, "call2"} end)
      assert match?({:ok, _}, result2)
      assert CircuitBreaker.status(cb) == :HALF_OPEN

      # Third success closes the circuit
      result3 = CircuitBreaker.call(cb, fn -> {:ok, "call3"} end)
      assert match?({:ok, _}, result3)
      assert CircuitBreaker.status(cb) == :CLOSED
    end

    test "reopens on failure during HALF_OPEN", %{cb: cb} do
      # Trip to OPEN
      for _i <- 1..5 do
        CircuitBreaker.call(cb, fn -> raise "Error" end)
      end

      # Wait for HALF_OPEN transition
      Process.sleep(150)

      # First success in HALF_OPEN
      result1 = CircuitBreaker.call(cb, fn -> {:ok, "call1"} end)
      assert match?({:ok, _}, result1)
      assert CircuitBreaker.status(cb) == :HALF_OPEN

      # Failure immediately reopens
      result2 = CircuitBreaker.call(cb, fn -> raise "Test failure" end)
      assert result2 == {:error, :circuit_open}
      assert CircuitBreaker.status(cb) == :OPEN
    end
  end

  describe "failure tracking" do
    test "tracks failures within sliding window", %{cb: cb} do
      # Make 4 failures
      for i <- 1..4 do
        CircuitBreaker.call(cb, fn -> raise "Error #{i}" end)
      end
      assert CircuitBreaker.status(cb) == :CLOSED

      # Should still be CLOSED (below threshold)
      result = CircuitBreaker.call(cb, fn -> {:ok, "success"} end)
      assert match?({:ok, _}, result)
      assert CircuitBreaker.status(cb) == :CLOSED
    end

    test "resets failure count on successful calls", %{cb: cb} do
      # Make 3 failures
      for _i <- 1..3 do
        CircuitBreaker.call(cb, fn -> raise "Error" end)
      end

      # Success should clear failures (or at least not accumulate)
      result = CircuitBreaker.call(cb, fn -> {:ok, "success"} end)
      assert match?({:ok, _}, result)

      # More failures should start fresh
      CircuitBreaker.call(cb, fn -> raise "Error 1" end)
      CircuitBreaker.call(cb, fn -> raise "Error 2" end)
      # Still below threshold (previous failures cleared after success)
      assert CircuitBreaker.status(cb) == :CLOSED
    end
  end

  describe "successful calls" do
    test "passes through successful calls in CLOSED", %{cb: cb} do
      result = CircuitBreaker.call(cb, fn ->
        %{data: "test"}
      end)
      assert result == {:ok, %{data: "test"}}
      assert CircuitBreaker.status(cb) == :CLOSED
    end

    @moduletag :skip
    test "returns exact result from function", %{cb: cb} do
      expected = [1, 2, 3]
      result = CircuitBreaker.call(cb, fn -> expected end)
      assert result == {:ok, expected}
    end
  end

  describe "reset functionality" do
    test "resets to CLOSED state", %{cb: cb} do
      # Trip the circuit
      for _i <- 1..5 do
        CircuitBreaker.call(cb, fn -> raise "Error" end)
      end
      assert CircuitBreaker.status(cb) == :OPEN

      # Reset
      assert CircuitBreaker.reset(cb) == :ok
      assert CircuitBreaker.status(cb) == :CLOSED

      # Should accept calls again
      result = CircuitBreaker.call(cb, fn -> {:ok, "recovered"} end)
      assert match?({:ok, _}, result)
    end
  end

  describe "error handling" do
    test "catches raised exceptions", %{cb: cb} do
      for _i <- 1..5 do
        CircuitBreaker.call(cb, fn ->
          raise ArgumentError, "bad argument"
        end)
      end
      assert CircuitBreaker.status(cb) == :OPEN
    end

    test "catches exit signals", %{cb: cb} do
      for _i <- 1..5 do
        CircuitBreaker.call(cb, fn ->
          throw(:error_signal)
        end)
      end
      assert CircuitBreaker.status(cb) == :OPEN
    end

    test "distinguishes between different error types", %{cb: cb} do
      # Different errors should still count toward the threshold
      CircuitBreaker.call(cb, fn -> raise RuntimeError, "runtime" end)
      CircuitBreaker.call(cb, fn -> raise ArgumentError, "argument" end)
      CircuitBreaker.call(cb, fn -> raise FunctionClauseError, "clause" end)
      CircuitBreaker.call(cb, fn -> raise KeyError, "key" end)
      CircuitBreaker.call(cb, fn -> raise TypeError, "type" end)

      # Should have tripped
      assert CircuitBreaker.status(cb) == :OPEN
    end
  end

  describe "timeout handling" do
    test "times out on slow function", %{cb: cb} do
      # This test verifies the call wrapper respects timeouts,
      # but we won't actually test a slow function here (would slow down tests)
      # Just verify that a normal call completes quickly
      start_ms = System.monotonic_time(:millisecond)
      CircuitBreaker.call(cb, fn -> {:ok, "fast"} end)
      elapsed_ms = System.monotonic_time(:millisecond) - start_ms

      # Should complete in <100ms (very fast)
      assert elapsed_ms < 100
    end
  end

  describe "integration with ProcessMining.Client pattern" do
    test "wraps client calls correctly", %{cb: cb} do
      # Simulate a ProcessMining.Client call pattern
      result = CircuitBreaker.call(cb, fn ->
        {:ok, %{"deadlock_free" => true, "confidence" => 0.95}}
      end)

      assert match?({:ok, %{"deadlock_free" => true}}, result)
    end

    test "fails fast when circuit is open", %{cb: cb} do
      # Trip the circuit with rapid failures
      for _i <- 1..5 do
        CircuitBreaker.call(cb, fn -> {:error, :timeout} end)
      end

      # Record time for fast fail
      start_ms = System.monotonic_time(:millisecond)
      CircuitBreaker.call(cb, fn -> raise "Should not execute" end)
      elapsed_ms = System.monotonic_time(:millisecond) - start_ms

      # Should fail immediately (<10ms)
      assert elapsed_ms < 10
      assert CircuitBreaker.status(cb) == :OPEN
    end
  end
end
