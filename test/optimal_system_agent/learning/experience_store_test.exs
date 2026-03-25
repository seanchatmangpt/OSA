defmodule OptimalSystemAgent.Learning.ExperienceStoreTest do
  @moduledoc """
  Integration tests for ExperienceStore and FeedbackLoop.

  Tests the agent learning loop: experience recording, embedding generation,
  similarity search, feedback aggregation, and action recommendation.

  Marked as integration tests since they depend on ETS initialization.
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

  describe "store and retrieve experience" do
    test "records single experience and retrieves it" do
      agent_id = "agent_001"
      action = "read_file"
      context = %{"file" => "data.txt", "encoding" => "utf-8"}
      outcome = "success"
      feedback = 0.95
      timestamp = DateTime.utc_now()

      experience = {action, context, outcome, feedback, timestamp}

      assert :ok = ExperienceStore.record(agent_id, experience)

      # Small delay to ensure write completes
      Process.sleep(10)

      assert {:ok, recent} = ExperienceStore.get_recent(agent_id, 10)
      assert is_list(recent)
      assert Enum.count(recent) >= 1

      # Verify the stored experience
      {stored_action, stored_context, stored_outcome, stored_feedback, _stored_timestamp} =
        List.first(recent)

      assert stored_action == action
      assert stored_context == context
      assert stored_outcome == outcome
      assert stored_feedback == feedback
    end

    test "retrieves multiple experiences in reverse order" do
      agent_id = "agent_002"
      timestamp_base = DateTime.utc_now()

      experiences = [
        {"action_1", %{"step" => 1}, "success", 0.8, DateTime.add(timestamp_base, -2, :second)},
        {"action_2", %{"step" => 2}, "success", 0.9, DateTime.add(timestamp_base, -1, :second)},
        {"action_3", %{"step" => 3}, "failure", 0.3, timestamp_base}
      ]

      Enum.each(experiences, fn exp ->
        assert :ok = ExperienceStore.record(agent_id, exp)
      end)

      Process.sleep(20)

      assert {:ok, recent} = ExperienceStore.get_recent(agent_id, 10)
      assert Enum.count(recent) >= 3

      # Most recent should be first (action_3)
      {first_action, _, _, _, _} = List.first(recent)
      assert first_action == "action_3"
    end

    test "limits retrieval with max count" do
      agent_id = "agent_003"
      timestamp_base = DateTime.utc_now()

      # Record 15 experiences
      Enum.each(1..15, fn i ->
        exp = {
          "action_#{i}",
          %{"index" => i},
          "success",
          0.8,
          DateTime.add(timestamp_base, -i, :second)
        }

        ExperienceStore.record(agent_id, exp)
      end)

      Process.sleep(30)

      # Request only 5
      assert {:ok, recent} = ExperienceStore.get_recent(agent_id, 5)
      assert Enum.count(recent) <= 5
    end

    test "rejects invalid experience tuple" do
      agent_id = "agent_004"

      assert {:error, :invalid_experience} = ExperienceStore.record(agent_id, "not_a_tuple")
      assert {:error, :invalid_experience} = ExperienceStore.record(agent_id, {1, 2, 3})
    end
  end

  describe "compute experience embedding" do
    test "generates 128-dimensional embedding" do
      agent_id = "agent_embedding_001"
      action = "read_file"
      context = %{"file" => "data.txt"}
      outcome = "success"

      assert {:ok, embedding} = ExperienceStore.embedding(agent_id, {action, context, outcome, 0.9, DateTime.utc_now()})

      assert is_list(embedding)
      assert Enum.count(embedding) == 128

      # All dimensions should be floats in [0.0, 1.0]
      Enum.each(embedding, fn dim ->
        assert is_float(dim)
        assert dim >= 0.0 and dim <= 1.0
      end)
    end

    test "embedding is deterministic for same input" do
      agent_id = "agent_embedding_002"
      action = "write_file"
      context = %{"target" => "output.txt"}
      outcome = "success"

      exp1 = {action, context, outcome, 0.8, DateTime.utc_now()}
      exp2 = {action, context, outcome, 0.8, DateTime.utc_now()}

      assert {:ok, embed1} = ExperienceStore.embedding(agent_id, exp1)
      assert {:ok, embed2} = ExperienceStore.embedding(agent_id, exp2)

      # Embeddings for identical inputs should match
      assert embed1 == embed2
    end

    test "different inputs produce different embeddings" do
      agent_id = "agent_embedding_003"

      exp1 = {"action_a", %{"key" => "value_a"}, "success", 0.8, DateTime.utc_now()}
      exp2 = {"action_b", %{"key" => "value_b"}, "failure", 0.2, DateTime.utc_now()}

      assert {:ok, embed1} = ExperienceStore.embedding(agent_id, exp1)
      assert {:ok, embed2} = ExperienceStore.embedding(agent_id, exp2)

      # Embeddings should differ
      refute embed1 == embed2
    end

    test "rejects invalid experience for embedding" do
      agent_id = "agent_embedding_004"

      assert {:error, :invalid_experience} =
               ExperienceStore.embedding(agent_id, "not_a_tuple")

      assert {:error, :invalid_experience} =
               ExperienceStore.embedding(agent_id, {123, %{}, "outcome", 0.5, DateTime.utc_now()})
    end
  end

  describe "find similar past experiences" do
    test "finds similar experiences by query" do
      agent_id = "agent_similar_001"
      timestamp_base = DateTime.utc_now()

      # Store multiple experiences
      experiences = [
        {"read_file", %{"file" => "data.txt"}, "success", 0.9, DateTime.add(timestamp_base, -3, :second)},
        {"read_file", %{"file" => "config.yaml"}, "success", 0.85, DateTime.add(timestamp_base, -2, :second)},
        {"write_file", %{"file" => "output.txt"}, "success", 0.8, DateTime.add(timestamp_base, -1, :second)},
        {"delete_file", %{"file" => "temp.tmp"}, "failure", 0.1, timestamp_base}
      ]

      Enum.each(experiences, fn exp ->
        ExperienceStore.record(agent_id, exp)
      end)

      Process.sleep(30)

      # Query for read_file operations
      query = {"read_file", %{"file" => "data.txt"}, "success"}

      assert {:ok, similar} = ExperienceStore.find_similar(agent_id, query, 3)
      assert is_list(similar)
      assert Enum.count(similar) <= 3

      # Results should be tuples of {experience, similarity_score}
      Enum.each(similar, fn {exp, sim_score} ->
        assert is_tuple(exp)
        assert tuple_size(exp) == 5
        assert is_float(sim_score)
        assert sim_score >= 0.0 and sim_score <= 1.0
      end)
    end

    test "returns results sorted by descending similarity" do
      agent_id = "agent_similar_002"
      timestamp_base = DateTime.utc_now()

      experiences = [
        {"api_call", %{"endpoint" => "/users"}, "success", 0.9, DateTime.add(timestamp_base, -4, :second)},
        {"api_call", %{"endpoint" => "/posts"}, "success", 0.85, DateTime.add(timestamp_base, -3, :second)},
        {"api_call", %{"endpoint" => "/users"}, "success", 0.95, DateTime.add(timestamp_base, -2, :second)},
        {"database_query", %{"table" => "users"}, "success", 0.8, DateTime.add(timestamp_base, -1, :second)}
      ]

      Enum.each(experiences, fn exp ->
        ExperienceStore.record(agent_id, exp)
      end)

      Process.sleep(30)

      query = {"api_call", %{"endpoint" => "/users"}, "success"}

      assert {:ok, similar} = ExperienceStore.find_similar(agent_id, query, 10)

      # Verify descending order
      similarity_scores = Enum.map(similar, fn {_exp, score} -> score end)

      assert similarity_scores == Enum.sort(similarity_scores, :desc)
    end

    test "respects top_k limit" do
      agent_id = "agent_similar_003"
      timestamp_base = DateTime.utc_now()

      # Create 10 similar experiences
      Enum.each(1..10, fn i ->
        exp = {
          "generic_action",
          %{"index" => i},
          "success",
          0.8,
          DateTime.add(timestamp_base, -i, :second)
        }

        ExperienceStore.record(agent_id, exp)
      end)

      Process.sleep(50)

      query = {"generic_action", %{"index" => 5}, "success"}

      # Request top 3
      assert {:ok, top3} = ExperienceStore.find_similar(agent_id, query, 3)
      assert Enum.count(top3) <= 3

      # Request top 20 (more than available)
      assert {:ok, top20} = ExperienceStore.find_similar(agent_id, query, 20)
      assert Enum.count(top20) <= 10
    end

    test "returns empty list for no matches" do
      agent_id = "agent_similar_004"

      # Don't store any experiences for this agent

      query = {"nonexistent_action", %{"key" => "value"}, "success"}

      assert {:ok, similar} = ExperienceStore.find_similar(agent_id, query, 5)
      assert is_list(similar)
      assert Enum.count(similar) == 0
    end
  end

  describe "aggregate feedback by action" do
    test "computes learning signals from experiences" do
      agent_id = "agent_signals_001"
      timestamp = DateTime.utc_now()

      # Record varied experiences
      experiences = [
        {"api_request", %{}, "success", 0.95, DateTime.add(timestamp, -5, :second)},
        {"api_request", %{}, "success", 0.90, DateTime.add(timestamp, -4, :second)},
        {"api_request", %{}, "failure", 0.10, DateTime.add(timestamp, -3, :second)},
        {"file_operation", %{}, "success", 0.85, DateTime.add(timestamp, -2, :second)},
        {"file_operation", %{}, "failure", 0.20, DateTime.add(timestamp, -1, :second)}
      ]

      Enum.each(experiences, fn exp ->
        ExperienceStore.record(agent_id, exp)
      end)

      Process.sleep(30)

      assert {:ok, signals} = ExperienceStore.learning_signals(agent_id)
      assert is_map(signals)

      # Should have entries for both actions
      assert Map.has_key?(signals, "api_request")
      assert Map.has_key?(signals, "file_operation")

      # api_request: 2 successes, 1 failure
      {api_success, api_failure, api_avg} = signals["api_request"]
      assert api_success == 2
      assert api_failure == 1
      assert is_float(api_avg)
      assert api_avg > 0.5 and api_avg < 1.0

      # file_operation: 1 success, 1 failure
      {file_success, file_failure, file_avg} = signals["file_operation"]
      assert file_success == 1
      assert file_failure == 1
      assert is_float(file_avg)
    end

    test "marks success when feedback >= 0.5" do
      agent_id = "agent_signals_002"
      timestamp = DateTime.utc_now()

      experiences = [
        {"action", %{}, "success", 0.5, DateTime.add(timestamp, -1, :second)},
        {"action", %{}, "success", 0.51, timestamp}
      ]

      Enum.each(experiences, fn exp ->
        ExperienceStore.record(agent_id, exp)
      end)

      Process.sleep(20)

      assert {:ok, signals} = ExperienceStore.learning_signals(agent_id)
      {success_count, failure_count, _avg} = signals["action"]

      assert success_count == 2
      assert failure_count == 0
    end

    test "marks failure when feedback < 0.5" do
      agent_id = "agent_signals_003"
      timestamp = DateTime.utc_now()

      experiences = [
        {"action", %{}, "failure", 0.49, DateTime.add(timestamp, -1, :second)},
        {"action", %{}, "failure", 0.0, timestamp}
      ]

      Enum.each(experiences, fn exp ->
        ExperienceStore.record(agent_id, exp)
      end)

      Process.sleep(20)

      assert {:ok, signals} = ExperienceStore.learning_signals(agent_id)
      {success_count, failure_count, _avg} = signals["action"]

      assert success_count == 0
      assert failure_count == 2
    end

    test "returns empty map for agent with no experiences" do
      agent_id = "agent_signals_empty"

      assert {:ok, signals} = ExperienceStore.learning_signals(agent_id)
      assert is_map(signals)
      assert map_size(signals) == 0
    end
  end

  describe "feedback loop integration" do
    test "records feedback and influences learning signals" do
      agent_id = "agent_feedback_001"

      # Record multiple feedback entries
      assert :ok = FeedbackLoop.record_feedback(agent_id, "tool_a", 0.95)
      assert :ok = FeedbackLoop.record_feedback(agent_id, "tool_a", 0.90)
      assert :ok = FeedbackLoop.record_feedback(agent_id, "tool_b", 0.40)

      Process.sleep(30)

      # Check learning signals
      assert {:ok, signals} = ExperienceStore.learning_signals(agent_id)
      assert map_size(signals) >= 2

      # tool_a should have high average
      {tool_a_succ, tool_a_fail, tool_a_avg} = signals["tool_a"]
      assert tool_a_succ >= 2
      assert tool_a_fail == 0
      assert tool_a_avg > 0.85

      # tool_b should have low average
      {_tool_b_succ, tool_b_fail, tool_b_avg} = signals["tool_b"]
      assert tool_b_fail >= 1
      assert tool_b_avg < 0.5
    end

    test "recommends action with highest average feedback" do
      agent_id = "agent_feedback_002"

      # Record varied feedback
      assert :ok = FeedbackLoop.record_feedback(agent_id, "read_file", 0.95)
      assert :ok = FeedbackLoop.record_feedback(agent_id, "read_file", 0.90)
      assert :ok = FeedbackLoop.record_feedback(agent_id, "write_file", 0.60)
      assert :ok = FeedbackLoop.record_feedback(agent_id, "write_file", 0.50)

      Process.sleep(30)

      assert {:ok, recommendation} = FeedbackLoop.recommend_action(agent_id, %{})

      assert is_map(recommendation)
      assert Map.has_key?(recommendation, :action)
      assert Map.has_key?(recommendation, :confidence)

      # read_file has higher average than write_file
      assert recommendation.action == "read_file"
      assert recommendation.confidence > 0.8
    end

    test "explore when success rate is low" do
      agent_id = "agent_feedback_003"

      # Record many failures
      Enum.each(1..8, fn _ ->
        FeedbackLoop.record_feedback(agent_id, "risky_action", 0.2)
      end)

      Enum.each(1..2, fn _ ->
        FeedbackLoop.record_feedback(agent_id, "risky_action", 0.9)
      end)

      Process.sleep(30)

      # Success rate is 2/10 = 20%, below 70% threshold
      assert {:ok, should_explore} = FeedbackLoop.should_explore?(agent_id)
      assert should_explore == true
    end

    test "exploit when success rate is high" do
      agent_id = "agent_feedback_004"

      # Record many successes
      Enum.each(1..8, fn _ ->
        FeedbackLoop.record_feedback(agent_id, "reliable_action", 0.95)
      end)

      Enum.each(1..2, fn _ ->
        FeedbackLoop.record_feedback(agent_id, "reliable_action", 0.80)
      end)

      Process.sleep(30)

      # Success rate is 10/10 = 100%, above 70% threshold
      assert {:ok, should_explore} = FeedbackLoop.should_explore?(agent_id)
      assert should_explore == false
    end

    test "explore for new agents with no history" do
      agent_id = "agent_feedback_new"

      # No feedback recorded yet

      assert {:ok, should_explore} = FeedbackLoop.should_explore?(agent_id)
      assert should_explore == true
    end

    test "rejects invalid feedback score" do
      agent_id = "agent_feedback_invalid"

      assert {:error, :invalid_feedback} = FeedbackLoop.record_feedback(agent_id, "action", -0.1)
      assert {:error, :invalid_feedback} = FeedbackLoop.record_feedback(agent_id, "action", 1.1)
      assert {:error, :invalid_feedback} = FeedbackLoop.record_feedback(agent_id, "action", "not_a_float")
    end

    test "handles agents with empty history gracefully" do
      agent_id = "agent_feedback_empty"

      # No experiences recorded

      assert {:error, :no_history} = FeedbackLoop.recommend_action(agent_id, %{})
      assert {:ok, should_explore} = FeedbackLoop.should_explore?(agent_id)
      assert should_explore == true
    end
  end

  describe "edge cases" do
    test "handles max experiences limit per agent" do
      agent_id = "agent_limit_001"
      timestamp_base = DateTime.utc_now()

      # Record 1100 experiences (exceeds 1000 limit)
      Enum.each(1..1100, fn i ->
        exp = {
          "action",
          %{"index" => i},
          "success",
          0.8,
          DateTime.add(timestamp_base, -i, :second)
        }

        ExperienceStore.record(agent_id, exp)
      end)

      Process.sleep(100)

      # Should have at most 1000 experiences
      assert {:ok, recent} = ExperienceStore.get_recent(agent_id, 2000)
      assert Enum.count(recent) <= 1000
    end

    test "handles zero-length embeddings gracefully" do
      agent_id = "agent_edge_001"

      # Empty strings
      assert {:ok, embedding} = ExperienceStore.embedding(agent_id, {"", %{}, "", 0.5, DateTime.utc_now()})
      assert Enum.count(embedding) == 128
    end

    test "cosine similarity handles zero vectors" do
      # Zero vector similarity should be 0.0
      zero_vec = List.duplicate(0.0, 128)
      ones_vec = List.duplicate(1.0, 128)

      similarity = ExperienceStore.cosine_similarity(zero_vec, ones_vec)
      assert similarity == 0.0

      # Same vector similarity should be 1.0
      similarity = ExperienceStore.cosine_similarity(ones_vec, ones_vec)
      assert similarity == 1.0
    end

    test "handles concurrent feedback recording" do
      agent_id = "agent_concurrent_001"

      # Record feedback from multiple "concurrent" calls
      Enum.each(1..50, fn i ->
        FeedbackLoop.record_feedback(agent_id, "action_#{rem(i, 5)}", Float.round(i / 100, 2))
      end)

      Process.sleep(50)

      # All feedback should be recorded
      assert {:ok, signals} = ExperienceStore.learning_signals(agent_id)
      total_trials =
        signals
        |> Enum.map(fn {_action, {succ, fail, _avg}} -> succ + fail end)
        |> Enum.sum()

      assert total_trials >= 40
    end
  end
end
