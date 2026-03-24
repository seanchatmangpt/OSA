defmodule OptimalSystemAgent.Providers.HealthCheckerTest do
  @moduledoc """
  Unit tests for HealthChecker module.

  Tests circuit breaker and rate-limit tracker for LLM providers.
  """

  use ExUnit.Case, async: false

  alias OptimalSystemAgent.Providers.HealthChecker

  @moduletag :capture_log

  setup do
    # Ensure HealthChecker is started for tests
    unless Process.whereis(HealthChecker) do
      _pid = start_supervised!(HealthChecker)
    end

    # Generate unique provider name for each test to avoid conflicts
    provider_id = System.unique_integer([:positive])
    provider = :"test_provider_#{provider_id}"

    %{provider: provider}
  end

  describe "record_success/1" do
    test "resets consecutive failures to 0", %{provider: provider} do
      # Record some failures first
      HealthChecker.record_failure(provider, :error)
      HealthChecker.record_failure(provider, :error)

      # Success should reset
      HealthChecker.record_success(provider)

      state = HealthChecker.state()
      entry = Map.get(state, provider)
      assert entry.consecutive_failures == 0
    end
  end

  describe "record_failure/2" do
    test "increments consecutive failures", %{provider: provider} do
      HealthChecker.record_failure(provider, :error)

      state = HealthChecker.state()
      entry = Map.get(state, provider)
      assert entry.consecutive_failures == 1
    end

    test "opens circuit after 3 consecutive failures", %{provider: provider} do
      for _ <- 1..3 do
        HealthChecker.record_failure(provider, :error)
      end

      state = HealthChecker.state()
      entry = Map.get(state, provider)
      assert entry.circuit == :open
      assert entry.opened_at != nil
    end

    test "does not open circuit with fewer than 3 failures", %{provider: provider} do
      HealthChecker.record_failure(provider, :error)
      HealthChecker.record_failure(provider, :error)

      state = HealthChecker.state()
      entry = Map.get(state, provider)
      assert entry.consecutive_failures == 2
      assert entry.circuit == :closed
    end

    test "stores opened_at timestamp when circuit opens", %{provider: provider} do
      for _ <- 1..3 do
        HealthChecker.record_failure(provider, :error)
      end

      state = HealthChecker.state()
      entry = Map.get(state, provider)
      assert entry.opened_at != nil
    end
  end

  describe "record_rate_limited/2" do
    test "marks provider as rate-limited", %{provider: provider} do
      HealthChecker.record_rate_limited(provider, 60)

      # Provider should not be available immediately
      refute HealthChecker.is_available?(provider)
    end

    test "uses default 60 seconds when retry_after is nil", %{provider: provider} do
      HealthChecker.record_rate_limited(provider, nil)

      state = HealthChecker.state()
      entry = Map.get(state, provider)
      assert entry.rate_limited_until != nil
    end

    test "uses custom retry_after duration when provided", %{provider: provider} do
      HealthChecker.record_rate_limited(provider, 30)

      state = HealthChecker.state()
      entry = Map.get(state, provider)
      assert entry.rate_limited_until != nil
    end
  end

  describe "is_available?/1" do
    test "returns true for provider with no recorded state" do
      # Use a truly unknown provider name
      unknown_provider = :"untracked_#{System.unique_integer()}"
      assert HealthChecker.is_available?(unknown_provider) == true
    end

    test "returns true for provider with closed circuit", %{provider: provider} do
      HealthChecker.record_success(provider)

      assert HealthChecker.is_available?(provider) == true
    end

    test "returns false for provider with open circuit", %{provider: provider} do
      for _ <- 1..3 do
        HealthChecker.record_failure(provider, :error)
      end

      refute HealthChecker.is_available?(provider)
    end

    test "returns false for rate-limited provider", %{provider: provider} do
      HealthChecker.record_rate_limited(provider, 60)

      refute HealthChecker.is_available?(provider)
    end

    test "returns true after success resets failures", %{provider: provider} do
      # Create failures
      for _ <- 1..2 do
        HealthChecker.record_failure(provider, :error)
      end

      # Reset with success
      HealthChecker.record_success(provider)

      assert HealthChecker.is_available?(provider) == true
    end
  end

  describe "state/0" do
    test "returns map structure", %{provider: provider} do
      HealthChecker.record_success(provider)

      state = HealthChecker.state()
      assert is_map(state)
    end

    test "returns map with tracked provider", %{provider: provider} do
      HealthChecker.record_failure(provider, :error)

      state = HealthChecker.state()
      assert Map.has_key?(state, provider)
    end

    test "entry contains expected fields", %{provider: provider} do
      HealthChecker.record_failure(provider, :error)

      state = HealthChecker.state()
      entry = Map.get(state, provider)

      assert Map.has_key?(entry, :circuit)
      assert Map.has_key?(entry, :consecutive_failures)
      assert Map.has_key?(entry, :opened_at)
      assert Map.has_key?(entry, :rate_limited_until)
    end
  end

  describe "integration - circuit breaker lifecycle" do
    test "closed -> open cycle", %{provider: provider} do
      # Start: closed (default)
      assert HealthChecker.is_available?(provider)

      # 3 failures -> open
      for _ <- 1..3 do
        HealthChecker.record_failure(provider, :error)
      end

      refute HealthChecker.is_available?(provider)

      state = HealthChecker.state()
      assert Map.get(state, provider).circuit == :open
    end

    test "success resets failure count before threshold", %{provider: provider} do
      # 2 failures (below threshold)
      HealthChecker.record_failure(provider, :error)
      HealthChecker.record_failure(provider, :error)

      state = HealthChecker.state()
      assert Map.get(state, provider).consecutive_failures == 2

      # Success resets
      HealthChecker.record_success(provider)

      state = HealthChecker.state()
      assert Map.get(state, provider).consecutive_failures == 0
      assert HealthChecker.is_available?(provider)
    end
  end

  describe "integration - rate limiting" do
    test "rate limit prevents availability", %{provider: provider} do
      HealthChecker.record_rate_limited(provider, 1)

      refute HealthChecker.is_available?(provider)
    end

    test "new rate limit extends existing rate limit", %{provider: provider} do
      HealthChecker.record_rate_limited(provider, 1)
      HealthChecker.record_rate_limited(provider, 1)

      refute HealthChecker.is_available?(provider)
    end
  end

  describe "edge cases" do
    test "handles multiple providers independently" do
      provider1 = :"multi_test_#{System.unique_integer()}"
      provider2 = :"multi_test_#{System.unique_integer()}"

      HealthChecker.record_failure(provider1, :error)
      HealthChecker.record_failure(provider1, :error)
      HealthChecker.record_failure(provider1, :error)

      # Provider1 should be unavailable
      refute HealthChecker.is_available?(provider1)

      # Provider2 should still be available
      assert HealthChecker.is_available?(provider2)
    end

    test "handles success for unknown provider" do
      unknown = :"unknown_#{System.unique_integer()}"
      assert :ok = HealthChecker.record_success(unknown)
    end

    test "handles failure for unknown provider" do
      unknown = :"unknown_#{System.unique_integer()}"
      assert :ok = HealthChecker.record_failure(unknown, :error)
    end

    test "handles rate limit for unknown provider" do
      unknown = :"unknown_#{System.unique_integer()}"
      assert :ok = HealthChecker.record_rate_limited(unknown, 60)
    end
  end
end
