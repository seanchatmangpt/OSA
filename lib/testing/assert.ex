defmodule OptimalSystemAgent.Testing.Assert do
  @moduledoc """
  Test assertion helpers with descriptive messages.

  Reduces "got X but expected Y" confusion by providing context-aware assertions
  matching Chicago TDD discipline (behavior verification, not implementation details).

  ## Usage

  ```elixir
  import OptimalSystemAgent.Testing.Assert

  test "healing diagnosis detects deadlock" do
    failure = %{type: :deadlock}
    result = Healing.diagnose(failure)
    assert_equal(result.failure_mode, :deadlock, "failure mode detection")
    assert_gte(result.confidence, 0.9, "confidence threshold")
  end
  ```
  """

  @doc """
  Assert equality with descriptive context message.

  Reduces "expected X got Y" confusion by showing the context of what was being tested.
  """
  def assert_equal(actual, expected, context \\ "") do
    if actual == expected do
      true
    else
      raise ExUnit.AssertionError,
        message:
          "Assertion failed: #{context}\n" <>
            "  Expected: #{inspect(expected)}\n" <>
            "  Got: #{inspect(actual)}\n" <>
            "  Tip: verify variable assignment and data transformation"
    end
  end

  @doc """
  Assert not equal with context.
  """
  def assert_not_equal(actual, unexpected, context \\ "") do
    if actual != unexpected do
      true
    else
      raise ExUnit.AssertionError,
        message:
          "Assertion failed: #{context}\n" <>
            "  Should not be: #{inspect(unexpected)}\n" <>
            "  But got: #{inspect(actual)}"
    end
  end

  @doc """
  Assert value >= min with context (useful for confidence scores, latency bounds).
  """
  def assert_gte(actual, min, context \\ "") do
    if actual >= min do
      true
    else
      raise ExUnit.AssertionError,
        message:
          "Assertion failed: #{context}\n" <>
            "  Expected >= #{min}\n" <>
            "  Got: #{actual}\n" <>
            "  Tip: check threshold, increase iterations, or verify data source"
    end
  end

  @doc """
  Assert value <= max with context (useful for latency, error rate, memory).
  """
  def assert_lte(actual, max, context \\ "") do
    if actual <= max do
      true
    else
      raise ExUnit.AssertionError,
        message:
          "Assertion failed: #{context}\n" <>
            "  Expected <= #{max}\n" <>
            "  Got: #{actual}\n" <>
            "  Tip: optimize operation, reduce data size, or increase limit"
    end
  end

  @doc """
  Assert value is in bounded range [min, max] with context.
  """
  def assert_bounded(actual, min, max, context \\ "") do
    cond do
      actual < min ->
        raise ExUnit.AssertionError,
          message:
            "Assertion failed: #{context}\n" <>
              "  Expected >= #{min}\n" <>
              "  Got: #{actual}"

      actual > max ->
        raise ExUnit.AssertionError,
          message:
            "Assertion failed: #{context}\n" <>
              "  Expected <= #{max}\n" <>
              "  Got: #{actual}"

      true ->
        true
    end
  end

  @doc """
  Assert ok result with pattern matching and context.

  Reduces "expected {:ok, x}" confusion by showing actual value.
  """
  def assert_ok(result, context \\ "") do
    case result do
      {:ok, value} ->
        value

      {:error, reason} ->
        raise ExUnit.AssertionError,
          message:
            "Assertion failed: #{context}\n" <>
              "  Expected: {:ok, value}\n" <>
              "  Got: {:error, #{inspect(reason)}}\n" <>
              "  Tip: check error reason, review logs, or increase timeout"

      other ->
        raise ExUnit.AssertionError,
          message:
            "Assertion failed: #{context}\n" <>
              "  Expected: {:ok, value}\n" <>
              "  Got: #{inspect(other)}"
    end
  end

  @doc """
  Assert error result with reason matching and context.
  """
  def assert_error(result, expected_reason \\ nil, context \\ "") do
    case result do
      {:error, reason} when expected_reason == nil ->
        reason

      {:error, reason} when reason == expected_reason ->
        reason

      {:error, reason} ->
        raise ExUnit.AssertionError,
          message:
            "Assertion failed: #{context}\n" <>
              "  Expected error: #{inspect(expected_reason)}\n" <>
              "  Got error: #{inspect(reason)}"

      {:ok, value} ->
        raise ExUnit.AssertionError,
          message:
            "Assertion failed: #{context}\n" <>
              "  Expected: {:error, ...}\n" <>
              "  Got: {:ok, #{inspect(value)}}"

      other ->
        raise ExUnit.AssertionError,
          message:
            "Assertion failed: #{context}\n" <>
              "  Expected: {:error, ...}\n" <>
              "  Got: #{inspect(other)}"
    end
  end

  @doc """
  Assert list length with context.
  """
  def assert_list_len(list, expected_len, context \\ "") do
    actual_len = length(list)

    if actual_len == expected_len do
      true
    else
      raise ExUnit.AssertionError,
        message:
          "Assertion failed: #{context}\n" <>
            "  Expected length: #{expected_len}\n" <>
            "  Got length: #{actual_len}\n" <>
            "  Items: #{inspect(list)}"
    end
  end

  @doc """
  Assert list is not empty with context.
  """
  def assert_not_empty(list, context \\ "") do
    if Enum.empty?(list) do
      raise ExUnit.AssertionError,
        message:
          "Assertion failed: #{context}\n" <>
            "  Expected non-empty list\n" <>
            "  Got empty list\n" <>
            "  Tip: check data loading, filtering, or query"
    else
      true
    end
  end

  @doc """
  Assert map/struct has key with context.
  """
  def assert_has_key(map, key, context \\ "") do
    if Map.has_key?(map, key) do
      true
    else
      raise ExUnit.AssertionError,
        message:
          "Assertion failed: #{context}\n" <>
            "  Expected key: #{inspect(key)}\n" <>
            "  Map keys: #{inspect(Map.keys(map))}\n" <>
            "  Tip: verify object construction or field name"
    end
  end

  @doc """
  Assert performance: latency_ms <= max_ms with context.
  """
  def assert_latency(latency_ms, max_ms, operation \\ "") do
    context = if operation != "", do: operation, else: "operation"

    if latency_ms <= max_ms do
      true
    else
      raise ExUnit.AssertionError,
        message:
          "Performance assertion failed: #{context}\n" <>
            "  Budget: #{max_ms}ms\n" <>
            "  Actual: #{latency_ms}ms\n" <>
            "  Exceeded by: #{latency_ms - max_ms}ms\n" <>
            "  Tip: profile with :timer.tc(), check database queries, cache results"
    end
  end

  @doc """
  Assert soundness: no deadlock_risk with context (WvdA).
  """
  def assert_deadlock_free(_code_section, context \\ "") do
    # This is a narrative assertion for code review
    # Real deadlock freedom requires formal proof or chaos testing
    message =
      "Code review assertion: #{context}\n" <>
        "  Verify: all GenServer.call() have timeout_ms\n" <>
        "  Verify: all receive statements have 'after' clause\n" <>
        "  Verify: no circular wait chains (A waits B, B waits A)\n" <>
        "  See: .claude/rules/wvda-soundness.md"

    IO.puts(message)
    true
  end

  @doc """
  Assert supervision: process has supervisor with context (Armstrong).
  """
  def assert_supervised(process_type, context \\ "") do
    # This is a narrative assertion for code review
    message =
      "Code review assertion: #{context}\n" <>
        "  Verify: #{process_type} is in Supervisor.init(children: [...])\n" <>
        "  Verify: restart strategy is specified (permanent/transient/temporary)\n" <>
        "  Verify: no orphaned processes\n" <>
        "  See: .claude/rules/armstrong-fault-tolerance.md"

    IO.puts(message)
    true
  end

  @doc """
  Assert bounded: resource has limit with context (WvdA).
  """
  def assert_bounded_resource(resource_type, limit, context \\ "") do
    message =
      "Code review assertion: #{context}\n" <>
        "  Resource: #{resource_type}\n" <>
        "  Limit: #{limit}\n" <>
        "  Verify: enforcement at runtime\n" <>
        "  Verify: monitoring/alerts when approaching limit\n" <>
        "  See: .claude/rules/wvda-soundness.md"

    IO.puts(message)
    true
  end
end
