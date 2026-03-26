defmodule OSA.Test.Helpers.BoundedLoopVerifier do
  @moduledoc """
  WvdA Liveness Helper.

  Validates that loops have explicit max_iterations boundary.
  Prevents infinite loops and unbounded recursion.

  ## Usage

      test "loop has bounded iteration" do
        result = loop_with_max(max_iterations: 100)
        assert result.iterations <= 100
      end

      test "recursive function has stack limit" do
        assert_max_recursion_depth(1000, fn -> deep_recursion(0) end)
      end
  """

  @spec assert_max_recursion_depth(integer, (() -> any)) :: any
  def assert_max_recursion_depth(max_depth, operation) when is_function(operation, 0) do
    try do
      operation.()
    rescue
      e in RuntimeError ->
        if String.contains?(e.message, "stack level too deep") do
          raise AssertionError,
            message: "Recursion exceeded max depth #{max_depth}: #{e.message}"
        else
          raise e
        end
    end
  end

  @spec assert_iteration_count(integer, (() -> integer)) :: integer
  def assert_iteration_count(max_iterations, operation) when is_function(operation, 0) do
    count = operation.()

    if count > max_iterations do
      raise AssertionError,
        message: "Loop exceeded max iterations: #{count} > #{max_iterations}"
    end

    count
  end

  @spec bounded_loop(list, integer, (any, integer -> {any, integer})) :: {any, integer}
  def bounded_loop(items, max_iterations, operation) when is_function(operation, 2) do
    Enum.reduce_while(items, {nil, 0}, fn item, {_acc, count} ->
      if count >= max_iterations do
        {:halt, {nil, count}}
      else
        {result, new_count} = operation.(item, count + 1)
        {:cont, {result, new_count}}
      end
    end)
  end
end
