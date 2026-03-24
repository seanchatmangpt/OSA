defmodule OptimalSystemAgent.Process.Fingerprint do
  @moduledoc """
  Process DNA Fingerprinting -- Innovation 4.

  Extracts a compressed, comparable "fingerprint" from process execution data
  using Signal Theory's S=(M,G,T,F,W) classification. Like a genomic
  fingerprint but for business processes.

  Each fingerprint captures the essential behavioral signature of a process:
  its signal vector, quantitative metrics, a deterministic pattern hash, and
  a compressed barcode for fast lookup and comparison.

  ## Signal Vector Dimensions

  | Dim | Name       | Values                                                   |
  |-----|------------|----------------------------------------------------------|
  | M   | Mode       | execute, analyze, communicate, coordinate               |
  | G   | Genre      | business, technical, creative, administrative           |
  | T   | Type       | sequential, parallel, conditional, iterative             |
  | F   | Format     | api_call, file_op, shell_cmd, web_search, memory         |
  | W   | Structure  | linear, branching, looping, mesh                         |

  ## ETS Tables

  * `:osa_fingerprints`       -- set, keyed by `{:id, fingerprint_id}`
  * `:osa_fingerprint_index`   -- bag, keyed by `{:process_type, type}`

  ## Usage

      {:ok, fp} = OptimalSystemAgent.Process.Fingerprint.extract_fingerprint(events, process_type: "crm_deal_flow")
      {:ok, comparison} = OptimalSystemAgent.Process.Fingerprint.compare_fingerprints(fp_a, fp_b)
      {:ok, evolution} = OptimalSystemAgent.Process.Fingerprint.evolution_track([fp_old, fp_new])
      {:ok, bench} = OptimalSystemAgent.Process.Fingerprint.industry_benchmark(fp, "saas")

  Reference: Signal Theory S=(M,G,T,F,W) -- Luna, R. (2026).
  """
  use GenServer
  require Logger

  # ---------------------------------------------------------------------------
  # Constants
  # ---------------------------------------------------------------------------

  @fingerprint_table :osa_fingerprints
  @index_table :osa_fingerprint_index

  # Industry benchmark baselines (averages from cross-industry analysis)
  @industry_benchmarks %{
    saas: %{
      avg_duration_ms: 2500,
      total_steps: 12,
      success_rate: 0.92,
      tool_diversity: 0.65,
      parallelism_score: 0.4,
      error_rate: 0.08
    },
    fintech: %{
      avg_duration_ms: 3500,
      total_steps: 18,
      success_rate: 0.96,
      tool_diversity: 0.5,
      parallelism_score: 0.3,
      error_rate: 0.04
    },
    healthcare: %{
      avg_duration_ms: 4000,
      total_steps: 15,
      success_rate: 0.89,
      tool_diversity: 0.45,
      parallelism_score: 0.25,
      error_rate: 0.11
    },
    ecommerce: %{
      avg_duration_ms: 2000,
      total_steps: 10,
      success_rate: 0.88,
      tool_diversity: 0.7,
      parallelism_score: 0.5,
      error_rate: 0.12
    },
    manufacturing: %{
      avg_duration_ms: 5000,
      total_steps: 22,
      success_rate: 0.94,
      tool_diversity: 0.35,
      parallelism_score: 0.2,
      error_rate: 0.06
    },
    default: %{
      avg_duration_ms: 3000,
      total_steps: 14,
      success_rate: 0.90,
      tool_diversity: 0.55,
      parallelism_score: 0.35,
      error_rate: 0.10
    }
  }

  # Thresholds
  @similarity_threshold_similar 0.75
  @similarity_threshold_identical 0.95
  @divergence_metric_threshold 0.2

  # ---------------------------------------------------------------------------
  # State
  # ---------------------------------------------------------------------------

  defstruct total_fingerprints: 0,
            process_type_counts: %{}

  # ---------------------------------------------------------------------------
  # Types
  # ---------------------------------------------------------------------------

  @type signal_vector :: %{
          M: String.t(),
          G: String.t(),
          T: String.t(),
          F: String.t(),
          W: String.t()
        }

  @type metrics :: %{
          avg_duration_ms: float(),
          total_steps: non_neg_integer(),
          success_rate: float(),
          tool_diversity: float(),
          parallelism_score: float(),
          error_rate: float()
        }

  @type fingerprint :: %{
          id: String.t(),
          process_type: String.t(),
          signal_vector: signal_vector(),
          metrics: metrics(),
          pattern_hash: String.t(),
          signature: String.t(),
          extracted_at: DateTime.t(),
          sample_size: non_neg_integer()
        }

  @type comparison :: %{
          similarity: float(),
          duration_diff_pct: float(),
          pattern_match: boolean(),
          signal_vector_distance: float(),
          divergent_metrics: [atom()],
          recommendation: String.t()
        }

  @type evolution :: %{
          velocity: float(),
          trajectory: :improving | :degrading | :stable | :stagnant,
          drift_score: float(),
          anomaly_detected: boolean(),
          predicted_state: map()
        }

  @type process_event :: %{
          tool_name: String.t(),
          duration_ms: number(),
          status: String.t(),
          timestamp: DateTime.t() | String.t(),
          session_id: String.t()
        }

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc "Start the fingerprint GenServer."
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Extract a fingerprint from process execution events.

  ## Options

  * `:process_type` -- human-readable process name (required)
  * `:precision`    -- decimal precision for metric canonicalization (default 2)
  """
  @spec extract_fingerprint([process_event()], keyword()) :: {:ok, fingerprint()} | {:error, term()}
  def extract_fingerprint(process_events, opts \\ []) do
    GenServer.call(__MODULE__, {:extract_fingerprint, process_events, opts})
  end

  @doc """
  Compare two fingerprints and return similarity analysis.

  Returns a similarity score between 0.0 (completely different) and 1.0 (identical),
  along with detailed divergence analysis.
  """
  @spec compare_fingerprints(fingerprint(), fingerprint()) :: {:ok, comparison()} | {:error, term()}
  def compare_fingerprints(fp_a, fp_b) do
    GenServer.call(__MODULE__, {:compare_fingerprints, fp_a, fp_b})
  end

  @doc """
  Track the evolution of a process over time.

  Takes fingerprints ordered chronologically (earliest first) and returns
  velocity, trajectory, drift, and anomaly detection metrics.
  """
  @spec evolution_track([fingerprint()]) :: {:ok, evolution()} | {:error, term()}
  def evolution_track(fingerprints) do
    GenServer.call(__MODULE__, {:evolution_track, fingerprints})
  end

  @doc """
  Benchmark a fingerprint against industry averages.

  ## Supported industries

  `saas`, `fintech`, `healthcare`, `ecommerce`, `manufacturing`, or `default`.
  """
  @spec industry_benchmark(fingerprint(), String.t()) :: {:ok, map()} | {:error, term()}
  def industry_benchmark(fingerprint, industry) do
    GenServer.call(__MODULE__, {:industry_benchmark, fingerprint, industry})
  end

  @doc "Look up a stored fingerprint by ID."
  @spec get_fingerprint(String.t()) :: fingerprint() | nil
  def get_fingerprint(id) do
    case :ets.lookup(@fingerprint_table, {:id, id}) do
      [{{:id, ^id}, fp}] -> fp
      [] -> nil
    end
  end

  @doc "List all fingerprint IDs for a given process type."
  @spec list_by_process_type(String.t()) :: [String.t()]
  def list_by_process_type(process_type) do
    :ets.lookup(@index_table, {:process_type, process_type})
    |> Enum.map(fn {{:process_type, ^process_type}, fp_id} -> fp_id end)
  end

  @doc "Return count of stored fingerprints."
  @spec count() :: non_neg_integer()
  def count do
    GenServer.call(__MODULE__, :count)
  end

  @doc "List all stored fingerprints (reads directly from ETS)."
  def list_all do
    :ets.tab2list(@fingerprint_table)
    |> Enum.map(fn {_key, fp} -> fp end)
  end

  # ---------------------------------------------------------------------------
  # GenServer Callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(_opts) do
    :ets.new(@fingerprint_table, [:set, :named_table, :public, read_concurrency: true])
    :ets.new(@index_table, [:bag, :named_table, :public, read_concurrency: true])

    Logger.info("[Process.Fingerprint] Started -- ETS tables initialized")

    {:ok, %__MODULE__{}}
  end

  @impl true
  def handle_call({:extract_fingerprint, events, opts}, _from, state) do
    process_type = Keyword.get(opts, :process_type, "unknown")
    precision = Keyword.get(opts, :precision, 2)

    case do_extract_fingerprint(events, process_type, precision) do
      {:ok, fingerprint} ->
        store_fingerprint(fingerprint)

        type_counts =
          Map.update(state.process_type_counts, process_type, 1, &(&1 + 1))

        new_state = %{
          state
          | total_fingerprints: state.total_fingerprints + 1,
            process_type_counts: type_counts
        }

        {:reply, {:ok, fingerprint}, new_state}

      {:error, _} = err ->
        {:reply, err, state}
    end
  end

  @impl true
  def handle_call({:compare_fingerprints, fp_a, fp_b}, _from, state) do
    result = do_compare_fingerprints(fp_a, fp_b)
    {:reply, result, state}
  end

  @impl true
  def handle_call({:evolution_track, fingerprints}, _from, state) do
    result = do_evolution_track(fingerprints)
    {:reply, result, state}
  end

  @impl true
  def handle_call({:industry_benchmark, fingerprint, industry}, _from, state) do
    result = do_industry_benchmark(fingerprint, industry)
    {:reply, result, state}
  end

  @impl true
  def handle_call(:count, _from, state) do
    {:reply, state.total_fingerprints, state}
  end

  # ---------------------------------------------------------------------------
  # Fingerprint Extraction (Core)
  # ---------------------------------------------------------------------------

  defp do_extract_fingerprint(events, process_type, precision) when is_list(events) and length(events) > 0 do
    metrics = compute_metrics(events, precision)
    signal_vector = classify_signal_vector(events, metrics)

    pattern_hash = compute_pattern_hash(signal_vector, metrics, precision)
    signature = compute_signature(signal_vector, pattern_hash)
    fingerprint_id = "fp_#{pattern_hash |> String.slice(0, 16)}"

    fingerprint = %{
      id: fingerprint_id,
      process_type: process_type,
      signal_vector: signal_vector,
      metrics: metrics,
      pattern_hash: pattern_hash,
      signature: signature,
      extracted_at: DateTime.utc_now(),
      sample_size: length(events)
    }

    {:ok, fingerprint}
  end

  defp do_extract_fingerprint([], _process_type, _precision) do
    {:error, :empty_events}
  end

  defp do_extract_fingerprint(_events, _process_type, _precision) do
    {:error, :invalid_events}
  end

  # ---------------------------------------------------------------------------
  # Metrics Computation
  # ---------------------------------------------------------------------------

  defp compute_metrics(events, precision) do
    durations = Enum.map(events, &parse_duration/1)
    statuses = Enum.map(events, &Map.get(&1, :status, "unknown"))
    tools = Enum.map(events, &Map.get(&1, :tool_name, "unknown"))
    sessions = Enum.map(events, &Map.get(&1, :session_id, nil))

    total = length(events)
    total_duration = Enum.sum(durations)

    # Success rate: "success" or "completed" statuses
    successes =
      Enum.count(statuses, fn s ->
        String.downcase(to_string(s)) in ["success", "completed", "ok"]
      end)

    # Error rate: "error", "failed", "timeout" statuses
    errors =
      Enum.count(statuses, fn s ->
        String.downcase(to_string(s)) in ["error", "failed", "timeout", "exception"]
      end)

    # Tool diversity: unique tools / total steps (Shannon-like)
    unique_tools = tools |> Enum.uniq() |> length()
    tool_diversity = if total > 0, do: unique_tools / total, else: 0.0

    # Parallelism score: ratio of unique sessions to total events
    unique_sessions = sessions |> Enum.reject(&is_nil/1) |> Enum.uniq() |> length()
    parallelism_score =
      if total > 0 and unique_sessions > 0 do
        min(1.0, unique_sessions / total * unique_sessions)
      else
        0.0
      end

    %{
      avg_duration_ms: Float.round(total_duration / total, precision),
      total_steps: total,
      success_rate: Float.round(successes / total, precision),
      tool_diversity: Float.round(tool_diversity, precision),
      parallelism_score: Float.round(parallelism_score, precision),
      error_rate: Float.round(errors / total, precision)
    }
  end

  defp parse_duration(%{duration_ms: d}) when is_number(d), do: d * 1.0
  defp parse_duration(_), do: 0.0

  # ---------------------------------------------------------------------------
  # Signal Vector Classification
  # ---------------------------------------------------------------------------

  defp classify_signal_vector(events, metrics) do
    tools = Enum.map(events, &Map.get(&1, :tool_name, ""))
    sessions = Enum.map(events, &Map.get(&1, :session_id, nil))
    timestamps = Enum.map(events, &parse_timestamp/1)
    statuses = Enum.map(events, &Map.get(&1, :status, "unknown"))

    %{
      M: classify_mode(tools, metrics),
      G: classify_genre(tools, metrics),
      T: classify_type(timestamps, sessions, metrics),
      F: classify_format(tools, metrics),
      W: classify_structure(timestamps, sessions, statuses)
    }
  end

  # M (Mode): Classify based on dominant tool types
  defp classify_mode(tools, metrics) do
    tool_str = Enum.join(tools, " ") |> String.downcase()

    # Weighted scoring across tool name patterns
    scores = %{
      execute: score_patterns(tool_str, [
        ~r/exec|run|invoke|call|trigger|send|deploy|start|stop|restart|provision/i
      ]),
      analyze: score_patterns(tool_str, [
        ~r/analy|report|metric|query|search|scan|inspect|measure|monitor|dashboard/i
      ]),
      communicate: score_patterns(tool_str, [
        ~r/email|slack|notify|message|notify|sms|webhook|notify|chat|post|broadcast/i
      ]),
      coordinate: score_patterns(tool_str, [
        ~r/schedul|queue|dispatch|route|assign|delegate|orchestrat|workflow|approve/i
      ])
    }

    # If tool patterns are weak, use metrics to infer mode
    {dominant, _score} =
      if Enum.sum(Map.values(scores)) == 0 do
        cond do
          metrics.error_rate > 0.3 -> {"execute", 1.0}
          metrics.parallelism_score > 0.5 -> {"coordinate", 1.0}
          metrics.tool_diversity > 0.7 -> {"analyze", 1.0}
          true -> {"execute", 1.0}
        end
      else
        Enum.max_by(scores, fn {_k, v} -> v end)
      end

    dominant
  end

  # G (Genre): Classify based on BusinessOS domain
  defp classify_genre(tools, metrics) do
    tool_str = Enum.join(tools, " ") |> String.downcase()

    scores = %{
      business: score_patterns(tool_str, [
        ~r/crm|deal|invoice|customer|order|payment|billing|contract|sales|revenue|lead/i
      ]),
      technical: score_patterns(tool_str, [
        ~r/deploy|build|test|compile|docker|git|ci|cd|server|api|database|cache|queue/i
      ]),
      creative: score_patterns(tool_str, [
        ~r/design|image|video|render|generat|content|write|draft|edit|compose|creative/i
      ]),
      administrative: score_patterns(tool_str, [
        ~r/fil|record|log|archive|backup|sync|import|export|clean|organiz|sort|audit/i
      ])
    }

    {dominant, _score} =
      if Enum.sum(Map.values(scores)) == 0 do
        cond do
          metrics.success_rate > 0.95 -> {"technical", 1.0}
          metrics.tool_diversity < 0.3 -> {"administrative", 1.0}
          true -> {"business", 1.0}
        end
      else
        Enum.max_by(scores, fn {_k, v} -> v end)
      end

    dominant
  end

  # T (Type): Classify based on execution pattern
  defp classify_type(timestamps, sessions, metrics) do
    has_overlap = detect_temporal_overlap?(timestamps)

    cond do
      metrics.parallelism_score > 0.5 and has_overlap ->
        "parallel"

      metrics.error_rate > 0.2 ->
        "conditional"

      detect_repeated_tool_sequences?(timestamps, sessions) ->
        "iterative"

      true ->
        "sequential"
    end
  end

  # F (Format): Classify based on tool format
  defp classify_format(tools, _metrics) do
    tool_str = Enum.join(tools, " ") |> String.downcase()

    scores = %{
      api_call: score_patterns(tool_str, [~r/api|http|rest|graphql|endpoint|request/i]),
      file_op: score_patterns(tool_str, [~r/file|read|write|upload|download|save|open|path|dir/i]),
      shell_cmd: score_patterns(tool_str, [~r/shell|bash|cmd|exec|terminal|run_command|script/i]),
      web_search: score_patterns(tool_str, [~r/search|browse|scrape|fetch|crawl|lookup|google/i]),
      memory: score_patterns(tool_str, [~r/memory|store|cache|remember|recall|ets|redis|db/i])
    }

    {dominant, _score} =
      if Enum.sum(Map.values(scores)) == 0 do
        {"api_call", 1.0}
      else
        Enum.max_by(scores, fn {_k, v} -> v end)
      end

    dominant
  end

  # W (Structure): Classify based on workflow shape
  defp classify_structure(timestamps, sessions, statuses) do
    has_overlap = detect_temporal_overlap?(timestamps)
    unique_sessions = sessions |> Enum.reject(&is_nil/1) |> Enum.uniq() |> length()
    has_errors = Enum.any?(statuses, fn s ->
      String.downcase(to_string(s)) in ["error", "failed"]
    end)
    has_loops = detect_repeated_tool_sequences?(timestamps, sessions)

    cond do
      has_loops and has_errors ->
        "mesh"

      has_loops ->
        "looping"

      has_overlap and unique_sessions > 2 ->
        "branching"

      true ->
        "linear"
    end
  end

  # ---------------------------------------------------------------------------
  # Pattern Hash & Signature
  # ---------------------------------------------------------------------------

  defp compute_pattern_hash(signal_vector, metrics, precision) do
    # Canonicalize: fixed precision, deterministic key order
    canonical =
      [
        "M:#{Map.get(signal_vector, :M)}",
        "G:#{Map.get(signal_vector, :G)}",
        "T:#{Map.get(signal_vector, :T)}",
        "F:#{Map.get(signal_vector, :F)}",
        "W:#{Map.get(signal_vector, :W)}",
        "avg_duration_ms:#{Float.round(metrics.avg_duration_ms, precision)}",
        "total_steps:#{metrics.total_steps}",
        "success_rate:#{Float.round(metrics.success_rate, precision)}",
        "tool_diversity:#{Float.round(metrics.tool_diversity, precision)}",
        "parallelism_score:#{Float.round(metrics.parallelism_score, precision)}",
        "error_rate:#{Float.round(metrics.error_rate, precision)}"
      ]
      |> Enum.join("|")

    :crypto.hash(:sha256, canonical) |> Base.encode16(case: :lower)
  end

  defp compute_signature(signal_vector, pattern_hash) do
    # Compress signal vector + first 8 bytes of pattern hash into a short barcode
    vector_str =
      "#{Map.get(signal_vector, :M)}.#{Map.get(signal_vector, :G)}.#{Map.get(signal_vector, :T)}.#{Map.get(signal_vector, :F)}.#{Map.get(signal_vector, :W)}"

    payload = "#{vector_str}:#{String.slice(pattern_hash, 0, 8)}"
    Base.url_encode64(payload, padding: false)
  end

  # ---------------------------------------------------------------------------
  # Fingerprint Comparison
  # ---------------------------------------------------------------------------

  defp do_compare_fingerprints(fp_a, fp_b) do
    metric_similarity = compute_metric_similarity(fp_a.metrics, fp_b.metrics)
    vector_distance = compute_vector_distance(fp_a.signal_vector, fp_b.signal_vector)

    # Weighted combination: 70% metrics, 30% signal vector
    similarity = Float.round(0.7 * metric_similarity + 0.3 * (1.0 - vector_distance), 4)

    duration_diff_pct = compute_duration_diff_pct(fp_a.metrics, fp_b.metrics)

    divergent_metrics = find_divergent_metrics(fp_a.metrics, fp_b.metrics)

    recommendation =
      cond do
        similarity >= @similarity_threshold_identical -> "identical_process"
        similarity >= @similarity_threshold_similar -> "similar_process"
        similarity >= 0.4 -> "related_process"
        true -> "distinct_process"
      end

    {:ok,
     %{
       similarity: similarity,
       duration_diff_pct: duration_diff_pct,
       pattern_match: fp_a.pattern_hash == fp_b.pattern_hash,
       signal_vector_distance: Float.round(vector_distance, 4),
       divergent_metrics: divergent_metrics,
       recommendation: recommendation
     }}
  end

  defp compute_metric_similarity(m_a, m_b) do
    numeric_keys = [:avg_duration_ms, :success_rate, :tool_diversity, :parallelism_score, :error_rate]

    # Normalize each metric to 0..1 range for comparison
    # Use the max of both values as the normalizer to handle scale differences
    similarities =
      Enum.map(numeric_keys, fn key ->
        val_a = Map.get(m_a, key, 0.0)
        val_b = Map.get(m_b, key, 0.0)

        if val_a == 0.0 and val_b == 0.0 do
          1.0
        else
          max_val = max(abs(val_a), abs(val_b))
          if max_val == 0.0, do: 1.0, else: 1.0 - abs(val_a - val_b) / max_val
        end
      end)

    # Steps similarity: closeness ratio
    steps_sim =
      case {m_a.total_steps, m_b.total_steps} do
        {0, 0} -> 1.0
        {a, b} -> min(a, b) / max(a, b)
      end

    all_sims = [steps_sim | similarities]
    Enum.sum(all_sims) / length(all_sims)
  end

  defp compute_vector_distance(v_a, v_b) do
    # Hamming-like distance: fraction of dimensions that differ
    dims = [:M, :G, :T, :F, :W]
    differences = Enum.count(dims, fn dim -> Map.get(v_a, dim) != Map.get(v_b, dim) end)
    differences / length(dims)
  end

  defp compute_duration_diff_pct(m_a, m_b) do
    base = max(m_a.avg_duration_ms, m_b.avg_duration_ms)

    if base == 0.0 do
      0.0
    else
      Float.round(abs(m_a.avg_duration_ms - m_b.avg_duration_ms) / base * 100, 1)
    end
  end

  defp find_divergent_metrics(m_a, m_b) do
    numeric_keys = [:avg_duration_ms, :success_rate, :tool_diversity, :parallelism_score, :error_rate]

    Enum.filter(numeric_keys, fn key ->
      val_a = Map.get(m_a, key, 0.0)
      val_b = Map.get(m_b, key, 0.0)
      max_val = max(abs(val_a), abs(val_b))

      if max_val == 0.0 do
        false
      else
        abs(val_a - val_b) / max_val > @divergence_metric_threshold
      end
    end)
  end

  # ---------------------------------------------------------------------------
  # Evolution Tracking
  # ---------------------------------------------------------------------------

  defp do_evolution_track([_single]) do
    {:ok,
     %{
       velocity: 0.0,
       trajectory: :stable,
       drift_score: 0.0,
       anomaly_detected: false,
       predicted_state: %{}
     }}
  end

  defp do_evolution_track(fingerprints) when is_list(fingerprints) and length(fingerprints) >= 2 do
    # Sort by extraction time (earliest first)
    sorted = Enum.sort_by(fingerprints, & &1.extracted_at, DateTime)

    # Compute pairwise drifts between consecutive fingerprints
    pairwise_drifts =
      sorted
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.map(fn [a, b] -> compute_pairwise_drift(a, b) end)

    # Velocity: average normalized change per time interval
    time_span_days = compute_time_span_days(sorted)

    velocity =
      if time_span_days > 0 do
        Float.round(Enum.sum(pairwise_drifts) / length(pairwise_drifts) / time_span_days * 7, 2)
      else
        0.0
      end

    # Drift score: cumulative drift from oldest to newest
    drift_score =
      case {List.first(sorted), List.last(sorted)} do
        {nil, nil} -> 0.0
        {first, last} -> compute_pairwise_drift(first, last)
      end

    # Trajectory: compare first-half average to second-half average
    trajectory = classify_trajectory(sorted)

    # Anomaly detection: Z-score on drift values
    anomaly_detected = detect_anomaly?(pairwise_drifts)

    # Predicted state: linear extrapolation of metric trends
    predicted_state = extrapolate_metrics(sorted)

    {:ok,
     %{
       velocity: velocity,
       trajectory: trajectory,
       drift_score: Float.round(drift_score, 4),
       anomaly_detected: anomaly_detected,
       predicted_state: predicted_state
     }}
  end

  defp do_evolution_track([]) do
    {:error, :empty_fingerprints}
  end

  defp do_evolution_track(_) do
    {:error, :invalid_fingerprints}
  end

  defp compute_pairwise_drift(fp_a, fp_b) do
    metric_keys = [:avg_duration_ms, :success_rate, :tool_diversity, :parallelism_score, :error_rate]

    drifts =
      Enum.map(metric_keys, fn key ->
        val_a = Map.get(fp_a.metrics, key, 0.0)
        val_b = Map.get(fp_b.metrics, key, 0.0)
        max_val = max(abs(val_a), abs(val_b))

        if max_val == 0.0, do: 0.0, else: abs(val_a - val_b) / max_val
      end)

    # Include signal vector change
    vector_change = compute_vector_distance(fp_a.signal_vector, fp_b.signal_vector)

    all_drifts = [vector_change | drifts]
    Enum.sum(all_drifts) / length(all_drifts)
  end

  defp compute_time_span_days([_]), do: 0.0

  defp compute_time_span_days(sorted) do
    first = List.first(sorted)
    last = List.last(sorted)

    DateTime.diff(last.extracted_at, first.extracted_at, :second) / 86400
  end

  defp classify_trajectory(sorted) do
    midpoint = div(length(sorted), 2)

    {first_half, second_half} = Enum.split(sorted, midpoint)

    if length(first_half) < 1 or length(second_half) < 1 do
      :stable
    else
      avg_success_first = average_metric(first_half, :success_rate)
      avg_success_second = average_metric(second_half, :success_rate)
      avg_error_first = average_metric(first_half, :error_rate)
      avg_error_second = average_metric(second_half, :error_rate)

      success_delta = avg_success_second - avg_success_first
      error_delta = avg_error_second - avg_error_first

      cond do
        success_delta > 0.05 and error_delta < -0.03 -> :improving
        success_delta < -0.05 and error_delta > 0.03 -> :degrading
        abs(success_delta) < 0.02 and abs(error_delta) < 0.02 -> :stagnant
        true -> :stable
      end
    end
  end

  defp average_metric(fingerprints, key) do
    values = Enum.map(fingerprints, &Map.get(&1.metrics, key, 0.0))

    if length(values) > 0 do
      Enum.sum(values) / length(values)
    else
      0.0
    end
  end

  defp detect_anomaly?(drifts) when length(drifts) < 3 do
    false
  end

  defp detect_anomaly?(drifts) do
    mean = Enum.sum(drifts) / length(drifts)
    variance = Enum.sum(Enum.map(drifts, fn d -> (d - mean) * (d - mean) end)) / length(drifts)
    std_dev = :math.sqrt(variance)

    # A value is anomalous if it exceeds 2 standard deviations from the mean
    Enum.any?(drifts, fn d -> abs(d - mean) > 2 * std_dev end)
  end

  defp extrapolate_metrics(sorted) do
    # Simple linear regression on the most recent N fingerprints
    recent = Enum.take(sorted, -5)
    n = length(recent)

    if n < 2 do
      %{}
    else
      metric_keys = [:avg_duration_ms, :success_rate, :tool_diversity, :parallelism_score, :error_rate]
      last_fp = List.last(recent)

      predictions =
        Enum.map(metric_keys, fn key ->
          values = Enum.map(recent, &Map.get(&1.metrics, key, 0.0))

          # Linear regression: y = slope * x + intercept
          {slope, _intercept} = linear_regression(values)

          predicted = Float.round(last_fp.metrics[key] + slope, 4)
          {key, predicted}
        end)
        |> Map.new()

      # Predict signal vector: majority vote of last 3
      predicted_vector =
        [:M, :G, :T, :F, :W]
        |> Enum.map(fn dim ->
          recent_vectors = Enum.map(recent, &Map.get(&1.signal_vector, dim))
          {dim, mode(recent_vectors)}
        end)
        |> Map.new()

      Map.put(predictions, :signal_vector, predicted_vector)
    end
  end

  defp linear_regression(values) do
    n = length(values)
    indices = Enum.to_list(0..(n - 1))

    sum_x = Enum.sum(indices)
    sum_y = Enum.sum(values)
    sum_xy = Enum.zip(indices, values) |> Enum.map(fn {x, y} -> x * y end) |> Enum.sum()
    sum_xx = Enum.map(indices, fn x -> x * x end) |> Enum.sum()

    denominator = n * sum_xx - sum_x * sum_x

    if denominator == 0 do
      {0.0, sum_y / n}
    else
      slope = (n * sum_xy - sum_x * sum_y) / denominator
      intercept = (sum_y - slope * sum_x) / n
      {slope, intercept}
    end
  end

  defp mode(list) do
    list
    |> Enum.frequencies()
    |> Enum.max_by(fn {_val, count} -> count end, fn -> {nil, 0} end)
    |> elem(0)
  end

  # ---------------------------------------------------------------------------
  # Industry Benchmarking
  # ---------------------------------------------------------------------------

  defp do_industry_benchmark(fingerprint, industry) do
    industry_key =
      industry
      |> String.downcase()
      |> String.to_atom()

    benchmark =
      Map.get(@industry_benchmarks, industry_key, @industry_benchmarks.default)

    metric_keys = [:avg_duration_ms, :total_steps, :success_rate, :tool_diversity, :parallelism_score, :error_rate]

    # Compute per-metric comparison
    metric_comparisons =
      Enum.map(metric_keys, fn key ->
        actual = Map.get(fingerprint.metrics, key, 0.0)
        expected = Map.get(benchmark, key, 0.0)

        # For error_rate, lower is better; for everything else, closer to industry avg is neutral
        diff =
          if expected == 0.0 do
            0.0
          else
            Float.round((actual - expected) / expected * 100, 1)
          end

        # Determine if this metric is favorable
        favorable? =
          case key do
            :error_rate -> actual < expected
            :success_rate -> actual > expected
            :total_steps -> abs(diff) < 30.0  # steps close to norm is fine
            _ -> abs(diff) < 20.0  # other metrics: within 20% of benchmark
          end

        {key, %{actual: actual, benchmark: expected, diff_pct: diff, favorable: favorable?}}
      end)
      |> Map.new()

    # Overall score: weighted average of how close to benchmark
    overall_score =
      metric_keys
      |> Enum.map(fn key ->
        actual = Map.get(fingerprint.metrics, key, 0.0)
        expected = Map.get(benchmark, key, 0.0)

        if expected == 0.0 do
          1.0
        else
          1.0 - min(1.0, abs(actual - expected) / expected)
        end
      end)
      |> Enum.sum()
      |> then(fn sum -> Float.round(sum / length(metric_keys) * 100, 1) end)

    favorable_count =
      metric_comparisons
      |> Map.values()
      |> Enum.count(& &1.favorable?)

    total_count = map_size(metric_comparisons)

    # Signal vector comparison
    vector_insights = analyze_vector_vs_industry(fingerprint.signal_vector, industry_key)

    {:ok,
     %{
       industry: industry,
       overall_score: overall_score,
       favorable_metrics: favorable_count,
       total_metrics: total_count,
       metric_comparisons: metric_comparisons,
       signal_vector_insights: vector_insights,
       recommendation: benchmark_recommendation(overall_score, favorable_count, total_count)
     }}
  end

  defp analyze_vector_vs_industry(_signal_vector, :default) do
    %{
      dominant_mode: "varies",
      dominant_genre: "varies",
      note: "No industry-specific signal vector data available for default category"
    }
  end

  defp analyze_vector_vs_industry(signal_vector, industry_key) do
    # Expected dominant dimensions per industry
    expected_dominants = %{
      saas: %{M: "execute", G: "technical", T: "parallel", F: "api_call", W: "linear"},
      fintech: %{M: "execute", G: "business", T: "sequential", F: "api_call", W: "linear"},
      healthcare: %{M: "coordinate", G: "business", T: "sequential", F: "api_call", W: "branching"},
      ecommerce: %{M: "execute", G: "business", T: "parallel", F: "api_call", W: "branching"},
      manufacturing: %{M: "coordinate", G: "technical", T: "sequential", F: "shell_cmd", W: "linear"}
    }

    expected = Map.get(expected_dominants, industry_key, %{})

    matches =
      [:M, :G, :T, :F, :W]
      |> Enum.map(fn dim ->
        actual = Map.get(signal_vector, dim)
        exp = Map.get(expected, dim, "varies")
        {dim, %{actual: actual, expected: exp, match: actual == exp}}
      end)
      |> Map.new()

    match_count = matches |> Map.values() |> Enum.count(& &1.match)

    %{
      dominant_mode: Map.get(signal_vector, :M),
      dominant_genre: Map.get(signal_vector, :G),
      dimension_matches: matches,
      match_count: match_count,
      total_dimensions: 5
    }
  end

  defp benchmark_recommendation(overall_score, favorable, total) do
    ratio = favorable / total

    cond do
      overall_score >= 90 and ratio >= 0.8 ->
        "best_in_class -- process performs above industry benchmarks"

      overall_score >= 75 and ratio >= 0.6 ->
        "competitive -- process is aligned with industry standards"

      overall_score >= 50 ->
        "needs_attention -- some metrics deviate significantly from benchmarks"

      true ->
        "requires_improvement -- process metrics substantially below industry norms"
    end
  end

  # ---------------------------------------------------------------------------
  # ETS Storage
  # ---------------------------------------------------------------------------

  defp store_fingerprint(fingerprint) do
    :ets.insert(@fingerprint_table, {{:id, fingerprint.id}, fingerprint})
    :ets.insert(@index_table, {{:process_type, fingerprint.process_type}, fingerprint.id})

    Logger.debug(
      "[Process.Fingerprint] Stored #{fingerprint.id} " <>
        "(type: #{fingerprint.process_type}, sample: #{fingerprint.sample_size})"
    )
  end

  # ---------------------------------------------------------------------------
  # Temporal Analysis Helpers
  # ---------------------------------------------------------------------------

  defp parse_timestamp(%{timestamp: %DateTime{} = dt}), do: dt
  defp parse_timestamp(%{timestamp: ts}) when is_binary(ts) do
    case DateTime.from_iso8601(ts) do
      {:ok, dt, _offset} -> dt
      _ -> DateTime.utc_now()
    end
  end
  defp parse_timestamp(_), do: DateTime.utc_now()

  defp detect_temporal_overlap?(timestamps) do
    # Sort timestamps and check if any adjacent pair is within 100ms (suggests parallelism)
    sorted = Enum.sort(timestamps, DateTime)

    sorted
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.any?(fn [a, b] ->
      abs(DateTime.diff(b, a, :millisecond)) < 100
    end)
  end

  defp detect_repeated_tool_sequences?(_timestamps, sessions) do
    # Detect repeated tool usage patterns as a proxy for iteration
    # If the same session appears with multiple events, it may indicate iteration
    session_counts = Enum.frequencies(sessions)

    session_counts
    |> Map.values()
    |> Enum.any?(fn count -> count >= 3 end)
  end

  # ---------------------------------------------------------------------------
  # Pattern Scoring Helpers
  # ---------------------------------------------------------------------------

  defp score_patterns(text, patterns) do
    Enum.reduce(patterns, 0, fn pattern, acc ->
      if Regex.match?(pattern, text), do: acc + 1, else: acc
    end)
  end
end
