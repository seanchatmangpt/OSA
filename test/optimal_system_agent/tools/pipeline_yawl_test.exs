defmodule OptimalSystemAgent.Tools.PipelineYawlTest do
  use ExUnit.Case, async: true

  alias OptimalSystemAgent.Tools.Pipeline

  # A simple executor that always succeeds and returns the params
  defp success_executor(_tool, params), do: {:ok, params}

  describe "retry/2 WvdA boundedness" do
    test "rejects attempts: 0 as invalid" do
      result = Pipeline.retry("some_tool", attempts: 0, executor: &success_executor/2)
      assert {:error, :zero_attempts_invalid} = result
    end

    test "succeeds with attempts: 1" do
      result = Pipeline.retry("some_tool", attempts: 1, executor: &success_executor/2)
      assert {:ok, _} = result
    end

    test "succeeds with attempts: 3 on first try" do
      result = Pipeline.retry("some_tool", attempts: 3, executor: &success_executor/2)
      assert {:ok, _} = result
    end

    test "emits warning log when attempts exceeds cap" do
      import ExUnit.CaptureLog

      log =
        capture_log(fn ->
          Pipeline.retry("some_tool", attempts: 11, executor: &success_executor/2)
        end)

      assert log =~ "may be unbounded"
    end

    test "still executes when attempts exceeds cap (warn-only, not blocked)" do
      result = Pipeline.retry("some_tool", attempts: 11, executor: &success_executor/2)
      assert {:ok, _} = result
    end
  end
end
