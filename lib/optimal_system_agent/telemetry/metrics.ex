defmodule OptimalSystemAgent.Telemetry.Metrics do
  @moduledoc """
  Metrics collection and reporting for OptimalSystemAgent.

  Provides a named GenServer that accumulates metrics for:
  - Tool executions (duration tracking)
  - Provider API calls (latency by provider)
  - Noise filter outcomes (signal vs noise detection)
  - Signal weights (distribution across 4 buckets)
  - Session statistics (turns, messages)

  All record_* functions are idempotent and return :ok. get_* functions
  return consistent map structures. Summary statistics aggregate raw metrics.

  The GenServer uses ETS tables for storage to support concurrent reads
  from multiple processes without lock contention.

  ## Examples

      iex> Metrics.record_tool_execution("grep_files", 245)
      :ok

      iex> Metrics.record_provider_call(:anthropic, 1200, true)
      :ok

      iex> Metrics.get_metrics() |> Map.keys()
      [:tool_executions, :provider_latency, :session_stats, :noise_filter, :signal_weights]

      iex> summary = Metrics.get_summary()
      iex> summary.noise_filter_rate
      33.33
  """

  use GenServer
  require Logger

  # =====================================================================
  # Public API
  # =====================================================================

  @doc """
  Record a tool execution with its duration in milliseconds (int or float).

  Returns :ok. Raises nothing. Duration must be non-negative.
  """
  @spec record_tool_execution(String.t(), number()) :: :ok
  def record_tool_execution(tool_name, duration_ms) when is_binary(tool_name) and is_number(duration_ms) and duration_ms >= 0 do
    GenServer.cast(__MODULE__, {:record_tool, tool_name, duration_ms})
  end

  @doc """
  Record an LLM provider call with latency and success flag.

  Provider should be an atom like :anthropic, :openai, :ollama, etc.
  Duration is milliseconds. Success is boolean.

  Returns :ok. Raises nothing.
  """
  @spec record_provider_call(atom(), number(), boolean()) :: :ok
  def record_provider_call(provider, duration_ms, success) when is_atom(provider) and is_number(duration_ms) and duration_ms >= 0 and is_boolean(success) do
    GenServer.cast(__MODULE__, {:record_provider, provider, duration_ms, success})
  end

  @doc """
  Record a noise filter outcome: :filtered, :clarify, or :pass.

  Returns :ok. Raises nothing.
  """
  @spec record_noise_filter_result(:filtered | :clarify | :pass) :: :ok
  def record_noise_filter_result(outcome) when outcome in [:filtered, :clarify, :pass] do
    GenServer.cast(__MODULE__, {:record_noise_filter, outcome})
  end

  @doc """
  Record a signal weight (float 0.0–1.0 or integer 0–1).

  Weight is bucketed into one of four ranges:
  - "0.0-0.2"
  - "0.2-0.5"
  - "0.5-0.8"
  - "0.8-1.0"

  Returns :ok. Raises nothing.
  """
  @spec record_signal_weight(float() | integer()) :: :ok
  def record_signal_weight(weight) when (is_float(weight) or is_integer(weight)) and weight >= 0.0 and weight <= 1.0 do
    GenServer.cast(__MODULE__, {:record_signal_weight, weight})
  end

  @doc """
  Get all raw metrics collected so far.

  Returns a map with keys:
  - :tool_executions -> map of tool_name => [durations_list]
  - :provider_latency -> map of provider => [{duration, success}]
  - :session_stats -> map with :turns_by_session, :messages_today
  - :noise_filter -> map with :filtered, :clarify, :pass counters
  - :signal_weights -> map with :"0.0-0.2", :"0.2-0.5", :"0.5-0.8", :"0.8-1.0"
  """
  @spec get_metrics() :: map()
  def get_metrics do
    GenServer.call(__MODULE__, :get_metrics)
  end

  @doc """
  Get summary statistics aggregated from raw metrics.

  Returns a map with keys:
  - :tool_executions -> map of tool_name => %{count, avg_ms, min_ms, max_ms, p99_ms}
  - :provider_latency -> map of provider => %{count, avg_ms, p99_ms}
  - :session_stats -> map with :turns_by_session, :messages_today
  - :noise_filter_rate -> float 0.0-100.0, percentage of filtered+clarify
  - :signal_weight_distribution -> map with :"0.0-0.2", etc. as percentages
  """
  @spec get_summary() :: map()
  def get_summary do
    GenServer.call(__MODULE__, :get_summary)
  end

  # =====================================================================
  # GenServer Callbacks
  # =====================================================================

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    # Create ETS tables for each metric category
    :ets.new(:metrics_tool_executions, [:named_table, :public, :ordered_set])
    :ets.new(:metrics_provider_latency, [:named_table, :public, :ordered_set])
    :ets.new(:metrics_noise_filter, [:named_table, :public, :set])
    :ets.new(:metrics_signal_weights, [:named_table, :public, :set])
    :ets.new(:metrics_session_stats, [:named_table, :public, :set])

    # Initialize filter counters
    :ets.insert(:metrics_noise_filter, {:filtered, 0})
    :ets.insert(:metrics_noise_filter, {:clarify, 0})
    :ets.insert(:metrics_noise_filter, {:pass, 0})

    # Initialize signal weight buckets
    :ets.insert(:metrics_signal_weights, {:"0.0-0.2", 0})
    :ets.insert(:metrics_signal_weights, {:"0.2-0.5", 0})
    :ets.insert(:metrics_signal_weights, {:"0.5-0.8", 0})
    :ets.insert(:metrics_signal_weights, {:"0.8-1.0", 0})

    # Initialize session stats
    :ets.insert(:metrics_session_stats, {:turns_by_session, %{}})
    :ets.insert(:metrics_session_stats, {:messages_today, 0})

    {:ok, %{}}
  end

  @impl true
  def handle_cast({:record_tool, tool_name, duration_ms}, state) do
    # Convert to float for consistent storage
    dur = if is_float(duration_ms), do: duration_ms, else: duration_ms / 1.0

    # Get or create the list for this tool
    case :ets.lookup(:metrics_tool_executions, tool_name) do
      [{^tool_name, durations}] ->
        :ets.update_element(:metrics_tool_executions, tool_name, {2, [dur | durations]})

      [] ->
        :ets.insert(:metrics_tool_executions, {tool_name, [dur]})
    end

    {:noreply, state}
  end

  def handle_cast({:record_provider, provider, duration_ms, success}, state) do
    dur = if is_float(duration_ms), do: duration_ms, else: duration_ms / 1.0

    case :ets.lookup(:metrics_provider_latency, provider) do
      [{^provider, calls}] ->
        :ets.update_element(:metrics_provider_latency, provider, {2, [{dur, success} | calls]})

      [] ->
        :ets.insert(:metrics_provider_latency, {provider, [{dur, success}]})
    end

    {:noreply, state}
  end

  def handle_cast({:record_noise_filter, outcome}, state) do
    case :ets.lookup(:metrics_noise_filter, outcome) do
      [{^outcome, count}] ->
        :ets.update_element(:metrics_noise_filter, outcome, {2, count + 1})

      [] ->
        :ets.insert(:metrics_noise_filter, {outcome, 1})
    end

    {:noreply, state}
  end

  def handle_cast({:record_signal_weight, weight}, state) do
    bucket = bucket_for_weight(weight)

    case :ets.lookup(:metrics_signal_weights, bucket) do
      [{^bucket, count}] ->
        :ets.update_element(:metrics_signal_weights, bucket, {2, count + 1})

      [] ->
        :ets.insert(:metrics_signal_weights, {bucket, 1})
    end

    {:noreply, state}
  end

  @impl true
  def handle_call(:get_metrics, _from, state) do
    metrics = %{
      tool_executions: build_tool_executions_map(),
      provider_latency: build_provider_latency_map(),
      session_stats: build_session_stats_map(),
      noise_filter: build_noise_filter_map(),
      signal_weights: build_signal_weights_map()
    }

    {:reply, metrics, state}
  end

  def handle_call(:get_summary, _from, state) do
    summary = %{
      tool_executions: summarize_tool_executions(),
      provider_latency: summarize_provider_latency(),
      session_stats: build_session_stats_map(),
      noise_filter_rate: calculate_noise_filter_rate(),
      signal_weight_distribution: calculate_signal_distribution()
    }

    {:reply, summary, state}
  end

  # =====================================================================
  # Helper Functions
  # =====================================================================

  defp bucket_for_weight(weight) when is_integer(weight) do
    w = weight / 1.0
    bucket_for_weight(w)
  end

  defp bucket_for_weight(weight) when is_float(weight) do
    cond do
      weight < 0.2 -> :"0.0-0.2"
      weight < 0.5 -> :"0.2-0.5"
      weight < 0.8 -> :"0.5-0.8"
      true -> :"0.8-1.0"
    end
  end

  defp build_tool_executions_map do
    :ets.tab2list(:metrics_tool_executions)
    |> Map.new(fn {tool, durations} -> {tool, durations} end)
  end

  defp build_provider_latency_map do
    :ets.tab2list(:metrics_provider_latency)
    |> Map.new(fn {provider, calls} -> {provider, calls} end)
  end

  defp build_noise_filter_map do
    :ets.tab2list(:metrics_noise_filter)
    |> Map.new(fn {outcome, count} -> {outcome, count} end)
  end

  defp build_signal_weights_map do
    :ets.tab2list(:metrics_signal_weights)
    |> Map.new(fn {bucket, count} -> {bucket, count} end)
  end

  defp build_session_stats_map do
    case :ets.lookup(:metrics_session_stats, :turns_by_session) do
      [{:turns_by_session, turns_map}] ->
        case :ets.lookup(:metrics_session_stats, :messages_today) do
          [{:messages_today, msg_count}] ->
            %{turns_by_session: turns_map, messages_today: msg_count}

          [] ->
            %{turns_by_session: turns_map, messages_today: 0}
        end

      [] ->
        %{turns_by_session: %{}, messages_today: 0}
    end
  end

  defp summarize_tool_executions do
    build_tool_executions_map()
    |> Map.new(fn {tool, durations} ->
      {tool, compute_stats(durations)}
    end)
  end

  defp summarize_provider_latency do
    build_provider_latency_map()
    |> Map.new(fn {provider, calls} ->
      # Extract just the durations, ignoring success flag
      durations = Enum.map(calls, fn {dur, _success} -> dur end)
      {provider, compute_stats(durations)}
    end)
  end

  defp compute_stats(durations) when is_list(durations) and durations != [] do
    sorted = Enum.sort(durations)
    count = length(sorted)
    sum = Enum.sum(sorted)
    avg = sum / count
    min = Enum.min(sorted)
    max = Enum.max(sorted)
    p99 = percentile(sorted, 0.99)

    %{
      count: count,
      avg_ms: Float.round(avg, 2),
      min_ms: Float.round(min, 2),
      max_ms: Float.round(max, 2),
      p99_ms: Float.round(p99, 2)
    }
  end

  defp compute_stats(_) do
    %{count: 0, avg_ms: 0.0, min_ms: 0.0, max_ms: 0.0, p99_ms: 0.0}
  end

  defp percentile(sorted_list, p) when is_float(p) and p >= 0.0 and p <= 1.0 do
    case length(sorted_list) do
      0 -> 0.0
      n ->
        idx = Float.round(p * (n - 1))
        idx_int = trunc(idx)
        Enum.at(sorted_list, idx_int, 0.0)
    end
  end

  defp calculate_noise_filter_rate do
    case :ets.lookup(:metrics_noise_filter, :filtered) do
      [{:filtered, filtered}] ->
        case :ets.lookup(:metrics_noise_filter, :clarify) do
          [{:clarify, clarify}] ->
            case :ets.lookup(:metrics_noise_filter, :pass) do
              [{:pass, pass}] ->
                total = filtered + clarify + pass

                if total == 0 do
                  0.0
                else
                  rate = (filtered + clarify) / total * 100.0
                  Float.round(rate, 2)
                end

              [] ->
                0.0
            end

          [] ->
            0.0
        end

      [] ->
        0.0
    end
  end

  defp calculate_signal_distribution do
    weights_map = build_signal_weights_map()
    total = weights_map |> Map.values() |> Enum.sum()

    if total == 0 do
      %{
        :"0.0-0.2" => 0.0,
        :"0.2-0.5" => 0.0,
        :"0.5-0.8" => 0.0,
        :"0.8-1.0" => 0.0
      }
    else
      weights_map
      |> Map.new(fn {bucket, count} ->
        {bucket, Float.round(count / total * 100.0, 2)}
      end)
    end
  end

  @impl true
  def format_status(status) do
    status
  end
end
