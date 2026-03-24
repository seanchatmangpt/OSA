defmodule OptimalSystemAgent.Tools.MiddlewareRealTest do
  @moduledoc """
  Chicago TDD integration tests for Tools.Middleware.

  NO MOCKS. Tests real middleware chain execution, Validation, Timing.
  Every gap found is a real bug or missing behavior.
  """

  use ExUnit.Case, async: true

  @moduletag :integration

  alias OptimalSystemAgent.Tools.Middleware
  alias OptimalSystemAgent.Tools.Instruction
  alias OptimalSystemAgent.Tools.Middleware.{Validation, Timing, Logging}

  describe "Middleware.execute/3" do
    test "CRASH: empty middleware calls executor directly" do
      inst = %Instruction{tool: "test", params: %{}}
      result = Middleware.execute(inst, [], fn i -> {:ok, i.params} end)
      assert result == {:ok, %{}}
    end

    test "CRASH: single Timing middleware wraps executor" do
      inst = %Instruction{tool: "test", params: %{}}
      result = Middleware.execute(inst, [Timing], fn i -> {:ok, i.params} end)
      assert {:ok, val, elapsed} = result
      assert is_map(val)
      assert is_integer(elapsed)
      assert elapsed >= 0
    end

    test "CRASH: multiple Timing middleware chains left-to-right" do
      inst = %Instruction{tool: "test", params: %{}}
      result = Middleware.execute(inst, [Timing, Timing], fn i -> {:ok, i.params} end)
      assert {:ok, _val, elapsed} = result
      assert is_integer(elapsed)
      assert elapsed >= 0
    end

    test "CRASH: error passes through Timing unchanged" do
      inst = %Instruction{tool: "test", params: %{}}
      result = Middleware.execute(inst, [Timing], fn _ -> {:error, "boom"} end)
      assert result == {:error, "boom"}
    end

    test "CRASH: Validation with opts blocks missing params via execute/3" do
      # GAP FIXED: execute/3 now forwards opts to middleware
      inst = %Instruction{tool: "test", params: %{}}
      result = Middleware.execute(inst, [Validation], fn _ -> {:ok, %{} } end, required: ["key"])
      assert {:error, msg} = result
      assert is_binary(msg)
      assert String.contains?(msg, "key")
    end

    test "CRASH: Validation with opts passes when all params present" do
      inst = %Instruction{tool: "test", params: %{"key" => "val"}}
      result = Middleware.execute(inst, [Validation], fn _ -> {:ok, %{} } end, required: ["key"])
      assert result == {:ok, %{}}
    end

    test "CRASH: Validation with empty required passes" do
      inst = %Instruction{tool: "test", params: %{}}
      result = Middleware.execute(inst, [Validation], fn _ -> {:ok, %{} } end, required: [])
      assert result == {:ok, %{}}
    end

    test "CRASH: Timing adds elapsed to ok tuple" do
      inst = %Instruction{tool: "test", params: %{}}
      result = Middleware.execute(inst, [Timing], fn _ -> {:ok, "result"} end)
      assert {:ok, "result", elapsed} = result
      assert elapsed >= 0
    end

    test "CRASH: Timing preserves error tuple" do
      inst = %Instruction{tool: "test", params: %{}}
      result = Middleware.execute(inst, [Timing], fn _ -> {:error, "fail"} end)
      assert result == {:error, "fail"}
    end

    test "CRASH: Logging passes through ok result" do
      inst = %Instruction{tool: "test", params: %{}}
      result = Middleware.execute(inst, [Logging], fn _ -> {:ok, "result"} end)
      assert result == {:ok, "result"}
    end

    test "CRASH: Logging passes through error result" do
      inst = %Instruction{tool: "test", params: %{}}
      result = Middleware.execute(inst, [Logging], fn _ -> {:error, "fail"} end)
      assert result == {:error, "fail"}
    end

    test "CRASH: execute/3 with opts chains Validation then Timing" do
      inst = %Instruction{tool: "test", params: %{"key" => "val"}}
      result = Middleware.execute(inst, [Validation, Timing], fn _ -> {:ok, "done"} end,
        required: ["key"]
      )
      assert {:ok, "done", elapsed} = result
      assert elapsed >= 0
    end

    test "CRASH: execute/3 without opts uses empty list (backward compat)" do
      inst = %Instruction{tool: "test", params: %{}}
      # No opts → Validation gets [] → required defaults to [] → passes
      result = Middleware.execute(inst, [Validation], fn _ -> {:ok, %{} } end)
      assert result == {:ok, %{}}
    end
  end
end
