defmodule OptimalSystemAgent.Learning.FeedbackLoop do
  @moduledoc """
  Feedback mechanism and adaptive action recommendation for agents.

  Implements outcome-based learning through feedback scoring, action
  recommendation with confidence metrics, and epsilon-greedy exploration
  strategies for autonomous agent behavior.

  ## Feedback Scoring

  Scores range from 0.0 (complete failure) to 1.0 (complete success).
  Feedback is aggregated to compute per-action success rates and guide
  future decisions.

  ## Action Recommendation

  Recommendations draw from past experiences via ExperienceStore:
  - Select actions with highest average feedback scores
  - Return confidence metric based on success frequency
  - Tie-breaking by most recent success

  ## Exploration vs. Exploitation

  Epsilon-greedy strategy:
  - If agent success rate ≥ 70%: exploit (recommend best action)
  - If agent success rate < 70%: explore (randomize action selection)
  - Encourages learning in new action spaces

  ## Usage

      {:ok, _pid} = FeedbackLoop.start_link()
      :ok = FeedbackLoop.record_feedback("agent_001", "read_file", 0.95)
      {:ok, rec} = FeedbackLoop.recommend_action("agent_001", %{file: "data.txt"})
      {:ok, should_explore} = FeedbackLoop.should_explore?("agent_001")
  """

  use GenServer
  require Logger

  alias OptimalSystemAgent.Learning.ExperienceStore
  alias OptimalSystemAgent.Signal

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Record outcome feedback for an agent's action.

  Score should be a float between 0.0 and 1.0:
  - 0.0 = complete failure
  - 0.5 = neutral/mixed outcome
  - 1.0 = complete success
  """
  @spec record_feedback(String.t(), String.t(), float()) :: :ok | {:error, term()}
  def record_feedback(agent_id, action, score)
      when is_binary(agent_id) and is_binary(action) and is_float(score) and score >= 0.0 and
           score <= 1.0 do
    GenServer.cast(__MODULE__, {:record_feedback, agent_id, action, score})
  end

  def record_feedback(_agent_id, _action, _score) do
    {:error, :invalid_feedback}
  end

  @doc """
  Recommend the best action for an agent in a given context.

  Returns:
  - `{:ok, %{action: String.t(), confidence: float()}}` — recommended action + confidence (0.0–1.0)
  - `{:error, reason}` — if no history available or recommendation failed
  """
  @spec recommend_action(String.t(), map()) :: {:ok, map()} | {:error, term()}
  def recommend_action(agent_id, context) when is_binary(agent_id) and is_map(context) do
    GenServer.call(__MODULE__, {:recommend_action, agent_id, context}, :infinity)
  end

  def recommend_action(_agent_id, _context) do
    {:error, :invalid_context}
  end

  @doc """
  Determine whether agent should explore new actions (epsilon-greedy).

  Returns:
  - `{:ok, true}` — agent should explore (success rate < 70%)
  - `{:ok, false}` — agent should exploit (success rate ≥ 70%)
  - `{:error, reason}` — if no history available
  """
  @spec should_explore?(String.t()) :: {:ok, boolean()} | {:error, term()}
  def should_explore?(agent_id) when is_binary(agent_id) do
    GenServer.call(__MODULE__, {:should_explore, agent_id}, :infinity)
  end

  def should_explore?(_agent_id) do
    {:error, :invalid_agent_id}
  end

  # ---------------------------------------------------------------------------
  # GenServer callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(_opts) do
    Logger.info("[Learning.FeedbackLoop] Started")
    {:ok, %{}}
  end

  @impl true
  def handle_cast({:record_feedback, agent_id, action, score}, state) do
    timestamp = DateTime.utc_now()

    # Record as experience tuple with feedback
    context = %{"recorded_at" => DateTime.to_iso8601(timestamp), "agent_id" => agent_id}
    outcome = if score >= 0.5, do: "success", else: "failure"

    experience = {action, context, outcome, score, timestamp}

    case ExperienceStore.record(agent_id, experience) do
      :ok ->
        Logger.debug("[FeedbackLoop] Recorded feedback: agent=#{agent_id}, action=#{action}, score=#{score}")

      error ->
        Logger.warning("[FeedbackLoop] Failed to record feedback: #{inspect(error)}")
    end

    {:noreply, state}
  end

  @impl true
  def handle_call({:recommend_action, agent_id, _context}, _from, state) do
    result =
      case ExperienceStore.learning_signals(agent_id) do
        {:ok, signals} when map_size(signals) > 0 ->
          # Find action with highest average score
          {best_action, {success_count, failure_count, avg_score}} =
            signals
            |> Enum.max_by(fn {_action, {_succ, _fail, avg}} -> avg end)

          total = success_count + failure_count
          confidence = Float.round(avg_score, 2)

          {:ok,
           %{
             action: best_action,
             confidence: confidence,
             success_rate: Float.round(success_count / total, 2),
             trials: total
           }}

        {:ok, _empty} ->
          {:error, :no_history}

        error ->
          error
      end

    {:reply, result, state}
  end

  @impl true
  def handle_call({:should_explore, agent_id}, _from, state) do
    result =
      case ExperienceStore.learning_signals(agent_id) do
        {:ok, signals} when map_size(signals) > 0 ->
          # Calculate overall success rate across all actions
          total_success =
            signals
            |> Enum.map(fn {_action, {success, _fail, _avg}} -> success end)
            |> Enum.sum()

          total_trials =
            signals
            |> Enum.map(fn {_action, {success, failure, _avg}} -> success + failure end)
            |> Enum.sum()

          if total_trials > 0 do
            success_rate = total_success / total_trials
            should_explore = success_rate < 0.7
            {:ok, should_explore}
          else
            {:ok, true}
          end

        {:ok, _empty} ->
          {:ok, true}

        error ->
          error
      end

    {:reply, result, state}
  end

  @doc false
  def to_signal(recommendation) when is_map(recommendation) do
    Signal.new(%{
      mode: :assist,
      genre: :decide,
      type: :request,
      format: :json,
      weight: 0.75,
      content: Jason.encode!(recommendation),
      metadata: %{"source" => "feedback_loop", "timestamp" => DateTime.utc_now()}
    })
  end
end
