defmodule OptimalSystemAgent.Learning.ExperienceStore do
  @moduledoc """
  Vector store for agent learning experiences with embeddings and similarity search.

  Implements experience storage, retrieval, embedding computation, and similarity
  search for adaptive agent behavior. Uses ETS for fast in-memory access with a
  1000-experience per-agent limit.

  ## Data Model

  Experience tuple: `{action, context, outcome, feedback, timestamp}`

  - **action**: String.t() — agent action taken
  - **context**: map() — operational context
  - **outcome**: String.t() — result description
  - **feedback**: float() — outcome score (0.0–1.0)
  - **timestamp**: DateTime.t() — when experience occurred

  ## Embeddings

  Experience embeddings are computed via SHA256 hash + normalization:
  1. Hash action+context+outcome with SHA256
  2. Extract 128 dimensions from hash bytes
  3. Normalize to [0.0, 1.0] range

  ## Similarity Search

  Cosine similarity between normalized embeddings: `similarity = A·B / (|A||B|)`

  ## Usage

      {:ok, _pid} = ExperienceStore.start_link(agent_id: "agent_001")
      :ok = ExperienceStore.record("agent_001", {action, context, outcome, feedback, now})
      {:ok, recent} = ExperienceStore.get_recent("agent_001", 10)
      {:ok, embedding} = ExperienceStore.embedding("agent_001", experience)
      {:ok, similar} = ExperienceStore.find_similar("agent_001", query, 5)
      {:ok, signals} = ExperienceStore.learning_signals("agent_001")
  """

  use GenServer
  require Logger

  alias OptimalSystemAgent.Signal

  @ets_table :osa_experiences
  @max_experiences_per_agent 1000
  @embedding_dimensions 128
  @call_timeout 30_000

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Record a new experience for an agent.

  Experience tuple: {action, context, outcome, feedback, timestamp}
  """
  @spec record(String.t(), tuple()) :: :ok | {:error, term()}
  def record(agent_id, {_action, _context, _outcome, _feedback, _timestamp} = experience)
      when is_binary(agent_id) do
    GenServer.cast(__MODULE__, {:record, agent_id, experience})
  end

  def record(_agent_id, _experience) do
    {:error, :invalid_experience}
  end

  @doc """
  Retrieve the last N experiences for an agent.
  """
  @spec get_recent(String.t(), non_neg_integer()) :: {:ok, [tuple()]} | {:error, term()}
  def get_recent(agent_id, limit \\ 10) when is_binary(agent_id) and is_integer(limit) do
    GenServer.call(__MODULE__, {:get_recent, agent_id, limit}, @call_timeout)
  end

  @doc """
  Compute 128-dimensional embedding for an experience using SHA256.

  Returns a list of 128 floats in [0.0, 1.0] range.
  """
  @spec embedding(String.t(), tuple()) :: {:ok, [float()]} | {:error, term()}
  def embedding(agent_id, {action, context, outcome, _feedback, _timestamp})
      when is_binary(agent_id) and is_binary(action) and is_map(context) and
           is_binary(outcome) do
    GenServer.call(__MODULE__, {:embedding, agent_id, action, context, outcome}, @call_timeout)
  end

  def embedding(_agent_id, _experience) do
    {:error, :invalid_experience}
  end

  @doc """
  Find similar past experiences using cosine similarity.

  Query: {action, context, outcome} tuple.
  Returns up to top_k results sorted by descending similarity.
  """
  @spec find_similar(String.t(), tuple(), non_neg_integer()) ::
          {:ok, [{tuple(), float()}]} | {:error, term()}
  def find_similar(agent_id, query, top_k \\ 5)

  def find_similar(agent_id, {_action, _context, _outcome} = query, top_k)
      when is_binary(agent_id) and is_integer(top_k) do
    GenServer.call(__MODULE__, {:find_similar, agent_id, query, top_k}, @call_timeout)
  end

  def find_similar(_agent_id, _query, _top_k) do
    {:error, :invalid_query}
  end

  @doc """
  Aggregate learning signals by action from feedback history.

  Returns map: %{action => {success_count, failure_count, avg_score}}
  """
  @spec learning_signals(String.t()) :: {:ok, map()} | {:error, term()}
  def learning_signals(agent_id) when is_binary(agent_id) do
    GenServer.call(__MODULE__, {:learning_signals, agent_id}, @call_timeout)
  end

  # ---------------------------------------------------------------------------
  # GenServer callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(_opts) do
    create_ets_table()
    Logger.info("[Learning.ExperienceStore] Started")
    {:ok, %{}}
  end

  @impl true
  def handle_cast({:record, agent_id, {action, context, outcome, feedback, timestamp}}, state) do
    key = {agent_id, System.monotonic_time(:nanosecond)}

    if :ets.whereis(@ets_table) != :undefined do
      :ets.insert(@ets_table, {key, {action, context, outcome, feedback, timestamp}})
      trim_agent_experiences(agent_id)
    end

    {:noreply, state}
  end

  @impl true
  def handle_call({:get_recent, agent_id, limit}, _from, state) do
    result =
      if :ets.whereis(@ets_table) != :undefined do
        experiences =
          @ets_table
          |> :ets.match_object({agent_id_pattern(agent_id), :_})
          |> Enum.map(fn {{_aid, _key}, exp} -> exp end)
          |> Enum.reverse()
          |> Enum.take(limit)

        {:ok, experiences}
      else
        {:error, :ets_error}
      end

    {:reply, result, state}
  end

  @impl true
  def handle_call({:embedding, _agent_id, action, context, outcome}, _from, state) do
    result =
      try do
        embedding_vector = compute_embedding(action, context, outcome)
        {:ok, embedding_vector}
      rescue
        _ -> {:error, :embedding_failed}
      end

    {:reply, result, state}
  end

  @impl true
  def handle_call({:find_similar, agent_id, {query_action, query_context, query_outcome}, top_k}, _from, state) do
    result =
      try do
        query_embedding = compute_embedding(query_action, query_context, query_outcome)

        experiences =
          @ets_table
          |> :ets.match_object({agent_id_pattern(agent_id), :_})
          |> Enum.map(fn {{_aid, _key}, exp} -> exp end)

        similar =
          experiences
          |> Enum.map(fn {action, context, outcome, _feedback, _timestamp} = exp ->
            exp_embedding = compute_embedding(action, context, outcome)
            similarity = cosine_similarity(query_embedding, exp_embedding)
            {exp, similarity}
          end)
          |> Enum.sort_by(fn {_exp, sim} -> sim end, :desc)
          |> Enum.take(top_k)

        {:ok, similar}
      rescue
        _ -> {:error, :similarity_search_failed}
      end

    {:reply, result, state}
  end

  @impl true
  def handle_call({:learning_signals, agent_id}, _from, state) do
    result =
      try do
        experiences =
          @ets_table
          |> :ets.match_object({agent_id_pattern(agent_id), :_})
          |> Enum.map(fn {{_aid, _key}, exp} -> exp end)

        signals =
          experiences
          |> Enum.reduce(%{}, fn {action, _context, _outcome, feedback, _timestamp}, acc ->
            current = Map.get(acc, action, {0, 0, 0.0})
            {success_count, failure_count, sum_score} = current

            new_success = if feedback >= 0.5, do: success_count + 1, else: success_count
            new_failure = if feedback < 0.5, do: failure_count + 1, else: failure_count
            new_sum = sum_score + feedback

            Map.put(acc, action, {new_success, new_failure, new_sum})
          end)
          |> Enum.into(%{}, fn {action, {success, failure, sum}} ->
            avg_score = if success + failure > 0, do: sum / (success + failure), else: 0.0
            {action, {success, failure, Float.round(avg_score, 3)}}
          end)

        {:ok, signals}
      rescue
        _ -> {:error, :signal_aggregation_failed}
      end

    {:reply, result, state}
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp create_ets_table do
    try do
      :ets.new(@ets_table, [:named_table, :ordered_set, :public])
    rescue
      ArgumentError -> :already_exists
    end
  end

  defp agent_id_pattern(agent_id) do
    {agent_id, :_}
  end

  defp trim_agent_experiences(agent_id) do
    if :ets.whereis(@ets_table) != :undefined do
      count =
        @ets_table
        |> :ets.match_object({agent_id_pattern(agent_id), :_})
        |> Enum.count()

      if count > @max_experiences_per_agent do
        excess = count - @max_experiences_per_agent
        trim_oldest_for_agent(agent_id, excess)
      end
    end
  end

  defp trim_oldest_for_agent(agent_id, n) do
    if :ets.whereis(@ets_table) != :undefined do
      @ets_table
      |> :ets.match_object({agent_id_pattern(agent_id), :_})
      |> Enum.sort_by(fn {{_aid, key}, _exp} -> key end)
      |> Enum.take(n)
      |> Enum.each(fn {{_aid, key}, _exp} ->
        :ets.delete(@ets_table, {agent_id, key})
      end)
    end
  end

  @doc false
  def compute_embedding(action, context, outcome) do
    content = "#{action}|#{inspect(context)}|#{outcome}"
    hash = :crypto.hash(:sha256, content)

    # Extract 128 dimensions from the 32-byte hash
    dimensions =
      hash
      |> :binary.bin_to_list()
      |> Enum.map(&(&1 / 255.0))

    # Pad or truncate to exactly 128 dimensions
    if Enum.count(dimensions) < @embedding_dimensions do
      dimensions ++ List.duplicate(0.0, @embedding_dimensions - Enum.count(dimensions))
    else
      Enum.take(dimensions, @embedding_dimensions)
    end
  end

  @doc false
  def cosine_similarity(vec1, vec2) when is_list(vec1) and is_list(vec2) do
    dot_product = Enum.zip(vec1, vec2) |> Enum.map(fn {a, b} -> a * b end) |> Enum.sum()

    mag1 =
      vec1
      |> Enum.map(&(&1 * &1))
      |> Enum.sum()
      |> :math.sqrt()

    mag2 =
      vec2
      |> Enum.map(&(&1 * &1))
      |> Enum.sum()
      |> :math.sqrt()

    if mag1 == 0.0 or mag2 == 0.0 do
      0.0
    else
      similarity = dot_product / (mag1 * mag2)
      Float.round(similarity, 4)
    end
  end

  @doc false
  def to_signal(learning_signals) when is_map(learning_signals) do
    Signal.new(%{
      mode: :analyze,
      genre: :inform,
      type: :report,
      format: :json,
      weight: 0.8,
      content: Jason.encode!(learning_signals),
      metadata: %{"source" => "experience_store", "timestamp" => DateTime.utc_now()}
    })
  end
end
