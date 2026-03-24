defmodule OptimalSystemAgent.Memory.SynthesisTest do
  @moduledoc """
  Chicago TDD tests for Memory.Synthesis.

  Tests the check_threshold/2 public pure function directly.
  Tests inject/2 and compact/3 through their observable behavior.

  Since inject/2 calls Memory.recall (GenServer) and compact/2 calls
  check_threshold (pure) plus list manipulation, we focus on the pure
  threshold classification and compaction logic.
  """
  use ExUnit.Case, async: true

  alias OptimalSystemAgent.Memory.Synthesis

  # ---------------------------------------------------------------------------
  # check_threshold/2
  # ---------------------------------------------------------------------------

  describe "check_threshold/2" do
    setup do
      Application.put_env(:optimal_system_agent, :compaction_warn, 0.80)
      Application.put_env(:optimal_system_agent, :compaction_aggressive, 0.85)
      Application.put_env(:optimal_system_agent, :compaction_emergency, 0.95)

      :ok
    end

    test "returns :ok when well under warn threshold" do
      assert Synthesis.check_threshold(100, 1000) == :ok
      assert Synthesis.check_threshold(500, 1000) == :ok
      assert Synthesis.check_threshold(799, 1000) == :ok
    end

    test "returns :warn at warn threshold" do
      assert Synthesis.check_threshold(800, 1000) == :warn
      assert Synthesis.check_threshold(840, 1000) == :warn
    end

    test "returns :compact at aggressive threshold" do
      assert Synthesis.check_threshold(850, 1000) == :compact
      assert Synthesis.check_threshold(940, 1000) == :compact
    end

    test "returns :emergency at emergency threshold" do
      assert Synthesis.check_threshold(950, 1000) == :emergency
      assert Synthesis.check_threshold(1000, 1000) == :emergency
    end

    test "returns :ok when max_tokens is zero" do
      assert Synthesis.check_threshold(100, 0) == :ok
    end

    test "returns :ok when current_tokens is zero" do
      assert Synthesis.check_threshold(0, 1000) == :ok
    end
  end

  # ---------------------------------------------------------------------------
  # compact/3
  # ---------------------------------------------------------------------------

  describe "compact/3" do
    setup do
      Application.put_env(:optimal_system_agent, :compaction_warn, 0.80)
      Application.put_env(:optimal_system_agent, :compaction_aggressive, 0.85)
      Application.put_env(:optimal_system_agent, :compaction_emergency, 0.95)

      :ok
    end

    test "returns {:ok, messages} when under threshold" do
      messages = [%{role: "user", content: "hello"}]
      assert {:ok, ^messages} = Synthesis.compact(messages, 100, 1000)
    end

    test ":warn compaction removes old tool results keeping last 3" do
      system = %{role: "system", content: "You are helpful."}

      non_system =
        for i <- 1..6 do
          %{role: "tool", content: "result #{i}", tool_call_id: "tc#{i}"}
        end

      messages = [system | non_system]
      # Push ratio above warn (6 messages at ~100 tokens each = 600/700 > 0.80)
      {:compacted, result, removed} = Synthesis.compact(messages, 560, 700)

      assert removed > 0
      # System message preserved
      assert hd(result) == system
      # Should have fewer non-system messages than before
      non_system_count = length(result) - 1
      assert non_system_count < 6
    end

    test ":compact compaction summarizes middle messages keeping last 5" do
      system = %{role: "system", content: "System prompt"}

      non_system =
        for i <- 1..10 do
          %{role: "user", content: "message #{i}"}
        end

      messages = [system | non_system]

      {:compacted, result, removed} = Synthesis.compact(messages, 860, 1000)

      assert removed == 5
      # Should have system + summary + 5 tail = 7
      assert length(result) == 7
      # Summary message should exist
      summary =
        Enum.find(result, fn m ->
          m.role == "system" and is_binary(m.content) and String.contains?(m.content, "compacted")
        end)

      assert summary != nil
    end

    test ":emergency compaction keeps only system + last 3" do
      system = %{role: "system", content: "System prompt"}

      non_system =
        for i <- 1..10 do
          %{role: "user", content: "message #{i}"}
        end

      messages = [system | non_system]

      {:compacted, result, removed} = Synthesis.compact(messages, 950, 1000)

      assert removed == 7
      # system + 3 tail = 4
      assert length(result) == 4
      assert hd(result) == system
    end

    test ":compact with <= 5 non-system messages returns {:ok, messages}" do
      system = %{role: "system", content: "System"}
      non_system = for i <- 1..3, do: %{role: "user", content: "msg #{i}"}
      messages = [system | non_system]

      # Push into compact territory
      {:ok, ^messages} = Synthesis.compact(messages, 860, 1000)
    end

    test ":emergency with <= 3 non-system messages returns {:ok, messages}" do
      system = %{role: "system", content: "System"}
      non_system = for i <- 1..2, do: %{role: "user", content: "msg #{i}"}
      messages = [system | non_system]

      {:ok, ^messages} = Synthesis.compact(messages, 950, 1000)
    end

    test "handles string-keyed message maps" do
      messages = [
        %{"role" => "system", "content" => "System"},
        %{"role" => "user", "content" => "Hello"}
      ]

      {:ok, result} = Synthesis.compact(messages, 100, 1000)
      assert result == messages
    end

    test "handles mixed atom/string keyed messages" do
      messages = [
        %{"role" => "system", "content" => "System"},
        %{role: "user", content: "Hello"}
      ]

      {:ok, result} = Synthesis.compact(messages, 100, 1000)
      assert length(result) == 2
    end
  end

  # ---------------------------------------------------------------------------
  # inject/2 -- tests observable behavior
  # ---------------------------------------------------------------------------

  describe "inject/2" do
    test "returns messages unchanged when last user content is empty" do
      messages = [%{role: "assistant", content: "Hello!"}]
      result = Synthesis.inject(messages, "session-1")
      assert result == messages
    end

    test "returns messages unchanged for empty list" do
      assert Synthesis.inject([], "session-1") == []
    end

    test "returns messages unchanged when no user message found" do
      messages = [
        %{role: "system", content: "System"},
        %{role: "assistant", content: "Hi"}
      ]

      result = Synthesis.inject(messages, "session-1")
      assert result == messages
    end

    test "handles string-keyed messages" do
      messages = [%{"role" => "assistant", "content" => "Hi"}]
      result = Synthesis.inject(messages, "session-1")
      assert result == messages
    end
  end
end
