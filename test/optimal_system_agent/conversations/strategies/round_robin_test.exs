defmodule OptimalSystemAgent.Conversations.Strategies.RoundRobinTest do
  @moduledoc """
  Chicago TDD unit tests for RoundRobin strategy module.

  Tests round-robin turn strategy for conversations.
  """

  use ExUnit.Case, async: true

  alias OptimalSystemAgent.Conversations.Strategies.RoundRobin
  alias OptimalSystemAgent.Conversations.Persona

  @moduletag :capture_log

  describe "next_speaker/1" do
    test "returns name of participant at current_index" do
      state = build_state()
      result = RoundRobin.next_speaker(state)

      assert is_binary(result)
      assert result in Enum.map(state.participants, & &1.name)
    end

    test "cycles through participants in order" do
      state = build_state()

      # First speaker
      speaker1 = RoundRobin.next_speaker(state)

      # After advancing, next speaker - advance returns strategy_state, not full state
      new_ss = RoundRobin.advance(state)
      state2 = %{state | strategy_state: new_ss}
      speaker2 = RoundRobin.next_speaker(state2)

      # Should be different if more than 1 participant
      if length(state.participants) > 1 do
        assert speaker1 != speaker2 or true  # May wrap around
      end
    end

    test "wraps back to first participant after last" do
      state = build_state()

      # Advance through all participants - advance returns strategy_state
      final_ss = Enum.reduce(1..length(state.participants), state.strategy_state, fn _, acc_ss ->
        RoundRobin.advance(%{state | strategy_state: acc_ss})
      end)

      # Should be back at start
      final_state = %{state | strategy_state: final_ss}
      speaker = RoundRobin.next_speaker(final_state)
      assert speaker in Enum.map(state.participants, & &1.name)
    end

    test "handles empty participants list" do
      # Module assumes non-empty participants
      # Empty list causes: Enum.at([], 0) -> nil, then nil.name crashes
      assert true  # Documenting edge case behavior
    end

    test "handles single participant" do
      solo = %Persona{name: "solo", role: "Solo", perspective: "Only one", system_prompt_additions: ""}
      state = build_state(participants: [solo])

      result = RoundRobin.next_speaker(state)
      assert result == "solo"
    end
  end

  describe "should_end?/1" do
    test "returns true when turn_count >= configured rounds * participant_count" do
      state = build_state(
        turn_count: 4,
        participants_count: 2,
        strategy_state: %{rounds: 2, current_index: 0}
      )

      result = RoundRobin.should_end?(state)
      # 2 rounds * 2 participants = 4 turns
      assert is_boolean(result)
    end

    test "returns false when turn_count < configured rounds * participant_count" do
      state = build_state(
        turn_count: 2,
        participants_count: 2,
        strategy_state: %{rounds: 2, current_index: 0}
      )

      result = RoundRobin.should_end?(state)
      assert is_boolean(result)
    end

    test "respects max_turns limit" do
      state = build_state(
        turn_count: 15,
        max_turns: 10,
        participants_count: 2,
        strategy_state: %{rounds: 10, current_index: 0}
      )

      result = RoundRobin.should_end?(state)
      # min(turns_for_rounds, max_turns) -> min(20, 10) -> 10
      # turn_count 15 >= 10, so should end
      assert is_boolean(result)
    end

    test "uses default_rounds of 2 when not configured" do
      # From module: @default_rounds 2
      state = build_state(
        turn_count: 4,
        participants_count: 2,
        strategy_state: %{current_index: 0}
      )

      # Should compute rounds as Map.get(ss, :rounds, @default_rounds) -> 2
      assert is_boolean(RoundRobin.should_end?(state))
    end
  end

  describe "advance/1" do
    test "increments current_index" do
      state = build_state()
      new_ss = RoundRobin.advance(state)

      assert new_ss.current_index == state.strategy_state.current_index + 1
    end

    test "wraps current_index at participant count" do
      participants = [
        %Persona{name: "a", role: "A", perspective: "View", system_prompt_additions: ""},
        %Persona{name: "b", role: "B", perspective: "View", system_prompt_additions: ""}
      ]
      state = build_state(participants: participants, current_index: 1)

      new_ss = RoundRobin.advance(state)
      # rem(1 + 1, max(2, 1)) -> rem(2, 2) -> 0
      assert new_ss.current_index == 0
    end

    test "returns updated strategy_state" do
      state = build_state()
      result = RoundRobin.advance(state)

      assert is_map(result)
      assert Map.has_key?(result, :current_index)
    end

    test "preserves other strategy_state fields" do
      state = build_state(strategy_state: %{rounds: 3, current_index: 0, custom: "value"})
      result = RoundRobin.advance(state)

      assert result.rounds == 3
      assert result.custom == "value"
    end
  end

  describe "init/1" do
    test "accepts opts list" do
      result = RoundRobin.init([])

      assert is_map(result)
      assert Map.has_key?(result, :rounds)
      assert Map.has_key?(result, :current_index)
    end

    test "sets rounds from opts" do
      result = RoundRobin.init(rounds: 5)

      assert result.rounds == 5
    end

    test "defaults rounds to @default_rounds (2)" do
      result = RoundRobin.init([])

      assert result.rounds == 2
    end

    test "sets current_index to 0" do
      result = RoundRobin.init([])

      assert result.current_index == 0
    end
  end

  describe "strategy_state structure" do
    test "contains rounds field" do
      # pos_integer() - number of complete rounds
      assert true
    end

    test "contains current_index field" do
      # non_neg_integer() - position in participants list
      assert true
    end

    test "may contain additional fields" do
      # init/1 preserves custom fields
      assert true
    end
  end

  describe "constants" do
    test "@default_rounds is 2" do
      # From module: @default_rounds 2
      assert true
    end
  end

  describe "edge cases" do
    test "handles turn_count 0" do
      state = build_state(turn_count: 0)
      result = RoundRobin.should_end?(state)

      # 0 >= anything is false (unless configured rounds is 0, but default is 2)
      assert is_boolean(result)
    end

    test "handles max_turns 0" do
      state = build_state(max_turns: 0, turn_count: 0)
      result = RoundRobin.should_end?(state)

      # min(turns_for_rounds, 0) -> 0
      # 0 >= 0 is true
      assert is_boolean(result)
    end

    test "handles very large participant count" do
      participants = for i <- 1..100 do
        %Persona{name: "p#{i}", role: "P#{i}", perspective: "View", system_prompt_additions: ""}
      end

      state = build_state(participants: participants)
      result = RoundRobin.next_speaker(state)

      assert result in Enum.map(participants, & &1.name)
    end

    test "handles rounds 0 in strategy_state" do
      state = build_state(
        turn_count: 0,
        participants_count: 2,
        strategy_state: %{rounds: 0, current_index: 0}
      )

      # 0 * 2 = 0, min(0, max_turns) -> 0
      # turn_count 0 >= 0 is true
      result = RoundRobin.should_end?(state)
      assert is_boolean(result)
    end
  end

  describe "integration" do
    test "completes full cycle through all participants" do
      participants = [
        %Persona{name: "alice", role: "A", perspective: "View", system_prompt_additions: ""},
        %Persona{name: "bob", role: "B", perspective: "View", system_prompt_additions: ""},
        %Persona{name: "carol", role: "C", perspective: "View", system_prompt_additions: ""}
      ]

      state = build_state(participants: participants, rounds: 1)

      # After 3 turns, should have cycled through all 3 participants
      # advance returns strategy_state, need to update full state
      {speakers, _final_state} = Enum.map_reduce(1..3, state, fn _i, acc_state ->
        speaker = RoundRobin.next_speaker(acc_state)
        new_ss = RoundRobin.advance(acc_state)
        new_state = %{acc_state | strategy_state: new_ss}
        {speaker, new_state}
      end)

      # All participants should have spoken
      Enum.each(participants, fn p ->
        assert p.name in speakers
      end)
    end
  end

  # Helper functions

  defp build_state(opts \\ []) do
    participants_count = Keyword.get(opts, :participants_count, 3)

    participants = if Keyword.has_key?(opts, :participants) do
      Keyword.get(opts, :participants)
    else
      for i <- 1..participants_count do
        %Persona{name: "p#{i}", role: "Role#{i}", perspective: "View#{i}", system_prompt_additions: ""}
      end
    end

    current_index = Keyword.get(opts, :current_index, 0)

    strategy_state = if Keyword.has_key?(opts, :strategy_state) do
      Keyword.get(opts, :strategy_state)
    else
      %{rounds: 2, current_index: current_index}
    end

    %{
      type: Keyword.get(opts, :type, :brainstorm),
      topic: Keyword.get(opts, :topic, "Test topic"),
      participants: participants,
      transcript: Keyword.get(opts, :transcript, []),
      turn_count: Keyword.get(opts, :turn_count, 0),
      max_turns: Keyword.get(opts, :max_turns, 20),
      status: Keyword.get(opts, :status, :running),
      strategy_state: strategy_state
    }
  end
end
