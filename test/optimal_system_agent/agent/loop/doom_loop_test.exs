defmodule OptimalSystemAgent.Agent.Loop.DoomLoopTest do
  @moduledoc """
  Unit tests for the DoomLoop module.

  Tests the doom loop detection algorithm: when the same tool+error
  signature repeats 3+ consecutive times, execution halts to avoid
  wasting tokens on a stuck task.

  Functions covered:
    - check/3  — main detection entry point returning {:ok, state} or {:halt, msg, state}
  """

  use ExUnit.Case, async: false

  alias OptimalSystemAgent.Agent.Loop.DoomLoop

  setup_all do
    # DoomLoop.check/3 calls Bus.emit on the halt path, which requires
    # the Events.TaskSupervisor. Start it so those calls don't crash.
    case Process.whereis(OptimalSystemAgent.Events.TaskSupervisor) do
      nil ->
        start_supervised!({Task.Supervisor, name: OptimalSystemAgent.Events.TaskSupervisor, max_children: 2000})

      _pid ->
        :ok
    end

    :ok
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp base_state(opts \\ []) do
    %{
      session_id: Keyword.get(opts, :session_id, "doom-test-#{:erlang.unique_integer([:positive])}"),
      recent_failure_signatures: Keyword.get(opts, :recent_failure_signatures, [])
    }
  end

  defp tool_call(name, args \\ %{}) do
    %{id: "tc_#{:erlang.unique_integer([:positive])}", name: name, arguments: args}
  end

  defp tool_msg(name, content) do
    %{
      role: "tool",
      tool_call_id: "tc_#{:erlang.unique_integer([:positive])}",
      name: name,
      content: content
    }
  end

  defp error_result(tool_name, error_msg) do
    tc = tool_call(tool_name, %{})
    msg = tool_msg(tool_name, error_msg)
    {tc, {msg, error_msg}}
  end

  defp success_result(tool_name, content) do
    tc = tool_call(tool_name, %{})
    msg = tool_msg(tool_name, content)
    {tc, {msg, content}}
  end

  # A success message guaranteed to not contain any error indicator substrings.
  # The DoomLoop source uses @error_indicators which includes single-word atoms
  # like :file, :error, :failed, etc. So the success content must avoid all
  # of these substrings to be treated as a clean success.
  defp clean_success_result(tool_name) do
    success_result(tool_name, "Done OK output ready")
  end

  # ---------------------------------------------------------------------------
  # check/3 — no doom loop (normal operation)
  # ---------------------------------------------------------------------------

  describe "check/3 — no failures, no doom loop" do
    test "returns {:ok, state} when all tools succeed" do
      state = base_state()
      results = [clean_success_result("file_read")]
      tool_calls = [tool_call("file_read")]

      assert {:ok, updated_state} = DoomLoop.check(results, tool_calls, state)
      assert updated_state.recent_failure_signatures == []
    end

    test "returns {:ok, state} when there are no results at all" do
      state = base_state()

      assert {:ok, updated_state} = DoomLoop.check([], [], state)
      assert updated_state.recent_failure_signatures == []
    end
  end

  # ---------------------------------------------------------------------------
  # check/3 — single failure does not trigger
  # ---------------------------------------------------------------------------

  describe "check/3 — single failure, no doom loop" do
    test "returns {:ok, state} after one error" do
      state = base_state()
      results = [error_result("bash", "Error: command not found: foo")]
      tool_calls = [tool_call("bash")]

      assert {:ok, updated_state} = DoomLoop.check(results, tool_calls, state)
      # One failure signature recorded, but not 3x
      assert length(updated_state.recent_failure_signatures) == 1
    end
  end

  # ---------------------------------------------------------------------------
  # check/3 — two failures do not trigger (need 3)
  # ---------------------------------------------------------------------------

  describe "check/3 — two failures, no doom loop" do
    test "returns {:ok, state} after two identical errors" do
      state = base_state(recent_failure_signatures: ["bash:Error: command not found: foo"])
      results = [error_result("bash", "Error: command not found: foo")]
      tool_calls = [tool_call("bash")]

      assert {:ok, updated_state} = DoomLoop.check(results, tool_calls, state)
      assert length(updated_state.recent_failure_signatures) == 2
    end
  end

  # ---------------------------------------------------------------------------
  # check/3 — three identical failures trigger doom loop
  # ---------------------------------------------------------------------------

  describe "check/3 — three identical failures trigger doom loop" do
    test "returns {:halt, message, state} when same error repeats 3 times" do
      sig = "bash:Error: command not found: foo"
      state = base_state(recent_failure_signatures: [sig, sig])
      results = [error_result("bash", "Error: command not found: foo")]
      tool_calls = [tool_call("bash")]

      assert {:halt, message, updated_state} = DoomLoop.check(results, tool_calls, state)
      assert is_binary(message)
      assert String.contains?(message, "3 times")
      assert String.contains?(message, "bash")
      assert updated_state.session_id == state.session_id
    end

    test "halt message includes the triggering error pattern" do
      sig = "file_read:Error: No such file or directory"
      state = base_state(recent_failure_signatures: [sig, sig])
      results = [error_result("file_read", "Error: No such file or directory")]
      tool_calls = [tool_call("file_read")]

      assert {:halt, message, _state} = DoomLoop.check(results, tool_calls, state)
      assert String.contains?(message, "No such file")
    end

    test "halt message includes a suggestion for how to proceed" do
      sig = "bash:Error: command not found"
      state = base_state(recent_failure_signatures: [sig, sig])
      results = [error_result("bash", "Error: command not found")]
      tool_calls = [tool_call("bash")]

      assert {:halt, message, _state} = DoomLoop.check(results, tool_calls, state)
      assert String.contains?(message, "How to proceed")
    end
  end

  # ---------------------------------------------------------------------------
  # check/3 — any clean success resets the failure window
  # ---------------------------------------------------------------------------

  describe "check/3 — success prevents new signatures from accumulating" do
    test "clean success alongside errors does not add new signatures" do
      # Two prior failures
      sig = "bash:Error: permission denied"
      state = base_state(recent_failure_signatures: [sig, sig])

      # This iteration has a clean success mixed with an error
      results = [
        error_result("bash", "Error: permission denied"),
        success_result("file_read", "data loaded successfully")
      ]
      tool_calls = [tool_call("bash"), tool_call("file_read")]

      assert {:ok, updated_state} = DoomLoop.check(results, tool_calls, state)
      # Clean success prevents adding the new bash error signature,
      # but existing signatures are preserved (not cleared)
      assert updated_state.recent_failure_signatures == [sig, sig]
    end

    test "clean success after many failures preserves existing signatures" do
      # Build up 5 prior failures
      sigs = for i <- 1..5, do: "bash:Error: permission denied #{i}"
      state = base_state(recent_failure_signatures: sigs)

      results = [success_result("bash", "output: done")]
      tool_calls = [tool_call("bash")]

      assert {:ok, updated_state} = DoomLoop.check(results, tool_calls, state)
      # Clean success prevents new signatures but does not clear old ones
      assert updated_state.recent_failure_signatures == sigs
    end
  end

  # ---------------------------------------------------------------------------
  # check/3 — signature window is capped at 30 entries
  # ---------------------------------------------------------------------------

  describe "check/3 — sliding window cap at 30 entries" do
    test "failure signatures are capped at 30 entries" do
      # Pre-fill with 29 entries (all different, so no 3-repeat)
      sigs = for i <- 1..29, do: "tool_#{i}:Error: something went wrong #{i}"
      state = base_state(recent_failure_signatures: sigs)

      # Add one more unique failure
      results = [error_result("tool_30", "Error: something went wrong 30")]
      tool_calls = [tool_call("tool_30")]

      assert {:ok, updated_state} = DoomLoop.check(results, tool_calls, state)
      assert length(updated_state.recent_failure_signatures) <= 30
    end
  end

  # ---------------------------------------------------------------------------
  # check/3 — different error messages on same tool do not trigger
  # ---------------------------------------------------------------------------

  describe "check/3 — different error messages are distinct signatures" do
    test "same tool with different error messages does not trigger doom loop" do
      # Three failures on same tool but different errors
      sig1 = "bash:Error: command not found: foo"
      sig2 = "bash:Error: permission denied"
      sig3 = "bash:Error: timeout after 30s"
      state = base_state(recent_failure_signatures: [sig1, sig2])

      results = [error_result("bash", "Error: timeout after 30s")]
      tool_calls = [tool_call("bash")]

      assert {:ok, updated_state} = DoomLoop.check(results, tool_calls, state)
      assert length(updated_state.recent_failure_signatures) == 3
      # No single signature appears 3 times
    end
  end

  # ---------------------------------------------------------------------------
  # check/3 — partial success (mixed errors + successes) resets
  # ---------------------------------------------------------------------------

  describe "check/3 — partial success prevents new signatures" do
    test "mix of error and success does not add new signatures" do
      state = base_state(recent_failure_signatures: ["bash:Error: 1", "bash:Error: 1"])

      results = [
        error_result("bash", "Error: failed again"),
        success_result("file_read", "data retrieved OK")
      ]
      tool_calls = [tool_call("bash"), tool_call("file_read")]

      assert {:ok, updated_state} = DoomLoop.check(results, tool_calls, state)
      # The clean success prevents adding the new bash error signature,
      # but existing signatures are preserved
      assert updated_state.recent_failure_signatures == ["bash:Error: 1", "bash:Error: 1"]
    end
  end

  # ---------------------------------------------------------------------------
  # check/3 — multiple tool calls in one iteration
  # ---------------------------------------------------------------------------

  describe "check/3 — multiple tool calls in one iteration" do
    test "all failures from multiple tools add signatures" do
      state = base_state()

      results = [
        error_result("bash", "Error: command not found"),
        error_result("file_read", "Error: No such file")
      ]
      tool_calls = [tool_call("bash"), tool_call("file_read")]

      assert {:ok, updated_state} = DoomLoop.check(results, tool_calls, state)
      assert length(updated_state.recent_failure_signatures) == 2
    end
  end

  # ---------------------------------------------------------------------------
  # check/3 — suggestion content varies by error type
  # ---------------------------------------------------------------------------

  describe "check/3 — suggestion content matches error type" do
    test "'command not found' error produces installation suggestion" do
      sig = "bash:Error: command not found: xyz"
      state = base_state(recent_failure_signatures: [sig, sig])
      results = [error_result("bash", "Error: command not found: xyz")]
      tool_calls = [tool_call("bash")]

      assert {:halt, message, _state} = DoomLoop.check(results, tool_calls, state)
      assert String.contains?(message, "does not exist")
      assert String.contains?(message, "installed")
    end

    test "'Permission denied' error produces permissions suggestion" do
      sig = "bash:Error: Permission denied"
      state = base_state(recent_failure_signatures: [sig, sig])
      results = [error_result("bash", "Error: Permission denied")]
      tool_calls = [tool_call("bash")]

      assert {:halt, message, _state} = DoomLoop.check(results, tool_calls, state)
      assert String.contains?(message, "elevated permissions") or
             String.contains?(message, "permissions") or
             String.contains?(message, "inaccessible")
    end

    test "'No such file' error produces path suggestion" do
      sig = "file_read:Error: No such file or directory"
      state = base_state(recent_failure_signatures: [sig, sig])
      results = [error_result("file_read", "Error: No such file or directory")]
      tool_calls = [tool_call("file_read")]

      assert {:halt, message, _state} = DoomLoop.check(results, tool_calls, state)
      assert String.contains?(message, "does not exist") or
             String.contains?(message, "correct path")
    end

    test "'Blocked:' error produces permission tier suggestion" do
      sig = "file_write:Blocked: read_only mode"
      state = base_state(recent_failure_signatures: [sig, sig])
      results = [error_result("file_write", "Blocked: read_only mode")]
      tool_calls = [tool_call("file_write")]

      assert {:halt, message, _state} = DoomLoop.check(results, tool_calls, state)
      assert String.contains?(message, "permission") or
             String.contains?(message, "Blocked")
    end

    test "generic error produces generic suggestion" do
      sig = "bash:Error: something unexpected happened"
      state = base_state(recent_failure_signatures: [sig, sig])
      results = [error_result("bash", "Error: something unexpected happened")]
      tool_calls = [tool_call("bash")]

      assert {:halt, message, _state} = DoomLoop.check(results, tool_calls, state)
      assert String.contains?(message, "different strategy")
    end
  end

  # ---------------------------------------------------------------------------
  # check/3 — four or more repetitions
  # ---------------------------------------------------------------------------

  describe "check/3 — more than 3 repetitions" do
    test "doom loop still triggers at 4 repetitions" do
      sig = "bash:Error: permission denied"
      state = base_state(recent_failure_signatures: [sig, sig, sig])
      results = [error_result("bash", "Error: permission denied")]
      tool_calls = [tool_call("bash")]

      assert {:halt, message, _state} = DoomLoop.check(results, tool_calls, state)
      assert String.contains?(message, "4 times")
    end

    test "doom loop still triggers at 5 repetitions" do
      sig = "bash:Error: permission denied"
      state = base_state(recent_failure_signatures: [sig, sig, sig, sig])
      results = [error_result("bash", "Error: permission denied")]
      tool_calls = [tool_call("bash")]

      assert {:halt, message, _state} = DoomLoop.check(results, tool_calls, state)
      assert String.contains?(message, "5 times")
    end
  end
end
