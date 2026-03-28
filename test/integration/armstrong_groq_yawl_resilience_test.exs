defmodule OptimalSystemAgent.Integration.ArmstrongGroqYawlResilienceTest do
  @moduledoc """
  Joe Armstrong Resilience Tests for the Groq + YAWL integration layer.

  Distinct from groq_armstrong_fault_tolerance_test.exs, which tests Armstrong
  principles at the Groq *provider* level (circuit breakers, auth failures).
  This file tests Armstrong principles at the Groq *→ YAWL integration* level:
  how failures in the YAWL workflow layer surface and recover.

  Three principles demonstrated:

  1. Let-It-Crash — A YAWL launch failure returns a visible {:error, _} tuple.
     Groq then diagnoses the error, proving observability of failures.

  2. Supervision Trees — Killing the CaseLifecycle GenServer causes the
     :one_for_one supervisor to restart it; subsequent calls succeed.

  3. No Shared State — Two concurrent case launches do not interfere.
     Each case operates on its own isolated state.

  Run:
    GROQ_API_KEY=<key> mix test test/integration/armstrong_groq_yawl_resilience_test.exs \\
      --include integration

  Prerequisites:
    - GROQ_API_KEY env var set
    - YAWL embedded server running at :yawl_url (default http://localhost:8080)
    - Full OTP application running (never use --no-start)
  """

  use ExUnit.Case, async: false

  @moduletag :integration
  @moduletag :requires_application

  alias OptimalSystemAgent.Providers.OpenAICompatProvider
  alias OptimalSystemAgent.Yawl.CaseLifecycle
  alias OptimalSystemAgent.Yawl.SpecBuilder

  @groq_model "openai/gpt-oss-20b"

  # ---------------------------------------------------------------------------
  # Setup
  # ---------------------------------------------------------------------------

  setup do
    api_key =
      Application.get_env(:optimal_system_agent, :groq_api_key) ||
        System.get_env("GROQ_API_KEY")

    if is_nil(api_key) or api_key == "" do
      flunk("GROQ_API_KEY required — set it in environment or ~/.osa/.env")
    end

    Application.put_env(:optimal_system_agent, :groq_api_key, api_key)

    # CaseLifecycle is started by the application supervisor on boot.
    # Only call start_supervised if not registered (handles isolated test runs).
    case Process.whereis(CaseLifecycle) do
      nil -> start_supervised({CaseLifecycle, []})
      _pid -> :ok
    end

    :ok
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  # Poll for a named process to reappear after a crash.
  # Mirrors the pattern from groq_armstrong_fault_tolerance_test.exs.
  defp wait_for_pid(name, timeout_ms \\ 2_000) do
    deadline = System.monotonic_time(:millisecond) + timeout_ms
    do_wait_for_pid(name, deadline)
  end

  defp do_wait_for_pid(name, deadline) do
    case Process.whereis(name) do
      nil ->
        if System.monotonic_time(:millisecond) >= deadline do
          raise "Process #{inspect(name)} did not restart within timeout"
        else
          Process.sleep(50)
          do_wait_for_pid(name, deadline)
        end

      pid ->
        pid
    end
  end

  # ---------------------------------------------------------------------------
  # Test 1: Let-It-Crash — YAWL failure is visible, Groq confirms observability
  # ---------------------------------------------------------------------------

  @tag timeout: 60_000
  test "Let-It-Crash: failed YAWL launch is visible as {:error, _}, Groq diagnoses it" do
    bad_xml = "THIS IS NOT VALID XML AT ALL"
    case_id = "bad-xml-#{:erlang.unique_integer([:positive])}"

    # Armstrong: failure must surface as a tagged tuple — never swallowed as nil
    result = CaseLifecycle.launch_case(bad_xml, case_id, nil)

    assert match?({:error, _}, result),
           "launch_case with invalid XML must return {:error, _}, got: #{inspect(result)}"

    {:error, reason} = result
    reason_str = inspect(reason)

    # Groq diagnoses the visible error — proves failures are observable, not hidden
    messages = [
      %{
        role: "user",
        content:
          "A YAWL workflow failed with: #{reason_str}. " <>
            "In 5 words or less, what type of error is this?"
      }
    ]

    assert {:ok, %{content: diagnosis}} =
             OpenAICompatProvider.chat(
               :groq,
               messages,
               model: @groq_model,
               temperature: 0.0,
               receive_timeout: 30_000
             )

    assert is_binary(diagnosis),
           "Groq diagnosis must be a string, got: #{inspect(diagnosis)}"

    assert String.length(String.trim(diagnosis)) > 0,
           "Groq diagnosis must not be empty"

    IO.puts("\n  [Let-It-Crash] YAWL error: #{reason_str}")
    IO.puts("  [Let-It-Crash] Groq diagnosis: #{diagnosis}")
  end

  # ---------------------------------------------------------------------------
  # Test 2: Supervision Trees — CaseLifecycle restarts after :kill
  # ---------------------------------------------------------------------------

  @tag timeout: 30_000
  test "Supervision: CaseLifecycle restarts after :kill — supervisor recovers it" do
    original_pid = Process.whereis(CaseLifecycle)

    assert original_pid != nil,
           "CaseLifecycle must be running under the YAWL supervisor"

    assert Process.alive?(original_pid)

    # Monitor so we can confirm the crash before polling for restart
    ref = Process.monitor(original_pid)

    # Kill the process — unhandled exit; :one_for_one supervisor restarts permanent children
    Process.exit(original_pid, :kill)

    # Confirm the crash was received
    assert_receive {:DOWN, ^ref, :process, ^original_pid, :killed}, 2_000,
                   "Expected :killed DOWN message from CaseLifecycle"

    # Allow supervisor time to restart — :one_for_one is fast but not instant
    Process.sleep(200)

    # Poll until the supervisor restarts the named process
    new_pid = wait_for_pid(CaseLifecycle, 2_000)

    assert new_pid != nil,
           "Supervisor must restart CaseLifecycle after :kill"

    assert new_pid != original_pid,
           "Restarted process must have a new PID (different from the killed one)"

    assert Process.alive?(new_pid),
           "Restarted CaseLifecycle must be alive"

    # The restarted GenServer must handle calls — returns tagged tuple, not crash
    probe_id = "post-restart-probe-#{:erlang.unique_integer([:positive])}"
    call_result = CaseLifecycle.list_workitems(probe_id)

    assert match?({:ok, _}, call_result) or match?({:error, _}, call_result),
           "Restarted CaseLifecycle must handle calls as tagged tuples, got: #{inspect(call_result)}"

    IO.puts("\n  [Supervision] Old PID: #{inspect(original_pid)} → New PID: #{inspect(new_pid)}")
    IO.puts("  [Supervision] Post-restart call: #{inspect(call_result)}")
  end

  # ---------------------------------------------------------------------------
  # Test 3: No Shared State — concurrent cases don't interfere
  # ---------------------------------------------------------------------------

  @tag timeout: 60_000
  test "No Shared State: concurrent case launches are independent, results don't cross" do
    spec_xml = SpecBuilder.sequence(["TaskA"])

    case_id_1 = "concurrent-case-1-#{:erlang.unique_integer([:positive])}"
    case_id_2 = "concurrent-case-2-#{:erlang.unique_integer([:positive])}"

    # Launch two cases concurrently — no shared mutable state means no interference
    task_1 = Task.async(fn -> CaseLifecycle.launch_case(spec_xml, case_id_1, nil) end)
    task_2 = Task.async(fn -> CaseLifecycle.launch_case(spec_xml, case_id_2, nil) end)

    result_1 = Task.await(task_1, 20_000)
    result_2 = Task.await(task_2, 20_000)

    # Both must return tagged tuples — no crash, no interference
    assert match?({:ok, _}, result_1) or match?({:error, _}, result_1),
           "Case 1 must return tagged tuple, got: #{inspect(result_1)}"

    assert match?({:ok, _}, result_2) or match?({:error, _}, result_2),
           "Case 2 must return tagged tuple, got: #{inspect(result_2)}"

    # When server is available: each response must be scoped to its own case_id
    case result_1 do
      {:ok, body} ->
        assert body["case_id"] == case_id_1,
               "Case 1 response must belong to #{case_id_1}, got: #{inspect(body["case_id"])}"

      {:error, _} ->
        :ok
    end

    case result_2 do
      {:ok, body} ->
        assert body["case_id"] == case_id_2,
               "Case 2 response must belong to #{case_id_2}, got: #{inspect(body["case_id"])}"

      {:error, _} ->
        :ok
    end

    # Cleanup
    _r1 = CaseLifecycle.cancel_case(case_id_1)
    _r2 = CaseLifecycle.cancel_case(case_id_2)

    IO.puts("\n  [No-Shared-State] Case 1 (#{case_id_1}): #{inspect(result_1)}")
    IO.puts("  [No-Shared-State] Case 2 (#{case_id_2}): #{inspect(result_2)}")
  end
end
