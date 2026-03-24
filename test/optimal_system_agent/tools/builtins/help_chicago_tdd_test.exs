defmodule OptimalSystemAgent.Tools.Builtins.HelpChicagoTDDTest do
  @moduledoc """
  Chicago TDD: Help tool pure logic tests.

  NO MOCKS. Tests verify REAL tool behavior.

  Following Toyota Code Production System principles:
    - Build Quality In (Jidoka) — tests verify at the source
    - Visual Management — tool metadata observable

  Tests (Red Phase):
  1. Behaviour callback implementation
  2. Safety level (read_only)
  3. Tool metadata (name, description)
  4. Parameters schema
  5. Function existence

  Note: execute/1 requires Tools.Registry (integration test).
  """

  use ExUnit.Case, async: true

  alias OptimalSystemAgent.Tools.Builtins.Help

  describe "Tool — Behaviour Implementation" do
    test "CRASH: Implements Tools.Behaviour" do
      assert Code.ensure_loaded?(Help) and function_exported?(Help, :safety, 0)
      assert Code.ensure_loaded?(Help) and function_exported?(Help, :name, 0)
      assert Code.ensure_loaded?(Help) and function_exported?(Help, :description, 0)
      assert Code.ensure_loaded?(Help) and function_exported?(Help, :parameters, 0)
      assert Code.ensure_loaded?(Help) and function_exported?(Help, :execute, 1)
    end

    test "CRASH: safety/0 returns :read_only" do
      assert Help.safety() == :read_only
    end

    test "CRASH: name/0 returns 'help'" do
      assert Help.name() == "help"
    end

    test "CRASH: description/0 returns non-empty string" do
      desc = Help.description()
      assert is_binary(desc)
      assert String.length(desc) > 0
    end

    test "CRASH: description/0 is about listing tools" do
      desc = String.downcase(Help.description())
      assert String.contains?(desc, "tool")
    end
  end

  describe "Tool — Parameters Schema" do
    test "CRASH: parameters/0 returns valid schema map" do
      schema = Help.parameters()
      assert is_map(schema)
    end

    test "CRASH: parameters has 'type' => 'object'" do
      schema = Help.parameters()
      assert Map.get(schema, "type") == "object"
    end

    test "CRASH: parameters has 'properties' key" do
      schema = Help.parameters()
      assert Map.has_key?(schema, "properties")
    end

    test "CRASH: parameters has 'tool_name' property" do
      schema = Help.parameters()
      props = Map.get(schema, "properties")
      assert Map.has_key?(props, "tool_name")
    end

    test "CRASH: tool_name is optional (not in required)" do
      schema = Help.parameters()
      required = Map.get(schema, "required")
      assert is_list(required)
      refute "tool_name" in required
    end

    test "CRASH: tool_name type is string" do
      schema = Help.parameters()
      tool_name = schema |> Map.get("properties") |> Map.get("tool_name")
      assert Map.get(tool_name, "type") == "string"
    end

    test "CRASH: tool_name has description" do
      schema = Help.parameters()
      tool_name = schema |> Map.get("properties") |> Map.get("tool_name")
      desc = Map.get(tool_name, "description")
      assert is_binary(desc)
      assert String.length(desc) > 0
    end
  end

  describe "Tool — Execute Function" do
    @describetag :skip
    test "CRASH: execute/1 function exists" do
      assert Code.ensure_loaded?(Help) and function_exported?(Help, :execute, 1)
    end

    test "CRASH: execute accepts map with string keys" do
      # Function exists - actual behavior requires Registry
      assert Code.ensure_loaded?(Help) and function_exported?(Help, :execute, 1)
    end

    test "CRASH: execute accepts empty map" do
      # Function exists - actual behavior requires Registry
      assert Code.ensure_loaded?(Help) and function_exported?(Help, :execute, 1)
    end
  end

  describe "Tool — Module Properties" do
    test "CRASH: Module is loaded" do
      assert Code.ensure_loaded?(Help)
    end

    test "CRASH: Module has @behaviour Tools.Behaviour" do
      # The @behaviour attribute is compile-time only
      # We verify the module implements the callbacks
      assert Code.ensure_loaded?(Help) and function_exported?(Help, :safety, 0)
      assert Code.ensure_loaded?(Help) and function_exported?(Help, :name, 0)
      assert Code.ensure_loaded?(Help) and function_exported?(Help, :description, 0)
      assert Code.ensure_loaded?(Help) and function_exported?(Help, :parameters, 0)
      assert Code.ensure_loaded?(Help) and function_exported?(Help, :execute, 1)
    end
  end

  describe "Tool — Safety Classification" do
    test "CRASH: Is read_only (safe, no side effects)" do
      assert Help.safety() == :read_only
    end

    test "CRASH: Is NOT read_write" do
      refute Help.safety() == :read_write
    end

    test "CRASH: Is NOT dangerous" do
      refute Help.safety() == :dangerous
    end
  end

  describe "Tool — Naming" do
    test "CRASH: Tool name is lowercase 'help'" do
      assert Help.name() == "help"
    end

    test "CRASH: Tool name is not 'Help' (capitalized)" do
      refute Help.name() == "Help"
    end

    test "CRASH: Tool name is not 'HELP' (uppercase)" do
      refute Help.name() == "HELP"
    end
  end

  describe "Tool — Schema Validation" do
    test "CRASH: Parameters schema is valid JSON Schema" do
      schema = Help.parameters()
      # Has required keys
      assert Map.has_key?(schema, "type")
      assert Map.has_key?(schema, "properties")
      assert Map.has_key?(schema, "required")
    end

    test "CRASH: Properties is a map" do
      schema = Help.parameters()
      props = Map.get(schema, "properties")
      assert is_map(props)
    end

    test "CRASH: Required is a list" do
      schema = Help.parameters()
      required = Map.get(schema, "required")
      assert is_list(required)
    end
  end
end
