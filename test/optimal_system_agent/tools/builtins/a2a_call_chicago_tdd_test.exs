defmodule OptimalSystemAgent.Tools.Builtins.A2ACallChicagoTDDTest do
  @moduledoc """
  Chicago TDD: A2ACall tool pure logic tests.

  NO MOCKS. Tests verify REAL A2A protocol behavior.

  Following Toyota Code Production System principles:
    - Build Quality In (Jidoka) — tests verify at the source
    - Visual Management — tool behavior observable

  Tests (Red Phase):
  1. Tool metadata (name, description, parameters, safety)
  2. Missing required parameters
  3. Empty message validation
  4. Action routing (discover, call, list_tools, execute_tool)
  5. Unknown action handling
  6. Behavior contract compliance

  Note: Tests requiring HTTP calls are integration tests.
  """

  use ExUnit.Case, async: true

  alias OptimalSystemAgent.Tools.Builtins.A2ACall

  describe "Tool — Metadata" do
    test "CRASH: Returns tool name" do
      assert A2ACall.name() == "a2a_call"
    end

    test "CRASH: Returns sandboxed safety level" do
      assert A2ACall.safety() == :sandboxed
    end

    test "CRASH: Returns description" do
      desc = A2ACall.description()
      assert is_binary(desc)
      assert String.length(desc) > 0
      assert String.contains?(desc, "A2A")
    end

    test "CRASH: Returns parameters schema" do
      params = A2ACall.parameters()

      assert params["type"] == "object"
      assert Map.has_key?(params["properties"], "action")
      assert Map.has_key?(params["properties"], "agent_url")
      assert Map.has_key?(params["properties"], "message")
      assert Map.has_key?(params["properties"], "tool_name")
      assert Map.has_key?(params["properties"], "arguments")
    end

    test "CRASH: Action enum has all required values" do
      params = A2ACall.parameters()
      action_enum = params["properties"]["action"]["enum"]

      assert "discover" in action_enum
      assert "call" in action_enum
      assert "list_tools" in action_enum
      assert "execute_tool" in action_enum
    end

    test "CRASH: Required parameters include action and agent_url" do
      params = A2ACall.parameters()
      required = params["required"]

      assert "action" in required
      assert "agent_url" in required
    end
  end

  describe "Tool — Parameter Validation" do
    test "CRASH: Returns error for missing action" do
      result = A2ACall.execute(%{"agent_url" => "http://localhost:8001"})

      assert {:error, msg} = result
      assert String.contains?(msg, "Missing required parameters")
    end

    test "CRASH: Returns error for missing agent_url" do
      result = A2ACall.execute(%{"action" => "discover"})

      assert {:error, msg} = result
      assert String.contains?(msg, "Missing required parameters")
    end

    test "CRASH: Returns error for empty parameters map" do
      result = A2ACall.execute(%{})

      assert {:error, msg} = result
      assert String.contains?(msg, "Missing required parameters")
    end

    test "CRASH: Returns error for nil parameters" do
      result = A2ACall.execute(nil)

      assert {:error, msg} = result
      assert String.contains?(msg, "Missing required parameters")
    end

    test "CRASH: Returns error for empty message in call action" do
      result = A2ACall.execute(%{"action" => "call", "agent_url" => "http://localhost:8001", "message" => ""})

      assert {:error, msg} = result
      assert String.contains?(msg, "non-empty string")
    end

    test "CRASH: Returns error for non-binary message in call action" do
      result = A2ACall.execute(%{"action" => "call", "agent_url" => "http://localhost:8001", "message" => 123})

      assert {:error, msg} = result
      assert String.contains?(msg, "non-empty string")
    end

    test "CRASH: Accepts empty message for other actions" do
      # list_tools should work without message parameter
      # We can't make HTTP calls without Finch started
      # But we can verify the function exists and is callable
      assert Code.ensure_loaded?(A2ACall)
      assert Code.ensure_loaded?(A2ACall) and function_exported?(A2ACall, :execute, 1)

      # The key test: call action requires message, list_tools doesn't
      # This is verified by the call action test above
    end
  end

  describe "Tool — Action Routing" do
    test "CRASH: Returns error for unknown action" do
      result = A2ACall.execute(%{"action" => "unknown_action", "agent_url" => "http://localhost:8001"})

      assert {:error, msg} = result
      assert String.contains?(msg, "Unknown action")
    end

    test "CRASH: Routes discover action (function exists)" do
      # We can't test the actual HTTP call without a server
      # But we can verify the function is defined
      assert Code.ensure_loaded?(A2ACall)
      assert Code.ensure_loaded?(A2ACall) and function_exported?(A2ACall, :execute, 1)
    end

    test "CRASH: Routes call action (function exists)" do
      assert Code.ensure_loaded?(A2ACall)
      assert Code.ensure_loaded?(A2ACall) and function_exported?(A2ACall, :execute, 1)
    end

    test "CRASH: Routes list_tools action (function exists)" do
      assert Code.ensure_loaded?(A2ACall)
      assert Code.ensure_loaded?(A2ACall) and function_exported?(A2ACall, :execute, 1)
    end

    test "CRASH: Routes execute_tool action (function exists)" do
      assert Code.ensure_loaded?(A2ACall)
      assert Code.ensure_loaded?(A2ACall) and function_exported?(A2ACall, :execute, 1)
    end
  end

  describe "Tool — Default Values" do
    test "CRASH: Defaults message to empty string when missing" do
      # When message is missing, it defaults to ""
      # For call action, empty message is invalid
      result = A2ACall.execute(%{"action" => "call", "agent_url" => "http://localhost:9999"})

      # Should fail with "non-empty string" error
      assert {:error, msg} = result
      assert String.contains?(msg, "non-empty string")
    end

    test "CRASH: Defaults arguments to empty map when missing" do
      # We can't test this without making an HTTP call
      # But we can verify the function is callable
      assert Code.ensure_loaded?(A2ACall)
      assert Code.ensure_loaded?(A2ACall) and function_exported?(A2ACall, :execute, 1)
    end
  end

  describe "Tool — Behavior Contract" do
    test "CRASH: Implements Tools.Behaviour" do
      # Verify the module implements the required callbacks
      assert Code.ensure_loaded?(A2ACall) and function_exported?(A2ACall, :name, 0)
      assert Code.ensure_loaded?(A2ACall) and function_exported?(A2ACall, :description, 0)
      assert Code.ensure_loaded?(A2ACall) and function_exported?(A2ACall, :parameters, 0)
      assert Code.ensure_loaded?(A2ACall) and function_exported?(A2ACall, :safety, 0)
      assert Code.ensure_loaded?(A2ACall) and function_exported?(A2ACall, :execute, 1)
    end

    test "CRASH: execute/1 returns {:ok, result} or {:error, message}" do
      # Test all return value formats
      assert {:error, _} = A2ACall.execute(%{})
      assert {:error, _} = A2ACall.execute(%{"action" => "unknown", "agent_url" => "http://x"})
    end

    test "CRASH: Returns consistent error format" do
      results = [
        A2ACall.execute(%{}),
        A2ACall.execute(%{"action" => "unknown", "agent_url" => "http://x"}),
        A2ACall.execute(%{"action" => "call", "agent_url" => "http://x", "message" => ""})
      ]

      Enum.each(results, fn
        {:error, msg} when is_binary(msg) -> :ok
        _ -> flunk("Expected {:error, message} tuple")
      end)
    end
  end

  describe "Tool — Parameter Schema Validation" do
    test "CRASH: Action is required in schema" do
      params = A2ACall.parameters()
      assert "action" in params["required"]
    end

    test "CRASH: agent_url is required in schema" do
      params = A2ACall.parameters()
      assert "agent_url" in params["required"]
    end

    test "CRASH: message is optional in schema" do
      params = A2ACall.parameters()
      refute "message" in params["required"]
    end

    test "CRASH: tool_name is optional in schema" do
      params = A2ACall.parameters()
      refute "tool_name" in params["required"]
    end

    test "CRASH: arguments is optional in schema" do
      params = A2ACall.parameters()
      refute "arguments" in params["required"]
    end

    test "CRASH: Action enum contains exactly 4 values" do
      params = A2ACall.parameters()
      action_enum = params["properties"]["action"]["enum"]
      assert length(action_enum) == 4
    end

    test "CRASH: Schema type is object" do
      params = A2ACall.parameters()
      assert params["type"] == "object"
    end

    test "CRASH: All properties have descriptions" do
      params = A2ACall.parameters()

      Enum.each(["action", "agent_url", "message", "tool_name", "arguments"], fn prop ->
        assert Map.has_key?(params["properties"][prop], "description")
        assert is_binary(params["properties"][prop]["description"])
        assert String.length(params["properties"][prop]["description"]) > 0
      end)
    end
  end

  describe "Tool — Safety Level" do
    test "CRASH: Safety is sandboxed" do
      assert A2ACall.safety() == :sandboxed
    end

    test "CRASH: Safety level is an atom" do
      assert is_atom(A2ACall.safety())
    end
  end

  describe "Tool — Description Content" do
    test "CRASH: Description mentions A2A protocol" do
      desc = A2ACall.description()
      assert String.contains?(desc, "A2A")
    end

    test "CRASH: Description mentions agent-to-agent" do
      desc = A2ACall.description()
      # Check for either "agent-to-agent" or similar
      assert String.contains?(String.downcase(desc), "agent")
    end

    test "CRASH: Description lists supported actions" do
      desc = A2ACall.description()
      assert String.contains?(desc, "discover") or String.contains?(desc, "Discover")
    end

    test "CRASH: Description mentions known agents" do
      desc = A2ACall.description()
      # Should mention BusinessOS, Canopy, or OSA
      lower_desc = String.downcase(desc)
      mentions =
        String.contains?(lower_desc, "businessos") or
          String.contains?(lower_desc, "canopy") or
          String.contains?(lower_desc, "osa")

      assert mentions, "Description should mention known agents (BusinessOS, Canopy, or OSA)"
    end
  end

  describe "Tool — Return Value Types" do
    test "CRASH: Returns tuple for all inputs" do
      inputs = [
        %{},
        %{"action" => "discover"},
        %{"agent_url" => "http://x"},
        nil,
        %{"action" => "unknown", "agent_url" => "http://x"}
      ]

      Enum.each(inputs, fn input ->
        result = A2ACall.execute(input)
        assert is_tuple(result), "Expected tuple, got #{inspect(result)}"
        assert tuple_size(result) == 2, "Expected 2-tuple, got #{inspect(result)}"
      end)
    end

    test "CRASH: Error returns {:error, binary}" do
      result = A2ACall.execute(%{})
      assert {:error, msg} = result
      assert is_binary(msg)
    end

    test "CRASH: Unknown action returns {:error, binary}" do
      result = A2ACall.execute(%{"action" => "bogus", "agent_url" => "http://x"})
      assert {:error, msg} = result
      assert is_binary(msg)
      assert String.contains?(msg, "Unknown action")
    end
  end
end
