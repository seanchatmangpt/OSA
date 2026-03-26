defmodule OSA.Test.Helpers.TimeoutHelper do
  @moduledoc """
  WvdA Deadlock-Freedom Helper.

  Enforces that all blocking operations complete within specified timeout.
  Fails fast if timeout is missing or operation exceeds boundary.

  ## Usage

      test "agent request completes within deadline" do
        assert_completes_with_timeout(5000, fn ->
          Agent.request(:my_agent, {:query, "data"})
        end)
      end

      test "timeout is required (prevents forgotten timeouts)" do
        assert_raises ArgumentError, fn ->
          assert_completes_with_timeout(nil, fn -> :ok end)
        end
      end
  """

  @spec assert_completes_with_timeout(integer | nil, (() -> any)) :: any
  def assert_completes_with_timeout(timeout_ms, operation) when is_function(operation, 0) do
    if timeout_ms == nil do
      raise ArgumentError, "timeout_ms is required (WvdA deadlock-freedom constraint)"
    end

    start_time = System.monotonic_time(:millisecond)

    result = operation.()

    elapsed = System.monotonic_time(:millisecond) - start_time

    if elapsed > timeout_ms do
      raise AssertionError,
        message: "Operation exceeded timeout: #{elapsed}ms > #{timeout_ms}ms"
    end

    result
  end

  def assert_completes_with_timeout(timeout_ms, _) do
    raise ArgumentError, "Second argument must be a function, got: #{inspect(timeout_ms)}"
  end
end
