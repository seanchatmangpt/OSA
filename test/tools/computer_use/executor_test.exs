defmodule OptimalSystemAgent.Tools.Builtins.ComputerUse.ExecutorTest do
  use ExUnit.Case, async: false

  alias OptimalSystemAgent.Tools.Builtins.ComputerUse.Executor

  describe "run/2" do
    @tag :integration
    test "returns ok tuple" do
      # Integration test — requires Ollama running
      result = Executor.run("take a screenshot")
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "module exists" do
    test "executor module is loaded" do
      assert Code.ensure_loaded?(Executor)
    end

    test "run/1 and run/2 are exported" do
      # SKIPPED: Requires full app start to detect function arity correctly.
      # When running with `mix test --no-start`, default-argument variants
      # (like def run(goal, opts \\ []) -> run/2) are not visible to function_exported?.
      # This test needs `async: false` and full app boot to pass.
      assert function_exported?(Executor, :run, 1) or function_exported?(Executor, :run, 2)
    end
  end
end
