defmodule OptimalSystemAgent.Providers.OpenAICompatRealTest do
  @moduledoc """
  Chicago TDD integration tests for Providers.OpenAICompat (pure functions only).

  NO MOCKS. Tests real message formatting, tool formatting, model detection.
  Every gap found is a real bug or missing behavior.
  """

  use ExUnit.Case, async: true

  @moduletag :integration

  alias OptimalSystemAgent.Providers.OpenAICompat

  describe "OpenAICompat.format_messages/1" do
    test "CRASH: formats user message" do
      messages = [%{role: "user", content: "hello"}]
      result = OpenAICompat.format_messages(messages)
      assert [%{"role" => "user", "content" => "hello"}] = result
    end

    test "CRASH: formats system message" do
      messages = [%{role: "system", content: "You are helpful"}]
      result = OpenAICompat.format_messages(messages)
      assert [%{"role" => "system", "content" => "You are helpful"}] = result
    end

    test "CRASH: formats assistant message" do
      messages = [%{role: "assistant", content: "Hi there"}]
      result = OpenAICompat.format_messages(messages)
      assert [%{"role" => "assistant", "content" => "Hi there"}] = result
    end

    test "CRASH: formats tool result message with tool_call_id" do
      messages = [%{role: "tool", content: "file contents", tool_call_id: "call_123"}]
      result = OpenAICompat.format_messages(messages)
      assert [%{"role" => "tool", "content" => "file contents", "tool_call_id" => "call_123"}] = result
    end

    test "CRASH: tool result includes name when present" do
      messages = [%{role: "tool", content: "result", tool_call_id: "id1", name: "file_read"}]
      result = OpenAICompat.format_messages(messages)
      [msg] = result
      assert msg["name"] == "file_read"
    end

    test "CRASH: assistant message with tool_calls preserves structure" do
      calls = [%{id: "call_1", name: "file_read", arguments: %{path: "/tmp"}}]
      messages = [%{role: "assistant", content: "", tool_calls: calls}]
      result = OpenAICompat.format_messages(messages)
      [msg] = result
      assert msg["role"] == "assistant"
      assert length(msg["tool_calls"]) == 1
      [tc] = msg["tool_calls"]
      assert tc["id"] == "call_1"
      assert tc["type"] == "function"
      assert tc["function"]["name"] == "file_read"
    end

    test "CRASH: tool_calls arguments serialized to JSON string" do
      calls = [%{id: "c1", name: "write", arguments: %{path: "/tmp/f.txt", content: "hello"}}]
      messages = [%{role: "assistant", content: "", tool_calls: calls}]
      result = OpenAICompat.format_messages(messages)
      [tc] = hd(result)["tool_calls"]
      args = tc["function"]["arguments"]
      assert is_binary(args)
      assert String.contains?(args, "path")
    end

    test "CRASH: tool_calls with string arguments preserved" do
      calls = [%{id: "c1", name: "write", arguments: ~s({"path":"/tmp"})}]
      messages = [%{role: "assistant", content: "", tool_calls: calls}]
      result = OpenAICompat.format_messages(messages)
      [tc] = hd(result)["tool_calls"]
      assert tc["function"]["arguments"] == ~s({"path":"/tmp"})
    end

    test "CRASH: handles string-keyed messages" do
      messages = [%{"role" => "user", "content" => "hello"}]
      result = OpenAICompat.format_messages(messages)
      assert [%{"role" => "user", "content" => "hello"}] = result
    end

    test "CRASH: empty content becomes empty string" do
      messages = [%{role: "user", content: nil}]
      result = OpenAICompat.format_messages(messages)
      [msg] = result
      assert msg["content"] == ""
    end

    test "CRASH: formats multiple messages" do
      messages = [
        %{role: "system", content: "sys"},
        %{role: "user", content: "hello"},
        %{role: "assistant", content: "hi"}
      ]
      result = OpenAICompat.format_messages(messages)
      assert length(result) == 3
    end
  end

  describe "OpenAICompat.format_tools/1" do
    test "CRASH: wraps flat tool map" do
      tools = [%{name: "read", description: "Read files", parameters: %{type: "object"}}]
      result = OpenAICompat.format_tools(tools)
      [tool] = result
      assert tool["type"] == "function"
      assert tool["function"]["name"] == "read"
      assert tool["function"]["description"] == "Read files"
    end

    test "CRASH: passes through already-formatted tool" do
      tool = %{"type" => "function", "function" => %{"name" => "read", "description" => "d", "parameters" => %{}}}
      result = OpenAICompat.format_tools([tool])
      assert result == [tool]
    end

    test "CRASH: formats atom-keyed tool" do
      tool = %{type: "function", function: %{name: "write", description: "Write", parameters: %{}}}
      result = OpenAICompat.format_tools([tool])
      [t] = result
      assert is_binary(t["type"])
      assert is_binary(t["function"]["name"])
    end

    test "CRASH: empty list returns empty" do
      assert OpenAICompat.format_tools([]) == []
    end

    test "CRASH: formats multiple tools" do
      tools = [
        %{name: "read", description: "Read", parameters: %{}},
        %{name: "write", description: "Write", parameters: %{}}
      ]
      result = OpenAICompat.format_tools(tools)
      assert length(result) == 2
      names = Enum.map(result, fn t -> t["function"]["name"] end)
      assert "read" in names
      assert "write" in names
    end
  end

  describe "OpenAICompat.reasoning_model?/1" do
    test "CRASH: o3-mini is a reasoning model" do
      assert OpenAICompat.reasoning_model?("o3-mini")
    end

    test "CRASH: o1-preview is a reasoning model" do
      assert OpenAICompat.reasoning_model?("o1-preview")
    end

    test "CRASH: o4-mini is a reasoning model" do
      assert OpenAICompat.reasoning_model?("o4-mini")
    end

    test "CRASH: deepseek-reasoner is a reasoning model" do
      assert OpenAICompat.reasoning_model?("deepseek-reasoner")
    end

    test "CRASH: kimi model is a reasoning model" do
      assert OpenAICompat.reasoning_model?("kimi-k2-0711")
    end

    test "CRASH: gpt-4o is NOT a reasoning model" do
      refute OpenAICompat.reasoning_model?("gpt-4o")
    end

    test "CRASH: gpt-3.5-turbo is NOT a reasoning model" do
      refute OpenAICompat.reasoning_model?("gpt-3.5-turbo")
    end

    test "CRASH: case insensitive" do
      assert OpenAICompat.reasoning_model?("O3-MINI")
    end

    test "CRASH: atom input converted to string" do
      assert OpenAICompat.reasoning_model?(:o3)
    end
  end
end
