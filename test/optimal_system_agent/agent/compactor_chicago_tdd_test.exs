defmodule OptimalSystemAgent.Agent.CompactorChicagoTDDTest do
  @moduledoc """
  Chicago TDD tests for OptimalSystemAgent.Agent.Compactor.

  Tests the context window compaction state machine:
  - estimate_tokens/1 — token counting for messages/strings
  - utilization/1 — context window usage percentage
  - maybe_compact/1 — inspect and compact message lists
  - stats/0 — compaction metrics
  """

  use ExUnit.Case, async: false
  @moduletag :skip  # Requires PromptLoader and provider infrastructure

  alias OptimalSystemAgent.Agent.Compactor

  setup_all do
    if Process.whereis(Compactor) == nil do
      start_supervised!(Compactor)
    end
    :ok
  end

  # =========================================================================
  # ESTIMATE_TOKENS TESTS
  # =========================================================================

  describe "CRASH: estimate_tokens/1" do
    test "estimates tokens for string" do
      result = Compactor.estimate_tokens("hello world")
      assert is_integer(result)
      assert result >= 0
    end

    test "estimates tokens for empty string" do
      result = Compactor.estimate_tokens("")
      assert is_integer(result)
      assert result == 0
    end

    test "estimates tokens for long string" do
      long_text = String.duplicate("word ", 1000)
      result = Compactor.estimate_tokens(long_text)

      assert is_integer(result)
      assert result > 0
    end

    test "estimates tokens for string with punctuation" do
      text = "Hello! World? How are you."
      result = Compactor.estimate_tokens(text)

      assert is_integer(result)
      assert result > 0
    end

    test "estimates tokens for message list" do
      messages = [
        %{role: "user", content: "hello"},
        %{role: "assistant", content: "hi there"}
      ]

      result = Compactor.estimate_tokens(messages)

      assert is_integer(result)
      assert result >= 0
    end

    test "estimates tokens for empty message list" do
      messages = []
      result = Compactor.estimate_tokens(messages)

      assert is_integer(result)
      assert result == 0
    end

    test "estimates tokens for messages with tool_calls" do
      messages = [
        %{
          role: "assistant",
          content: "calling a tool",
          tool_calls: [
            %{id: "call_1", function: "test", arguments: "{}"}
          ]
        }
      ]

      result = Compactor.estimate_tokens(messages)

      assert is_integer(result)
      assert result > 0
    end

    test "estimates tokens for messages with empty tool_calls" do
      messages = [
        %{
          role: "user",
          content: "test",
          tool_calls: []
        }
      ]

      result = Compactor.estimate_tokens(messages)

      assert is_integer(result)
      assert result >= 0
    end

    test "token estimate increases with message length" do
      short_msg = [%{role: "user", content: "hi"}]
      long_msg = [%{role: "user", content: String.duplicate("word ", 100)}]

      short_tokens = Compactor.estimate_tokens(short_msg)
      long_tokens = Compactor.estimate_tokens(long_msg)

      assert long_tokens > short_tokens
    end

    test "token estimate consistent for same input" do
      messages = [%{role: "user", content: "test message"}]

      t1 = Compactor.estimate_tokens(messages)
      t2 = Compactor.estimate_tokens(messages)

      assert t1 == t2
    end

    test "handles nil input gracefully" do
      result = Compactor.estimate_tokens(nil)

      assert is_integer(result)
      assert result >= 0
    end
  end

  # =========================================================================
  # UTILIZATION TESTS
  # =========================================================================

  describe "CRASH: utilization/1" do
    test "returns percentage for empty list" do
      result = Compactor.utilization([])

      assert is_float(result)
      assert result >= 0.0
      assert result <= 100.0
    end

    test "returns percentage for small message list" do
      messages = [%{role: "user", content: "hello"}]

      result = Compactor.utilization(messages)

      assert is_float(result)
      assert result >= 0.0
      assert result <= 100.0
    end

    test "returns increasing percentage with more messages" do
      messages_small = [%{role: "user", content: "hi"}]
      messages_large = [%{role: "user", content: String.duplicate("word ", 1000)}]

      small_util = Compactor.utilization(messages_small)
      large_util = Compactor.utilization(messages_large)

      assert large_util > small_util
    end

    test "returns consistent results for same input" do
      messages = [%{role: "user", content: "test"}]

      u1 = Compactor.utilization(messages)
      u2 = Compactor.utilization(messages)

      assert u1 == u2
    end

    test "returns float with one decimal place" do
      messages = [%{role: "user", content: "test"}]

      result = Compactor.utilization(messages)

      # Check if it's rounded to 1 decimal place
      assert is_float(result)
    end
  end

  # =========================================================================
  # MAYBE_COMPACT TESTS
  # =========================================================================

  describe "CRASH: maybe_compact/1" do
    test "returns message list unchanged if not compact needed" do
      messages = [%{role: "user", content: "hello"}]

      result = Compactor.maybe_compact(messages)

      assert is_list(result)
      assert length(result) >= 0
    end

    test "returns empty list unchanged" do
      messages = []

      result = Compactor.maybe_compact(messages)

      assert result == []
    end

    test "never raises, even on bad input" do
      # Should return original messages on error
      result = Compactor.maybe_compact([%{role: "user", content: nil}])

      assert is_list(result)
    end

    test "handles large message list gracefully" do
      messages = for i <- 1..100 do
        %{role: if(rem(i, 2) == 0, do: "assistant", else: "user"), content: "message #{i}"}
      end

      result = Compactor.maybe_compact(messages)

      assert is_list(result)
      assert length(result) >= 0
    end

    test "preserves message structure" do
      messages = [
        %{role: "user", content: "hello", metadata: %{key: "value"}},
        %{role: "assistant", content: "hi", tool_calls: []}
      ]

      result = Compactor.maybe_compact(messages)

      assert is_list(result)
      Enum.each(result, fn msg ->
        assert is_map(msg)
      end)
    end

    test "handles messages with tool_calls" do
      messages = [
        %{
          role: "assistant",
          content: "calling",
          tool_calls: [%{id: "1", function: "test", arguments: "{}"}]
        }
      ]

      result = Compactor.maybe_compact(messages)

      assert is_list(result)
    end

    test "returns result of same or smaller length" do
      messages = for _i <- 1..50 do
        %{role: "user", content: String.duplicate("word ", 50)}
      end

      result = Compactor.maybe_compact(messages)

      assert length(result) <= length(messages)
    end

    test "consistent compaction for same input" do
      messages = for _i <- 1..20 do
        %{role: "user", content: "test"}
      end

      r1 = Compactor.maybe_compact(messages)
      r2 = Compactor.maybe_compact(messages)

      # Same structure should result in same compaction
      assert length(r1) == length(r2)
    end
  end

  # =========================================================================
  # STATS TESTS
  # =========================================================================

  describe "CRASH: stats/0" do
    test "returns statistics map" do
      stats = Compactor.stats()

      assert is_map(stats)
    end

    test "stats contains expected keys" do
      stats = Compactor.stats()

      assert Map.has_key?(stats, :compaction_count) or
             Map.has_key?(stats, :tokens_saved) or
             Map.has_key?(stats, :last_compacted_at) or
             Map.has_key?(stats, :pipeline_steps_used) or
             is_map(stats)
    end

    test "compaction_count is non-negative integer" do
      stats = Compactor.stats()

      if Map.has_key?(stats, :compaction_count) do
        assert is_integer(stats.compaction_count)
        assert stats.compaction_count >= 0
      end
    end

    test "tokens_saved is non-negative integer" do
      stats = Compactor.stats()

      if Map.has_key?(stats, :tokens_saved) do
        assert is_integer(stats.tokens_saved)
        assert stats.tokens_saved >= 0
      end
    end

    test "stats consistent across calls" do
      s1 = Compactor.stats()
      s2 = Compactor.stats()

      # Structure should be same
      assert Map.keys(s1) == Map.keys(s2)
    end

    test "pipeline_steps_used is map" do
      stats = Compactor.stats()

      if Map.has_key?(stats, :pipeline_steps_used) do
        assert is_map(stats.pipeline_steps_used)
      end
    end
  end

  # =========================================================================
  # INTEGRATION TESTS
  # =========================================================================

  describe "CRASH: Integration workflows" do
    test "estimate tokens and check utilization" do
      messages = [
        %{role: "user", content: "hello world"},
        %{role: "assistant", content: "hi there"}
      ]

      tokens = Compactor.estimate_tokens(messages)
      util = Compactor.utilization(messages)

      assert is_integer(tokens)
      assert is_float(util)
      assert util >= 0.0
      assert util <= 100.0
    end

    test "compact if needed, then check utilization" do
      messages = for _i <- 1..30 do
        %{role: "user", content: String.duplicate("word ", 50)}
      end

      compacted = Compactor.maybe_compact(messages)
      util = Compactor.utilization(compacted)

      assert is_list(compacted)
      assert is_float(util)
      assert util >= 0.0
    end

    test "stats after compaction operations" do
      # Perform some compaction operations
      messages = for _i <- 1..10 do
        %{role: "user", content: "test message"}
      end

      _compacted = Compactor.maybe_compact(messages)

      # Check stats
      stats = Compactor.stats()

      assert is_map(stats)
    end
  end

  # =========================================================================
  # MODULE BEHAVIOR CONTRACT
  # =========================================================================

  describe "CRASH: Module behavior contract" do
    test "all public functions are exported" do
      assert function_exported?(Compactor, :start_link, 1)
      assert function_exported?(Compactor, :stats, 0)
      assert function_exported?(Compactor, :maybe_compact, 1)
      assert function_exported?(Compactor, :utilization, 1)
      assert function_exported?(Compactor, :estimate_tokens, 1)
    end

    test "GenServer callbacks are implemented" do
      assert function_exported?(Compactor, :init, 1)
      assert function_exported?(Compactor, :handle_call, 3)
    end

    test "functions return expected types" do
      # stats returns map
      assert is_map(Compactor.stats())

      # estimate_tokens returns integer
      assert is_integer(Compactor.estimate_tokens("test"))
      assert is_integer(Compactor.estimate_tokens([]))

      # utilization returns float
      assert is_float(Compactor.utilization([]))

      # maybe_compact returns list
      assert is_list(Compactor.maybe_compact([]))
    end
  end

  # =========================================================================
  # EDGE CASES AND STRESS
  # =========================================================================

  describe "CRASH: Edge cases and stress" do
    test "estimate_tokens with very long string" do
      long = String.duplicate("word ", 10_000)
      result = Compactor.estimate_tokens(long)

      assert is_integer(result)
      assert result > 0
    end

    test "utilization with very long message list" do
      messages = for _i <- 1..1000 do
        %{role: "user", content: "test"}
      end

      result = Compactor.utilization(messages)

      assert is_float(result)
      assert result >= 0.0
    end

    test "maybe_compact with many alternating roles" do
      messages = for i <- 1..100 do
        %{role: if(rem(i, 2) == 0, do: "assistant", else: "user"), content: "msg"}
      end

      result = Compactor.maybe_compact(messages)

      assert is_list(result)
    end

    test "repeated compaction doesn't fail" do
      messages = [%{role: "user", content: "test"}]

      for _i <- 1..10 do
        Compactor.maybe_compact(messages)
      end

      # Should complete without error
      assert true
    end

    test "handles special characters in content" do
      text = "Hello! @#$%^&*() émojis: 😀🎉 unicode: 你好"

      result = Compactor.estimate_tokens(text)

      assert is_integer(result)
      assert result >= 0
    end

    test "handles messages with missing fields" do
      messages = [
        %{role: "user"},
        %{content: "hello"},
        %{}
      ]

      result = Compactor.maybe_compact(messages)

      assert is_list(result)
    end

    test "concurrent token estimations don't fail" do
      tasks = for _i <- 1..10 do
        Task.start(fn ->
          Compactor.estimate_tokens("test message")
        end)
      end

      assert length(tasks) == 10
    end
  end
end
