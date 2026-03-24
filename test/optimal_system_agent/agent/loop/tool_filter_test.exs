defmodule OptimalSystemAgent.Agent.Loop.ToolFilterTest do
  @moduledoc """
  Chicago TDD unit tests for the ToolFilter module.

  Tests the three-layer tool filtering pipeline:
    1. Signal weight gate  — low-weight inputs (< 0.20) skip tools entirely
    2. Computer-use focus  — trims tool list for local providers when CU is active
    3. Local provider budget — caps at 10 tools for slow providers (Ollama, LM Studio, llama.cpp)

  Functions covered:
    - filter/2  — main pipeline returning (possibly reduced) tool list
  """

  use ExUnit.Case, async: true

  alias OptimalSystemAgent.Agent.Loop.ToolFilter

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp tool(name), do: %{name: name}

  defp all_tools do
    [
      tool("file_read"),
      tool("file_write"),
      tool("file_edit"),
      tool("shell_execute"),
      tool("ask_user"),
      tool("computer_use"),
      tool("memory_recall"),
      tool("memory_save"),
      tool("web_search"),
      tool("web_fetch"),
      tool("git"),
      tool("dir_list"),
      tool("file_glob"),
      tool("grep_search"),
      tool("delegate"),
      tool("task_write"),
      tool("download"),
      tool("create_skill")
    ]
  end

  defp base_state(opts \\ []) do
    %{
      provider: Keyword.get(opts, :provider, :openai),
      signal_weight: Keyword.get(opts, :signal_weight, 0.5),
      messages: Keyword.get(opts, :messages, [])
    }
  end

  # ---------------------------------------------------------------------------
  # filter/2 — signal weight gate
  # ---------------------------------------------------------------------------

  describe "filter/2 — signal weight gate" do
    test "returns empty list when signal_weight is below threshold (0.20)" do
      state = base_state(signal_weight: 0.10)
      tools = all_tools()

      result = ToolFilter.filter(tools, state)
      assert result == []
    end

    test "returns empty list when signal_weight is exactly 0.19" do
      state = base_state(signal_weight: 0.19)
      tools = all_tools()

      result = ToolFilter.filter(tools, state)
      assert result == []
    end

    test "returns all tools when signal_weight equals threshold (0.20)" do
      state = base_state(signal_weight: 0.20)
      tools = all_tools()

      result = ToolFilter.filter(tools, state)
      assert length(result) == length(tools)
    end

    test "returns all tools when signal_weight is above threshold" do
      state = base_state(signal_weight: 0.75)
      tools = all_tools()

      result = ToolFilter.filter(tools, state)
      assert length(result) == length(tools)
    end

    test "returns all tools when signal_weight is 1.0" do
      state = base_state(signal_weight: 1.0)
      tools = all_tools()

      result = ToolFilter.filter(tools, state)
      assert length(result) == length(tools)
    end

    test "returns all tools when signal_weight is not set (nil)" do
      state = base_state() |> Map.delete(:signal_weight)
      tools = all_tools()

      result = ToolFilter.filter(tools, state)
      assert length(result) == length(tools)
    end

    test "weight gate applies before other filters (returns empty even for local providers)" do
      state = base_state(signal_weight: 0.05, provider: :ollama)
      tools = all_tools()

      result = ToolFilter.filter(tools, state)
      assert result == []
    end
  end

  # ---------------------------------------------------------------------------
  # filter/2 — computer-use focus mode
  # ---------------------------------------------------------------------------

  describe "filter/2 — computer-use focus mode" do
    test "trims to CU-related tools when computer_use was used on a local provider" do
      state = %{
        base_state(provider: :ollama, signal_weight: 0.5) |
        messages: [%{name: "computer_use", content: "screenshot taken"}]
      }
      tools = all_tools()

      result = ToolFilter.filter(tools, state)

      # Only computer_use, file_read, and ask_user should remain
      remaining_names = Enum.map(result, & &1.name)
      assert "computer_use" in remaining_names
      assert "file_read" in remaining_names
      assert "ask_user" in remaining_names
      # Non-CU tools should be removed
      refute "shell_execute" in remaining_names
      refute "file_write" in remaining_names
      refute "web_search" in remaining_names
    end

    test "does NOT apply CU focus mode for non-local providers" do
      state = %{
        base_state(provider: :openai, signal_weight: 0.5) |
        messages: [%{name: "computer_use", content: "screenshot taken"}]
      }
      tools = all_tools()

      result = ToolFilter.filter(tools, state)
      # All tools should remain for OpenAI
      assert length(result) == length(tools)
    end

    test "does NOT apply CU focus mode when no computer_use in message history" do
      # Use a cloud provider to avoid budget cap interference
      state = base_state(provider: :anthropic, signal_weight: 0.5)
      state = %{state | messages: [%{name: "file_read", content: "file contents"}]}
      tools = all_tools()

      result = ToolFilter.filter(tools, state)
      # All tools should remain (CU focus not triggered)
      assert length(result) == length(tools)
    end

    test "CU focus mode returns empty when weight gate already filtered tools" do
      state = %{
        base_state(provider: :ollama, signal_weight: 0.05) |
        messages: [%{name: "computer_use", content: "screenshot"}]
      }
      tools = all_tools()

      result = ToolFilter.filter(tools, state)
      # Weight gate fires first, returns empty
      assert result == []
    end
  end

  # ---------------------------------------------------------------------------
  # filter/2 — local provider budget cap
  # ---------------------------------------------------------------------------

  describe "filter/2 — local provider budget cap" do
    test "trims tools to 10 for Ollama when list exceeds 10" do
      state = base_state(provider: :ollama, signal_weight: 0.5)
      tools = all_tools()  # 18 tools

      result = ToolFilter.filter(tools, state)
      assert length(result) <= 10
    end

    test "trims tools to 10 for LM Studio when list exceeds 10" do
      state = base_state(provider: :lmstudio, signal_weight: 0.5)
      tools = all_tools()

      result = ToolFilter.filter(tools, state)
      assert length(result) <= 10
    end

    test "trims tools to 10 for llama.cpp when list exceeds 10" do
      state = base_state(provider: :llamacpp, signal_weight: 0.5)
      tools = all_tools()

      result = ToolFilter.filter(tools, state)
      assert length(result) <= 10
    end

    test "does NOT trim for OpenAI (cloud provider)" do
      state = base_state(provider: :openai, signal_weight: 0.5)
      tools = all_tools()

      result = ToolFilter.filter(tools, state)
      assert length(result) == length(tools)
    end

    test "does NOT trim for Anthropic (cloud provider)" do
      state = base_state(provider: :anthropic, signal_weight: 0.5)
      tools = all_tools()

      result = ToolFilter.filter(tools, state)
      assert length(result) == length(tools)
    end

    test "does NOT trim when tool list is already at or below 10" do
      state = base_state(provider: :ollama, signal_weight: 0.5)
      tools = Enum.take(all_tools(), 8)

      result = ToolFilter.filter(tools, state)
      assert length(result) == 8
    end

    test "does NOT trim when tool list is exactly 10" do
      state = base_state(provider: :ollama, signal_weight: 0.5)
      tools = Enum.take(all_tools(), 10)

      result = ToolFilter.filter(tools, state)
      assert length(result) == 10
    end

    test "priority tools are kept when trimming for local providers" do
      state = base_state(provider: :ollama, signal_weight: 0.5)
      tools = all_tools()

      result = ToolFilter.filter(tools, state)
      remaining_names = Enum.map(result, & &1.name)

      # Priority tools should be preserved
      assert "file_read" in remaining_names
      assert "file_write" in remaining_names
      assert "file_edit" in remaining_names
      assert "shell_execute" in remaining_names
      assert "ask_user" in remaining_names
      assert "computer_use" in remaining_names
      assert "memory_recall" in remaining_names
    end

    test "empty tool list stays empty" do
      state = base_state(provider: :ollama, signal_weight: 0.5)
      result = ToolFilter.filter([], state)
      assert result == []
    end
  end

  # ---------------------------------------------------------------------------
  # filter/2 — pipeline order (weight gate -> CU focus -> budget cap)
  # ---------------------------------------------------------------------------

  describe "filter/2 — pipeline order" do
    test "weight gate fires first, preventing budget cap from running" do
      # Low weight + local provider: weight gate returns [] before budget cap
      state = base_state(provider: :ollama, signal_weight: 0.01)
      tools = all_tools()

      result = ToolFilter.filter(tools, state)
      assert result == []
    end

    test "CU focus fires before budget cap" do
      state = %{
        base_state(provider: :ollama, signal_weight: 0.5) |
        messages: [%{name: "computer_use", content: "action"}]
      }
      tools = all_tools()

      result = ToolFilter.filter(tools, state)

      # CU focus trims to 3 tools, then budget cap would trim to 10
      # Since CU focus already produces <= 10, budget cap is a no-op
      remaining_names = Enum.map(result, & &1.name)
      assert "computer_use" in remaining_names
      assert "file_read" in remaining_names
      assert "ask_user" in remaining_names
      assert length(result) <= 10
    end
  end
end
