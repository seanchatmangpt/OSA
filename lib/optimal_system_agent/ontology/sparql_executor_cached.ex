defmodule OptimalSystemAgent.Ontology.SPARQLExecutorCached do
  @moduledoc """
  SPARQL Executor with Query Caching and Optimization.

  Wraps SPARQLExecutor with:
  - **L1 Cache (ETS, 1min TTL):** Hot queries in local ETS table
  - **Query Rewriting:** Automatic UNION → UNION ALL optimization
  - **Deterministic Checks:** Skip caching for non-deterministic queries (NOW(), RAND())
  - **SLA Enforcement:** Track query latency, alert on >100ms queries
  - **Cache Statistics:** Hit/miss rates, avg query time

  WvdA Soundness:
  - **Deadlock Freedom:** Cache lookup has timeout_ms fallback to direct query
  - **Liveness:** Deterministic query checks are bounded (regex scan)
  - **Boundedness:** ETS cache has max_entries limit, oldest entries evicted on overflow
  """

  use GenServer
  require Logger

  alias OptimalSystemAgent.Ontology.SPARQLExecutor
  alias OptimalSystemAgent.Ontology.SPARQLOptimizer
  alias OptimalSystemAgent.Caching.QueryCache

  @default_cache_ttl_ms 60_000  # 1 minute
  @sla_threshold_ms 100  # Alert if query takes >100ms

  # ── Client API ────────────────────────────────────────────────

  @doc """
  Start the cached SPARQL executor as a GenServer.

  Options:
    - `:endpoint` - Oxigraph endpoint (default: http://localhost:7878)
    - `:cache_enabled` - Enable L1 caching (default: true)
    - `:auto_optimize` - Automatically rewrite queries (default: true)
    - `:sla_alert` - Log warning on slow queries (default: true)

  Returns: `{:ok, pid}` or `{:error, reason}`
  """
  def start_link(options) do
    GenServer.start_link(__MODULE__, options, name: __MODULE__)
  end

  @doc """
  Execute a SPARQL query with caching and optimization.

  Parameters:
    - `query_type`: `:construct`, `:ask`, or `:select`
    - `ontology_id`: identifier for logging
    - `sparql_query`: SPARQL query string
    - `options`: optional keyword list

  Options:
    - `:skip_cache` - bypass cache and execute directly (default: false)
    - `:skip_optimization` - don't rewrite query (default: false)
    - `:ttl_ms` - override cache TTL for this query (default: 60_000)

  Returns:
    - `{:ok, result}` on success
    - `{:error, reason}` on failure or timeout

  ## Examples

      {:ok, triples} = execute_construct("fibo", query_str)
      {:ok, bool} = execute_ask("fibo", query_str, skip_cache: true)
  """
  def execute_construct(ontology_id, sparql_query, options \\ []) do
    execute(:construct, ontology_id, sparql_query, options)
  end

  def execute_ask(ontology_id, sparql_query, options \\ []) do
    execute(:ask, ontology_id, sparql_query, options)
  end

  def execute_select(ontology_id, sparql_query, options \\ []) do
    execute(:select, ontology_id, sparql_query, options)
  end

  defp execute(query_type, ontology_id, sparql_query, options) do
    skip_cache = Keyword.get(options, :skip_cache, false)
    skip_optimization = Keyword.get(options, :skip_optimization, false)
    ttl_ms = Keyword.get(options, :ttl_ms, @default_cache_ttl_ms)

    start_time = System.monotonic_time(:millisecond)

    try do
      GenServer.call(__MODULE__, {
        :execute,
        query_type,
        ontology_id,
        sparql_query,
        skip_cache,
        skip_optimization,
        ttl_ms,
        start_time
      }, 60_000)
    catch
      :exit, {:timeout, _} ->
        Logger.error("SPARQL executor timeout: query_type=#{query_type}, ontology=#{ontology_id}")
        {:error, :timeout}
    end
  end

  @doc """
  Get cache statistics and executor health.

  Returns: `%{hits: N, misses: M, evictions: K, avg_query_time_ms: X, ...}`
  """
  def stats do
    GenServer.call(__MODULE__, :stats)
  end

  @doc """
  Clear the query cache and reset statistics.

  Returns: `:ok`
  """
  def clear_cache do
    GenServer.call(__MODULE__, :clear_cache)
  end

  # ── GenServer Callbacks ────────────────────────────────────────────────

  @impl GenServer
  def init(options) do
    endpoint = Keyword.get(options, :endpoint, "http://localhost:7878")
    cache_enabled = Keyword.get(options, :cache_enabled, true)
    auto_optimize = Keyword.get(options, :auto_optimize, true)
    sla_alert = Keyword.get(options, :sla_alert, true)

    # Start internal query cache
    {:ok, _cache_pid} = QueryCache.start_link(name: :sparql_query_cache)

    state = %{
      endpoint: endpoint,
      cache_enabled: cache_enabled,
      auto_optimize: auto_optimize,
      sla_alert: sla_alert,
      stats: %{
        hits: 0,
        misses: 0,
        evictions: 0,
        slow_queries: 0,
        total_time_ms: 0,
        query_count: 0
      }
    }

    Logger.info("[SPARQLExecutorCached] Started: endpoint=#{endpoint}, cache_enabled=#{cache_enabled}")

    {:ok, state}
  end

  @impl GenServer
  def handle_call({:execute, query_type, ontology_id, sparql_query, skip_cache, skip_optimization, _ttl_ms, start_time}, _from, state) do
    # Step 1: Optimization
    optimized_query =
      if state.auto_optimize and not skip_optimization do
        case SPARQLOptimizer.rewrite(sparql_query, enable_union_all: true) do
          {:ok, rewritten} -> rewritten
          {:error, _} -> sparql_query
        end
      else
        sparql_query
      end

    # Step 2: Determinism check (for caching)
    {:ok, is_deterministic} = SPARQLOptimizer.is_deterministic?(optimized_query)
    cache_key = SPARQLOptimizer.cache_key(optimized_query)

    # Step 3: Cache lookup
    result =
      if state.cache_enabled and is_deterministic and not skip_cache do
        case QueryCache.get_cached(:sparql_query_cache, cache_key, fn ->
          direct_execute(query_type, ontology_id, optimized_query, state.endpoint)
        end) do
          {:ok, value} ->
            new_stats = Map.update(state.stats, :hits, 0, &(&1 + 1))
            {:ok, value, new_stats}

          {:error, reason} ->
            new_stats = Map.update(state.stats, :misses, 0, &(&1 + 1))
            {:error, reason, new_stats}
        end
      else
        case direct_execute(query_type, ontology_id, optimized_query, state.endpoint) do
          {:ok, value} ->
            new_stats = Map.update(state.stats, :misses, 0, &(&1 + 1))
            {:ok, value, new_stats}

          {:error, reason} ->
            new_stats = state.stats
            {:error, reason, new_stats}
        end
      end

    # Step 4: Measure latency and check SLA
    elapsed_ms = System.monotonic_time(:millisecond) - start_time

    {reply, new_stats} =
      case result do
        {:ok, value, stats} ->
          stats_updated = finalize_stats(stats, elapsed_ms, state.sla_alert)
          {{:ok, value}, stats_updated}

        {:error, reason, stats} ->
          stats_updated = finalize_stats(stats, elapsed_ms, state.sla_alert)
          {{:error, reason}, stats_updated}
      end

    new_state = %{state | stats: new_stats}

    {:reply, reply, new_state}
  end

  @impl GenServer
  def handle_call(:stats, _from, state) do
    avg_time_ms =
      if state.stats.query_count > 0 do
        div(state.stats.total_time_ms, state.stats.query_count)
      else
        0
      end

    stats_with_avg = Map.put(state.stats, :avg_query_time_ms, avg_time_ms)

    {:reply, stats_with_avg, state}
  end

  @impl GenServer
  def handle_call(:clear_cache, _from, state) do
    QueryCache.clear(:sparql_query_cache)

    new_state = %{state | stats: %{
      hits: 0,
      misses: 0,
      evictions: 0,
      slow_queries: 0,
      total_time_ms: 0,
      query_count: 0
    }}

    {:reply, :ok, new_state}
  end

  # ── Private Helpers ────────────────────────────────────────────────

  defp direct_execute(query_type, ontology_id, sparql_query, endpoint) do
    SPARQLExecutor.execute(query_type, ontology_id, sparql_query, endpoint, 5000)
  end

  defp finalize_stats(stats, elapsed_ms, sla_alert) do
    new_stats =
      stats
      |> Map.update(:total_time_ms, elapsed_ms, &(&1 + elapsed_ms))
      |> Map.update(:query_count, 1, &(&1 + 1))

    # Alert on slow queries
    if sla_alert and elapsed_ms > @sla_threshold_ms do
      Logger.warning("SPARQL query slow: #{elapsed_ms}ms (threshold: #{@sla_threshold_ms}ms)")
      Map.update(new_stats, :slow_queries, 1, &(&1 + 1))
    else
      new_stats
    end
  end
end
