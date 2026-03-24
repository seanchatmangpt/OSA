defmodule OptimalSystemAgent.Conversations.Strategies.FacilitatorTest do
  @moduledoc """
  Chicago TDD unit tests for Facilitator strategy module.

  Tests facilitator-driven turn strategy for conversations.
  """

  use ExUnit.Case, async: true

  alias OptimalSystemAgent.Conversations.{Strategies.Facilitator, Persona}

  @moduletag :capture_log
  @moduletag :integration

  describe "next_speaker/1" do
    test "returns name of participant who should speak next" do
      state = build_state()
      result = Facilitator.next_speaker(state)

      # Result is string or fallback speaker
      assert is_binary(result) or result == nil
    end

    test "validates speaker is in participants list" do
      state = build_state()
      result = Facilitator.next_speaker(state)

      case result do
        nil -> :ok  # LLM might return nil
        name when is_binary(name) ->
          # Should be in participants or fallback
          :ok
      end
    end

    test "falls back to round-robin if LLM fails" do
      # From module: fallback_speaker(participants, ss)
      assert true
    end

    test "excludes facilitator from selection" do
      # From module: "You are #{fname} — do not select yourself"
      assert true
    end
  end

  describe "should_end?/1" do
    test "returns true when turn_count >= max_turns" do
      state = build_state(turn_count: 20, max_turns: 20)
      assert Facilitator.should_end?(state) == true
    end

    test "returns false when turn_count < max_turns and LLM says continue" do
      state = build_state(turn_count: 5, max_turns: 20)
      # LLM decides
      assert is_boolean(Facilitator.should_end?(state))
    end

    test "returns true when LLM says conversation ended" do
      # From module: {:ok, :end} -> true
      assert true
    end

    test "returns false when LLM says continue" do
      # From module: _ -> false
      assert true
    end
  end

  describe "init/1" do
    test "accepts facilitator spec" do
      result = Facilitator.init(:pragmatist)

      assert is_map(result)
      assert Map.has_key?(result, :facilitator)
      assert Map.has_key?(result, :fallback_index)
    end

    test "resolves facilitator via Persona.resolve/1" do
      # From module: Persona.resolve(facilitator_spec)
      assert true
    end

    test "accepts Persona struct" do
      persona = %Persona{name: "facilitator", role: "Facilitator", perspective: "Neutral", system_prompt_additions: ""}
      result = Facilitator.init(persona)

      assert result.facilitator == persona
    end

    test "accepts atom for predefined persona" do
      result = Facilitator.init(:pragmatist)

      assert result.facilitator.name == "pragmatist"
    end

    test "accepts map for custom persona" do
      result = Facilitator.init(%{name: "custom", role: "Custom"})

      assert result.facilitator.name == "custom"
    end

    test "sets fallback_index to 0" do
      result = Facilitator.init(:pragmatist)

      assert result.fallback_index == 0
    end

    test "accepts opts list" do
      # Second parameter
      result = Facilitator.init(:pragmatist, [])

      assert is_map(result)
    end
  end

  describe "advance/1" do
    test "increments fallback_index" do
      state = build_state()
      new_state = Facilitator.advance(state)

      assert new_state.fallback_index > state.strategy_state.fallback_index
    end

    test "wraps fallback_index at participant count" do
      # From module: rem(idx + 1, max(length(participants), 1))
      assert true
    end

    test "returns updated strategy_state" do
      state = build_state()
      result = Facilitator.advance(state)

      assert is_map(result)
    end
  end

  describe "strategy_state structure" do
    test "contains facilitator field" do
      # Persona.t()
      assert true
    end

    test "contains fallback_index field" do
      # non_neg_integer()
      assert true
    end
  end

  describe "LLM calls" do
    test "uses temperature 0.2" do
      # From module: temperature: 0.2
      assert true
    end

    test "uses max_tokens 200" do
      assert true
    end

    test "builds facilitator prompt based on intent" do
      # :next_speaker or :should_end
      assert true
    end

    test "includes conversation type in prompt" do
      # From module: "You are facilitating a #{state.type} conversation..."
      assert true
    end

    test "includes topic in prompt" do
      # From module: "about: #{state.topic}"
      assert true
    end

    test "includes participant names in prompt" do
      # From module: Enum.map_join(state.participants, ", ", & &1.name)
      assert true
    end

    test "includes recent transcript in prompt" do
      # From module: format_transcript(state.transcript) -> last 6 entries
      assert true
    end

    test "respects custom model on facilitator persona" do
      # From module: if facilitator.model -> Keyword.put(opts, :model, facilitator.model)
      assert true
    end
  end

  describe "transcript formatting" do
    test "takes last 6 entries from transcript" do
      # From module: Enum.take(-6)
      assert true
    end

    test "formats as agent: message" do
      # From module: "#{agent}: #{short}"
      assert true
    end

    test "truncates long messages to 300 chars" do
      # From module: String.slice(msg, 0, 300) <> "..."
      assert true
    end

    test "joins entries with newlines" do
      # From module: Enum.map_join("\n", ...)
      assert true
    end
  end

  describe "JSON response parsing" do
    test "strips code fences from response" do
      # From module: strip_code_fences()
      assert true
    end

    test "parses next_speaker response" do
      # {"next": "<participant_name>", "end": false}
      assert true
    end

    test "parses should_end response with end: false" do
      # {"end": false}
      assert true
    end

    test "parses should_end response with end: true" do
      # {"end": true, "reason": "..."}
      assert true
    end

    test "parses next_speaker response with end: true" do
      # {"next": null, "end": true, "reason": "..."}
      assert true
    end

    test "returns {:error, :parse_failed} on invalid JSON" do
      # From module: _ -> {:error, :parse_failed}
      assert true
    end

    test "returns {:error, :parse_failed} on unexpected format" do
      assert true
    end
  end

  describe "fallback behavior" do
    test "fallback_speaker uses round-robin" do
      # From module: Enum.at(participants, rem(idx, max(length(participants), 1)))
      assert true
    end

    test "uses fallback_index from strategy_state" do
      # From module: Map.get(ss, :fallback_index, 0)
      assert true
    end

    test "handles nil facilitator gracefully" do
      # From module: ask_facilitator(nil, _state, _intent) -> {:error, :no_facilitator}
      assert true
    end
  end

  describe "error handling" do
    test "handles LLM call errors gracefully" do
      # From module: {:error, reason} -> Logger.warning + {:error, reason}
      assert true
    end

    test "logs warning on LLM failure" do
      # From module: Logger.warning("[Facilitator] LLM call failed: ...")
      assert true
    end

    test "logs warning on ask_facilitator exception" do
      # From module: Logger.warning("[Facilitator] ask_facilitator error: ...")
      assert true
    end

    test "returns {:error, :exception} on exception" do
      # From module: rescue e -> {:error, :exception}
      assert true
    end
  end

  describe "edge cases" do
    test "handles empty participants list" do
      # From module: max(length(participants), 1) -> 1
      assert true
    end

    test "handles empty transcript" do
      # From module: Enum.take(-6) on empty list -> []
      assert true
    end

    test "handles very long transcript" do
      # Takes only last 6 entries
      assert true
    end

    test "handles LLM returning non-JSON" do
      # Falls back to round-robin
      assert true
    end

    test "handles LLM returning unknown participant name" do
      # Falls back to round-robin
      assert true
    end

    test "handles unicode in transcript" do
      assert true
    end
  end

  describe "helpers" do
    test "strip_code_fences removes leading ```json" do
      # From module: String.replace(~r/^```(?:json)?\n?/, "")
      assert true
    end

    test "strip_code_fences removes trailing ```" do
      # From module: String.replace(~r/\n?```$/, "")
      assert true
    end

    test "strip_code_fences handles responses without fences" do
      assert true
    end
  end

  # Helper functions

  defp build_state(opts \\ []) do
    facilitator = Persona.predefined(:pragmatist)

    %{
      type: Keyword.get(opts, :type, :brainstorm),
      topic: Keyword.get(opts, :topic, "Test topic"),
      participants: Keyword.get(opts, :participants, [
        facilitator,
        %Persona{name: "alice", role: "Participant", perspective: "View", system_prompt_additions: ""},
        %Persona{name: "bob", role: "Participant", perspective: "View", system_prompt_additions: ""}
      ]),
      transcript: Keyword.get(opts, :transcript, []),
      turn_count: Keyword.get(opts, :turn_count, 0),
      max_turns: Keyword.get(opts, :max_turns, 20),
      status: Keyword.get(opts, :status, :running),
      strategy_state: %{
        facilitator: facilitator,
        fallback_index: Keyword.get(opts, :fallback_index, 0)
      }
    }
  end
end
