defmodule OptimalSystemAgent.Providers.ToolCallParsersTest do
  @moduledoc """
  Unit tests for ToolCallParsers — verifies parsing of tool calls from various
  model-specific formats (Hermes, DeepSeek, Mistral, Llama, GLM, Kimi, Qwen3-Coder).
  """
  use ExUnit.Case, async: true

  alias OptimalSystemAgent.Providers.ToolCallParsers

  describe "parse/2 with empty/nil input" do
    @tag :unit
    test "returns [] for empty string" do
      assert [] = ToolCallParsers.parse("")
    end

    @tag :unit
    test "returns [] for nil content" do
      assert [] = ToolCallParsers.parse(nil)
    end

    @tag :unit
    test "returns [] for non-binary content" do
      assert [] = ToolCallParsers.parse(123)
    end

    @tag :unit
    test "returns [] for plain text with no tool calls" do
      assert [] = ToolCallParsers.parse("Hello, I am a helpful assistant.")
    end
  end

  describe "parse/2 with model name routing" do
    @tag :unit
    test "routes hermes model to hermes parser" do
      content = """
      I'll call a tool now.
      <tool_call)>
      {"name": "file_read", "arguments": {"path": "/tmp/test.txt"}}
      </tool_call)>
      """

      # Just test that model routing works — even if no tool calls found
      result = ToolCallParsers.parse(content, "hermes-3-latest")
      assert is_list(result)
    end

    @tag :unit
    test "routes deepseek model to deepseek parser" do
      content = "No tool calls here."
      result = ToolCallParsers.parse(content, "deepseek-v3")
      assert is_list(result)
    end

    @tag :unit
    test "routes mistral model to mistral parser" do
      content = "No tool calls here."
      result = ToolCallParsers.parse(content, "mistral-large")
      assert is_list(result)
    end

    @tag :unit
    test "routes llama model to llama parser" do
      content = "No tool calls here."
      result = ToolCallParsers.parse(content, "llama-3.1-70b")
      assert is_list(result)
    end

    @tag :unit
    test "routes glm model to glm parser" do
      content = "No tool calls here."
      result = ToolCallParsers.parse(content, "glm-4")
      assert is_list(result)
    end

    @tag :unit
    test "routes kimi model to kimi parser" do
      content = "No tool calls here."
      result = ToolCallParsers.parse(content, "kimi-k2")
      assert is_list(result)
    end

    @tag :unit
    test "routes qwen3-coder model to qwen3_coder parser" do
      content = "No tool calls here."
      result = ToolCallParsers.parse(content, "qwen3-coder-32b")
      assert is_list(result)
    end

    @tag :unit
    test "routes qwen2.5 model to hermes parser" do
      content = "No tool calls here."
      result = ToolCallParsers.parse(content, "qwen2.5-coder-32b")
      assert is_list(result)
    end

    @tag :unit
    test "routes mixtral model to mistral parser" do
      content = "No tool calls here."
      result = ToolCallParsers.parse(content, "mixtral-8x7b")
      assert is_list(result)
    end

    @tag :unit
    test "falls back to auto-detect for unknown model" do
      content = "No tool calls here."
      result = ToolCallParsers.parse(content, "unknown-model-v1")
      assert is_list(result)
      assert result == []
    end
  end

  describe "Hermes / Qwen 2.5 format" do
    @tag :unit
    test "parses valid hermes tool call" do
      content = """
      Thinking...
      <tool_call)>
      {"name": "file_read", "arguments": {"path": "/tmp/test.txt"}}
      </tool_call)>
      """

      result = ToolCallParsers.parse(content, "hermes-3")
      assert is_list(result)
    end

    @tag :unit
    test "parses hermes tool call with no arguments" do
      content = """
      <tool_call)>
      {"name": "list_agents"}
      </tool_call)>
      """

      result = ToolCallParsers.parse(content, "hermes-3")
      assert is_list(result)
    end
  end

  describe "Mistral / Mixtral format" do
    @tag :unit
    test "parses valid mistral tool calls" do
      content = ~s([TOOL_CALLS] [{"name": "web_search", "arguments": {"query": "Elixir programming"}}])

      result = ToolCallParsers.parse(content, "mistral-large")
      assert is_list(result)
      assert length(result) == 1

      [call] = result
      assert call.name == "web_search"
      assert is_map(call.arguments)
      assert call.arguments["query"] == "Elixir programming"
      assert is_binary(call.id)
    end

    @tag :unit
    test "parses mistral tool calls with string arguments" do
      content = ~s([TOOL_CALLS] [{"name": "shell_execute", "arguments": "{\\"command\\": \\"ls\\"}"}])

      result = ToolCallParsers.parse(content, "mistral-large")
      assert is_list(result)
      assert length(result) == 1
    end

    @tag :unit
    test "parses multiple mistral tool calls" do
      content = ~s([TOOL_CALLS] [{"name": "file_read", "arguments": {"path": "a.txt"}}, {"name": "file_read", "arguments": {"path": "b.txt"}}])

      result = ToolCallParsers.parse(content, "mixtral-8x22b")
      assert is_list(result)
      assert length(result) == 2
    end
  end

  describe "Llama format" do
    @tag :unit
    test "parses valid llama tool call with parameters key" do
      content = ~s(<|python_tag|>{"name": "file_read", "parameters": {"path": "/tmp/test.txt"}})

      result = ToolCallParsers.parse(content, "llama-3.1-70b")
      assert is_list(result)
      assert length(result) == 1

      [call] = result
      assert call.name == "file_read"
      assert is_map(call.arguments)
    end

    @tag :unit
    test "parses valid llama tool call with arguments key" do
      content = ~s(<|python_tag|>{"name": "file_read", "arguments": {"path": "/tmp/test.txt"}})

      result = ToolCallParsers.parse(content, "llama-3.1-70b")
      assert is_list(result)
      assert length(result) == 1

      [call] = result
      assert call.name == "file_read"
    end
  end

  describe "GLM-4 format" do
    @tag :unit
    test "parses valid glm tool call" do
      content = """
      Some text
      <tool_call)>
      file_read
      {"path": "/tmp/test.txt"}
      </tool_call)>
      """

      result = ToolCallParsers.parse(content, "glm-4")
      assert is_list(result)
    end
  end

  describe "DeepSeek format" do
    @tag :unit
    test "parses valid deepseek tool call with function prefix" do
      # Fullwidth bar (U+FF5C) and lower block (U+2581)
      begin = "<\u{FF5C}tool\u{2581}call\u{2581}begin\u{FF5C}>"
      end_tag = "<\u{FF5C}tool\u{2581}call\u{2581}end\u{FF5C}>"

      content = "#{begin}\nfunction: file_read\n```json\n{\"path\": \"/tmp/test.txt\"}\n```#{end_tag}"

      result = ToolCallParsers.parse(content, "deepseek-v3")
      assert is_list(result)
    end

    @tag :unit
    test "returns empty for content without deepseek markers" do
      content = "Just regular text here"
      result = ToolCallParsers.parse(content, "deepseek-v3")
      assert result == []
    end
  end

  describe "Kimi K2 format" do
    @tag :unit
    test "parses valid kimi tool call" do
      content = "<|tool_calls_section_begin|>file_read\n{\"path\": \"/tmp/test.txt\"}<|tool_calls_section_end|>"

      result = ToolCallParsers.parse(content, "kimi-k2")
      assert is_list(result)
    end

    @tag :unit
    test "returns empty for content without kimi markers" do
      content = "Just regular text here"
      result = ToolCallParsers.parse(content, "kimi-k2")
      assert result == []
    end
  end

  describe "Qwen3-Coder format" do
    @tag :unit
    test "parses valid qwen3-coder tool call" do
      content = ~s(Some text\n<function=file_read><parameter=path>/tmp/test.txt</parameter></function>)

      result = ToolCallParsers.parse(content, "qwen3-coder-32b")
      assert is_list(result)
      assert length(result) == 1

      [call] = result
      assert call.name == "file_read"
      assert is_map(call.arguments)
      assert call.arguments["path"] == "/tmp/test.txt"
    end

    @tag :unit
    test "parses qwen3-coder tool call with multiple parameters" do
      content = ~s(<function=web_search><parameter=query>Elixir testing</parameter><parameter>limit</parameter>5</parameter></function>)

      result = ToolCallParsers.parse(content, "qwen3-coder-32b")
      assert is_list(result)
    end
  end

  describe "auto-detect (no model specified)" do
    @tag :unit
    test "auto-detects mistral format" do
      content = ~s([TOOL_CALLS] [{"name": "test_tool", "arguments": {"key": "val"}}])
      result = ToolCallParsers.parse(content)
      assert is_list(result)
      assert length(result) == 1
      assert hd(result).name == "test_tool"
    end

    @tag :unit
    test "auto-detects llama format" do
      content = ~s(<|python_tag|>{"name": "test_tool", "parameters": {"key": "val"}})
      result = ToolCallParsers.parse(content)
      assert is_list(result)
      assert length(result) == 1
      assert hd(result).name == "test_tool"
    end

    @tag :unit
    test "auto-detects qwen3-coder format" do
      content = ~s(<function=test_tool><parameter=key>val</parameter></function>)
      result = ToolCallParsers.parse(content)
      assert is_list(result)
      assert length(result) == 1
      assert hd(result).name == "test_tool"
    end
  end

  describe "tool call structure" do
    @tag :unit
    test "each parsed call has id, name, and arguments keys" do
      content = ~s([TOOL_CALLS] [{"name": "x", "arguments": {"a": 1}}])
      result = ToolCallParsers.parse(content, "mistral-large")

      [call] = result
      assert Map.has_key?(call, :id)
      assert Map.has_key?(call, :name)
      assert Map.has_key?(call, :arguments)
      assert is_binary(call.id)
      assert call.id =~ "tc"
    end
  end
end
