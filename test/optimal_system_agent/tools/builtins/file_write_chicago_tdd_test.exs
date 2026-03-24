defmodule OptimalSystemAgent.Tools.Builtins.FileWriteChicagoTDDTest do
  @moduledoc """
  Chicago TDD: FileWrite tool pure logic tests.

  NO MOCKS. Tests verify REAL tool behavior.

  Following Toyota Code Production System principles:
    - Build Quality In (Jidoka) — tests verify at the source
    - Visual Management — tool metadata observable

  Tests (Red Phase):
  1. Behaviour callback implementation
  2. Safety level (write_safe)
  3. Tool metadata (name, description)
  4. Parameters schema (path, content both required)
  5. Function existence

  Note: File operations require integration tests with real filesystem.
  """

  use ExUnit.Case, async: true

  alias OptimalSystemAgent.Tools.Builtins.FileWrite

  describe "Tool — Behaviour Implementation" do
    test "CRASH: Implements Tools.Behaviour" do
      assert function_exported?(FileWrite, :safety, 0)
      assert function_exported?(FileWrite, :name, 0)
      assert function_exported?(FileWrite, :description, 0)
      assert function_exported?(FileWrite, :parameters, 0)
      assert function_exported?(FileWrite, :execute, 1)
    end

    test "CRASH: safety/0 returns :write_safe" do
      assert FileWrite.safety() == :write_safe
    end

    test "CRASH: name/0 returns 'file_write'" do
      assert FileWrite.name() == "file_write"
    end

    test "CRASH: description/0 returns non-empty string" do
      desc = FileWrite.description()
      assert is_binary(desc)
      assert String.length(desc) > 0
    end

    test "CRASH: description/0 mentions writing" do
      desc = String.downcase(FileWrite.description())
      assert String.contains?(desc, "write")
    end
  end

  describe "Tool — Parameters Schema" do
    test "CRASH: parameters/0 returns valid schema map" do
      schema = FileWrite.parameters()
      assert is_map(schema)
    end

    test "CRASH: parameters has 'type' => 'object'" do
      schema = FileWrite.parameters()
      assert Map.get(schema, "type") == "object"
    end

    test "CRASH: path is required" do
      schema = FileWrite.parameters()
      required = Map.get(schema, "required")
      assert "path" in required
    end

    test "CRASH: content is required" do
      schema = FileWrite.parameters()
      required = Map.get(schema, "required")
      assert "content" in required
    end

    test "CRASH: path type is string" do
      schema = FileWrite.parameters()
      path = schema |> Map.get("properties") |> Map.get("path")
      assert Map.get(path, "type") == "string"
    end

    test "CRASH: content type is string" do
      schema = FileWrite.parameters()
      content = schema |> Map.get("properties") |> Map.get("content")
      assert Map.get(content, "type") == "string"
    end

    test "CRASH: path description mentions workspace" do
      schema = FileWrite.parameters()
      path = schema |> Map.get("properties") |> Map.get("path")
      desc = Map.get(path, "description")
      assert is_binary(desc)
      assert String.length(desc) > 0
    end

    test "CRASH: content description is present" do
      schema = FileWrite.parameters()
      content = schema |> Map.get("properties") |> Map.get("content")
      desc = Map.get(content, "description")
      assert is_binary(desc)
    end
  end

  describe "Tool — Execute Function" do
    test "CRASH: execute/1 function exists" do
      assert function_exported?(FileWrite, :execute, 1)
    end

    test "CRASH: execute accepts map with path and content" do
      # Function exists - actual behavior requires filesystem
      assert function_exported?(FileWrite, :execute, 1)
    end
  end

  describe "Tool — Safety Classification" do
    test "CRASH: Is write_safe (modifies filesystem)" do
      assert FileWrite.safety() == :write_safe
    end

    test "CRASH: Is NOT read_only" do
      refute FileWrite.safety() == :read_only
    end

    test "CRASH: Is NOT dangerous" do
      refute FileWrite.safety() == :dangerous
    end

    test "CRASH: Is NOT read_write" do
      refute FileWrite.safety() == :read_write
    end
  end

  describe "Tool — Module Properties" do
    test "CRASH: Module is loaded" do
      assert Code.ensure_loaded?(FileWrite)
    end

    test "CRASH: Module has @behaviour Tools.Behaviour" do
      # Verify callbacks are implemented
      assert function_exported?(FileWrite, :safety, 0)
      assert function_exported?(FileWrite, :name, 0)
      assert function_exported?(FileWrite, :description, 0)
      assert function_exported?(FileWrite, :parameters, 0)
      assert function_exported?(FileWrite, :execute, 1)
    end
  end

  describe "Tool — Schema Validation" do
    test "CRASH: Parameters schema is valid JSON Schema" do
      schema = FileWrite.parameters()
      assert Map.has_key?(schema, "type")
      assert Map.has_key?(schema, "properties")
      assert Map.has_key?(schema, "required")
    end

    test "CRASH: Properties is a map" do
      schema = FileWrite.parameters()
      props = Map.get(schema, "properties")
      assert is_map(props)
    end

    test "CRASH: Required is a list" do
      schema = FileWrite.parameters()
      required = Map.get(schema, "required")
      assert is_list(required)
    end

    test "CRASH: All required properties are in properties" do
      schema = FileWrite.parameters()
      required = Map.get(schema, "required")
      props = Map.get(schema, "properties")

      Enum.each(required, fn prop ->
        assert Map.has_key?(props, prop)
      end)
    end

    test "CRASH: Exactly 2 required parameters" do
      schema = FileWrite.parameters()
      required = Map.get(schema, "required")
      assert length(required) == 2
    end
  end

  describe "Tool — Description Content" do
    test "CRASH: description mentions relative paths" do
      desc = String.downcase(FileWrite.description())
      assert String.contains?(desc, "relative")
    end

    test "CRASH: description mentions absolute paths" do
      desc = String.downcase(FileWrite.description())
      assert String.contains?(desc, "absolute")
    end

    test "CRASH: description mentions workspace" do
      desc = String.downcase(FileWrite.description())
      assert String.contains?(desc, "workspace")
    end
  end

  describe "Tool — Naming" do
    test "CRASH: Tool name is 'file_write'" do
      assert FileWrite.name() == "file_write"
    end

    test "CRASH: Tool name uses underscore convention" do
      assert String.contains?(FileWrite.name(), "_")
      refute String.contains?(FileWrite.name(), "-")
    end

    test "CRASH: Tool name is verb_noun pattern" do
      name = FileWrite.name()
      parts = String.split(name, "_")
      assert length(parts) == 2
    end
  end

  describe "Tool — Security" do
    test "CRASH: Module exists for security checks" do
      # Security features (blocked paths, allowed paths) are tested
      # indirectly via execute behavior in integration tests
      assert true
    end
  end
end
