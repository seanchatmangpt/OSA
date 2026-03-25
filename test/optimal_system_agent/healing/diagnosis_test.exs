defmodule OptimalSystemAgent.Healing.DiagnosisTest do
  @moduledoc """
  Unit tests for Diagnosis — verifies classification of errors into 11 failure modes.

  Maps errors to Shannon/Ashby/Beer/Wiener + 7 derived combinations:
  1. Shannon: Information loss
  2. Ashby: Regulatory failure
  3. Beer: Complexity overload
  4. Wiener: Feedback instability
  5. Deadlock: Circular wait condition
  6. Cascade: Failure spreads downstream
  7. Byzantine: Compromised/malicious component
  8. Starvation: Resource exhaustion
  9. Livelock: Agents conflict without progress
  10. Timeout: Operation exceeds deadline
  11. Inconsistent: State mismatch across systems
  """
  use ExUnit.Case, async: true

  alias OptimalSystemAgent.Healing.Diagnosis

  # -------- Shannon: Information Loss --------

  describe "diagnose/2 — Shannon (information loss)" do
    @tag :unit
    test "detects missing key as information loss" do
      error = {:error, "field 'x' not found"}
      {mode, desc, cause} = Diagnosis.diagnose(error)
      assert mode == :shannon
      assert desc == "information loss"
      assert String.contains?(cause, "not found") or String.contains?(cause, "missing")
    end

    @tag :unit
    test "detects truncation as information loss" do
      error = {:error, :truncated_message}
      {mode, desc, _cause} = Diagnosis.diagnose(error)
      assert mode == :shannon
      assert desc == "information loss"
    end

    @tag :unit
    test "detects incomplete data as information loss" do
      error = %{error: "incomplete response"}
      {mode, desc, _cause} = Diagnosis.diagnose(error)
      assert mode == :shannon
      assert desc == "information loss"
    end

    @tag :unit
    test "detects missing data as information loss" do
      error = %{error: :missing_data}
      {mode, desc, _cause} = Diagnosis.diagnose(error)
      assert mode == :shannon
      assert desc == "information loss"
    end
  end

  # -------- Ashby: Regulatory Failure --------

  describe "diagnose/2 — Ashby (regulatory failure)" do
    @tag :unit
    test "detects drift as regulatory failure" do
      error = {:error, :drift_detected}
      {mode, desc, _cause} = Diagnosis.diagnose(error)
      assert mode == :ashby
      assert desc == "regulatory failure"
    end

    @tag :unit
    test "detects oscillation as regulatory failure" do
      error = %{error: :oscillation}
      {mode, desc, _cause} = Diagnosis.diagnose(error)
      assert mode == :ashby
      assert desc == "regulatory failure"
    end

    @tag :unit
    test "detects wrong setpoint as regulatory failure" do
      error = %{reason: :wrong_setpoint}
      {mode, desc, _cause} = Diagnosis.diagnose(error)
      assert mode == :ashby
      assert desc == "regulatory failure"
    end
  end

  # -------- Beer: Complexity Overload --------

  describe "diagnose/2 — Beer (complexity overload)" do
    @tag :unit
    test "detects state explosion as complexity overload" do
      error = {:error, :state_explosion}
      {mode, desc, _cause} = Diagnosis.diagnose(error)
      assert mode == :beer
      assert desc == "complexity overload"
    end

    @tag :unit
    test "detects too many variables as complexity overload" do
      error = %{error: :too_many_vars}
      {mode, desc, _cause} = Diagnosis.diagnose(error)
      assert mode == :beer
      assert desc == "complexity overload"
    end

    @tag :unit
    test "detects state explosion in message as complexity overload" do
      error = %{message: "state explosion detected in loop"}
      {mode, desc, _cause} = Diagnosis.diagnose(error)
      assert mode == :beer
      assert desc == "complexity overload"
    end
  end

  # -------- Wiener: Feedback Instability --------

  describe "diagnose/2 — Wiener (feedback instability)" do
    @tag :unit
    test "detects overcorrection as feedback instability" do
      error = {:error, :overcorrection}
      {mode, desc, _cause} = Diagnosis.diagnose(error)
      assert mode == :wiener
      assert desc == "feedback instability"
    end

    @tag :unit
    test "detects hunting as feedback instability" do
      error = %{error: :hunting}
      {mode, desc, _cause} = Diagnosis.diagnose(error)
      assert mode == :wiener
      assert desc == "feedback instability"
    end

    @tag :unit
    test "detects oscillatory behavior as feedback instability" do
      error = %{message: "hunting detected in control loop"}
      {mode, desc, _cause} = Diagnosis.diagnose(error)
      assert mode == :wiener
      assert desc == "feedback instability"
    end
  end

  # -------- Deadlock --------

  describe "diagnose/2 — Deadlock (circular wait)" do
    @tag :unit
    test "detects circular wait as deadlock" do
      error = {:error, :circular_wait}
      {mode, desc, _cause} = Diagnosis.diagnose(error)
      assert mode == :deadlock
      assert desc == "circular wait condition"
    end

    @tag :unit
    test "detects deadlock message as deadlock" do
      error = %{error: "deadlock detected in agent coordination"}
      {mode, desc, _cause} = Diagnosis.diagnose(error)
      assert mode == :deadlock
      assert desc == "circular wait condition"
    end
  end

  # -------- Cascade --------

  describe "diagnose/2 — Cascade (failure spread)" do
    @tag :unit
    test "detects cascading failure as cascade" do
      error = {:error, :cascading_failure}
      {mode, desc, _cause} = Diagnosis.diagnose(error)
      assert mode == :cascade
      assert desc == "failure spreads to downstream components"
    end

    @tag :unit
    test "detects cascade in message as cascade" do
      error = %{message: "cascade detected: component B failed after A"}
      {mode, desc, _cause} = Diagnosis.diagnose(error)
      assert mode == :cascade
      assert desc == "failure spreads to downstream components"
    end
  end

  # -------- Byzantine --------

  describe "diagnose/2 — Byzantine (compromised component)" do
    @tag :unit
    test "detects malicious input as byzantine" do
      error = {:error, :malicious_input}
      {mode, desc, _cause} = Diagnosis.diagnose(error)
      assert mode == :byzantine
      assert desc == "compromised or malicious component"
    end

    @tag :unit
    test "detects compromised component as byzantine" do
      error = %{error: :compromised}
      {mode, desc, _cause} = Diagnosis.diagnose(error)
      assert mode == :byzantine
      assert desc == "compromised or malicious component"
    end

    @tag :unit
    test "detects byzantine in message as byzantine" do
      error = %{message: "byzantine fault detected in consensus"}
      {mode, desc, _cause} = Diagnosis.diagnose(error)
      assert mode == :byzantine
      assert desc == "compromised or malicious component"
    end
  end

  # -------- Starvation --------

  describe "diagnose/2 — Starvation (resource exhaustion)" do
    @tag :unit
    test "detects starvation as starvation" do
      error = {:error, :starvation}
      {mode, desc, _cause} = Diagnosis.diagnose(error)
      assert mode == :starvation
      assert desc == "resource exhaustion or priority inversion"
    end

    @tag :unit
    test "detects priority inversion as starvation" do
      error = %{error: :priority_inversion}
      {mode, desc, _cause} = Diagnosis.diagnose(error)
      assert mode == :starvation
      assert desc == "resource exhaustion or priority inversion"
    end

    @tag :unit
    test "detects resource exhaustion in message as starvation" do
      error = %{message: "resource exhaustion: no available threads"}
      {mode, desc, _cause} = Diagnosis.diagnose(error)
      assert mode == :starvation
      assert desc == "resource exhaustion or priority inversion"
    end
  end

  # -------- Livelock --------

  describe "diagnose/2 — Livelock (conflict without progress)" do
    @tag :unit
    test "detects livelock as livelock" do
      error = {:error, :livelock}
      {mode, desc, _cause} = Diagnosis.diagnose(error)
      assert mode == :livelock
      assert desc == "agents conflict without making progress"
    end

    @tag :unit
    test "detects livelock in message as livelock" do
      error = %{message: "livelock detected: agents continuously retry"}
      {mode, desc, _cause} = Diagnosis.diagnose(error)
      assert mode == :livelock
      assert desc == "agents conflict without making progress"
    end
  end

  # -------- Timeout --------

  describe "diagnose/2 — Timeout (exceeds deadline)" do
    @tag :unit
    test "detects timeout as timeout" do
      error = {:error, :timeout}
      {mode, desc, _cause} = Diagnosis.diagnose(error)
      assert mode == :timeout
      assert desc == "operation exceeds deadline"
    end

    @tag :unit
    test "detects deadline exceeded as timeout" do
      error = %{error: :deadline_exceeded}
      {mode, desc, _cause} = Diagnosis.diagnose(error)
      assert mode == :timeout
      assert desc == "operation exceeds deadline"
    end

    @tag :unit
    test "detects timeout in message as timeout" do
      error = %{message: "operation timed out after 30s"}
      {mode, desc, _cause} = Diagnosis.diagnose(error)
      assert mode == :timeout
      assert desc == "operation exceeds deadline"
    end
  end

  # -------- Inconsistent --------

  describe "diagnose/2 — Inconsistent (state mismatch)" do
    @tag :unit
    test "detects state mismatch as inconsistent" do
      error = {:error, :state_mismatch}
      {mode, desc, _cause} = Diagnosis.diagnose(error)
      assert mode == :inconsistent
      assert desc == "state mismatch across systems"
    end

    @tag :unit
    test "detects consistency violation as inconsistent" do
      error = %{error: :consistency_violation}
      {mode, desc, _cause} = Diagnosis.diagnose(error)
      assert mode == :inconsistent
      assert desc == "state mismatch across systems"
    end

    @tag :unit
    test "detects state mismatch in message as inconsistent" do
      error = %{message: "state mismatch between replica A and B"}
      {mode, desc, _cause} = Diagnosis.diagnose(error)
      assert mode == :inconsistent
      assert desc == "state mismatch across systems"
    end
  end

  # -------- Unknown/Fallback --------

  describe "diagnose/2 — Unknown errors" do
    @tag :unit
    test "returns unknown for unrecognized error atoms" do
      error = {:error, :some_random_error}
      {mode, desc, _cause} = Diagnosis.diagnose(error)
      assert mode == :unknown
      assert is_binary(desc) and is_binary(_cause)
    end

    @tag :unit
    test "returns unknown for completely unrecognized messages" do
      error = %{message: "something went sideways"}
      {mode, desc, _cause} = Diagnosis.diagnose(error)
      assert mode == :unknown
      assert is_binary(desc) and is_binary(_cause)
    end
  end

  # -------- Context usage --------

  describe "diagnose/2 with context" do
    @tag :unit
    test "includes context in diagnosis when provided" do
      error = {:error, :timeout}
      context = %{component: "scheduler", attempt: 3}
      {mode, _desc, cause} = Diagnosis.diagnose(error, context)
      assert mode == :timeout
      # Context may be included in the cause string
      assert is_binary(cause)
    end

    @tag :unit
    test "works without context (uses empty map by default)" do
      error = {:error, :shannon}
      result = Diagnosis.diagnose(error)
      assert is_tuple(result)
      assert tuple_size(result) == 3
    end
  end

  # -------- Return type verification --------

  describe "diagnose/2 — return structure" do
    @tag :unit
    test "always returns {mode, description, root_cause} tuple" do
      error = {:error, :timeout}
      result = Diagnosis.diagnose(error)
      assert is_tuple(result)
      assert tuple_size(result) == 3
      {mode, desc, cause} = result
      assert is_atom(mode)
      assert is_binary(desc)
      assert is_binary(cause)
    end
  end
end
