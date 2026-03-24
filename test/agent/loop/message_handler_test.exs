defmodule OptimalSystemAgent.Agent.Loop.MessageHandlerTest do
  @moduledoc """
  Chicago TDD unit tests for MessageHandler module.

  Tests message formatting, tool call extraction, and response parsing.
  Pure functions that transform data without side effects.
  """

  use ExUnit.Case, async: true

  alias OptimalSystemAgent.Agent.Loop.MessageHandler

  # ---------------------------------------------------------------------------
  # Red Phase: These tests describe the expected behavior
  # ---------------------------------------------------------------------------

  describe "format_messages/2" do
    test "wraps user input in user message structure" do
      messages = MessageHandler.format_messages("hello", [])

      assert length(messages) >= 1
      user_msg = Enum.find(messages, fn m -> m.role == "user" end)
      assert user_msg.content == "hello"
    end

    test "includes existing conversation history" do
      history = [%{role: "user", content: "previous"}]
      messages = MessageHandler.format_messages("new", history)

      assert length(messages) >= 2
      assert Enum.at(messages, 0).content == "previous"
    end
  end

  describe "extract_tool_calls/1" do
    test "returns empty list when no tool calls in response" do
      response = %{content: "just text", tool_calls: nil}
      assert MessageHandler.extract_tool_calls(response) == []
    end

    test "extracts tool calls array from response" do
      response = %{
        content: "done",
        tool_calls: [
          %{id: "call_1", name: "file_read", arguments: %{"path" => "/tmp/file"}}
        ]
      }

      calls = MessageHandler.extract_tool_calls(response)
      assert length(calls) == 1
      assert hd(calls).name == "file_read"
    end
  end

  describe "parse_response/1" do
    test "handles string-only response" do
      raw = "just a text response"
      assert {:ok, %{content: "just a text response", tool_calls: []}} = MessageHandler.parse_response(raw)
    end

    test "handles map response with tool_calls" do
      raw = %{
        "content" => "executing",
        "tool_calls" => [%{"id" => "1", "name" => "search"}]
      }

      assert {:ok, response} = MessageHandler.parse_response(raw)
      assert response.tool_calls |> length() > 0
    end
  end
end
