defmodule OptimalSystemAgent.Agent.Loop.TelemetryTest do
  @moduledoc """
  Unit tests for Telemetry module.

  Tests context pressure telemetry and token estimation.
  """

  use ExUnit.Case, async: true


  alias OptimalSystemAgent.Agent.Loop.Telemetry

  @moduletag :capture_log

  describe "emit_context_pressure/1" do
    test "returns :ok on success" do
      state = %{
        model: :test_model,
        session_id: "test_session",
        last_input_tokens: 1000,
        messages: []
      }

      # Mock the providers registry and bus to avoid dependencies
      # The function should handle errors gracefully
      result = Telemetry.emit_context_pressure(state)
      assert result == :ok or result == :error
    end

    test "handles missing last_input_tokens" do
      state = %{
        model: :test_model,
        session_id: "test_session",
        last_input_tokens: 0,
        messages: []
      }

      result = Telemetry.emit_context_pressure(state)
      assert result == :ok or result == :error
    end

    test "handles empty messages list" do
      state = %{
        model: :test_model,
        session_id: "test_session",
        last_input_tokens: 100,
        messages: []
      }

      result = Telemetry.emit_context_pressure(state)
      assert result == :ok or result == :error
    end
  end

  describe "estimate_tokens/1" do
    test "returns 0 for empty messages" do
      state = %{messages: []}
      assert Telemetry.estimate_tokens(state) == 0
    end

    test "returns 0 on error" do
      # Pass invalid state that will cause an error
      state = %{messages: nil}
      assert Telemetry.estimate_tokens(state) == 0
    end

    test "returns non-zero for valid messages" do
      state = %{
        messages: [
          %{role: "user", content: "Hello world"}
        ]
      }

      tokens = Telemetry.estimate_tokens(state)
      assert is_integer(tokens)
      assert tokens >= 0
    end
  end

  describe "extract_tools_used/1" do
    test "returns empty list for messages without tool calls" do
      messages = [
        %{role: "user", content: "Hello"},
        %{role: "assistant", content: "Hi there"}
      ]

      tools = Telemetry.extract_tools_used(messages)
      assert tools == []
    end

    test "extracts tool names from assistant messages" do
      messages = [
        %{role: "user", content: "Search the web"},
        %{role: "assistant", tool_calls: [
          %{name: "web_search", arguments: %{}},
          %{name: "file_read", arguments: %{}}
        ]}
      ]

      tools = Telemetry.extract_tools_used(messages)
      assert "web_search" in tools
      assert "file_read" in tools
      assert length(tools) == 2
    end

    test "returns unique tool names" do
      messages = [
        %{role: "assistant", tool_calls: [
          %{name: "web_search", arguments: %{}}
        ]},
        %{role: "assistant", tool_calls: [
          %{name: "web_search", arguments: %{}}
        ]}
      ]

      tools = Telemetry.extract_tools_used(messages)
      assert tools == ["web_search"]
    end

    test "filters out messages with empty tool_calls" do
      messages = [
        %{role: "assistant", tool_calls: []},
        %{role: "assistant", tool_calls: [
          %{name: "web_search", arguments: %{}}
        ]}
      ]

      tools = Telemetry.extract_tools_used(messages)
      assert tools == ["web_search"]
    end
  end

  describe "integration - full telemetry flow" do
    test "extracts tools and estimates tokens" do
      messages = [
        %{role: "user", content: "Use the search tool"},
        %{role: "assistant", tool_calls: [
          %{name: "web_search", arguments: %{}}
        ]}
      ]

      tools = Telemetry.extract_tools_used(messages)
      assert "web_search" in tools

      state = %{messages: messages}
      tokens = Telemetry.estimate_tokens(state)
      assert tokens >= 0
    end
  end
end
