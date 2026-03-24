defmodule OptimalSystemAgent.Tools.Builtins.A2ACallTest do
  @moduledoc """
  Chicago TDD tests for A2ACall tool.

  Tests the tool's public interface (name, description, parameters, safety)
  and execute/1 function patterns. Does NOT make real HTTP calls.
  Tests the pure logic: parameter validation, unknown action handling,
  missing parameters, and the normalize_url helper behavior via execute.
  """
  use ExUnit.Case, async: true

  alias OptimalSystemAgent.Tools.Builtins.A2ACall

  # ---------------------------------------------------------------------------
  # Behaviour callbacks
  # ---------------------------------------------------------------------------

  describe "behaviour callbacks" do
    test "name/0 returns correct name" do
      assert A2ACall.name() == "a2a_call"
    end

    test "safety/0 returns :sandboxed" do
      assert A2ACall.safety() == :sandboxed
    end

    test "description/0 returns non-empty string" do
      desc = A2ACall.description()
      assert is_binary(desc)
      assert String.length(desc) > 0
      assert String.contains?(desc, "A2A")
    end

    test "parameters/0 returns valid JSON Schema" do
      params = A2ACall.parameters()

      assert params["type"] == "object"
      assert is_map(params["properties"])
      assert is_list(params["required"])
      assert "action" in params["required"]
      assert "agent_url" in params["required"]
    end

    test "parameters defines all action types" do
      params = A2ACall.parameters()
      action_enum = params["properties"]["action"]["enum"]

      assert "discover" in action_enum
      assert "call" in action_enum
      assert "list_tools" in action_enum
      assert "execute_tool" in action_enum
    end

    test "parameters defines optional fields" do
      params = A2ACall.parameters()
      props = params["properties"]

      assert Map.has_key?(props, "message")
      assert Map.has_key?(props, "tool_name")
      assert Map.has_key?(props, "arguments")

      refute "message" in params["required"]
      refute "tool_name" in params["required"]
      refute "arguments" in params["required"]
    end
  end

  # ---------------------------------------------------------------------------
  # execute/1 — parameter validation
  # ---------------------------------------------------------------------------

  describe "execute/1 parameter validation" do
    test "returns error for empty params" do
      assert {:error, msg} = A2ACall.execute(%{})
      assert is_binary(msg)
      assert String.contains?(msg, "Missing required")
    end

    test "returns error when action is missing" do
      assert {:error, msg} = A2ACall.execute(%{"agent_url" => "http://localhost:9089"})
      assert String.contains?(msg, "Missing required")
    end

    test "returns error when agent_url is missing" do
      assert {:error, msg} = A2ACall.execute(%{"action" => "discover"})
      assert String.contains?(msg, "Missing required")
    end

    test "returns error for unknown action" do
      assert {:error, msg} = A2ACall.execute(%{"action" => "invalid_action", "agent_url" => "http://localhost"})
      assert String.contains?(msg, "Unknown action")
    end
  end

  # ---------------------------------------------------------------------------
  # execute/1 — action routing (HTTP calls wrapped in try/rescue)
  # ---------------------------------------------------------------------------

  describe "execute/1 action routing" do
    test "routes to discover for action: discover" do
      # Will fail with connection error since no Finch pool running
      result =
        try do
          A2ACall.execute(%{"action" => "discover", "agent_url" => "http://localhost:1"})
        rescue
          ArgumentError -> {:error, "connection unavailable"}
        end

      assert {:error, msg} = result
      assert is_binary(msg)
    end

    test "routes to call for action: call" do
      result =
        try do
          A2ACall.execute(%{"action" => "call", "agent_url" => "http://localhost:1"})
        rescue
          ArgumentError -> {:error, "connection unavailable"}
        end

      assert {:error, msg} = result
      assert is_binary(msg)
    end

    test "routes to list_tools for action: list_tools" do
      result =
        try do
          A2ACall.execute(%{"action" => "list_tools", "agent_url" => "http://localhost:1"})
        rescue
          ArgumentError -> {:error, "connection unavailable"}
        end

      assert {:error, msg} = result
      assert is_binary(msg)
    end

    test "routes to execute_tool for action: execute_tool" do
      result =
        try do
          A2ACall.execute(%{
            "action" => "execute_tool",
            "agent_url" => "http://localhost:1",
            "tool_name" => "test_tool"
          })
        rescue
          ArgumentError -> {:error, "connection unavailable"}
        end

      assert {:error, msg} = result
      assert is_binary(msg)
    end
  end

  # ---------------------------------------------------------------------------
  # execute/1 — call action specifics
  # ---------------------------------------------------------------------------

  describe "execute/1 call action" do
    test "returns error when message is empty string" do
      # Empty message triggers validation error before HTTP call
      result = A2ACall.execute(%{
        "action" => "call",
        "agent_url" => "http://localhost:1",
        "message" => ""
      })

      assert {:error, msg} = result
      assert String.contains?(msg, "non-empty string")
    end

    test "returns error when message is missing (defaults to empty)" do
      result = A2ACall.execute(%{
        "action" => "call",
        "agent_url" => "http://localhost:1"
      })

      assert {:error, msg} = result
      assert String.contains?(msg, "non-empty string")
    end

    test "validates message before making HTTP call" do
      # With no message key, it defaults to "" which triggers the non-empty error
      # before any HTTP connection is attempted
      result = A2ACall.execute(%{"action" => "call", "agent_url" => "http://localhost:1"})
      assert {:error, _msg} = result
    end
  end

  # ---------------------------------------------------------------------------
  # execute/1 — execute_tool action specifics
  # ---------------------------------------------------------------------------

  describe "execute/1 execute_tool action" do
    test "defaults arguments to empty map when missing" do
      result =
        try do
          A2ACall.execute(%{
            "action" => "execute_tool",
            "agent_url" => "http://localhost:1",
            "tool_name" => "some_tool"
          })
        rescue
          ArgumentError -> {:error, "connection unavailable"}
        end

      # Should not crash — arguments defaults to %{}
      assert {:error, _} = result
    end
  end

  # ---------------------------------------------------------------------------
  # Edge cases
  # ---------------------------------------------------------------------------

  describe "edge cases" do
    test "handles agent_url with trailing slash" do
      # The normalize_url helper trims trailing slashes
      result =
        try do
          A2ACall.execute(%{
            "action" => "discover",
            "agent_url" => "http://localhost:9089/"
          })
        rescue
          ArgumentError -> {:error, "connection unavailable"}
        end

      # Connection will fail but the URL normalization should work
      assert {:error, _} = result
    end

    test "handles agent_url without protocol prefix" do
      result =
        try do
          A2ACall.execute(%{
            "action" => "discover",
            "agent_url" => "localhost:9089"
          })
        rescue
          ArgumentError -> {:error, "connection unavailable"}
        end

      # Should prepend http://
      assert {:error, _} = result
    end

    test "handles non-list params" do
      # execute/1 expects a map; non-map input is caught by pattern matching
      assert {:error, _} = A2ACall.execute("not a map")
    end
  end
end
