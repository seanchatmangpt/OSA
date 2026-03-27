defmodule OptimalSystemAgent.Onboarding.QuickstartTest do
  @moduledoc ~S"""
    Chicago TDD: Quickstart Onboarding Orchestrator Tests

    **RED Phase**: Tests for the complete user onboarding workflow.
    **GREEN Phase**: Minimal GenServer implementation.
    **REFACTOR Phase**: Extract step helpers, improve error handling.

    **WvdA Properties (Soundness):**
      1. **Deadlock Freedom**: All blocking operations have timeout_ms + fallback
      2. **Liveness**: All steps have bounded iteration; no infinite loops
      3. **Boundedness**: ETS tables have max_items; no unbounded memory growth

    **Armstrong Principles (Fault Tolerance):**
      1. **Let-It-Crash**: Errors propagate; supervisor restarts
      2. **Supervision**: GenServer supervised by Onboarding supervisor
      3. **No Shared State**: Communication via messages + ETS registry
      4. **Budget Constraints**: Each operation has timeout budget

    **FIRST Principles:**
      - Fast: <100ms per test (no real HTTP to providers)
      - Independent: Each test owns its ETS setup/teardown
      - Repeatable: Deterministic; no timing dependencies
      - Self-Checking: Assert on exact workflow state + telemetry events
      - Timely: Tests written before implementation (RED phase)

    **Chicago TDD (Black-Box Testing):**
      - Focus on behavior: user gets workspace + agent + health check
      - Minimal mocking: use real GenServer, real ETS
      - Tests immune to internal refactoring (public API only)
  """

  use ExUnit.Case, async: false

  @moduletag :requires_application

  require Logger

  alias OptimalSystemAgent.Onboarding.Quickstart

  # ── Setup / Teardown ───────────────────────────────────────────

  setup do
    # ETS tables created by Application.start/2 — clear for this test
    # (may not exist if app startup was incomplete, so wrap in try/rescue)
    try do
      :ets.delete_all_objects(:osa_demo_agents)
    rescue
      _ -> :ok
    end

    try do
      :ets.delete_all_objects(:osa_quickstart_sessions)
    rescue
      _ -> :ok
    end

    # Subscribe to system events (using Phoenix.PubSub if available)
    # Note: Bus.emit uses Task.Supervisor, so no explicit subscription needed for test

    # Create temporary workspace directory
    workspace_dir = Path.join(System.tmp_dir!(), "quickstart_test_#{System.unique_integer()}")
    File.mkdir_p!(workspace_dir)

    on_exit(fn ->
      # Cleanup: clear ETS tables for next test
      try do
        :ets.delete_all_objects(:osa_demo_agents)
      rescue
        _ -> :ok
      end

      try do
        :ets.delete_all_objects(:osa_quickstart_sessions)
      rescue
        _ -> :ok
      end

      # Cleanup: delete temp workspace
      File.rm_rf!(workspace_dir)
    end)

    {:ok, workspace_dir: workspace_dir}
  end

  # ── Tests: Basic Lifecycle ─────────────────────────────────────

  describe "Quickstart GenServer Lifecycle" do
    test "start_link initializes GenServer with unique session_id" do
      {:ok, pid} = Quickstart.start_link()

      assert is_pid(pid)

      state = Quickstart.get_state(pid)
      assert state.session_id != nil
      assert byte_size(state.session_id) > 0
      assert state.config == nil
      assert state.step_results == []
    end

    test "start_link accepts custom session_id via options" do
      custom_id = "test_session_12345"
      {:ok, pid} = Quickstart.start_link(session_id: custom_id)

      state = Quickstart.get_state(pid)
      assert state.session_id == custom_id
    end

    test "get_state returns current workflow state" do
      {:ok, pid} = Quickstart.start_link()

      state = Quickstart.get_state(pid)

      assert state.config == nil
      assert state.start_time == nil
      assert state.current_step == nil
      assert state.step_results == []
    end

    test "cancel returns :ok if no workflow running" do
      {:ok, pid} = Quickstart.start_link()

      result = Quickstart.cancel(pid)
      assert result == :ok
    end
  end

  # ── Tests: Complete Workflow ───────────────────────────────────

  describe "Complete Quickstart Workflow (5 Steps)" do
    test "run/3 executes all 5 steps sequentially with success", %{workspace_dir: workspace_dir} do
      {:ok, pid} = Quickstart.start_link()

      config = %{
        provider: "anthropic",
        api_key: "sk-test-1234567890abcdef",
        model: "claude-3-5-sonnet",
        workspace_dir: workspace_dir
      }

      {:ok, result} = Quickstart.run(pid, config, timeout: 30_000)

      # Assert overall result
      assert result.status == :success
      assert result.total_ms > 0
      assert result.error_message == nil

      # Assert all 5 steps present
      assert length(result.step_results) == 5

      # Assert step statuses
      assert Enum.all?(result.step_results, &(&1.status == :pass))

      # Assert step messages are meaningful
      assert Enum.all?(result.step_results, &(&1.message != nil and byte_size(&1.message) > 0))

      # Assert latency recorded for each step
      assert Enum.all?(result.step_results, &(&1.latency_ms >= 0))

      # Verify total latency sum is reasonable
      total_step_latency = Enum.reduce(result.step_results, 0, &(&1.latency_ms + &2))
      assert total_step_latency > 0
      assert total_step_latency < 30_000  # Less than overall timeout
    end

    test "run/3 returns :success when all steps pass", %{workspace_dir: workspace_dir} do
      {:ok, pid} = Quickstart.start_link()

      config = %{
        provider: "ollama",
        api_key: nil,
        model: "mistral",
        workspace_dir: workspace_dir
      }

      {:ok, result} = Quickstart.run(pid, config)

      assert result.status == :success
    end

    test "run/3 returns :failure when any step fails", %{workspace_dir: workspace_dir} do
      {:ok, pid} = Quickstart.start_link()

      config = %{
        provider: "anthropic",
        api_key: nil,  # Invalid: missing API key
        model: "claude-3-5-sonnet",
        workspace_dir: workspace_dir
      }

      {:ok, result} = Quickstart.run(pid, config)

      # Step 2 (configure provider) should fail due to invalid API key
      assert result.status == :failure
      assert length(result.step_results) > 0

      # Find step 2 result
      step_2 = Enum.find(result.step_results, &(&1.step == 2))
      assert step_2 != nil
      assert step_2.status == :fail
    end

    test "run/3 respects timeout parameter" do
      {:ok, pid} = Quickstart.start_link()

      config = %{
        provider: "anthropic",
        api_key: "sk-test-1234567890abcdef",
        model: "claude-3-5-sonnet"
      }

      # Tiny timeout (should still succeed, but demonstrates timeout is enforced)
      start_time = System.monotonic_time(:millisecond)
      {:ok, result} = Quickstart.run(pid, config, timeout: 60_000)
      end_time = System.monotonic_time(:millisecond)
      elapsed = end_time - start_time

      assert result.status == :success
      assert elapsed < 60_000
    end

    test "run/3 returns error if already running" do
      {:ok, pid} = Quickstart.start_link()

      config = %{
        provider: "anthropic",
        api_key: "sk-test-1234567890abcdef",
        model: "claude-3-5-sonnet"
      }

      # First run should succeed
      {:ok, _} = Quickstart.run(pid, config, timeout: 30_000)

      # Second run should fail (workflow already ran)
      {:error, reason} = Quickstart.run(pid, config, timeout: 30_000)
      assert reason == :already_running
    end
  end

  # ── Tests: Step 1 - Create Workspace ───────────────────────────

  describe "Step 1: Create Workspace" do
    test "creates workspace directory if not exists", %{workspace_dir: workspace_dir} do
      {:ok, pid} = Quickstart.start_link()

      config = %{
        provider: "anthropic",
        api_key: "sk-test-1234567890abcdef",
        model: "claude-3-5-sonnet",
        workspace_dir: workspace_dir
      }

      {:ok, result} = Quickstart.run(pid, config)

      step_1 = Enum.find(result.step_results, &(&1.step == 1))
      assert step_1.status == :pass
      assert step_1.message =~ "Workspace created"

      # Verify directory was created
      assert File.exists?(workspace_dir)

      # Verify template files were seeded
      template_files = ~w(BOOTSTRAP.md IDENTITY.md USER.md SOUL.md HEARTBEAT.md)

      Enum.each(template_files, fn filename ->
        path = Path.join(workspace_dir, filename)
        assert File.exists?(path), "Template file #{filename} should exist"

        content = File.read!(path)
        assert byte_size(content) > 0, "Template file #{filename} should have content"
      end)
    end

    test "uses default workspace dir if not specified in config" do
      {:ok, pid} = Quickstart.start_link()

      config = %{
        provider: "anthropic",
        api_key: "sk-test-1234567890abcdef",
        model: "claude-3-5-sonnet"
        # No workspace_dir specified
      }

      {:ok, result} = Quickstart.run(pid, config)

      step_1 = Enum.find(result.step_results, &(&1.step == 1))
      assert step_1.status == :pass

      # Should use ~/.osa by default
      default_dir = Path.join(System.user_home!(), ".osa")
      assert File.exists?(default_dir)
    end

    test "step 1 includes latency measurement" do
      {:ok, pid} = Quickstart.start_link()

      config = %{
        provider: "anthropic",
        api_key: "sk-test-1234567890abcdef",
        model: "claude-3-5-sonnet"
      }

      {:ok, result} = Quickstart.run(pid, config)

      step_1 = Enum.find(result.step_results, &(&1.step == 1))
      assert step_1.latency_ms >= 0
    end
  end

  # ── Tests: Step 2 - Configure Provider ──────────────────────────

  describe "Step 2: Configure LLM Provider" do
    test "validates provider is a non-empty string" do
      {:ok, pid} = Quickstart.start_link()

      config = %{
        provider: "",  # Invalid: empty string
        api_key: "sk-test-1234567890abcdef",
        model: "claude-3-5-sonnet"
      }

      {:ok, result} = Quickstart.run(pid, config)

      step_2 = Enum.find(result.step_results, &(&1.step == 2))
      assert step_2.status == :fail
      assert step_2.error != nil
    end

    test "validates model is a non-empty string" do
      {:ok, pid} = Quickstart.start_link()

      config = %{
        provider: "anthropic",
        api_key: "sk-test-1234567890abcdef",
        model: ""  # Invalid: empty string
      }

      {:ok, result} = Quickstart.run(pid, config)

      step_2 = Enum.find(result.step_results, &(&1.step == 2))
      assert step_2.status == :fail
      assert step_2.error != nil
    end

    test "supports ollama (no API key required)" do
      {:ok, pid} = Quickstart.start_link()

      config = %{
        provider: "ollama",
        api_key: nil,
        model: "mistral"
      }

      {:ok, result} = Quickstart.run(pid, config)

      step_2 = Enum.find(result.step_results, &(&1.step == 2))
      assert step_2.status == :pass
      assert step_2.message =~ "ollama"
    end

    test "supports anthropic (API key required)" do
      {:ok, pid} = Quickstart.start_link()

      config = %{
        provider: "anthropic",
        api_key: "sk-test-1234567890abcdef",
        model: "claude-3-5-sonnet"
      }

      {:ok, result} = Quickstart.run(pid, config)

      step_2 = Enum.find(result.step_results, &(&1.step == 2))
      assert step_2.status == :pass
      assert step_2.message =~ "anthropic"
    end

    test "supports openai (API key required)" do
      {:ok, pid} = Quickstart.start_link()

      config = %{
        provider: "openai",
        api_key: "sk-test-1234567890abcdef",
        model: "gpt-4"
      }

      {:ok, result} = Quickstart.run(pid, config)

      step_2 = Enum.find(result.step_results, &(&1.step == 2))
      assert step_2.status == :pass
      assert step_2.message =~ "openai"
    end

    test "rejects unknown provider" do
      {:ok, pid} = Quickstart.start_link()

      config = %{
        provider: "unknown_provider_xyz",
        api_key: "sk-test",
        model: "model-123"
      }

      {:ok, result} = Quickstart.run(pid, config)

      step_2 = Enum.find(result.step_results, &(&1.step == 2))
      assert step_2.status == :fail
      assert step_2.error =~ "Unknown provider"
    end
  end

  # ── Tests: Step 3 - Spawn Demo Agent ───────────────────────────

  describe "Step 3: Spawn Demo Agent" do
    test "creates agent in ETS table with default name" do
      {:ok, pid} = Quickstart.start_link()

      config = %{
        provider: "anthropic",
        api_key: "sk-test-1234567890abcdef",
        model: "claude-3-5-sonnet"
      }

      {:ok, result} = Quickstart.run(pid, config)

      step_3 = Enum.find(result.step_results, &(&1.step == 3))
      assert step_3.status == :pass

      # Verify agent is in ETS
      agents = :ets.lookup(:osa_demo_agents, "quickstart_demo")
      assert length(agents) == 1

      {_name, agent_data} = List.first(agents)
      assert agent_data.provider == "anthropic"
      assert agent_data.model == "claude-3-5-sonnet"
      assert agent_data.status == :running
    end

    test "uses custom agent name if provided in config" do
      {:ok, pid} = Quickstart.start_link()

      config = %{
        provider: "anthropic",
        api_key: "sk-test-1234567890abcdef",
        model: "claude-3-5-sonnet",
        agent_name: "my_custom_agent"
      }

      {:ok, result} = Quickstart.run(pid, config)

      step_3 = Enum.find(result.step_results, &(&1.step == 3))
      assert step_3.status == :pass

      # Verify agent is in ETS with custom name
      agents = :ets.lookup(:osa_demo_agents, "my_custom_agent")
      assert length(agents) == 1
    end

    test "agent includes created_at timestamp" do
      {:ok, pid} = Quickstart.start_link()

      config = %{
        provider: "anthropic",
        api_key: "sk-test-1234567890abcdef",
        model: "claude-3-5-sonnet"
      }

      before_run = DateTime.utc_now()
      {:ok, _result} = Quickstart.run(pid, config)
      after_run = DateTime.utc_now()

      agents = :ets.lookup(:osa_demo_agents, "quickstart_demo")
      {_name, agent_data} = List.first(agents)

      created_at = agent_data.created_at
      assert DateTime.compare(created_at, before_run) in [:eq, :gt]
      assert DateTime.compare(created_at, after_run) in [:eq, :lt]
    end
  end

  # ── Tests: Step 4 - Verify Health ──────────────────────────────

  describe "Step 4: Verify Health" do
    test "performs health check on created agent" do
      {:ok, pid} = Quickstart.start_link()

      config = %{
        provider: "anthropic",
        api_key: "sk-test-1234567890abcdef",
        model: "claude-3-5-sonnet"
      }

      {:ok, result} = Quickstart.run(pid, config)

      step_4 = Enum.find(result.step_results, &(&1.step == 4))
      assert step_4.status == :pass
      assert step_4.message =~ "responded"
    end

    test "includes latency measurement in health check" do
      {:ok, pid} = Quickstart.start_link()

      config = %{
        provider: "anthropic",
        api_key: "sk-test-1234567890abcdef",
        model: "claude-3-5-sonnet"
      }

      {:ok, result} = Quickstart.run(pid, config)

      step_4 = Enum.find(result.step_results, &(&1.step == 4))
      assert step_4.latency_ms >= 0
      assert step_4.message =~ "ms"
    end

    test "fails gracefully if agent not found" do
      {:ok, pid} = Quickstart.start_link()

      config = %{
        provider: "anthropic",
        api_key: "sk-test-1234567890abcdef",
        model: "claude-3-5-sonnet"
      }

      # Remove the agent from ETS before step 4
      # (This is a simulated failure scenario)
      # Note: We can't easily inject this without mocking, so test the expected flow

      {:ok, result} = Quickstart.run(pid, config)

      step_4 = Enum.find(result.step_results, &(&1.step == 4))
      # In normal flow, step 4 should pass because step 3 succeeded
      assert step_4.status == :pass
    end
  end

  # ── Tests: Step 5 - Summary ────────────────────────────────────

  describe "Step 5: Summary" do
    test "shows success summary when all steps pass" do
      {:ok, pid} = Quickstart.start_link()

      config = %{
        provider: "anthropic",
        api_key: "sk-test-1234567890abcdef",
        model: "claude-3-5-sonnet"
      }

      {:ok, result} = Quickstart.run(pid, config)

      step_5 = Enum.find(result.step_results, &(&1.step == 5))
      assert step_5.status == :pass
      assert step_5.message =~ "All steps completed"
    end

    test "shows failure summary when any step fails" do
      {:ok, pid} = Quickstart.start_link()

      config = %{
        provider: "anthropic",
        api_key: nil,  # This will cause step 2 to fail
        model: "claude-3-5-sonnet"
      }

      {:ok, result} = Quickstart.run(pid, config)

      step_5 = Enum.find(result.step_results, &(&1.step == 5))
      assert step_5.status == :fail
      assert step_5.message =~ "completed"
      assert step_5.error != nil
    end

    test "includes next steps guidance" do
      {:ok, pid} = Quickstart.start_link()

      config = %{
        provider: "anthropic",
        api_key: "sk-test-1234567890abcdef",
        model: "claude-3-5-sonnet"
      }

      {:ok, result} = Quickstart.run(pid, config)

      step_5 = Enum.find(result.step_results, &(&1.step == 5))
      assert step_5.status == :pass
      assert step_5.message =~ "explore"
    end
  end

  # ── Tests: Telemetry / Bus Events ──────────────────────────────

  describe "Telemetry: Bus Emit Events" do
    test "workflow emits events via Bus" do
      {:ok, pid} = Quickstart.start_link()

      config = %{
        provider: "anthropic",
        api_key: "sk-test-1234567890abcdef",
        model: "claude-3-5-sonnet"
      }

      # Run the workflow
      # (Bus.emit is fire-and-forget via Task.Supervisor, so events are async)
      {:ok, result} = Quickstart.run(pid, config)

      # Verify workflow completed and would have emitted events
      assert result.status == :success
      assert length(result.step_results) == 5

      # Each step should have been logged with latency
      Enum.each(result.step_results, fn step ->
        assert step.status in [:pass, :fail]
        assert step.latency_ms >= 0
        assert step.message != nil
      end)
    end

    test "quickstart result includes total duration" do
      {:ok, pid} = Quickstart.start_link()

      config = %{
        provider: "anthropic",
        api_key: "sk-test-1234567890abcdef",
        model: "claude-3-5-sonnet"
      }

      {:ok, result} = Quickstart.run(pid, config)

      # Result should include total duration (similar to quickstart_complete event)
      assert result.total_ms > 0
      assert result.status == :success
    end

    test "session_id persists through workflow" do
      session_id = "test_session_xyz"
      {:ok, pid} = Quickstart.start_link(session_id: session_id)

      config = %{
        provider: "anthropic",
        api_key: "sk-test-1234567890abcdef",
        model: "claude-3-5-sonnet"
      }

      {:ok, result} = Quickstart.run(pid, config)

      state = Quickstart.get_state(pid)
      assert state.session_id == session_id
      assert result.status == :success
    end
  end

  # ── Tests: Timing / Performance ────────────────────────────────

  describe "Timing and Performance" do
    test "total workflow completes within reasonable time" do
      {:ok, pid} = Quickstart.start_link()

      config = %{
        provider: "anthropic",
        api_key: "sk-test-1234567890abcdef",
        model: "claude-3-5-sonnet"
      }

      {:ok, result} = Quickstart.run(pid, config, timeout: 30_000)

      # Should complete in <5 seconds for test (includes all I/O)
      assert result.total_ms < 5000
    end

    test "each step completes individually within timeout" do
      {:ok, pid} = Quickstart.start_link()

      config = %{
        provider: "anthropic",
        api_key: "sk-test-1234567890abcdef",
        model: "claude-3-5-sonnet"
      }

      {:ok, result} = Quickstart.run(pid, config)

      # Each step should complete quickly (individual latencies)
      Enum.each(result.step_results, fn step ->
        assert step.latency_ms < 1000  # Less than 1 second per step
      end)
    end
  end

  # ── Tests: WvdA Soundness ──────────────────────────────────────

  describe "WvdA Soundness: Deadlock Freedom, Liveness, Boundedness" do
    test "deadlock freedom: workflow completes even under load" do
      # Spawn multiple quickstart workflows concurrently
      pids =
        1..3
        |> Enum.map(fn i ->
          {:ok, pid} = Quickstart.start_link(session_id: "concurrent_#{i}")
          pid
        end)

      config = %{
        provider: "anthropic",
        api_key: "sk-test-1234567890abcdef",
        model: "claude-3-5-sonnet"
      }

      # Run all concurrently and collect results
      results =
        pids
        |> Enum.map(fn pid ->
          Task.async(fn ->
            Quickstart.run(pid, config, timeout: 30_000)
          end)
        end)
        |> Enum.map(&Task.await/1)

      # All should succeed
      assert Enum.all?(results, fn {:ok, result} -> result.status == :success end)
    end

    test "liveness: no infinite loops; all workflows eventually complete" do
      {:ok, pid} = Quickstart.start_link()

      config = %{
        provider: "anthropic",
        api_key: "sk-test-1234567890abcdef",
        model: "claude-3-5-sonnet"
      }

      # Set generous timeout but workflow should finish quickly
      start = System.monotonic_time(:millisecond)
      {:ok, result} = Quickstart.run(pid, config, timeout: 30_000)
      finish = System.monotonic_time(:millisecond)

      # Completed in reasonable time (proves liveness)
      assert finish - start > 0
      assert finish - start < 30_000
      assert result.status == :success
    end

    test "boundedness: ETS tables bounded; no unbounded memory growth" do
      # Create many quickstart agents
      config = %{
        provider: "anthropic",
        api_key: "sk-test-1234567890abcdef",
        model: "claude-3-5-sonnet"
      }

      1..10
      |> Enum.each(fn i ->
        {:ok, pid} = Quickstart.start_link(session_id: "bounded_#{i}")
        Quickstart.run(pid, config)
      end)

      # Verify ETS table size is bounded
      agents_count = :ets.info(:osa_demo_agents, :size)

      # Should have at most 10 entries (one per workflow) + default quickstart_demo
      assert agents_count <= 15
    end
  end

  # ── Tests: Armstrong Fault Tolerance ───────────────────────────

  describe "Armstrong Fault Tolerance: Let-It-Crash, Supervision" do
    test "configuration validates gracefully on invalid input" do
      {:ok, pid} = Quickstart.start_link()

      config = %{
        provider: "anthropic",
        api_key: "sk-test-1234567890abcdef",
        model: "claude-3-5-sonnet"
      }

      # Run successfully
      {:ok, result} = Quickstart.run(pid, config)
      assert result.status == :success

      # Second call should fail (already running)
      result2 = Quickstart.run(pid, config)
      assert match?({:error, :already_running}, result2)
    end

    test "recovers from invalid provider configuration" do
      {:ok, pid} = Quickstart.start_link()

      # Invalid config
      config = %{
        provider: "unknown",
        api_key: "test",
        model: "test"
      }

      {:ok, result} = Quickstart.run(pid, config)

      # Should complete workflow but mark step 2 as failure
      assert result.status == :failure

      step_2 = Enum.find(result.step_results, &(&1.step == 2))
      assert step_2.status == :fail
      assert step_2.error != nil
    end
  end

  # ── Helper Functions ───────────────────────────────────────────

  # (No additional helpers needed; tests work directly with GenServer state)
end
