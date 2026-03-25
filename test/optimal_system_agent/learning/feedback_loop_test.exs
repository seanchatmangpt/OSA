defmodule OptimalSystemAgent.Learning.FeedbackLoopTest do
  @moduledoc """
  Dedicated tests for FeedbackLoop learning mechanism.

  Tests feedback recording, action recommendation with confidence scoring,
  and epsilon-greedy exploration strategies.
  """

  use ExUnit.Case, async: false

  alias OptimalSystemAgent.Learning.{ExperienceStore, FeedbackLoop}

  @moduletag :integration

  setup_all do
    # Ensure ExperienceStore is started
    if Process.whereis(ExperienceStore) == nil do
      {:ok, _pid} = ExperienceStore.start_link([])
    end

    # Ensure FeedbackLoop is started
    if Process.whereis(FeedbackLoop) == nil do
      {:ok, _pid} = FeedbackLoop.start_link([])
    end

    :ok
  end

  describe "feedback recording and aggregation" do
    test "records and aggregates feedback over time" do
      agent_id = "agent_fb_001"

      # Record multiple feedback entries for same action
      assert :ok = FeedbackLoop.record_feedback(agent_id, "tool_a", 0.95)
      assert :ok = FeedbackLoop.record_feedback(agent_id, "tool_a", 0.90)
      assert :ok = FeedbackLoop.record_feedback(agent_id, "tool_a", 0.85)

      Process.sleep(30)

      # Verify aggregated signals
      assert {:ok, signals} = ExperienceStore.learning_signals(agent_id)
      assert map_size(signals) >= 1

      {success_count, failure_count, avg_score} = signals["tool_a"]
      assert success_count >= 3
      assert failure_count == 0
      assert avg_score > 0.8
    end

    test "distinguishes success from failure in feedback" do
      agent_id = "agent_fb_002"

      # Record mixed feedback
      assert :ok = FeedbackLoop.record_feedback(agent_id, "action", 0.95)
      assert :ok = FeedbackLoop.record_feedback(agent_id, "action", 0.85)
      assert :ok = FeedbackLoop.record_feedback(agent_id, "action", 0.40)
      assert :ok = FeedbackLoop.record_feedback(agent_id, "action", 0.20)

      Process.sleep(30)

      assert {:ok, signals} = ExperienceStore.learning_signals(agent_id)
      {success_count, failure_count, _avg} = signals["action"]

      # Two >= 0.5 (success), two < 0.5 (failure)
      assert success_count == 2
      assert failure_count == 2
    end

    test "handles concurrent feedback recording safely" do
      agent_id = "agent_fb_concurrent"

      # Simulate concurrent feedback submission
      tasks =
        Enum.map(1..20, fn i ->
          Task.async(fn ->
            score = Float.round(rem(i, 10) / 10.0, 1)
            FeedbackLoop.record_feedback(agent_id, "concurrent_action", score)
          end)
        end)

      # Wait for all tasks
      Enum.each(tasks, &Task.await/1)

      Process.sleep(50)

      # All feedback should be recorded
      assert {:ok, signals} = ExperienceStore.learning_signals(agent_id)
      assert map_size(signals) >= 1

      {total_success, total_failure, _avg} = signals["concurrent_action"]
      assert total_success + total_failure >= 15
    end
  end

  describe "action recommendation with confidence" do
    test "recommends action with highest average score" do
      agent_id = "agent_recommend_001"

      # Record feedback for multiple actions
      assert :ok = FeedbackLoop.record_feedback(agent_id, "read_file", 0.95)
      assert :ok = FeedbackLoop.record_feedback(agent_id, "read_file", 0.90)
      assert :ok = FeedbackLoop.record_feedback(agent_id, "write_file", 0.60)
      assert :ok = FeedbackLoop.record_feedback(agent_id, "write_file", 0.50)

      Process.sleep(30)

      assert {:ok, recommendation} = FeedbackLoop.recommend_action(agent_id, %{})

      assert is_map(recommendation)
      assert Map.has_key?(recommendation, :action)
      assert Map.has_key?(recommendation, :confidence)
      assert Map.has_key?(recommendation, :success_rate)
      assert Map.has_key?(recommendation, :trials)

      # read_file has higher average (0.925) vs write_file (0.55)
      assert recommendation.action == "read_file"
      assert recommendation.confidence > 0.9
      assert recommendation.success_rate == 1.0
      assert recommendation.trials == 2
    end

    test "confidence reflects both frequency and success rate" do
      agent_id = "agent_recommend_002"

      # Action with high average but low frequency
      assert :ok = FeedbackLoop.record_feedback(agent_id, "rare_success", 0.99)

      # Action with moderate average but high frequency
      Enum.each(1..10, fn _ ->
        FeedbackLoop.record_feedback(agent_id, "common_decent", 0.75)
      end)

      Process.sleep(40)

      assert {:ok, recommendation} = FeedbackLoop.recommend_action(agent_id, %{})

      # Both have high confidence, but common_decent wins due to higher frequency
      assert recommendation.action in ["rare_success", "common_decent"]
    end

    test "returns error when no recommendation history exists" do
      agent_id = "agent_recommend_empty"

      # No feedback recorded for this agent
      assert {:error, :no_history} = FeedbackLoop.recommend_action(agent_id, %{})
    end

    test "recommendation includes success rate calculation" do
      agent_id = "agent_recommend_003"

      # Record 3 successes, 2 failures
      Enum.each(1..3, fn _ ->
        FeedbackLoop.record_feedback(agent_id, "action", 0.9)
      end)

      Enum.each(1..2, fn _ ->
        FeedbackLoop.record_feedback(agent_id, "action", 0.2)
      end)

      Process.sleep(30)

      assert {:ok, recommendation} = FeedbackLoop.recommend_action(agent_id, %{})

      # Success rate should be 3/5 = 0.6
      assert recommendation.success_rate == 0.6
      assert recommendation.trials == 5
    end
  end

  describe "epsilon-greedy exploration strategy" do
    test "exploit when success rate is high (>= 70%)" do
      agent_id = "agent_explore_high"

      # Record very successful history
      Enum.each(1..8, fn _ ->
        FeedbackLoop.record_feedback(agent_id, "reliable_action", 0.95)
      end)

      Enum.each(1..2, fn _ ->
        FeedbackLoop.record_feedback(agent_id, "reliable_action", 0.80)
      end)

      Process.sleep(30)

      # 10/10 successful = 100%, well above 70% threshold
      assert {:ok, should_explore} = FeedbackLoop.should_explore?(agent_id)
      assert should_explore == false
    end

    test "explore when success rate is low (< 70%)" do
      agent_id = "agent_explore_low"

      # Record failure-heavy history
      Enum.each(1..8, fn _ ->
        FeedbackLoop.record_feedback(agent_id, "risky_action", 0.2)
      end)

      Enum.each(1..2, fn _ ->
        FeedbackLoop.record_feedback(agent_id, "risky_action", 0.9)
      end)

      Process.sleep(30)

      # 2/10 successful = 20%, below 70% threshold
      assert {:ok, should_explore} = FeedbackLoop.should_explore?(agent_id)
      assert should_explore == true
    end

    test "explore for new agents with empty history" do
      agent_id = "agent_explore_new"

      # No feedback recorded yet - should explore to build experience
      assert {:ok, should_explore} = FeedbackLoop.should_explore?(agent_id)
      assert should_explore == true
    end

    test "explore at the 70% boundary" do
      agent_id = "agent_explore_boundary"

      # Record exactly 70% success rate: 7 successes, 3 failures
      Enum.each(1..7, fn _ ->
        FeedbackLoop.record_feedback(agent_id, "boundary_action", 0.9)
      end)

      Enum.each(1..3, fn _ ->
        FeedbackLoop.record_feedback(agent_id, "boundary_action", 0.2)
      end)

      Process.sleep(30)

      # At exactly 70%, should exploit (>= threshold)
      assert {:ok, should_explore} = FeedbackLoop.should_explore?(agent_id)
      assert should_explore == false
    end
  end

  describe "feedback validation and edge cases" do
    test "rejects feedback score below 0.0" do
      agent_id = "agent_valid_001"

      assert {:error, :invalid_feedback} = FeedbackLoop.record_feedback(agent_id, "action", -0.1)
      assert {:error, :invalid_feedback} = FeedbackLoop.record_feedback(agent_id, "action", -1.0)
    end

    test "rejects feedback score above 1.0" do
      agent_id = "agent_valid_002"

      assert {:error, :invalid_feedback} = FeedbackLoop.record_feedback(agent_id, "action", 1.1)
      assert {:error, :invalid_feedback} = FeedbackLoop.record_feedback(agent_id, "action", 2.0)
    end

    test "accepts boundary scores 0.0 and 1.0" do
      agent_id = "agent_valid_003"

      assert :ok = FeedbackLoop.record_feedback(agent_id, "action", 0.0)
      assert :ok = FeedbackLoop.record_feedback(agent_id, "action", 1.0)

      Process.sleep(20)

      assert {:ok, signals} = ExperienceStore.learning_signals(agent_id)
      {success, failure, _avg} = signals["action"]
      assert success == 1
      assert failure == 1
    end

    test "rejects non-numeric feedback" do
      agent_id = "agent_valid_004"

      assert {:error, :invalid_feedback} = FeedbackLoop.record_feedback(agent_id, "action", "0.5")
      assert {:error, :invalid_feedback} = FeedbackLoop.record_feedback(agent_id, "action", nil)
    end

    test "rejects non-binary agent_id" do
      assert {:error, :invalid_feedback} = FeedbackLoop.record_feedback(123, "action", 0.5)
      assert {:error, :invalid_feedback} = FeedbackLoop.record_feedback(nil, "action", 0.5)
    end

    test "rejects non-binary action name" do
      agent_id = "agent_valid_005"

      assert {:error, :invalid_feedback} = FeedbackLoop.record_feedback(agent_id, 123, 0.5)
      assert {:error, :invalid_feedback} = FeedbackLoop.record_feedback(agent_id, nil, 0.5)
    end
  end

  describe "multi-agent independence" do
    test "agents maintain separate feedback histories" do
      agent1 = "agent_independent_001"
      agent2 = "agent_independent_002"

      # Agent 1: successful action
      Enum.each(1..5, fn _ ->
        FeedbackLoop.record_feedback(agent1, "action", 0.95)
      end)

      # Agent 2: failed action
      Enum.each(1..5, fn _ ->
        FeedbackLoop.record_feedback(agent2, "action", 0.10)
      end)

      Process.sleep(30)

      # Agent 1 should recommend with high confidence
      assert {:ok, rec1} = FeedbackLoop.recommend_action(agent1, %{})
      assert rec1.confidence > 0.9

      # Agent 2 should recommend with low confidence
      assert {:ok, rec2} = FeedbackLoop.recommend_action(agent2, %{})
      assert rec2.confidence < 0.2
    end

    test "agents explore independently" do
      agent1 = "agent_explore_indep_001"
      agent2 = "agent_explore_indep_002"

      # Agent 1: high success rate
      Enum.each(1..8, fn _ ->
        FeedbackLoop.record_feedback(agent1, "action", 0.9)
      end)

      # Agent 2: low success rate
      Enum.each(1..8, fn _ ->
        FeedbackLoop.record_feedback(agent2, "action", 0.2)
      end)

      Process.sleep(30)

      assert {:ok, explore1} = FeedbackLoop.should_explore?(agent1)
      assert {:ok, explore2} = FeedbackLoop.should_explore?(agent2)

      # Agent 1 should exploit, Agent 2 should explore
      assert explore1 == false
      assert explore2 == true
    end
  end

  describe "signal generation (Signal Theory)" do
    test "converts recommendation to Signal with proper encoding" do
      agent_id = "agent_signal_001"

      # Record feedback
      assert :ok = FeedbackLoop.record_feedback(agent_id, "action", 0.95)

      Process.sleep(20)

      assert {:ok, recommendation} = FeedbackLoop.recommend_action(agent_id, %{})

      # Convert to signal
      signal = FeedbackLoop.to_signal(recommendation)

      # Verify Signal structure (Mode, Genre, Type, Format, Weight)
      assert signal.mode == :assist
      assert signal.genre == :decide
      assert signal.type == :request
      assert signal.format == :json
      assert signal.weight == 0.75
      assert is_binary(signal.content)
    end
  end
end
