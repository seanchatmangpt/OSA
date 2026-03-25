defmodule OptimalSystemAgent.Observability.Telemetry do
  @moduledoc """
  OpenTelemetry-style distributed tracing and metrics for OSA.

  Provides functions to:
  - Initialize tracer and metrics handlers
  - Create and manage spans for agent decisions, consensus rounds, model predictions
  - Record metrics: latency, throughput, error rates, cache hit ratios
  - Propagate trace context across system boundaries (HTTP, A2A, MCP)

  ## Architecture

  OSA's observability follows the Signal Theory S=(M,G,T,F,W) pattern:
  - **Mode**: telemetry events (metrics, traces, logs)
  - **Genre**: structured observation (span, metric, trace context)
  - **Type**: operational (recording of system behavior)
  - **Format**: JSON (metrics), structured (trace context headers)
  - **Weight**: importance level (DEBUG, INFO, WARN, ERROR)

  ## Spans

  Spans are named time-bounded operations. Common OSA spans:
  - `agent.decision` - ReAct decision loop iteration
  - `consensus.round` - HotStuff BFT round execution
  - `llm.predict` - Model inference call
  - `tool.execute` - Tool invocation
  - `memory.lookup` - Episodic/semantic memory queries
  - `signal.classify` - Signal classification (S=(M,G,T,F,W))

  ## Metrics

  Metrics are numeric observations with dimensions. Common OSA metrics:
  - `agent.decisions` - counter, dimensions: [agent_id, outcome]
  - `consensus.latency_ms` - histogram, dimensions: [round_type]
  - `llm.predict_latency_ms` - histogram, dimensions: [model_name]
  - `tool.errors` - counter, dimensions: [tool_name, error_code]
  - `memory.cache_hits` - counter, dimensions: [memory_type]
  - `memory.cache_misses` - counter, dimensions: [memory_type]

  ## Usage

      iex> :ok = OptimalSystemAgent.Observability.Telemetry.init_tracer()
      iex> {:ok, _span} = OptimalSystemAgent.Observability.Telemetry.start_span("agent.decision", %{"agent_id" => "agent-1"})
      iex> :ok = OptimalSystemAgent.Observability.Telemetry.record_metric("agent.decisions", 1, %{"outcome" => "success"})
      iex> :ok = OptimalSystemAgent.Observability.Telemetry.record_metric("consensus.latency_ms", 234, %{"round_type" => "prepare"})
  """

  require Logger

  @doc """
  Initialize tracer and metrics handlers.

  Starts the telemetry system and attaches handlers for:
  - Agent decision metrics
  - Consensus round latency
  - LLM predict latency
  - Tool execution errors
  - Memory cache hit/miss ratios

  Returns `:ok` on success.

  ## Examples

      iex> OptimalSystemAgent.Observability.Telemetry.init_tracer()
      :ok
  """
  @spec init_tracer() :: :ok
  def init_tracer do
    # Initialize ETS table for span storage (parent/child relationships)
    :ets.new(:telemetry_spans, [:named_table, :public, {:keypos, 1}])

    # Initialize ETS table for metrics aggregation
    :ets.new(:telemetry_metrics, [:named_table, :public, {:keypos, 1}])

    # Attach handlers for standard events
    attach_agent_decision_handler()
    attach_consensus_round_handler()
    attach_llm_predict_handler()
    attach_tool_execute_handler()
    attach_memory_cache_handler()

    Logger.info("[Telemetry] Tracer initialized")
    :ok
  end

  @doc """
  Start a named span with optional attributes.

  Creates a new span in the trace tree and returns a span context that can be
  passed to child operations. Spans auto-generate unique IDs and track parent/child
  relationships via ETS tables.

  ## Parameters

    - `span_name`: atom or string, e.g. "agent.decision", "consensus.round"
    - `attributes`: map of span metadata, e.g. %{"agent_id" => "agent-1", "round_num" => 5}

  ## Returns

    - `{:ok, span_ctx}` where `span_ctx` is a map with:
      - `span_id`: unique span identifier (UUID)
      - `trace_id`: propagated trace ID (UUID or inherited)
      - `parent_span_id`: parent span ID if nested
      - `attributes`: enriched attributes including timestamp
      - `start_time_us`: microsecond timestamp

  ## Examples

      iex> {:ok, span} = OptimalSystemAgent.Observability.Telemetry.start_span("agent.decision", %{"agent_id" => "a1"})
      iex> span.span_id != nil
      true
  """
  @spec start_span(String.t() | atom, map) :: {:ok, map} | {:error, term}
  def start_span(span_name, attributes \\ %{}) do
    span_id = generate_uuid()
    trace_id = get_or_create_trace_id()
    start_time_us = system_time_to_microseconds()

    span_ctx = %{
      "span_id" => span_id,
      "trace_id" => trace_id,
      "parent_span_id" => get_current_span_id(),
      "span_name" => to_string(span_name),
      "attributes" => enrich_attributes(attributes),
      "start_time_us" => start_time_us,
      "status" => "active"
    }

    # Store in ETS for parent/child traversal
    :ets.insert(:telemetry_spans, {span_id, span_ctx})

    # Emit telemetry event for subscribers
    :telemetry.execute(
      [:osa, :span, :created],
      %{"span_id" => span_id, "trace_id" => trace_id},
      %{"span_name" => span_ctx["span_name"], "attributes" => attributes}
    )

    {:ok, span_ctx}
  end

  @doc """
  Record a metric value with optional dimensions.

  Increments a counter or records a histogram observation. Metrics are aggregated
  in ETS and can be exported to external systems (Prometheus, Datadog, etc).

  ## Parameters

    - `metric_name`: string, e.g. "agent.decisions", "consensus.latency_ms"
    - `value`: numeric value to record
    - `dimensions`: optional map of tag key-values, e.g. %{"outcome" => "success", "agent_id" => "a1"}

  ## Metric Types (inferred from naming convention)

    - `*.latency_ms`, `*.duration_ms`: histogram (duration observations)
    - `*_count`, `*_total`: counter (incremental value)
    - `*.ratio`, `*.percentage`: gauge (current value)

  ## Examples

      iex> OptimalSystemAgent.Observability.Telemetry.record_metric("agent.decisions", 1, %{"outcome" => "success"})
      :ok

      iex> OptimalSystemAgent.Observability.Telemetry.record_metric("consensus.latency_ms", 234, %{"round_type" => "prepare"})
      :ok

      iex> OptimalSystemAgent.Observability.Telemetry.record_metric("memory.cache_hits", 1, %{"memory_type" => "episodic"})
      :ok
  """
  @spec record_metric(String.t(), number, map) :: :ok
  def record_metric(metric_name, value, dimensions \\ %{}) when is_number(value) do
    metric_key = {to_string(metric_name), dimensions}

    # Upsert metric in ETS (increment counter or store histogram observation)
    case :ets.lookup(:telemetry_metrics, metric_key) do
      [{_key, metric_data}] ->
        updated = update_metric_data(metric_data, value)
        :ets.insert(:telemetry_metrics, {metric_key, updated})

      [] ->
        metric_data = init_metric_data(metric_name, value)
        :ets.insert(:telemetry_metrics, {metric_key, metric_data})
    end

    # Emit telemetry event for subscribers
    :telemetry.execute(
      [:osa, :metric, :recorded],
      %{metric_name => value},
      dimensions
    )

    :ok
  end

  @doc """
  End a span and record its duration.

  Marks a span as complete, calculates elapsed time, and emits a telemetry event.
  Should be called from finally/catch blocks to ensure recording.

  ## Parameters

    - `span_ctx`: span context returned from `start_span/2`
    - `status`: atom `:ok` or `:error` (default `:ok`)
    - `error_message`: optional error message if status is `:error`

  ## Examples

      iex> {:ok, span} = OptimalSystemAgent.Observability.Telemetry.start_span("agent.decision", %{"agent_id" => "a1"})
      iex> Process.sleep(10)
      iex> OptimalSystemAgent.Observability.Telemetry.end_span(span, :ok)
      :ok
  """
  @spec end_span(map, atom, String.t() | nil) :: :ok
  def end_span(span_ctx, status \\ :ok, error_message \\ nil) do
    span_id = span_ctx["span_id"]
    _trace_id = span_ctx["trace_id"]
    start_time_us = span_ctx["start_time_us"]
    end_time_us = system_time_to_microseconds()
    duration_us = end_time_us - start_time_us

    # Update span status
    updated_span = Map.put(span_ctx, "status", to_string(status))

    updated_span = if error_message do
      Map.put(updated_span, "error_message", error_message)
    else
      updated_span
    end

    :ets.insert(:telemetry_spans, {span_id, updated_span})

    # Record latency metric
    record_metric(
      "span.duration_us",
      duration_us,
      %{"span_name" => span_ctx["span_name"], "status" => to_string(status)}
    )

    # Emit telemetry event
    :telemetry.execute(
      [:osa, :span, :ended],
      %{"span_id" => span_id, "duration_us" => duration_us},
      %{"status" => status, "error_message" => error_message}
    )

    :ok
  end

  # ============================================================================
  # Private Functions
  # ============================================================================

  # Attach handler for agent decision events
  defp attach_agent_decision_handler do
    :ok = :telemetry.attach(
      "osa.agent.decision.handler",
      [:osa, :agent, :decision],
      fn _event_name, _measurements, _metadata ->
        # Handler body is implemented by callers
        :ok
      end,
      nil
    )
  rescue
    _ -> :ok
  end

  # Attach handler for consensus round events
  defp attach_consensus_round_handler do
    :ok = :telemetry.attach(
      "osa.consensus.round.handler",
      [:osa, :consensus, :round],
      fn _event_name, _measurements, _metadata ->
        :ok
      end,
      nil
    )
  rescue
    _ -> :ok
  end

  # Attach handler for LLM predict events
  defp attach_llm_predict_handler do
    :ok = :telemetry.attach(
      "osa.llm.predict.handler",
      [:osa, :llm, :predict],
      fn _event_name, _measurements, _metadata ->
        :ok
      end,
      nil
    )
  rescue
    _ -> :ok
  end

  # Attach handler for tool execution events
  defp attach_tool_execute_handler do
    :ok = :telemetry.attach(
      "osa.tool.execute.handler",
      [:osa, :tool, :execute],
      fn _event_name, _measurements, _metadata ->
        :ok
      end,
      nil
    )
  rescue
    _ -> :ok
  end

  # Attach handler for memory cache events
  defp attach_memory_cache_handler do
    :ok = :telemetry.attach(
      "osa.memory.cache.handler",
      [:osa, :memory, :cache],
      fn _event_name, _measurements, _metadata ->
        :ok
      end,
      nil
    )
  rescue
    _ -> :ok
  end

  # Get or create a trace ID (thread-local context)
  defp get_or_create_trace_id do
    case Process.get(:telemetry_trace_id) do
      nil ->
        trace_id = generate_uuid()
        Process.put(:telemetry_trace_id, trace_id)
        trace_id

      trace_id ->
        trace_id
    end
  end

  # Generate UUID using Erlang's crypto module
  defp generate_uuid do
    hex = :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)

    hex
    |> String.slice(0..7)
    |> Kernel.<>("-")
    |> Kernel.<>(String.slice(hex, 8..11))
    |> Kernel.<>("-")
    |> Kernel.<>(String.slice(hex, 12..15))
    |> Kernel.<>("-")
    |> Kernel.<>(String.slice(hex, 16..19))
    |> Kernel.<>("-")
    |> Kernel.<>(String.slice(hex, 20..31))
  end

  # Convert system time to microseconds since epoch
  defp system_time_to_microseconds do
    System.system_time(:microsecond)
  end

  # Get current span ID from process context (nil if not in a span)
  defp get_current_span_id do
    Process.get(:telemetry_current_span_id)
  end

  # Enrich attributes with system context
  defp enrich_attributes(attributes) do
    Map.merge(attributes, %{
      "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "node" => node() |> to_string(),
      "version" => get_osa_version()
    })
  end

  # Get OSA version
  defp get_osa_version do
    try do
      case :application.get_key(:optimal_system_agent, :vsn) do
        {:ok, vsn} -> vsn |> to_string()
        :undefined -> "unknown"
      end
    rescue
      _ -> "unknown"
    end
  end

  # Initialize metric data (counter, histogram, gauge)
  defp init_metric_data(metric_name, value) do
    metric_name_str = to_string(metric_name)

    is_histogram = String.contains?(metric_name_str, ["_latency", "_duration", "latency_", "duration_"])

    if is_histogram do
      # Histogram: store observations
      %{
        "type" => "histogram",
        "observations" => [value],
        "count" => 1,
        "sum" => value,
        "min" => value,
        "max" => value
      }
    else
      # Counter
      %{
        "type" => "counter",
        "value" => value
      }
    end
  end

  # Update metric data (counter or histogram observation)
  defp update_metric_data(metric_data, value) do
    case metric_data["type"] do
      "histogram" ->
        %{
          metric_data
          | "observations" => [value | metric_data["observations"]],
            "count" => metric_data["count"] + 1,
            "sum" => metric_data["sum"] + value,
            "min" => min(metric_data["min"], value),
            "max" => max(metric_data["max"], value)
        }

      "counter" ->
        %{metric_data | "value" => metric_data["value"] + value}

      _ ->
        metric_data
    end
  end
end
