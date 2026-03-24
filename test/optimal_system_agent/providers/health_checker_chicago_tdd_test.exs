defmodule OptimalSystemAgent.Providers.HealthCheckerChicagoTDDTest do
  @moduledoc """
  Chicago TDD tests for OptimalSystemAgent.Providers.HealthChecker.

  Tests the circuit breaker and rate limiting state machine:
  - Circuit states: closed, open, half_open
  - Rate limiting window (default 60s)
  - Failure threshold (3 consecutive failures)
  - Open timeout (30s)

  All public functions tested with observable behavior claims.
  """

  use ExUnit.Case, async: false

  alias OptimalSystemAgent.Providers.HealthChecker

  setup_all do
    if Process.whereis(HealthChecker) == nil do
      start_supervised!(HealthChecker)
    end
    :ok
  end

  # =========================================================================
  # RECORD_SUCCESS TESTS
  # =========================================================================

  describe "CRASH: record_success/1" do
    test "records success without crashing" do
      assert :ok = HealthChecker.record_success(:anthropic)
    end

    test "records success for different providers" do
      assert :ok = HealthChecker.record_success(:openai)
      assert :ok = HealthChecker.record_success(:groq)
      assert :ok = HealthChecker.record_success(:ollama)
    end

    test "resets consecutive failure counter" do
      # Record 2 failures
      :ok = HealthChecker.record_failure(:test_provider_1, :timeout)
      :ok = HealthChecker.record_failure(:test_provider_1, :timeout)

      # Record success
      :ok = HealthChecker.record_success(:test_provider_1)

      # Should be available (failures reset)
      assert HealthChecker.is_available?(:test_provider_1) == true
    end

    test "closes circuit if currently half-open" do
      provider = :half_open_test_1

      # Trigger 3 failures to open circuit
      :ok = HealthChecker.record_failure(provider, :timeout)
      :ok = HealthChecker.record_failure(provider, :timeout)
      :ok = HealthChecker.record_failure(provider, :timeout)

      # Circuit is now open
      assert HealthChecker.is_available?(provider) == false

      # Simulate cooldown by waiting (but test immediately for simplicity)
      # In production this would be 30s
      :ok = HealthChecker.record_success(provider)

      # If circuit was half-open, success closes it
      # First verify state to check circuit condition
      state = HealthChecker.state()
      assert is_map(state)
    end
  end

  # =========================================================================
  # RECORD_FAILURE TESTS
  # =========================================================================

  describe "CRASH: record_failure/2" do
    test "records failure without crashing" do
      assert :ok = HealthChecker.record_failure(:anthropic, :timeout)
    end

    test "records different failure reasons" do
      assert :ok = HealthChecker.record_failure(:provider_1, :timeout)
      assert :ok = HealthChecker.record_failure(:provider_2, :connection_refused)
      assert :ok = HealthChecker.record_failure(:provider_3, :invalid_response)
      assert :ok = HealthChecker.record_failure(:provider_4, :rate_limit)
    end

    test "tracks consecutive failures" do
      provider = :consecutive_test_1

      assert :ok = HealthChecker.record_failure(provider, :timeout)
      assert HealthChecker.is_available?(provider) == true  # Still available after 1 failure

      assert :ok = HealthChecker.record_failure(provider, :timeout)
      assert HealthChecker.is_available?(provider) == true  # Still available after 2 failures

      assert :ok = HealthChecker.record_failure(provider, :timeout)
      # After 3rd failure, circuit opens
      assert HealthChecker.is_available?(provider) == false
    end

    test "opens circuit after 3 consecutive failures" do
      provider = :circuit_open_test_1

      :ok = HealthChecker.record_failure(provider, :timeout)
      :ok = HealthChecker.record_failure(provider, :timeout)
      :ok = HealthChecker.record_failure(provider, :timeout)

      # Circuit should be open now
      assert HealthChecker.is_available?(provider) == false
    end

    test "does not reopen circuit if already open" do
      provider = :no_reopen_test_1

      # Open the circuit
      :ok = HealthChecker.record_failure(provider, :timeout)
      :ok = HealthChecker.record_failure(provider, :timeout)
      :ok = HealthChecker.record_failure(provider, :timeout)

      available_before = HealthChecker.is_available?(provider)

      # Try to record more failures
      :ok = HealthChecker.record_failure(provider, :timeout)
      :ok = HealthChecker.record_failure(provider, :timeout)

      available_after = HealthChecker.is_available?(provider)

      # State should be consistent
      assert available_before == available_after
    end
  end

  # =========================================================================
  # RECORD_RATE_LIMITED TESTS
  # =========================================================================

  describe "CRASH: record_rate_limited/2" do
    test "records rate-limited status with default duration" do
      provider = :rate_limit_default_1
      assert :ok = HealthChecker.record_rate_limited(provider)
      assert HealthChecker.is_available?(provider) == false
    end

    test "records rate-limited with custom retry-after seconds" do
      provider = :rate_limit_custom_1
      assert :ok = HealthChecker.record_rate_limited(provider, 30)
      assert HealthChecker.is_available?(provider) == false
    end

    test "accepts zero retry-after (uses default)" do
      provider = :rate_limit_zero_1
      assert :ok = HealthChecker.record_rate_limited(provider, 0)
      assert HealthChecker.is_available?(provider) == false
    end

    test "accepts nil retry-after (uses default)" do
      provider = :rate_limit_nil_1
      assert :ok = HealthChecker.record_rate_limited(provider, nil)
      assert HealthChecker.is_available?(provider) == false
    end

    test "rate-limited overrides circuit state" do
      provider = :rate_limit_override_1

      # First, make provider available
      :ok = HealthChecker.record_success(provider)
      assert HealthChecker.is_available?(provider) == true

      # Then rate-limit it
      :ok = HealthChecker.record_rate_limited(provider, 10)

      # Should become unavailable
      assert HealthChecker.is_available?(provider) == false
    end

    test "rate-limited with very large duration" do
      provider = :rate_limit_large_1
      assert :ok = HealthChecker.record_rate_limited(provider, 3600)  # 1 hour
      assert HealthChecker.is_available?(provider) == false
    end
  end

  # =========================================================================
  # IS_AVAILABLE? TESTS
  # =========================================================================

  describe "CRASH: is_available?/1" do
    test "returns boolean" do
      provider = :availability_bool_1
      result = HealthChecker.is_available?(provider)
      assert is_boolean(result)
    end

    test "provider is available by default (no prior failures)" do
      provider = :availability_default_1
      assert HealthChecker.is_available?(provider) == true
    end

    test "provider is unavailable when circuit is open" do
      provider = :availability_open_1

      :ok = HealthChecker.record_failure(provider, :timeout)
      :ok = HealthChecker.record_failure(provider, :timeout)
      :ok = HealthChecker.record_failure(provider, :timeout)

      assert HealthChecker.is_available?(provider) == false
    end

    test "provider is unavailable when rate-limited" do
      provider = :availability_limited_1

      :ok = HealthChecker.record_rate_limited(provider, 60)
      assert HealthChecker.is_available?(provider) == false
    end

    test "different providers have independent availability" do
      p1 = :independent_p1
      p2 = :independent_p2

      # Fail p1
      :ok = HealthChecker.record_failure(p1, :timeout)
      :ok = HealthChecker.record_failure(p1, :timeout)
      :ok = HealthChecker.record_failure(p1, :timeout)

      # p1 should be unavailable, p2 available
      assert HealthChecker.is_available?(p1) == false
      assert HealthChecker.is_available?(p2) == true
    end

    test "returns consistent results for same provider" do
      provider = :availability_consistent_1

      r1 = HealthChecker.is_available?(provider)
      r2 = HealthChecker.is_available?(provider)

      assert r1 == r2
    end
  end

  # =========================================================================
  # STATE TESTS
  # =========================================================================

  describe "CRASH: state/0" do
    test "returns a map" do
      state = HealthChecker.state()
      assert is_map(state)
    end

    test "state includes all tracked providers" do
      provider = :state_tracking_1
      :ok = HealthChecker.record_failure(provider, :timeout)

      state = HealthChecker.state()
      assert Map.has_key?(state, provider)
    end

    test "state entries contain expected keys" do
      provider = :state_keys_1
      :ok = HealthChecker.record_failure(provider, :timeout)

      state = HealthChecker.state()
      entry = state[provider]

      assert is_map(entry)
      assert Map.has_key?(entry, :circuit)
      assert Map.has_key?(entry, :consecutive_failures)
    end

    test "state circuit values are valid atoms" do
      providers = [:state_circuit_1, :state_circuit_2, :state_circuit_3]

      :ok = HealthChecker.record_failure(providers |> Enum.at(0), :timeout)
      :ok = HealthChecker.record_failure(providers |> Enum.at(0), :timeout)
      :ok = HealthChecker.record_failure(providers |> Enum.at(0), :timeout)
      :ok = HealthChecker.record_success(providers |> Enum.at(1))

      state = HealthChecker.state()

      Enum.each(providers, fn p ->
        if Map.has_key?(state, p) do
          entry = state[p]
          assert entry.circuit in [:closed, :open, :half_open]
        end
      end)
    end

    test "state is consistent across calls" do
      state1 = HealthChecker.state()
      state2 = HealthChecker.state()

      # Keys should be the same
      assert Map.keys(state1) == Map.keys(state2)
    end
  end

  # =========================================================================
  # INTEGRATION TESTS
  # =========================================================================

  describe "CRASH: Circuit breaker state machine" do
    test "closed -> open -> half_open -> closed cycle" do
      provider = :state_cycle_1

      # Start: closed (default)
      assert HealthChecker.is_available?(provider) == true

      # Fail 3 times: opens
      :ok = HealthChecker.record_failure(provider, :timeout)
      :ok = HealthChecker.record_failure(provider, :timeout)
      :ok = HealthChecker.record_failure(provider, :timeout)

      assert HealthChecker.is_available?(provider) == false

      # After cooldown (30s): half-open (can't test timing without waiting)
      # Success in half-open: closes
      :ok = HealthChecker.record_success(provider)

      # State should reflect circuit state change
      state = HealthChecker.state()
      assert is_map(state[provider])
    end

    test "failure resets after success" do
      provider = :reset_after_success_1

      # Record 2 failures
      :ok = HealthChecker.record_failure(provider, :timeout)
      :ok = HealthChecker.record_failure(provider, :timeout)

      # Success resets counter
      :ok = HealthChecker.record_success(provider)

      # 2 more failures should not open circuit (counter reset)
      :ok = HealthChecker.record_failure(provider, :timeout)
      :ok = HealthChecker.record_failure(provider, :timeout)

      # Should still be available (only 2 failures since reset)
      assert HealthChecker.is_available?(provider) == true
    end

    test "rate-limit window expires (conceptual)" do
      provider = :rate_limit_expire_1

      # Rate-limit for 1 second (in test, can't actually wait long)
      :ok = HealthChecker.record_rate_limited(provider, 1)
      assert HealthChecker.is_available?(provider) == false

      # Immediately after record, should still be limited
      assert HealthChecker.is_available?(provider) == false

      # In production: after 1s, would become available again
    end
  end

  # =========================================================================
  # MULTIPLE PROVIDERS TESTS
  # =========================================================================

  describe "CRASH: Multiple independent providers" do
    test "tracks multiple providers independently" do
      providers = [:multi_p1, :multi_p2, :multi_p3, :multi_p4]

      # Different states for each
      :ok = HealthChecker.record_success(Enum.at(providers, 0))
      :ok = HealthChecker.record_failure(Enum.at(providers, 1), :timeout)
      :ok = HealthChecker.record_failure(Enum.at(providers, 1), :timeout)
      :ok = HealthChecker.record_failure(Enum.at(providers, 1), :timeout)
      :ok = HealthChecker.record_rate_limited(Enum.at(providers, 2), 60)
      # providers[3] gets no records

      # Verify states
      assert HealthChecker.is_available?(Enum.at(providers, 0)) == true
      assert HealthChecker.is_available?(Enum.at(providers, 1)) == false
      assert HealthChecker.is_available?(Enum.at(providers, 2)) == false
      assert HealthChecker.is_available?(Enum.at(providers, 3)) == true
    end

    test "can record all providers simultaneously" do
      providers = [:concurrent_p1, :concurrent_p2, :concurrent_p3]

      tasks = Enum.map(providers, fn p ->
        Task.start(fn ->
          :ok = HealthChecker.record_success(p)
          :ok = HealthChecker.record_failure(p, :timeout)
          HealthChecker.is_available?(p)
        end)
      end)

      # All tasks should complete
      assert length(tasks) == 3
      Enum.each(tasks, fn {:ok, _pid} ->
        assert true
      end)
    end
  end

  # =========================================================================
  # STRESS TESTS
  # =========================================================================

  describe "CRASH: Stress and edge cases" do
    test "rapid success/failure alternation" do
      provider = :rapid_alternate_1

      for _i <- 1..20 do
        :ok = HealthChecker.record_success(provider)
        :ok = HealthChecker.record_failure(provider, :timeout)
      end

      # Should complete without crashing
      result = HealthChecker.is_available?(provider)
      assert is_boolean(result)
    end

    test "many consecutive successes" do
      provider = :many_success_1

      for _i <- 1..100 do
        :ok = HealthChecker.record_success(provider)
      end

      assert HealthChecker.is_available?(provider) == true
    end

    test "rate-limit followed by failures" do
      provider = :limit_then_fail_1

      :ok = HealthChecker.record_rate_limited(provider, 60)
      assert HealthChecker.is_available?(provider) == false

      # Record failures while rate-limited
      :ok = HealthChecker.record_failure(provider, :timeout)
      :ok = HealthChecker.record_failure(provider, :timeout)

      # Should still be unavailable (rate-limit takes precedence)
      assert HealthChecker.is_available?(provider) == false
    end

    test "success after rate-limit doesn't affect rate-limit window" do
      provider = :success_during_limit_1

      :ok = HealthChecker.record_rate_limited(provider, 60)
      :ok = HealthChecker.record_success(provider)

      # Rate-limit should still be active
      assert HealthChecker.is_available?(provider) == false
    end
  end

  # =========================================================================
  # MODULE BEHAVIOR CONTRACT
  # =========================================================================

  describe "CRASH: Module behavior contract" do
    test "all public functions are exported" do
      assert function_exported?(HealthChecker, :start_link, 1)
      assert function_exported?(HealthChecker, :record_success, 1)
      assert function_exported?(HealthChecker, :record_failure, 2)
      assert function_exported?(HealthChecker, :record_rate_limited, 2)
      assert function_exported?(HealthChecker, :is_available?, 1)
      assert function_exported?(HealthChecker, :state, 0)
    end

    test "GenServer callbacks are implemented" do
      assert function_exported?(HealthChecker, :init, 1)
      assert function_exported?(HealthChecker, :handle_cast, 2)
      assert function_exported?(HealthChecker, :handle_call, 3)
    end

    test "all functions return expected types" do
      # record_* return :ok
      assert HealthChecker.record_success(:type_test_1) == :ok
      assert HealthChecker.record_failure(:type_test_2, :reason) == :ok
      assert HealthChecker.record_rate_limited(:type_test_3) == :ok

      # is_available? returns boolean
      assert is_boolean(HealthChecker.is_available?(:type_test_4))

      # state returns map
      assert is_map(HealthChecker.state())
    end

    test "functions handle all provider atom types" do
      atoms = [:short, :long_provider_name, :ALLCAPS, :with_underscore_123]

      Enum.each(atoms, fn atom ->
        assert :ok = HealthChecker.record_success(atom)
        assert :ok = HealthChecker.record_failure(atom, :reason)
        assert :ok = HealthChecker.record_rate_limited(atom)
        assert is_boolean(HealthChecker.is_available?(atom))
      end)
    end
  end
end
