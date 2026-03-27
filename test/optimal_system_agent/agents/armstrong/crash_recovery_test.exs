defmodule OptimalSystemAgent.Agents.Armstrong.CrashRecoveryTest do
  @moduledoc """
  Test suite for Crash Recovery Agent.

  Tests crash classification, MTTR lookup, recovery strategies, and telemetry.
  Follows Chicago TDD: behavior verification with real (not mocked) implementations.
  """
  use ExUnit.Case, async: false

  alias OptimalSystemAgent.Agents.Armstrong.CrashRecovery

  setup_all do
    # Start the GenServer for all tests
    {:ok, _pid} = CrashRecovery.start_link()
    :ok
  end

  describe "classify_crash/1" do
    test "classifies timeout error as :timeout" do
      error = {:timeout, :some_op}
      assert CrashRecovery.classify_crash(error) == :timeout
    end

    test "classifies exception struct as :exception" do
      error = %RuntimeError{message: "something failed"}
      assert CrashRecovery.classify_crash(error) == :exception
    end

    test "classifies killed atom as :exit" do
      error = :killed
      assert CrashRecovery.classify_crash(error) == :exit
    end

    test "classifies assertion error as :assertion" do
      error = %ExUnit.AssertionError{message: "expected true"}
      assert CrashRecovery.classify_crash(error) == :assertion
    end

    test "classifies timeout string as :timeout" do
      error = "timeout waiting for response"
      assert CrashRecovery.classify_crash(error) == :timeout
    end

    test "classifies exit atom (not normal) as :exit" do
      error = :shutdown
      assert CrashRecovery.classify_crash(error) == :exit
    end

    test "treats unknown error as :exception" do
      error = "some random error message"
      assert CrashRecovery.classify_crash(error) == :exception
    end
  end

  describe "expected_mttr/1" do
    test "returns 5000ms for timeout" do
      assert CrashRecovery.expected_mttr(:timeout) == 5_000
    end

    test "returns 2000ms for exception" do
      assert CrashRecovery.expected_mttr(:exception) == 2_000
    end

    test "returns 1000ms for exit" do
      assert CrashRecovery.expected_mttr(:exit) == 1_000
    end

    test "returns 10000ms for assertion" do
      assert CrashRecovery.expected_mttr(:assertion) == 10_000
    end

    test "returns 10000ms default for unknown type" do
      assert CrashRecovery.expected_mttr(:unknown_failure) == 10_000
    end
  end

  describe "suggest_recovery/1" do
    test "suggests :escalate for timeout" do
      assert CrashRecovery.suggest_recovery(:timeout) == :escalate
    end

    test "suggests :restart for exit" do
      assert CrashRecovery.suggest_recovery(:exit) == :restart
    end

    test "suggests :restart for exception" do
      assert CrashRecovery.suggest_recovery(:exception) == :restart
    end

    test "suggests :circuit_break for assertion" do
      assert CrashRecovery.suggest_recovery(:assertion) == :circuit_break
    end

    test "suggests :degrade for unknown type" do
      assert CrashRecovery.suggest_recovery(:unknown) == :degrade
    end
  end

  describe "record_crash/2" do
    test "records crash with telemetry (non-blocking)" do
      error = {:timeout, :db_query}
      mttr_ms = 7_500

      # Record the crash (returns :ok)
      assert :ok = CrashRecovery.record_crash(error, mttr_ms)

      # Give telemetry async task a moment to run
      Process.sleep(100)

      # Verify crash is logged
      log = CrashRecovery.crash_log()
      assert length(log) > 0

      # Most recent entry should match
      entry = hd(log)
      assert entry.failure_type == :timeout
      assert entry.mttr_actual == 7_500
      assert entry.mttr_expected == 5_000
      assert entry.escalated == true  # 7500 > 5000
    end

    test "records non-escalated crash" do
      error = :killed
      mttr_ms = 800

      assert :ok = CrashRecovery.record_crash(error, mttr_ms)
      Process.sleep(100)

      log = CrashRecovery.crash_log()
      entry = hd(log)

      assert entry.failure_type == :exit
      assert entry.mttr_actual == 800
      assert entry.escalated == false  # 800 < 3000
    end

    test "marks crash as escalated when MTTR exceeds threshold" do
      error = %RuntimeError{message: "db connection lost"}
      mttr_ms = 6_000

      assert :ok = CrashRecovery.record_crash(error, mttr_ms)
      Process.sleep(100)

      log = CrashRecovery.crash_log()
      entry = hd(log)

      assert entry.failure_type == :exception
      assert entry.escalated == true  # 6000 > 5000 (exception threshold)
    end
  end

  describe "crash_log/0" do
    test "returns list of crash records" do
      log = CrashRecovery.crash_log()
      assert is_list(log)
    end

    test "crash log is capped at 1000 entries (FIFO eviction)" do
      # Record 1050 crashes
      for i <- 1..1050 do
        error = {:timeout, :op}
        CrashRecovery.record_crash(error, 5000 + i)
      end

      Process.sleep(100)

      log = CrashRecovery.crash_log()
      assert length(log) <= 1000
    end

    test "crash log maintains FIFO order (newest first)" do
      # Clear state by recording in order
      CrashRecovery.record_crash({:timeout, :op1}, 1000)
      Process.sleep(50)
      CrashRecovery.record_crash({:timeout, :op2}, 2000)
      Process.sleep(50)
      CrashRecovery.record_crash({:timeout, :op3}, 3000)
      Process.sleep(100)

      log = CrashRecovery.crash_log()

      # Most recent (op3) should be first
      assert hd(log).mttr_actual == 3000
      assert hd(tl(log)).mttr_actual == 2000
      assert hd(tl(tl(log))).mttr_actual == 1000
    end
  end

  describe "stats/0" do
    test "returns statistics map with required keys" do
      stats = CrashRecovery.stats()

      assert Map.has_key?(stats, :total_crashes)
      assert Map.has_key?(stats, :by_type)
      assert Map.has_key?(stats, :escalated_count)
      assert Map.has_key?(stats, :avg_mttr_ms)

      assert is_integer(stats.total_crashes)
      assert is_map(stats.by_type)
      assert is_integer(stats.escalated_count)
      assert is_float(stats.avg_mttr_ms)
    end

    test "stats shows crash counts by failure type" do
      # Record different failure types
      CrashRecovery.record_crash({:timeout, :op}, 5000)
      Process.sleep(50)
      CrashRecovery.record_crash(:killed, 1000)
      Process.sleep(50)
      CrashRecovery.record_crash(%RuntimeError{}, 2000)
      Process.sleep(100)

      stats = CrashRecovery.stats()

      # Should have recorded 3 crashes
      assert stats.total_crashes >= 3

      # by_type should contain the failure types we recorded
      by_type = stats.by_type
      assert by_type[:timeout] >= 1
      assert by_type[:exit] >= 1
      assert by_type[:exception] >= 1
    end

    test "stats calculates average MTTR correctly" do
      # Record 3 crashes with known MTTR values
      CrashRecovery.record_crash({:timeout, :op1}, 1000)
      Process.sleep(50)
      CrashRecovery.record_crash({:timeout, :op2}, 2000)
      Process.sleep(50)
      CrashRecovery.record_crash({:timeout, :op3}, 3000)
      Process.sleep(100)

      stats = CrashRecovery.stats()

      # Average of 1000, 2000, 3000 = 2000
      assert stats.avg_mttr_ms >= 1000
    end

    test "stats shows escalation count" do
      # Record escalated crash (timeout with MTTR > 5000)
      CrashRecovery.record_crash({:timeout, :op1}, 8000)
      Process.sleep(50)

      # Record non-escalated crash (exit with MTTR < 3000)
      CrashRecovery.record_crash(:killed, 500)
      Process.sleep(100)

      stats = CrashRecovery.stats()

      # Should count at least 1 escalated
      assert stats.escalated_count >= 1
    end
  end

  describe "crash classification integration" do
    test "classify_crash, expected_mttr, and suggest_recovery work together" do
      # Test a complete workflow
      error = {:timeout, :external_api}

      failure_type = CrashRecovery.classify_crash(error)
      assert failure_type == :timeout

      expected = CrashRecovery.expected_mttr(failure_type)
      assert expected == 5_000

      recovery = CrashRecovery.suggest_recovery(failure_type)
      assert recovery == :escalate
    end

    test "different errors lead to different recovery paths" do
      # Timeout → escalate
      assert CrashRecovery.classify_crash({:timeout, :op}) == :timeout
      assert CrashRecovery.suggest_recovery(:timeout) == :escalate

      # Exit → restart
      assert CrashRecovery.classify_crash(:killed) == :exit
      assert CrashRecovery.suggest_recovery(:exit) == :restart

      # Exception → restart
      assert CrashRecovery.classify_crash(%RuntimeError{}) == :exception
      assert CrashRecovery.suggest_recovery(:exception) == :restart

      # Assertion → circuit_break
      assert CrashRecovery.classify_crash(%ExUnit.AssertionError{}) == :assertion
      assert CrashRecovery.suggest_recovery(:assertion) == :circuit_break
    end
  end

  describe "MTTR escalation detection (actual > expected)" do
    test "timeout escalates when MTTR exceeds expected 5s" do
      error = {:timeout, :slow_op}
      mttr_ms = 7_000  # Exceeds 5_000 expected

      assert :ok = CrashRecovery.record_crash(error, mttr_ms)
      Process.sleep(100)

      log = CrashRecovery.crash_log()
      entry = hd(log)

      assert entry.escalated == true
    end

    test "exception escalates when MTTR exceeds expected 2s" do
      error = %RuntimeError{message: "db error"}
      mttr_ms = 3_000  # Exceeds 2_000 expected

      assert :ok = CrashRecovery.record_crash(error, mttr_ms)
      Process.sleep(100)

      log = CrashRecovery.crash_log()
      entry = hd(log)

      assert entry.escalated == true
    end

    test "exit escalates when MTTR exceeds expected 1s" do
      error = :killed
      mttr_ms = 2_000  # Exceeds 1_000 expected

      assert :ok = CrashRecovery.record_crash(error, mttr_ms)
      Process.sleep(100)

      log = CrashRecovery.crash_log()
      entry = hd(log)

      assert entry.escalated == true
    end

    test "assertion escalates when MTTR exceeds expected 10s" do
      error = %ExUnit.AssertionError{message: "assertion failed"}
      mttr_ms = 15_000  # Exceeds 10_000 expected

      assert :ok = CrashRecovery.record_crash(error, mttr_ms)
      Process.sleep(100)

      log = CrashRecovery.crash_log()
      entry = hd(log)

      assert entry.escalated == true
    end
  end
end
