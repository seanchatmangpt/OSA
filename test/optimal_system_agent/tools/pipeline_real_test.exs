defmodule OptimalSystemAgent.Tools.PipelineRealTest do
  @moduledoc """
  Chicago TDD integration tests for Tools.Pipeline.

  NO MOCKS. Tests real combinator logic with injectable executor.
  Every gap found is a real bug or missing behavior.
  """

  use ExUnit.Case, async: true

  @moduletag :integration

  alias OptimalSystemAgent.Tools.Pipeline

  describe "Pipeline.pipe/2" do
    test "CRASH: empty list returns ok with empty map" do
      assert {:ok, %{}} = Pipeline.pipe([])
    end

    test "CRASH: single instruction executes" do
      executor = fn _tool, params -> {:ok, params} end
      assert {:ok, _} = Pipeline.pipe(["test_tool"], executor: executor)
    end

    test "CRASH: pipes output into next input" do
      executor = fn
        "first", _params -> {:ok, %{step1: true}}
        "second", params -> {:ok, Map.put(params, :step2, true)}
      end
      assert {:ok, result} = Pipeline.pipe(["first", "second"], executor: executor)
      assert result.step1 == true
      assert result.step2 == true
    end

    test "CRASH: short-circuits on first error" do
      executor = fn _tool, _params -> {:error, "fail"} end
      assert {:error, "fail"} = Pipeline.pipe(["first", "second"], executor: executor)
    end

    test "CRASH: invalid instruction short-circuits" do
      executor = fn _, _ -> {:ok, %{} } end
      assert {:error, _} = Pipeline.pipe(["", "second"], executor: executor)
    end

    test "CRASH: default executor returns params" do
      assert {:ok, %{}} = Pipeline.pipe(["tool"])
    end
  end

  describe "Pipeline.parallel/2" do
    test "CRASH: empty list returns ok with empty list" do
      assert {:ok, []} = Pipeline.parallel([])
    end

    test "CRASH: all succeed returns ok list" do
      executor = fn _tool, params -> {:ok, params} end
      assert {:ok, results} = Pipeline.parallel(["a", "b", "c"], executor: executor)
      assert length(results) == 3
    end

    test "CRASH: some fail returns error list" do
      executor = fn
        "fail", _params -> {:error, "bad"}
        _, params -> {:ok, params}
      end
      assert {:error, errors} = Pipeline.parallel(["fail", "ok"], executor: executor)
      assert "bad" in errors
    end

    test "CRASH: all fail returns error list" do
      executor = fn _, _params -> {:error, "fail"} end
      assert {:error, errors} = Pipeline.parallel(["a", "b"], executor: executor)
      assert length(errors) == 2
    end

    test "CRASH: invalid instruction is an error" do
      executor = fn _, _ -> {:ok, %{} } end
      result = Pipeline.parallel([42], executor: executor)
      assert {:error, errors} = result
      assert length(errors) == 1
    end
  end

  describe "Pipeline.fallback/2" do
    test "CRASH: first success wins" do
      executor = fn _, _params -> {:ok, "first"} end
      assert {:ok, "first"} = Pipeline.fallback(["a", "b"], executor: executor)
    end

    test "CRASH: falls back to second on first fail" do
      executor = fn
        "first", _params -> {:error, "fail"}
        "second", _params -> {:ok, "second"}
      end
      assert {:ok, "second"} = Pipeline.fallback(["first", "second"], executor: executor)
    end

    test "CRASH: all fail returns last error" do
      executor = fn _, _params -> {:error, "fail"} end
      assert {:error, "fail"} = Pipeline.fallback(["a", "b"], executor: executor)
    end

    test "CRASH: empty list returns error" do
      assert {:error, "no instructions"} = Pipeline.fallback([])
    end

    test "CRASH: invalid instruction falls through" do
      _executor = fn _, _params -> {:ok, "ok"} end
      assert {:error, _} = Pipeline.fallback([42])
    end
  end

  describe "Pipeline.retry/2" do
    test "CRASH: success on first attempt returns ok" do
      # Default executor returns {:ok, params} — params is %{} for a bare string
      assert {:ok, %{}} = Pipeline.retry("tool")
    end

    test "CRASH: retries on failure, succeeds eventually" do
      # Use process dictionary for state since :counters.new/2 needs options
      executor = fn _, _params ->
        count = Process.get(:retry_count, 0) + 1
        Process.put(:retry_count, count)
        if count < 3, do: {:error, "not yet"}, else: {:ok, "done"}
      end
      Process.delete(:retry_count)
      assert {:ok, "done"} = Pipeline.retry("tool", executor: executor, attempts: 3)
      Process.delete(:retry_count)
    end

    test "CRASH: all attempts fail returns last error" do
      executor = fn _, _params -> {:error, "always fail"} end
      assert {:error, "always fail"} = Pipeline.retry("tool", executor: executor, attempts: 3)
    end

    test "CRASH: default attempts is 3" do
      executor = fn _, _params ->
        count = Process.get(:default_attempts_count, 0) + 1
        Process.put(:default_attempts_count, count)
        {:error, "fail"}
      end
      Process.delete(:default_attempts_count)
      assert {:error, "fail"} = Pipeline.retry("tool", executor: executor)
      assert Process.get(:default_attempts_count) == 3
      Process.delete(:default_attempts_count)
    end

    test "CRASH: invalid instruction returns error immediately" do
      _executor = fn _, _params -> {:ok, "ok"} end
      assert {:error, _} = Pipeline.retry(42)
    end

    test "CRASH: custom attempts" do
      executor = fn _, _params -> {:error, "fail"} end
      assert {:error, "fail"} = Pipeline.retry("tool", executor: executor, attempts: 1)
    end
  end
end
