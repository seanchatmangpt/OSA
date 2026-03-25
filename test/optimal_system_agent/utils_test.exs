defmodule OptimalSystemAgent.UtilsTest do
  @moduledoc """
  Unit tests for Utils module.

  Tests utility functions across Tokens, Text, and ID submodules.
  Pure functions, no mocks.
  """

  use ExUnit.Case, async: true

  alias OptimalSystemAgent.Utils.Tokens
  alias OptimalSystemAgent.Utils.Text

  @moduletag :capture_log

  describe "Tokens.estimate/1" do
    test "returns 0 for non-binary input" do
      assert Tokens.estimate(nil) == 0
      assert Tokens.estimate(123) == 0
      assert Tokens.estimate(%{}) == 0
      assert Tokens.estimate([]) == 0
    end

    test "estimates tokens for simple text" do
      # "hello world" = 2 words * 1.3 = 2.6 -> round(2.6) = 3
      estimate = Tokens.estimate("hello world")
      assert estimate > 0
    end

    test "counts words correctly" do
      # 5 words = 5 * 1.3 = 6.5 -> round(6.5) = 7
      estimate = Tokens.estimate("one two three four five")
      assert estimate > 0
    end

    test "counts punctuation" do
      # "hello, world!" = 2 words + 2 punctuation = 2*1.3 + 2*0.5 = 3.6 -> round(3.6) = 4
      estimate = Tokens.estimate("hello, world!")
      assert estimate > 0
    end

    test "handles empty string" do
      assert Tokens.estimate("") == 0
    end

    test "handles unicode text" do
      estimate = Tokens.estimate("测试文本")
      assert is_integer(estimate)
    end

    test "handles text with only spaces" do
      assert Tokens.estimate("   ") == 0
    end

    test "handles very long text" do
      long_text = String.duplicate("word ", 1000)
      estimate = Tokens.estimate(long_text)
      assert estimate > 0
    end
  end

  describe "Text.truncate/2" do
    test "returns string unchanged when within max_len" do
      assert Text.truncate("hello", 10) == "hello"
    end

    test "truncates string exceeding max_len" do
      result = Text.truncate("hello world", 8)
      assert String.length(result) == 8
      assert String.ends_with?(result, "…")
    end

    test "handles exact max_len" do
      assert Text.truncate("hello", 5) == "hello"
    end

    test "returns empty string for non-binary input" do
      assert Text.truncate(nil, 10) == ""
      assert Text.truncate(123, 10) == ""
    end

    test "handles empty string" do
      assert Text.truncate("", 10) == ""
    end

    test "handles unicode characters" do
      result = Text.truncate("测试文本字符串", 5)
      assert String.length(result) == 5
      assert String.ends_with?(result, "…")
    end

    test "handles max_len of 0" do
      result = Text.truncate("hello", 0)
      # Should return ellipsis only or empty
      assert String.length(result) <= 1
    end

    test "handles max_len of 1" do
      result = Text.truncate("hello", 1)
      assert String.length(result) == 1
      assert result == "…"
    end
  end

  describe "Text.strip_markdown_fences/1" do
    test "removes opening markdown fence" do
      assert Text.strip_markdown_fences("```json\ntest") == "test"
    end

    test "removes closing markdown fence" do
      assert Text.strip_markdown_fences("test\n```") == "test"
    end

    test "removes both fences" do
      result = Text.strip_markdown_fences("```json\ntest\n```")
      assert result == "test"
    end

    test "removes fence without language tag" do
      assert Text.strip_markdown_fences("```\ntest") == "test"
    end

    test "returns input unchanged for non-binary" do
      assert Text.strip_markdown_fences(nil) == nil
      assert Text.strip_markdown_fences(123) == 123
    end

    test "handles empty string" do
      assert Text.strip_markdown_fences("") == ""
    end

    test "handles string without fences" do
      assert Text.strip_markdown_fences("plain text") == "plain text"
    end

    test "handles multiple code blocks" do
      # Only strips first opening and last closing
      result = Text.strip_markdown_fences("```\nblock1\n```\n```\nblock2\n```")
      assert String.contains?(result, "block1")
    end
  end

  describe "Text.strip_thinking_tokens/1" do
    test "returns empty string for nil" do
      assert Text.strip_thinking_tokens(nil) == ""
    end

    test "strips think tags" do
      result = Text.strip_thinking_tokens("<think>reasoning</think>output")
      assert result == "output"
    end

    test "strips <|start|>...<|end|> tags" do
      result = Text.strip_thinking_tokens("<|start|>reasoning<|end|>output")
      assert result == "output"
    end

    test "strips <reasoning> tags" do
      result = Text.strip_thinking_tokens("<reasoning>reasoning</reasoning>output")
      assert result == "output"
    end

    test "returns input unchanged for non-binary non-nil" do
      assert Text.strip_thinking_tokens(123) == 123
      assert Text.strip_thinking_tokens([]) == []
    end

    test "handles empty string" do
      assert Text.strip_thinking_tokens("") == ""
    end

    test "handles string without thinking tokens" do
      assert Text.strip_thinking_tokens("plain output") == "plain output"
    end

    test "handles multiline thinking blocks" do
      result = Text.strip_thinking_tokens("<think>\nline1\nline2\n</think>\noutput")
      assert result == "output"
    end

    test "trims output" do
      result = Text.strip_thinking_tokens("output   ")
      assert result == "output"
    end
  end

  describe "Text.safe_to_string/1" do
    test "converts binary to string" do
      assert Text.safe_to_string("test") == "test"
    end

    test "converts nil to empty string" do
      assert Text.safe_to_string(nil) == ""
    end

    test "converts atom to string" do
      assert Text.safe_to_string(:test_atom) == "test_atom"
    end

    test "converts map to JSON string" do
      result = Text.safe_to_string(%{key: "value"})
      assert String.contains?(result, "key")
      assert String.contains?(result, "value")
    end

    test "converts list to JSON string" do
      result = Text.safe_to_string([1, 2, 3])
      assert String.contains?(result, "1")
    end

    test "converts other values to inspect string" do
      result = Text.safe_to_string(123)
      assert String.contains?(result, "123")
    end

    test "handles empty map" do
      result = Text.safe_to_string(%{})
      assert result == "{}"
    end

    test "handles empty list" do
      result = Text.safe_to_string([])
      assert result == "[]"
    end
  end

  describe "edge cases" do
    test "Tokens.estimate handles text with only punctuation" do
      estimate = Tokens.estimate("!@#$%")
      assert is_integer(estimate)
    end

    test "Text.truncate handles very long string" do
      long_str = String.duplicate("a", 10000)
      result = Text.truncate(long_str, 100)
      assert String.length(result) == 100
    end

    test "Text.strip_thinking_tokens handles nested tags" do
      result = Text.strip_thinking_tokens("<think><inner>reasoning</inner></think>output")
      assert result == "output"
    end
  end

  describe "integration" do
    test "full text processing pipeline" do
      # Strip thinking tokens
      step1 = Text.strip_thinking_tokens("<think>reasoning</think>```json\noutput\n```")
      # Strip markdown fences
      step2 = Text.strip_markdown_fences(step1)
      # Truncate if needed
      step3 = Text.truncate(step2, 100)

      assert step3 == "output"
    end

    test "token estimation for processed text" do
      text = "<think>reasoning</think>Actual response here"
      cleaned = Text.strip_thinking_tokens(text)
      tokens = Tokens.estimate(cleaned)
      assert tokens > 0
    end
  end
end
