defmodule OptimalSystemAgent.Tools.InstructionRealTest do
  @moduledoc """
  Chicago TDD integration tests for Tools.Instruction.

  NO MOCKS. Tests real normalization, merging, and raising.
  Every gap found is a real bug or missing behavior.
  """

  use ExUnit.Case, async: true

  @moduletag :integration

  alias OptimalSystemAgent.Tools.Instruction

  describe "Instruction.normalize/1 — string input" do
    test "CRASH: binary tool name returns ok" do
      assert {:ok, %Instruction{tool: "file_read"}} = Instruction.normalize("file_read")
    end

    test "CRASH: trims whitespace" do
      assert {:ok, %Instruction{tool: "file_read"}} = Instruction.normalize("  file_read  ")
    end

    test "CRASH: empty string returns error" do
      assert {:error, msg} = Instruction.normalize("")
      assert is_binary(msg)
    end

    test "CRASH: whitespace-only string returns error" do
      assert {:error, _} = Instruction.normalize("   ")
    end
  end

  describe "Instruction.normalize/1 — 2-tuple input" do
    test "CRASH: {tool, params} returns ok" do
      assert {:ok, %Instruction{tool: "read", params: %{"path" => "/tmp"}}} =
               Instruction.normalize({"read", %{"path" => "/tmp"}})
    end

    test "CRASH: {tool, params} with empty params" do
      assert {:ok, %Instruction{tool: "list", params: %{}}} =
               Instruction.normalize({"list", %{}})
    end

    test "CRASH: non-map params returns error" do
      assert {:error, msg} = Instruction.normalize({"read", "not a map"})
      assert is_binary(msg)
    end

    test "CRASH: non-binary tool returns error" do
      assert {:error, _} = Instruction.normalize({123, %{}})
    end
  end

  describe "Instruction.normalize/1 — 3-tuple input" do
    test "CRASH: {tool, params, context} returns ok" do
      assert {:ok, %Instruction{tool: "exec", params: %{"cmd" => "ls"}, context: %{session_id: "s1"}}} =
               Instruction.normalize({"exec", %{"cmd" => "ls"}, %{session_id: "s1"}})
    end

    test "CRASH: non-map context returns error" do
      assert {:error, msg} = Instruction.normalize({"exec", %{}, "not a map"})
      assert is_binary(msg)
    end
  end

  describe "Instruction.normalize/1 — struct input" do
    test "CRASH: existing Instruction returns ok" do
      inst = %Instruction{tool: "search", params: %{"q" => "test"}, context: %{}}
      assert {:ok, ^inst} = Instruction.normalize(inst)
    end
  end

  describe "Instruction.normalize/1 — unsupported input" do
    test "CRASH: integer returns error" do
      assert {:error, msg} = Instruction.normalize(42)
      assert is_binary(msg)
    end

    test "CRASH: nil returns error" do
      assert {:error, msg} = Instruction.normalize(nil)
      assert is_binary(msg)
    end

    test "CRASH: list returns error" do
      assert {:error, msg} = Instruction.normalize(["tool", %{}])
      assert is_binary(msg)
    end
  end

  describe "Instruction.normalize!/1" do
    test "CRASH: returns instruction for valid input" do
      assert %Instruction{tool: "file_read"} = Instruction.normalize!("file_read")
    end

    test "CRASH: raises for invalid input" do
      assert_raise ArgumentError, fn -> Instruction.normalize!("") end
    end

    test "CRASH: raises for nil" do
      assert_raise ArgumentError, fn -> Instruction.normalize!(nil) end
    end
  end

  describe "Instruction.merge_params/2" do
    test "CRASH: merges extra params" do
      inst = %Instruction{tool: "read", params: %{"path" => "/tmp"}}
      result = Instruction.merge_params(inst, %{"encoding" => "utf-8"})
      assert result.params == %{"path" => "/tmp", "encoding" => "utf-8"}
    end

    test "CRASH: extra overwrites existing keys" do
      inst = %Instruction{tool: "read", params: %{"path" => "/old"}}
      result = Instruction.merge_params(inst, %{"path" => "/new"})
      assert result.params == %{"path" => "/new"}
    end

    test "CRASH: empty extra leaves params unchanged" do
      inst = %Instruction{tool: "read", params: %{"path" => "/tmp"}}
      result = Instruction.merge_params(inst, %{})
      assert result.params == %{"path" => "/tmp"}
    end
  end
end
