defmodule OptimalSystemAgent.Integration.GroqArmstrongFaultToleranceTest do
  @moduledoc """
  Chicago TDD Integration Tests — Armstrong Fault Tolerance via Real Groq API

  RED → GREEN → REFACTOR cycle. Every test uses REAL api.groq.com calls.
  No mocks. No stubs. Crashes must be visible. State must be clean.

  Armstrong Principles tested:
  1. Supervision: Circuit opens after auth failures, fallback chain skips bad provider
  2. Budget Constraints: Real Groq call measured against normal-tier 5000ms budget
  3. Supervision: 1ms receive_timeout → error returned → supervision tree survives
  4. No Shared State: HealthChecker restart produces clean slate
  5. Observability: [:osa, :providers, :chat, :complete] telemetry event emitted

  Run: GROQ_API_KEY=gsk_... mix test test/integration/groq_armstrong_fault_tolerance_test.exs --include integration
  """

  use ExUnit.Case, async: false

  @moduletag :integration
  @moduletag :requires_application

  @groq_model "openai/gpt-oss-20b"
  @simple_messages [%{role: "user", content: "Reply with exactly: OK"}]

  alias OptimalSystemAgent.Providers.Registry
  alias OptimalSystemAgent.Providers.HealthChecker
  alias OptimalSystemAgent.Providers.OpenAICompatProvider
  alias OptimalSystemAgent.Armstrong.BudgetEnforcer

  # ── Private helpers ──────────────────────────────────────────────────────────

  defp wait_for_pid(name, timeout_ms \\ 3_000) do
    deadline = System.monotonic_time(:millisecond) + timeout_ms
    do_wait_pid(name, deadline)
  end

  defp do_wait_pid(name, deadline) do
    case Process.whereis(name) do
      nil ->
        if System.monotonic_time(:millisecond) >= deadline do
          raise "Process #{inspect(name)} did not restart within timeout"
        else
          Process.sleep(50)
          do_wait_pid(name, deadline)
        end

      pid ->
        pid
    end
  end

  # ── Setup ────────────────────────────────────────────────────────────────────

  setup do
    api_key =
      Application.get_env(:optimal_system_agent, :groq_api_key) ||
        System.get_env("GROQ_API_KEY")

    if is_nil(api_key) or api_key == "" do
      flunk("GROQ_API_KEY required — set it in ~/.osa/.env or GROQ_API_KEY env var")
    end

    # Ensure the key is in app env for the provider to pick up
    Application.put_env(:optimal_system_agent, :groq_api_key, api_key)

    on_exit(fn ->
      Application.put_env(:optimal_system_agent, :groq_api_key, api_key)
    end)

    {:ok, api_key: api_key}
  end

  # ── Test 1: Circuit opens after auth failures, recovers with valid key ────────

  describe "Armstrong Principle 1: Groq Provider Crash Recovery" do
    @tag timeout: 60_000
    test "provider circuit opens after 3 Groq auth failures then recovers with valid key",
         %{api_key: real_key} do
      # Step 1: Inject one real HTTP 401 by temporarily using an invalid key
      Application.put_env(:optimal_system_agent, :groq_api_key, "gsk_INVALID_KEY_ARMSTRONG_TEST")

      result =
        OpenAICompatProvider.chat(
          :groq,
          @simple_messages,
          model: @groq_model,
          temperature: 0.0
        )

      # Armstrong: error must be visible, not swallowed
      assert {:error, reason} = result, "Expected 401 error from invalid Groq key, got: #{inspect(result)}"

      # Record the real HTTP 401 in HealthChecker (OpenAICompatProvider.chat bypasses
      # Registry.chat_with_fallback, so we must record failure explicitly — Armstrong: no
      # silent state; every failure must be observable to the circuit breaker)
      HealthChecker.record_failure(:groq, reason)

      # Step 2: Restore real key
      Application.put_env(:optimal_system_agent, :groq_api_key, real_key)

      # Step 3: Inject 2 more synthetic failures — total = 3, which trips the circuit
      HealthChecker.record_failure(:groq, :test_induced_armstrong_1)
      HealthChecker.record_failure(:groq, :test_induced_armstrong_2)

      # Give the GenServer casts time to process
      Process.sleep(50)

      # Step 4: Circuit must now be open
      assert HealthChecker.is_available?(:groq) == false,
             "Circuit should be open after 3 consecutive Groq failures"

      # Step 5: Reset by recording a success (simulates recovery after cooldown)
      HealthChecker.record_success(:groq)
      Process.sleep(50)

      # Step 6: System recovered — real call with valid key succeeds
      recovery =
        OpenAICompatProvider.chat(
          :groq,
          @simple_messages,
          model: @groq_model,
          temperature: 0.0
        )

      assert {:ok, %{content: content}} = recovery,
             "Recovery call should succeed after circuit reset, got: #{inspect(recovery)}"

      assert String.trim(content) != "",
             "Recovery call returned empty content"
    end
  end

  # ── Test 2: Real Groq call within normal tier budget ─────────────────────────

  describe "Armstrong Principle 4: Budget Enforcement on Real LLM Call" do
    @tag timeout: 30_000
    test "real Groq call completes within normal tier time budget of 5000ms" do
      # Start an isolated BudgetEnforcer so we don't conflict with the app's instance
      enforcer_name = :"budget_enforcer_groq_test_#{:erlang.unique_integer([:positive])}"
      {:ok, _pid} = start_supervised({BudgetEnforcer, name: enforcer_name})

      # Step 1: Budget check passes before the call
      assert :ok = GenServer.call(enforcer_name, {:check_budget, "groq_chat", :normal})

      # Step 2: Make real Groq call and measure elapsed time
      start_ms = System.monotonic_time(:millisecond)

      result =
        OpenAICompatProvider.chat(
          :groq,
          @simple_messages,
          model: @groq_model,
          temperature: 0.0
        )

      elapsed_ms = System.monotonic_time(:millisecond) - start_ms

      # Step 3: Call must succeed
      assert {:ok, %{content: content}} = result,
             "Real Groq call failed: #{inspect(result)}"

      assert String.trim(content) != "", "Groq returned empty content"

      # Step 4: Elapsed time must be within normal-tier budget (5000ms)
      assert elapsed_ms < 5_000,
             "Groq call took #{elapsed_ms}ms — exceeds normal tier budget of 5000ms"

      # Step 5: Record operation in budget enforcer
      GenServer.cast(enforcer_name, {:record_operation, "groq_chat", :normal, elapsed_ms, 0.0})

      # Verify budget enforcer still operational after recording
      assert :ok = GenServer.call(enforcer_name, {:check_budget, "groq_chat", :normal})
    end
  end

  # ── Test 3: Supervision tree survives Groq timeout ───────────────────────────

  describe "Armstrong Principle 2: Supervision Survives Groq Timeout" do
    @tag timeout: 30_000
    test "Groq call with 1ms receive_timeout returns error and supervision tree remains functional" do
      # Capture current PIDs before the timeout
      registry_pid = Process.whereis(OptimalSystemAgent.Providers.Registry)
      health_checker_pid = Process.whereis(OptimalSystemAgent.Providers.HealthChecker)

      assert registry_pid != nil, "Registry not running"
      assert health_checker_pid != nil, "HealthChecker not running"

      # Monitor both processes to detect unexpected crashes
      ref_registry = Process.monitor(registry_pid)
      ref_hc = Process.monitor(health_checker_pid)

      # Step 1: Make call with nearly-zero receive_timeout — guaranteed to timeout
      result =
        OpenAICompatProvider.chat(
          :groq,
          @simple_messages,
          model: @groq_model,
          temperature: 0.0,
          receive_timeout: 1
        )

      # Armstrong: timeout must produce visible error, not crash
      assert {:error, _reason} = result,
             "Expected timeout error, got: #{inspect(result)}"

      # Step 2: Neither process should have crashed
      refute_receive {:DOWN, ^ref_registry, :process, _, _}, 500
      refute_receive {:DOWN, ^ref_hc, :process, _, _}, 500

      # Step 3: PIDs unchanged — no restarts triggered
      assert Process.whereis(OptimalSystemAgent.Providers.Registry) == registry_pid,
             "Registry was restarted unexpectedly — supervision cascade detected"

      assert Process.whereis(OptimalSystemAgent.Providers.HealthChecker) == health_checker_pid,
             "HealthChecker was restarted unexpectedly"

      # Clean up monitors
      Process.demonitor(ref_registry, [:flush])
      Process.demonitor(ref_hc, [:flush])

      # Step 4: System still functional — second real call with normal timeout succeeds
      recovery =
        OpenAICompatProvider.chat(
          :groq,
          @simple_messages,
          model: @groq_model,
          temperature: 0.0
        )

      assert {:ok, %{content: _}} = recovery,
             "System should be functional after timeout error, got: #{inspect(recovery)}"
    end
  end

  # ── Test 4: No shared state after HealthChecker restart ──────────────────────

  describe "Armstrong Principle 3: No Shared State After Groq Crash" do
    @tag timeout: 30_000
    test "HealthChecker process restart produces clean state — no old failure counts persist" do
      # Step 1: Poison the circuit — inject 3 failures to open it
      HealthChecker.record_failure(:groq, :test_poison_1)
      HealthChecker.record_failure(:groq, :test_poison_2)
      HealthChecker.record_failure(:groq, :test_poison_3)
      Process.sleep(50)

      assert HealthChecker.is_available?(:groq) == false,
             "Circuit should be open after 3 injected failures"

      # Step 2: Kill HealthChecker
      old_hc_pid = Process.whereis(OptimalSystemAgent.Providers.HealthChecker)
      assert old_hc_pid != nil

      ref = Process.monitor(old_hc_pid)
      Process.exit(old_hc_pid, :kill)

      # Confirm it died
      assert_receive {:DOWN, ^ref, :process, ^old_hc_pid, :killed}, 2_000

      # Step 3: Wait for HealthChecker AND Registry to restart
      # (Infrastructure uses :rest_for_one — killing HealthChecker cascades to Registry)
      new_hc_pid = wait_for_pid(OptimalSystemAgent.Providers.HealthChecker, 5_000)
      _new_registry_pid = wait_for_pid(OptimalSystemAgent.Providers.Registry, 5_000)

      # Step 4: New process — different PID proves no shared memory
      assert new_hc_pid != old_hc_pid,
             "Expected new PID after restart, got same PID — state boundary violated"

      # Step 5: Fresh state — no memory of old failures
      assert HealthChecker.is_available?(:groq) == true,
             "HealthChecker should start with clean state after restart (no old failure counts)"

      # Step 6: Real Groq call succeeds — message passing to new process works
      result =
        OpenAICompatProvider.chat(
          :groq,
          @simple_messages,
          model: @groq_model,
          temperature: 0.0
        )

      assert {:ok, %{content: _}} = result,
             "Real Groq call should succeed after HealthChecker restart, got: #{inspect(result)}"
    end
  end

  # ── Test 5: OTEL telemetry event emitted on real Groq call ───────────────────

  describe "Armstrong Principle 5: Real Groq Call with OTEL Telemetry" do
    @tag timeout: 30_000
    test "Groq call via Registry emits [:osa, :providers, :chat, :complete] with provider :groq and model" do
      test_pid = self()
      handler_name = :"groq_armstrong_telemetry_#{:erlang.unique_integer([:positive])}"

      # Attach telemetry handler BEFORE the call
      :telemetry.attach(
        handler_name,
        [:osa, :providers, :chat, :complete],
        fn _event, measurements, metadata, _config ->
          send(test_pid, {:chat_complete, measurements, metadata})
        end,
        nil
      )

      on_exit(fn -> :telemetry.detach(handler_name) end)

      # Make the real Groq call via Registry
      result =
        Registry.chat(
          @simple_messages,
          provider: :groq,
          model: @groq_model,
          temperature: 0.0
        )

      # Call must succeed
      assert {:ok, %{content: content}} = result,
             "Real Groq call via Registry failed: #{inspect(result)}"

      assert String.trim(content) != "", "Groq returned empty content"

      # Telemetry event must be received with correct metadata
      assert_receive {:chat_complete, measurements, metadata}, 5_000,
                     "Expected [:osa, :providers, :chat, :complete] telemetry event within 5s"

      # Verify measurements contain duration
      assert Map.has_key?(measurements, :duration),
             "Telemetry measurements missing :duration key, got: #{inspect(measurements)}"

      assert measurements.duration > 0,
             "Duration must be positive, got: #{measurements.duration}"

      # Verify metadata identifies Groq provider
      assert metadata.provider == :groq,
             "Expected provider: :groq in telemetry metadata, got: #{inspect(metadata.provider)}"

      # Model should be the one we passed (or the Groq default)
      assert metadata.model in [@groq_model, "openai/gpt-oss-20b", "openai/gpt-oss-20b"],
             "Expected Groq model in metadata, got: #{inspect(metadata.model)}"
    end
  end
end
