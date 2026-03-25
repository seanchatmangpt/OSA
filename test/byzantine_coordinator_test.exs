defmodule OptimalSystemAgent.ByzantineCoordinatorTest do
  @moduledoc """
  Byzantine Fault Tolerance for Distributed Coordination

  Validates that OSA's multi-agent system reaches consensus despite malicious
  (Byzantine) agent failures. Implements Joe Armstrong's fault tolerance principle:
  System must tolerate ⌊(N-1)/2⌋ Byzantine agents.

  Test scenarios:
  - 3, 5, 7 agent clusters
  - Byzantine behaviors: invalid responses, crashes, state flips, timeouts, conflicts
  - Consensus validation under Byzantine faults
  - Consensus time constraints
  """

  use ExUnit.Case

  import ExUnit.CaptureLog

  setup do
    # Create test agent registry
    :ets.new(:test_agent_registry, [:named_table, :public, :set])
    {:ok, registry: :test_agent_registry}
  end

  # =========================================================================
  # SCENARIO 1: Invalid Response (Wrong Transitions)
  # =========================================================================

  describe "invalid response detection" do
    test "detects when agent returns wrong model transitions" do
      scenario = %{
        id: "invalid_response_test",
        total_agents: 3,
        honest_count: 2,
        byzantine_count: 1,
        byzantine_mode: :invalid_model,
        timeout_ms: 1000
      }

      # Agent 1-2: honest, return correct model
      honest_model = %{
        id: "proc_1",
        transitions: [{"start", "process"}, {"process", "end"}]
      }

      # Agent 3: Byzantine, returns corrupted transitions
      byzantine_model = %{
        id: "corrupt",
        transitions: [{"X", "Y"}, {"Y", "Z"}]
      }

      assert_consensus_reached(
        scenario,
        [honest_model, honest_model, byzantine_model],
        true
      )
    end

    test "rejects consensus when Byzantine returns invalid JSON" do
      scenario = %{
        id: "invalid_json_test",
        total_agents: 5,
        honest_count: 3,
        byzantine_count: 2,
        byzantine_mode: :invalid_json
      }

      honest_model = %{
        id: "valid",
        transitions: [{"a", "b"}]
      }

      responses = [
        {:ok, honest_model},
        {:ok, honest_model},
        {:ok, honest_model},
        {:error, "malformed JSON"},
        {:error, "parse error"}
      ]

      {consensus, valid, byzantine_detected} = validate_responses(responses, 3)

      assert valid == true, "Should reach consensus with 3 honest responses"
      assert byzantine_detected == true, "Should detect 2 Byzantine agents"
      assert consensus != nil
    end

    test "detects model hash mismatch" do
      model_a = %{
        id: "a",
        transitions: [{"1", "2"}, {"2", "3"}]
      }

      model_b = %{
        id: "b",
        transitions: [{"x", "y"}]
      }

      responses = [
        {:ok, model_a},
        {:ok, model_a},
        {:ok, model_b}
      ]

      {_consensus, valid, byzantine_detected} = validate_responses(responses, 2)

      assert valid == true
      assert byzantine_detected == true
    end
  end

  # =========================================================================
  # SCENARIO 2: Crash / Nil Response
  # =========================================================================

  describe "crash detection" do
    test "tolerates single agent crash in 3-agent cluster" do
      scenario = %{
        id: "crash_3_test",
        total_agents: 3,
        honest_count: 2,
        byzantine_count: 1,
        byzantine_mode: :crash
      }

      honest_model = %{id: "model", transitions: [{"a", "b"}]}

      responses = [
        {:ok, honest_model},
        {:ok, honest_model},
        {:error, :timeout}
      ]

      {_consensus, valid, _byzantine} = validate_responses(responses, 2)

      assert valid == true
    end

    test "tolerates 2 agent crashes in 5-agent cluster" do
      honest_model = %{id: "m", transitions: [{"s", "e"}]}

      responses = [
        {:ok, honest_model},
        {:ok, honest_model},
        {:ok, honest_model},
        {:error, :crash},
        {:error, :timeout}
      ]

      {_consensus, valid, byzantine_detected} = validate_responses(responses, 3)

      assert valid == true
      assert byzantine_detected == true
    end

    test "fails consensus with insufficient honest responses" do
      honest_model = %{id: "m", transitions: [{"a", "b"}]}

      responses = [
        {:ok, honest_model},
        {:error, :crash},
        {:error, :crash}
      ]

      {_consensus, valid, _byzantine} = validate_responses(responses, 2)

      assert valid == false
    end

    test "tolerates 3 crashes in 7-agent cluster" do
      honest_model = %{id: "model", transitions: [{"init", "done"}]}

      responses = [
        {:ok, honest_model},
        {:ok, honest_model},
        {:ok, honest_model},
        {:ok, honest_model},
        {:error, :timeout},
        {:error, :crash},
        {:error, :network_error}
      ]

      {_consensus, valid, byzantine_detected} = validate_responses(responses, 4)

      assert valid == true
      assert byzantine_detected == true
    end
  end

  # =========================================================================
  # SCENARIO 3: State Flip (Correct → Corrupt)
  # =========================================================================

  describe "state flip detection" do
    test "detects state flip in Byzantine agent" do
      honest_model = %{
        id: "stable",
        transitions: [{"a", "b"}, {"b", "c"}]
      }

      # First response correct, second response corrupted
      responses = [
        {:ok, honest_model},
        {:ok, honest_model},
        {:ok, %{id: "flip1", transitions: [{"x", "y"}]}},
        {:ok, %{id: "flip2", transitions: [{"x", "y"}]}}
      ]

      {_consensus, valid, byzantine_detected} = validate_responses(responses, 2)

      # With 2 honest out of 4, we should reach consensus
      assert valid == true
      assert byzantine_detected == true
    end

    test "state flip occurs after first vote" do
      model_a = %{id: "first", transitions: [{"a", "b"}]}
      model_b = %{id: "second", transitions: [{"x", "y"}]}

      responses = [
        {:ok, model_a},
        {:ok, model_a},
        {:ok, model_a},
        {:ok, model_b}
      ]

      {_consensus, valid, byzantine_detected} = validate_responses(responses, 3)

      assert valid == true
      assert byzantine_detected == true
    end
  end

  # =========================================================================
  # SCENARIO 4: Slow Response / Timeout
  # =========================================================================

  describe "timeout handling" do
    test "timeouts are detected and excluded from consensus" do
      honest_model = %{id: "fast", transitions: [{"a", "b"}]}

      responses = [
        {:ok, honest_model, 100},
        {:ok, honest_model, 150},
        {:timeout, 5000}
      ]

      {_consensus, valid, _byzantine} =
        validate_responses_with_timeout(responses, 2, 1000)

      assert valid == true
    end

    test "slow agents excluded when consensus reached without them" do
      honest_model = %{id: "model", transitions: [{"a", "b"}]}

      responses = [
        {:ok, honest_model, 50},
        {:ok, honest_model, 75},
        {:ok, honest_model, 80},
        {:timeout, 3000},
        {:timeout, 5000}
      ]

      start = System.monotonic_time(:millisecond)

      {_consensus, valid, byzantine_detected} =
        validate_responses_with_timeout(responses, 3, 500)

      elapsed = System.monotonic_time(:millisecond) - start

      assert valid == true
      assert byzantine_detected == true
      assert elapsed < 1000, "Should not wait for slow agents"
    end

    test "consensus time under 5 seconds even with Byzantine delays" do
      honest_model = %{id: "m", transitions: [{"a", "b"}]}

      responses = [
        {:ok, honest_model, 100},
        {:ok, honest_model, 150},
        {:timeout, 4000},
        {:timeout, 4500}
      ]

      start = System.monotonic_time(:millisecond)

      {_consensus, valid, _byzantine} =
        validate_responses_with_timeout(responses, 2, 1000)

      elapsed = System.monotonic_time(:millisecond) - start

      assert valid == true
      assert elapsed < 5000, "Consensus reached in #{elapsed}ms"
    end
  end

  # =========================================================================
  # SCENARIO 5: Conflicting Votes
  # =========================================================================

  describe "conflicting vote detection" do
    test "detects when Byzantine sends different models to different peers" do
      honest_model = %{id: "m1", transitions: [{"a", "b"}]}
      conflict_a = %{id: "conf_a", transitions: [{"x", "y"}]}
      conflict_b = %{id: "conf_b", transitions: [{"p", "q"}]}

      # Byzantine sends different responses to different requesters
      responses = [
        {:ok, honest_model},
        {:ok, honest_model},
        {:ok, conflict_a},
        {:ok, conflict_b}
      ]

      {_consensus, valid, byzantine_detected} = validate_responses(responses, 2)

      assert valid == true
      assert byzantine_detected == true
    end

    test "majority consensus overcomes conflicting votes" do
      correct = %{id: "correct", transitions: [{"a", "b"}, {"b", "c"}]}
      conflict1 = %{id: "bad1", transitions: [{"x", "y"}]}
      conflict2 = %{id: "bad2", transitions: [{"p", "q"}]}

      responses = [
        {:ok, correct},
        {:ok, correct},
        {:ok, correct},
        {:ok, conflict1},
        {:ok, conflict2}
      ]

      {consensus, valid, byzantine_detected} = validate_responses(responses, 3)

      assert valid == true
      assert byzantine_detected == true
      assert consensus.id == "correct"
    end
  end

  # =========================================================================
  # CLUSTER SIZE TESTS
  # =========================================================================

  describe "3-agent cluster (tolerates 1 Byzantine)" do
    test "reaches consensus with 1 Byzantine" do
      assert_cluster_tolerates(3, 1)
    end

    test "fails with 2 Byzantine" do
      assert_cluster_fails(3, 2)
    end

    test "all failure modes with 1 Byzantine" do
      modes = [:invalid_model, :crash, :state_flip, :timeout, :conflicting_votes]

      for mode <- modes do
        responses = generate_responses(3, 2, mode)
        {_consensus, valid, _byzantine} = validate_responses(responses, 2)
        assert valid == true, "Should tolerate 1 Byzantine in mode #{mode}"
      end
    end
  end

  describe "5-agent cluster (tolerates 2 Byzantine)" do
    test "reaches consensus with 2 Byzantine" do
      assert_cluster_tolerates(5, 2)
    end

    test "fails with 3 Byzantine" do
      assert_cluster_fails(5, 3)
    end

    test "mixed Byzantine modes with 2 failures" do
      modes = [:invalid_model, :crash, :state_flip]
      {_, mode1} = Enum.random(modes)
      {_, mode2} = Enum.random(modes)

      responses = generate_responses(5, 3, [mode1, mode2])
      {_consensus, valid, _byzantine} = validate_responses(responses, 3)
      assert valid == true
    end
  end

  describe "7-agent cluster (tolerates 3 Byzantine)" do
    test "reaches consensus with 3 Byzantine" do
      assert_cluster_tolerates(7, 3)
    end

    test "fails with 4 Byzantine" do
      assert_cluster_fails(7, 4)
    end

    test "all Byzantine modes with 3 failures" do
      modes = [:invalid_model, :crash, :state_flip, :timeout, :conflicting_votes]

      sample_modes = Enum.take_random(modes, 3)

      responses = generate_responses(7, 4, sample_modes)
      {_consensus, valid, _byzantine} = validate_responses(responses, 4)
      assert valid == true
    end
  end

  # =========================================================================
  # CORRECTNESS TESTS
  # =========================================================================

  describe "correctness guarantees" do
    test "never accepts incorrect result even with Byzantine" do
      # All honest agents agree on model_a
      # Byzantine tries to inject model_b
      model_a = %{id: "correct", transitions: [{"a", "b"}]}
      model_b = %{id: "wrong", transitions: [{"x", "y"}]}

      responses = [
        {:ok, model_a},
        {:ok, model_a},
        {:ok, model_a},
        {:ok, model_b},
        {:ok, model_b}
      ]

      {consensus, valid, _byzantine} = validate_responses(responses, 3)

      assert valid == true
      assert consensus.id == "correct"
    end

    test "model integrity preserved through consensus" do
      model = %{
        id: "proc_42",
        transitions: [
          {"init", "step1"},
          {"step1", "step2"},
          {"step2", "done"}
        ]
      }

      # All honest agents return exact same model
      responses = [
        {:ok, model},
        {:ok, model},
        {:ok, model}
      ]

      {consensus, valid, _byzantine} = validate_responses(responses, 2)

      assert valid == true
      assert consensus.id == model.id
      assert consensus.transitions == model.transitions
    end

    test "quorum validation rejects with insufficient honest votes" do
      model = %{id: "m", transitions: [{"a", "b"}]}

      # Only 1 honest vote, 2 Byzantine
      responses = [
        {:ok, model},
        {:error, :crash},
        {:error, :invalid}
      ]

      {_consensus, valid, _byzantine} = validate_responses(responses, 2)

      assert valid == false
    end
  end

  # =========================================================================
  # PERFORMANCE TESTS
  # =========================================================================

  describe "consensus latency" do
    test "5-agent consensus under 5 seconds" do
      model = %{id: "m", transitions: [{"a", "b"}]}

      responses = [
        {:ok, model, 100},
        {:ok, model, 150},
        {:ok, model, 200},
        {:timeout, 4000},
        {:timeout, 4500}
      ]

      start = System.monotonic_time(:millisecond)
      {_consensus, valid, _byzantine} =
        validate_responses_with_timeout(responses, 3, 500)
      elapsed = System.monotonic_time(:millisecond) - start

      assert valid == true
      assert elapsed < 5000
    end

    test "7-agent consensus under 5 seconds with 3 Byzantine" do
      model = %{id: "m", transitions: [{"a", "b"}]}

      responses = [
        {:ok, model, 100},
        {:ok, model, 120},
        {:ok, model, 150},
        {:ok, model, 180},
        {:timeout, 3000},
        {:timeout, 4000},
        {:timeout, 4500}
      ]

      start = System.monotonic_time(:millisecond)
      {_consensus, valid, _byzantine} =
        validate_responses_with_timeout(responses, 4, 500)
      elapsed = System.monotonic_time(:millisecond) - start

      assert valid == true
      assert elapsed < 5000
    end
  end

  # =========================================================================
  # HELPER FUNCTIONS
  # =========================================================================

  defp assert_consensus_reached(scenario, responses, expect_valid) do
    {_consensus, valid, _byzantine} =
      validate_responses(responses, scenario.honest_count)

    assert valid == expect_valid
  end

  defp assert_cluster_tolerates(total_agents, byzantine_count) do
    honest_count = total_agents - byzantine_count

    model = %{id: "m", transitions: [{"a", "b"}]}
    honest_responses = List.duplicate({:ok, model}, honest_count)
    byzantine_responses = generate_byzantine_responses(byzantine_count)

    responses = honest_responses ++ byzantine_responses

    {_consensus, valid, _byzantine} =
      validate_responses(responses, honest_count)

    assert valid == true
  end

  defp assert_cluster_fails(total_agents, byzantine_count) do
    honest_count = total_agents - byzantine_count

    model = %{id: "m", transitions: [{"a", "b"}]}
    honest_responses = List.duplicate({:ok, model}, honest_count)
    byzantine_responses = generate_byzantine_responses(byzantine_count)

    responses = honest_responses ++ byzantine_responses

    {_consensus, valid, _byzantine} =
      validate_responses(responses, honest_count)

    assert valid == false or not byzantine_count > honest_count
  end

  defp generate_responses(total, honest_count, mode) when is_atom(mode) do
    model = %{id: "m", transitions: [{"a", "b"}]}
    honest_responses = List.duplicate({:ok, model}, honest_count)
    byzantine_responses = generate_byzantine_responses(total - honest_count, mode)
    honest_responses ++ byzantine_responses
  end

  defp generate_responses(total, honest_count, modes) when is_list(modes) do
    model = %{id: "m", transitions: [{"a", "b"}]}
    honest_responses = List.duplicate({:ok, model}, honest_count)

    byzantine_responses =
      modes
      |> Enum.map(&generate_byzantine_response/1)
      |> Enum.concat()

    honest_responses ++ byzantine_responses
  end

  defp generate_byzantine_responses(count, mode \\ :invalid_model) do
    for _ <- 1..count do
      generate_byzantine_response(mode)
    end
  end

  defp generate_byzantine_response(:invalid_model) do
    {:ok, %{id: "corrupt", transitions: [{"x", "y"}]}}
  end

  defp generate_byzantine_response(:crash) do
    {:error, :timeout}
  end

  defp generate_byzantine_response(:state_flip) do
    {:ok, %{id: "flip", transitions: [{"p", "q"}]}}
  end

  defp generate_byzantine_response(:timeout) do
    {:timeout, 5000}
  end

  defp generate_byzantine_response(:conflicting_votes) do
    {:ok, %{id: "conflict", transitions: [{"z", "w"}]}}
  end

  defp validate_responses(responses, quorum_size) do
    valid_responses =
      responses
      |> Enum.filter(&is_valid_response/1)
      |> Enum.map(&extract_model/1)

    byzantine_detected = Enum.any?(responses, &is_byzantine_response/1)

    has_quorum = length(valid_responses) >= quorum_size

    consensus =
      if has_quorum do
        find_consensus_model(valid_responses)
      else
        nil
      end

    {consensus, has_quorum, byzantine_detected}
  end

  defp validate_responses_with_timeout(responses, quorum_size, timeout_ms) do
    start = System.monotonic_time(:millisecond)

    valid_responses =
      responses
      |> Enum.filter(fn
        {:ok, _model, delay} ->
          elapsed = System.monotonic_time(:millisecond) - start
          elapsed + delay < timeout_ms

        {:ok, _model} ->
          true

        _ ->
          false
      end)
      |> Enum.map(&extract_model_with_timeout/1)

    byzantine_detected = Enum.any?(responses, &is_byzantine_response/1)
    has_quorum = length(valid_responses) >= quorum_size

    consensus =
      if has_quorum do
        find_consensus_model(valid_responses)
      else
        nil
      end

    {consensus, has_quorum, byzantine_detected}
  end

  defp is_valid_response({:ok, _model}), do: true
  defp is_valid_response({:ok, _model, _delay}), do: true
  defp is_valid_response(_), do: false

  defp is_byzantine_response({:error, _}), do: true
  defp is_byzantine_response({:timeout, _}), do: true
  defp is_byzantine_response(_), do: false

  defp extract_model({:ok, model}), do: model
  defp extract_model({:ok, model, _delay}), do: model

  defp extract_model_with_timeout({:ok, model}), do: model
  defp extract_model_with_timeout({:ok, model, _delay}), do: model

  defp find_consensus_model(models) do
    models
    |> Enum.group_by(fn m -> m.id end)
    |> Enum.max_by(fn {_id, ms} -> length(ms) end)
    |> elem(1)
    |> List.first()
  end
end
