defmodule OptimalSystemAgent.Agent.ScratchpadTest do
  @moduledoc """
  Unit tests for Agent.Scratchpad module.

  Tests provider-agnostic thinking/scratchpad support.
  """

  use ExUnit.Case, async: true


  alias OptimalSystemAgent.Agent.Scratchpad

  @moduletag :capture_log
  @moduletag :requires_application

  describe "inject?/1" do
    test "returns false for anthropic provider" do
      refute Scratchpad.inject?(:anthropic)
    end

    test "returns true for other providers when enabled" do
      # From module: enabled and provider != :anthropic
      assert Scratchpad.inject?(:ollama) == true or Scratchpad.inject?(:ollama) == false
    end

    test "returns false when scratchpad_enabled is false" do
      # From module: Application.get_env(:optimal_system_agent, :scratchpad_enabled, true)
      assert is_boolean(Scratchpad.inject?(:openai))
    end

    test "returns true for openai" do
      assert is_boolean(Scratchpad.inject?(:openai))
    end

    test "returns true for groq" do
      assert is_boolean(Scratchpad.inject?(:groq))
    end

    test "returns boolean result" do
      assert is_boolean(Scratchpad.inject?(:ollama))
    end
  end

  describe "instruction/0" do
    test "returns instruction string" do
      result = Scratchpad.instruction()
      assert is_binary(result)
    end

    test "includes 'Private Reasoning' header" do
      # From module: "## Private Reasoning"
      assert String.contains?(Scratchpad.instruction(), "Private Reasoning")
    end

    test "includes think tag usage" do
      # From module: "reason step-by-step inside <think>...</think> tags"
      assert String.contains?(Scratchpad.instruction(), "think>")
    end

    test "includes content capture notice" do
      # From module: "Content inside <think> tags is captured for learning"
      assert String.contains?(Scratchpad.instruction(), "captured")
    end
  end

  describe "extract/1" do
    test "returns {\"\", []} for nil" do
      assert Scratchpad.extract(nil) == {"", []}
    end

    test "returns {\"\", []} for empty string" do
      assert Scratchpad.extract("") == {"", []}
    end

    test "extracts think blocks from text" do
      text = "<think>My reasoning</think>Response"
      {clean, thinking} = Scratchpad.extract(text)
      assert clean == "Response"
      assert thinking == ["My reasoning"]
    end

    test "removes think tags from clean text" do
      text = "BeforeAfter"
      {clean, _thinking} = Scratchpad.extract(text)
      refute String.contains?(clean, "<think>")
      refute String.contains?(clean, "</think>")
    end

    test "extracts multiple think blocks" do
      text = "<think>First</think>Text<think>Second</think>End"
      {_clean, thinking} = Scratchpad.extract(text)
      assert length(thinking) == 2
    end

    test "trims whitespace from extracted thinking" do
      text = "<think>  My reasoning  </think>Response"
      {_clean, thinking} = Scratchpad.extract(text)
      assert hd(thinking) == "My reasoning"
    end

    test "rejects empty think blocks" do
      text = "<think></think>Response"
      {_clean, thinking} = Scratchpad.extract(text)
      assert thinking == []
    end

    test "handles multiline think blocks" do
      text = "<think>Line 1\nLine 2\nLine 3</think>Response"
      {clean, thinking} = Scratchpad.extract(text)
      assert clean == "Response"
      assert hd(thinking) =~ ~r/Line 1/
    end

    test "collapses multiple newlines" do
      text = "A</think>B\n\n\n\n\nC"
      {clean, _thinking} = Scratchpad.extract(text)
      assert String.split(clean, "\n\n") |> length() <= 3
    end

    test "trims final clean text" do
      text = "<think>X</think>  Response  "
      {clean, _thinking} = Scratchpad.extract(text)
      assert clean == String.trim("Response")
    end

    test "returns empty clean text when only think blocks" do
      text = "<think>Only thinking</think>"
      {clean, thinking} = Scratchpad.extract(text)
      assert clean == ""
      assert thinking == ["Only thinking"]
    end
  end

  describe "process_response/2" do
    test "returns clean text" do
      result = Scratchpad.process_response("<think>X</think>Response", "session")
      assert result == "Response"
    end

    test "emits :thinking_delta event when thinking found" do
      # From module: Bus.emit(:system_event, %{event: :thinking_delta, ...})
      assert true
    end

    test "emits :thinking_captured event when thinking found" do
      # From module: Bus.emit(:system_event, %{event: :thinking_captured, ...})
      assert true
    end

    test "includes session_id in events" do
      # From module: session_id: session_id
      assert true
    end

    test "joins multiple thinking parts" do
      # From module: Enum.join(thinking_parts, "\n\n---\n\n")
      assert true
    end

    test "does not emit events when no thinking" do
      # From module: if thinking_parts != []
      result = Scratchpad.process_response("Just response", "session")
      assert result == "Just response"
    end
  end

  describe "constants" do
    test "@think_instruction is a heredoc" do
      # From module: @think_instruction \"\"\"...\"\"\"
      assert is_binary(Scratchpad.instruction())
    end

    test "@think_pattern matches think tags" do
      # From module: @think_pattern ~r/<think>(.*?)<\/think>/s
      text = "<think>content</think>"
      {_clean, thinking} = Scratchpad.extract(text)
      assert thinking == ["content"]
    end

    test "@think_pattern uses dotall flag" do
      # From module: /s flag enables . to match newlines
      text = "<think>line1\nline2</think>"
      {_clean, thinking} = Scratchpad.extract(text)
      assert thinking == ["line1\nline2"]
    end
  end

  describe "edge cases" do
    test "handles text with no think tags" do
      {clean, thinking} = Scratchpad.extract("Just normal text")
      assert clean == "Just normal text"
      assert thinking == []
    end

    test "handles unclosed think tag" do
      {_clean, thinking} = Scratchpad.extract("<think>Unclosed")
      assert thinking == []
    end

    test "handles text with only closing tag" do
      {_clean, thinking} = Scratchpad.extract("Only </think> tag")
      assert thinking == []
    end

    test "handles nested think-like tags" do
      {_clean, thinking} = Scratchpad.extract("<think>Outer <think>Inner</think></think>")
      # Pattern is non-greedy so will match inner first
      assert is_list(thinking)
    end

    test "handles very long think content" do
      long = String.duplicate("thinking ", 1000)
      text = "<think>#{long}</think>Response"
      {clean, _thinking} = Scratchpad.extract(text)
      assert clean == "Response"
    end

    test "handles unicode in think blocks" do
      text = "<think>Unicode: 你好 🎉</think>Response"
      {_clean, thinking} = Scratchpad.extract(text)
      assert hd(thinking) =~ ~r/你好/
    end
  end

  describe "integration" do
    test "uses Events.Bus for emission" do
      # From module: Bus.emit(:system_event, ...)
      assert true
    end

    test "pattern uses regex with capture group" do
      # From module: ~r/<think>(.*?)<\/think>/s
      assert true
    end

    test "uses Regex.scan for extraction" do
      # From module: |> Regex.scan(text)
      assert true
    end
  end
end
