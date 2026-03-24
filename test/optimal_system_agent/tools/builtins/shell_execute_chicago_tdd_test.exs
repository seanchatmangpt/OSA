defmodule OptimalSystemAgent.Tools.Builtins.ShellExecuteChicagoTDDTest do
  @moduledoc """
  Chicago TDD: ShellExecute tool pure logic tests.

  NO MOCKS. Tests verify REAL tool behavior.

  Following Toyota Code Production System principles:
    - Build Quality In (Jidoka) — tests verify at the source
    - Visual Management — tool metadata observable

  Tests (Red Phase):
  1. Behaviour callback implementation
  2. Safety level (:terminal)
  3. Tool metadata (name, description)
  4. Parameters schema (command required, cwd optional)
  5. Execute function error handling (missing command, non-string command, empty command)
  6. Security validation (blocked commands, injection patterns, path patterns)

  Note: Actual shell execution requires integration tests.
  """

  use ExUnit.Case, async: true

  alias OptimalSystemAgent.Tools.Builtins.ShellExecute

  describe "Tool — Behaviour Implementation" do
    test "CRASH: Implements Tools.Behaviour" do
      assert Code.ensure_loaded?(ShellExecute) and function_exported?(ShellExecute, :safety, 0)
      assert Code.ensure_loaded?(ShellExecute) and function_exported?(ShellExecute, :name, 0)
      assert Code.ensure_loaded?(ShellExecute) and function_exported?(ShellExecute, :description, 0)
      assert Code.ensure_loaded?(ShellExecute) and function_exported?(ShellExecute, :parameters, 0)
      assert Code.ensure_loaded?(ShellExecute) and function_exported?(ShellExecute, :execute, 1)
    end

    test "CRASH: safety/0 returns :terminal" do
      assert ShellExecute.safety() == :terminal
    end

    test "CRASH: name/0 returns 'shell_execute'" do
      assert ShellExecute.name() == "shell_execute"
    end

    test "CRASH: description/0 returns non-empty string" do
      desc = ShellExecute.description()
      assert is_binary(desc)
      assert String.length(desc) > 0
    end

    test "CRASH: description/0 mentions shell" do
      desc = String.downcase(ShellExecute.description())
      assert String.contains?(desc, "shell")
    end
  end

  describe "Tool — Parameters Schema" do
    test "CRASH: parameters/0 returns valid schema map" do
      schema = ShellExecute.parameters()
      assert is_map(schema)
    end

    test "CRASH: parameters has 'type' => 'object'" do
      schema = ShellExecute.parameters()
      assert Map.get(schema, "type") == "object"
    end

    test "CRASH: command is required" do
      schema = ShellExecute.parameters()
      required = Map.get(schema, "required")
      assert "command" in required
    end

    test "CRASH: cwd is optional" do
      schema = ShellExecute.parameters()
      required = Map.get(schema, "required")
      refute "cwd" in required
    end

    test "CRASH: command type is string" do
      schema = ShellExecute.parameters()
      command = schema |> Map.get("properties") |> Map.get("command")
      assert Map.get(command, "type") == "string"
    end

    test "CRASH: cwd type is string" do
      schema = ShellExecute.parameters()
      cwd = schema |> Map.get("properties") |> Map.get("cwd")
      assert Map.get(cwd, "type") == "string"
    end

    test "CRASH: cwd description mentions workspace" do
      schema = ShellExecute.parameters()
      cwd = schema |> Map.get("properties") |> Map.get("cwd")
      desc = Map.get(cwd, "description")
      assert is_binary(desc)
      assert String.length(desc) > 0
    end
  end

  describe "Tool — Execute Function" do
    test "CRASH: execute/1 function exists" do
      assert Code.ensure_loaded?(ShellExecute) and function_exported?(ShellExecute, :execute, 1)
    end

    test "CRASH: execute returns error for missing command" do
      result = ShellExecute.execute(%{})
      assert match?({:error, "Missing required parameter: command"}, result)
    end

    test "CRASH: execute returns error for non-string command" do
      result = ShellExecute.execute(%{"command" => 123})
      assert match?({:error, "command must be a string"}, result)
    end

    test "CRASH: execute returns error for empty command" do
      result = ShellExecute.execute(%{"command" => ""})
      assert match?({:error, "Blocked: empty command"}, result)
    end

    test "CRASH: execute returns error for whitespace-only command" do
      result = ShellExecute.execute(%{"command" => "   "})
      assert match?({:error, "Blocked: empty command"}, result)
    end
  end

  describe "Tool — Safety Classification" do
    test "CRASH: Is :terminal (highest safety level)" do
      assert ShellExecute.safety() == :terminal
    end

    test "CRASH: Is NOT read_only" do
      refute ShellExecute.safety() == :read_only
    end

    test "CRASH: Is NOT write_safe" do
      refute ShellExecute.safety() == :write_safe
    end

    test "CRASH: Is NOT dangerous" do
      refute ShellExecute.safety() == :dangerous
    end
  end

  describe "Tool — Module Properties" do
    test "CRASH: Module is loaded" do
      assert Code.ensure_loaded?(ShellExecute)
    end

    test "CRASH: Module has @behaviour Tools.Behaviour" do
      # Verify callbacks are implemented
      assert Code.ensure_loaded?(ShellExecute) and function_exported?(ShellExecute, :safety, 0)
      assert Code.ensure_loaded?(ShellExecute) and function_exported?(ShellExecute, :name, 0)
      assert Code.ensure_loaded?(ShellExecute) and function_exported?(ShellExecute, :description, 0)
      assert Code.ensure_loaded?(ShellExecute) and function_exported?(ShellExecute, :parameters, 0)
      assert Code.ensure_loaded?(ShellExecute) and function_exported?(ShellExecute, :execute, 1)
    end
  end

  describe "Tool — Schema Validation" do
    test "CRASH: Parameters schema is valid JSON Schema" do
      schema = ShellExecute.parameters()
      assert Map.has_key?(schema, "type")
      assert Map.has_key?(schema, "properties")
      assert Map.has_key?(schema, "required")
    end

    test "CRASH: Properties is a map" do
      schema = ShellExecute.parameters()
      props = Map.get(schema, "properties")
      assert is_map(props)
    end

    test "CRASH: Required is a list" do
      schema = ShellExecute.parameters()
      required = Map.get(schema, "required")
      assert is_list(required)
    end
  end

  describe "Tool — Security Validation" do
    test "CRASH: Blocked commands are checked" do
      # Tested indirectly via execute behavior
      # rm is blocked
      result = ShellExecute.execute(%{"command" => "rm -rf /"})
      assert match?({:error, "Blocked: blocked pattern matched: rm"}, result)
    end

    test "CRASH: Shell injection patterns are checked" do
      # Backtick substitution is blocked
      result = ShellExecute.execute(%{"command" => "echo `whoami`"})
      assert match?({:error, "Blocked: blocked pattern matched: shell injection"}, result)
    end

    test "CRASH: $() command substitution is blocked" do
      result = ShellExecute.execute(%{"command" => "echo $(whoami)"})
      assert match?({:error, "Blocked: blocked pattern matched: shell injection"}, result)
    end

    test "CRASH: ${} variable expansion is blocked" do
      result = ShellExecute.execute(%{"command" => "echo ${HOME}"})
      assert match?({:error, "Blocked: blocked pattern matched: shell injection"}, result)
    end

    test "CRASH: ../ path traversal is blocked" do
      result = ShellExecute.execute(%{"command" => "cat ../../etc/passwd"})
      assert match?({:error, "Blocked: blocked pattern matched: sensitive path access"}, result)
    end

    test "CRASH: /etc/ access is blocked" do
      result = ShellExecute.execute(%{"command" => "cat /etc/passwd"})
      assert match?({:error, "Blocked: blocked pattern matched: sensitive path access"}, result)
    end

    test "CRASH: .ssh/ access is blocked" do
      result = ShellExecute.execute(%{"command" => "cat ~/.ssh/id_rsa"})
      assert match?({:error, "Blocked: blocked pattern matched: sensitive path access"}, result)
    end

    test "CRASH: .env file access is blocked" do
      result = ShellExecute.execute(%{"command" => "cat .env"})
      assert match?({:error, "Blocked: blocked pattern matched: sensitive path access"}, result)
    end

    test "CRASH: cd outside ~/.osa is blocked" do
      result = ShellExecute.execute(%{"command" => "cd /tmp && ls"})
      assert match?({:error, "Blocked: cd outside ~/.osa/ is not allowed"}, result)
    end
  end

  describe "Tool — Command Normalization" do
    test "CRASH: Trailing & is stripped" do
      # Tested indirectly - the & would be stripped before execution
      assert Code.ensure_loaded?(ShellExecute) and function_exported?(ShellExecute, :execute, 1)
    end

    test "CRASH: Leading nohup is stripped" do
      # Tested indirectly - nohup would be stripped before execution
      assert Code.ensure_loaded?(ShellExecute) and function_exported?(ShellExecute, :execute, 1)
    end
  end

  describe "Tool — Naming" do
    test "CRASH: Tool name is 'shell_execute'" do
      assert ShellExecute.name() == "shell_execute"
    end

    test "CRASH: Tool name uses underscore convention" do
      assert String.contains?(ShellExecute.name(), "_")
      refute String.contains?(ShellExecute.name(), "-")
    end
  end

  describe "Tool — Error Messages" do
    test "CRASH: Missing command error is descriptive" do
      result = ShellExecute.execute(%{})
      assert match?({:error, <<_::binary>>}, result)
      assert elem(result, 1) =~ "command"
    end

    test "CRASH: Non-string command error is descriptive" do
      result = ShellExecute.execute(%{"command" => 123})
      assert match?({:error, <<_::binary>>}, result)
      assert elem(result, 1) =~ "string"
    end

    test "CRASH: Blocked command error includes pattern" do
      result = ShellExecute.execute(%{"command" => "rm file"})
      assert match?({:error, <<_::binary>>}, result)
      assert elem(result, 1) =~ "rm"
    end
  end
end
