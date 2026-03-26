defmodule OptimalSystemAgent.Testing.TestContext do
  @moduledoc """
  Helpers for adding debugging context to test failures.

  Usage in tests:
    context = TestContext.api_failure(
      endpoint: "/api/test",
      expected_status: 200
    )
    raise context.error_message
  """

  defstruct [:category, :details, :error_message, :debug_steps]

  @doc """
  Context for API/network failures.
  """
  def api_failure(opts) do
    endpoint = Keyword.get(opts, :endpoint, "unknown")
    expected_status = Keyword.get(opts, :expected_status, 200)
    actual_status = Keyword.get(opts, :actual_status, nil)
    reason = Keyword.get(opts, :reason, "unknown")

    error_msg = """
    API Request Failed

    Endpoint: #{endpoint}
    Expected Status: #{expected_status}
    Actual Status: #{actual_status}
    Reason: #{reason}

    Debugging Steps:
      1. Is localhost:8089 running? Run: curl http://localhost:8089/health
      2. Check endpoint exists: curl -v http://localhost:8089#{endpoint}
      3. Check OSA logs: tail -f logs/osa.log
      4. Verify response format: curl http://localhost:8089#{endpoint} | jq .
    """

    %__MODULE__{
      category: :api_failure,
      details: opts,
      error_message: error_msg,
      debug_steps: [
        "Verify service is running",
        "Check endpoint URL",
        "Check response format",
        "Check logs"
      ]
    }
  end

  @doc """
  Context for timing/race condition failures.
  """
  def timing_failure(opts) do
    operation = Keyword.get(opts, :operation, "unknown")
    timeout_ms = Keyword.get(opts, :timeout_ms, 5000)
    expected_message = Keyword.get(opts, :expected_message, "unknown")

    error_msg = """
    Timing/Race Condition Detected

    Operation: #{operation}
    Timeout: #{timeout_ms}ms
    Expected: #{inspect(expected_message)}

    Debugging Steps:
      1. Run test in isolation: mix test path/to_test.exs --verbose
      2. Run serially (not parallel): mix test --max-cases 1
      3. Add IO.inspect to see actual values
      4. Check for missing async: false tag
      5. Verify all GenServer calls are synchronous

    If test passes in isolation but fails in parallel:
      → It's a timing issue, not logic
      → Check for shared state between tests
      → Add proper wait/assert_receive
    """

    %__MODULE__{
      category: :timing_failure,
      details: opts,
      error_message: error_msg,
      debug_steps: [
        "Run test in isolation",
        "Run tests serially",
        "Add explicit waits",
        "Check test isolation"
      ]
    }
  end

  @doc """
  Context for logic/assertion failures.
  """
  def logic_failure(opts) do
    expected = Keyword.get(opts, :expected, "unknown")
    actual = Keyword.get(opts, :actual, "unknown")
    operation = Keyword.get(opts, :operation, "unknown")

    error_msg = """
    Logic/Assertion Failure

    Operation: #{operation}
    Expected: #{inspect(expected)}
    Actual: #{inspect(actual)}

    Debugging Steps:
      1. Add IO.inspect at each step to trace execution
      2. Use IEx.pry() to drop into interactive console
      3. Check for off-by-one errors
      4. Verify data types match (string vs atom, int vs float)
      5. Check for nil values where non-nil expected

    Try this:
      # In iex console:
      iex> Code.load_file("lib/path/to/module.ex")
      iex> Module.function()
      # Manually trace execution
    """

    %__MODULE__{
      category: :logic_failure,
      details: opts,
      error_message: error_msg,
      debug_steps: [
        "Add debug output at each step",
        "Use IEx.pry for interactive debugging",
        "Check data types",
        "Trace execution path"
      ]
    }
  end

  @doc """
  Context for resource exhaustion failures.
  """
  def resource_failure(opts) do
    resource_type = Keyword.get(opts, :resource_type, "unknown")
    limit = Keyword.get(opts, :limit, "unknown")
    actual = Keyword.get(opts, :actual, "unknown")

    error_msg = """
    Resource Exhaustion Detected

    Resource: #{resource_type}
    Limit: #{inspect(limit)}
    Actual: #{inspect(actual)}

    Debugging Steps:
      1. Check memory usage: :erlang.memory() in iex
      2. Check process count: length(Process.list())
      3. Monitor during test: watch -n 1 'ps aux | grep beam'
      4. Check for unbounded collections (max_size missing)
      5. Verify resource cleanup in teardown (on_exit/1)

    Common causes:
      • Collection grows without max_size limit
      • Process not stopped (orphan process)
      • Cache without TTL or max item count
      • Queue grows unbounded
      • Connection not closed (resource leak)
    """

    %__MODULE__{
      category: :resource_failure,
      details: opts,
      error_message: error_msg,
      debug_steps: [
        "Check memory usage",
        "Check process count",
        "Verify resource cleanup",
        "Check for unbounded growth"
      ]
    }
  end

  @doc """
  Context for flaky test failures.
  """
  def flaky_test(opts) do
    test_name = Keyword.get(opts, :test_name, "unknown")
    pass_rate = Keyword.get(opts, :pass_rate, "unknown")
    failure_pattern = Keyword.get(opts, :failure_pattern, "unknown")

    error_msg = """
    Flaky Test Detected

    Test: #{test_name}
    Pass Rate: #{inspect(pass_rate)}
    Failure Pattern: #{inspect(failure_pattern)}

    Debugging Steps:
      1. Run test 20 times: for i in {1..20}; do mix test path/to_test.exs; done
      2. Check for timing issues (see Timing Issues category)
      3. Verify test isolation: mix test --max-cases 1
      4. Check for shared state between tests
      5. Seed random: :random.seed(:exsplus, {1, 2, 3})

    If fails only in parallel:
      → async: false test tag (disable parallelization)
      → Or add proper synchronization (wait/assert_receive)

    If fails unpredictably:
      → Likely timing or external service issue
      → Mock external services
      → Use fake clock instead of real time
    """

    %__MODULE__{
      category: :flaky_test,
      details: opts,
      error_message: error_msg,
      debug_steps: [
        "Run test multiple times",
        "Check test isolation",
        "Verify synchronization",
        "Mock external dependencies"
      ]
    }
  end

  @doc """
  Get formatted error message for display.
  """
  def error_message(%__MODULE__{error_message: msg}), do: msg

  @doc """
  Get debug steps for this context.
  """
  def debug_steps(%__MODULE__{debug_steps: steps}), do: steps
end
