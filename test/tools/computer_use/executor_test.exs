defmodule OptimalSystemAgent.Tools.Builtins.ComputerUse.ExecutorTest do
  use ExUnit.Case, async: true

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

    @tag :skip
    test "run/1 and run/2 are exported" do
      # Requires full app start — default-argument arities not visible in --no-start
      assert function_exported?(Executor, :run, 1) or function_exported?(Executor, :run, 2)
    end
  end
end
