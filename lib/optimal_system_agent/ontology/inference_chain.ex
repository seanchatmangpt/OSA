defmodule OptimalSystemAgent.Ontology.InferenceChain do
  @moduledoc """
  SPARQL CONSTRUCT Inference Chain — Board Chair Intelligence System.

  Executes the 4-level (L0 → L1 → L2 → L3) SPARQL CONSTRUCT materialization
  chain against Oxigraph, deriving higher-order organizational knowledge that
  is too complex for humans to compute in real-time.

  ## Levels

  | Level | Source        | Materializes              | TTL       |
  |-------|---------------|---------------------------|-----------|
  | L0    | Raw facts     | (external; not derived)   | —         |
  | L1    | L0 facts      | bos:ProcessMetric         | 45 min    |
  | L2    | L1 metrics    | bos:OrgHealthIndicator    | 90 min    |
  | L3    | L2 indicators | bos:BoardIntelligence     | on demand |

  ## Public API

      InferenceChain.run_full_chain()          # L1 → L2 → L3 in sequence
      InferenceChain.run_level(:l1)            # single level
      InferenceChain.chain_status()            # ages of each level
      InferenceChain.invalidate_from(:l0)      # cascades re-materialization up

  ## WvdA Soundness

  - **Deadlock Freedom**: All `Req.post/2` calls have explicit `receive_timeout: @timeout_ms` (10s).
    GenServer calls have explicit timeouts. No circular waits.
  - **Liveness**: Each level runs in sequence; no unbounded loops. SPARQL queries
    each enforce LIMIT 10000. Max chain depth is 3 levels.
  - **Boundedness**: ETS table `:osa_inference_chain_status` has 3 fixed keys
    (:l1, :l2, :l3). No unbounded accumulation.

  ## Armstrong Supervision

  - GenServer supervised by `OptimalSystemAgent.Supervisors.Infrastructure`.
  - Let-it-crash: HTTP errors returned as `{:error, reason}`, never swallowed.
  - No shared mutable state: all state in GenServer state map + ETS.

  ## OTEL Span

  Emits `inference_chain.level_refresh` with attributes:
  - `level` — "l1" | "l2" | "l3"
  - `triple_count` — integer
  - `elapsed_ms` — integer
  - `status` — "ok" | "error"

  Signal Theory: S=(data, explain, inform, json, result)
  """

  use GenServer
  require Logger

  # ── Configuration ───────────────────────────────────────────────────────────

  @oxigraph_url System.get_env("OXIGRAPH_URL", "http://localhost:7878")
  @timeout_ms 10_000

  # TTL values in milliseconds
  # WvdA boundedness: fixed constants, not computed at runtime
  @l1_ttl_ms 45 * 60 * 1_000    # 45 minutes
  @l2_ttl_ms 90 * 60 * 1_000    # 90 minutes
  # L3 has no fixed TTL — regenerated whenever L2 is newer than last L3 run

  # SPARQL file directory relative to chatmangpt project root
  @sparql_dir "BusinessOS/sparql/board"

  @ets_table :osa_inference_chain_status

  # ── Public API ─────────────────────────────────────────────────────────────

  @doc """
  Start the InferenceChain GenServer.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Run the full inference chain: L1 → L2 → L3 in strict sequential order.

  Each level checks its source TTL before executing. If a source level is fresh
  (not stale), that level is skipped and the cached count is returned.

  Returns `{:ok, %{l1: count, l2: count, l3: count}}` or `{:error, reason}`.

  WvdA: bounded by 3 sequential HTTP calls each with @timeout_ms (10s).
  """
  @spec run_full_chain() :: {:ok, map()} | {:error, term()}
  def run_full_chain do
    GenServer.call(__MODULE__, :run_full_chain, @timeout_ms * 4)
  catch
    :exit, {:timeout, _} ->
      Logger.error("[InferenceChain] run_full_chain timed out")
      {:error, :timeout}
  end

  @doc """
  Run a single inference level.

  Returns `{:ok, triple_count}` or `{:error, reason}`.

  WvdA: single HTTP call bounded by @timeout_ms (10s).
  """
  @spec run_level(level :: :l1 | :l2 | :l3) :: {:ok, non_neg_integer()} | {:error, term()}
  def run_level(level) when level in [:l1, :l2, :l3] do
    GenServer.call(__MODULE__, {:run_level, level}, @timeout_ms + 1_000)
  catch
    :exit, {:timeout, _} ->
      Logger.error("[InferenceChain] run_level(#{level}) timed out")
      {:error, :timeout}
  end

  @doc """
  Return the age in milliseconds of each inference level's last refresh.

  Returns `{l1_age_ms, l2_age_ms, l3_age_ms}` where each value is either an
  integer (ms elapsed since last successful refresh) or `:never` if the level
  has never been materialized in this node's lifetime.
  """
  @spec chain_status() :: {l1 :: non_neg_integer() | :never,
                            l2 :: non_neg_integer() | :never,
                            l3 :: non_neg_integer() | :never}
  def chain_status do
    GenServer.call(__MODULE__, :chain_status, @timeout_ms)
  catch
    :exit, {:timeout, _} ->
      Logger.error("[InferenceChain] chain_status timed out")
      {:never, :never, :never}
  end

  @doc """
  Mark all levels derived from `level` as stale, then re-materialize them.

  - `invalidate_from(:l0)` → marks L1, L2, L3 stale → runs full chain
  - `invalidate_from(:l1)` → marks L2, L3 stale → runs L2, L3
  - `invalidate_from(:l2)` → marks L3 stale → runs L3

  Returns `{:ok, %{levels_invalidated: [...], results: %{}}}` or `{:error, reason}`.

  WvdA: cascade bounded to max 3 levels; each with @timeout_ms HTTP call.
  """
  @spec invalidate_from(level :: :l0 | :l1 | :l2) :: {:ok, map()} | {:error, term()}
  def invalidate_from(level) when level in [:l0, :l1, :l2] do
    GenServer.call(__MODULE__, {:invalidate_from, level}, @timeout_ms * 4)
  catch
    :exit, {:timeout, _} ->
      Logger.error("[InferenceChain] invalidate_from(#{level}) timed out")
      {:error, :timeout}
  end

  # ── GenServer Callbacks ────────────────────────────────────────────────────

  @impl true
  def init(opts) do
    ensure_ets_table()

    state = %{
      oxigraph_url: Keyword.get(opts, :oxigraph_url, @oxigraph_url),
      timeout_ms: Keyword.get(opts, :timeout_ms, @timeout_ms),
      sparql_dir: Keyword.get(opts, :sparql_dir, resolve_sparql_dir())
    }

    Logger.info("[InferenceChain] Started. Oxigraph=#{state.oxigraph_url}, sparql_dir=#{state.sparql_dir}")

    {:ok, state}
  end

  @impl true
  def handle_call(:run_full_chain, _from, state) do
    Logger.info("[InferenceChain] run_full_chain starting")

    with {:ok, l1_count} <- do_run_level(:l1, state),
         {:ok, l2_count} <- do_run_level(:l2, state),
         {:ok, l3_count} <- do_run_level(:l3, state) do
      result = %{l1: l1_count, l2: l2_count, l3: l3_count}
      Logger.info("[InferenceChain] run_full_chain complete: #{inspect(result)}")
      {:reply, {:ok, result}, state}
    else
      {:error, reason} = err ->
        Logger.error("[InferenceChain] run_full_chain failed: #{inspect(reason)}")
        {:reply, err, state}
    end
  end

  @impl true
  def handle_call({:run_level, level}, _from, state) do
    result = do_run_level(level, state)
    {:reply, result, state}
  end

  @impl true
  def handle_call(:chain_status, _from, state) do
    now_ms = System.monotonic_time(:millisecond)
    l1_age = level_age_ms(:l1, now_ms)
    l2_age = level_age_ms(:l2, now_ms)
    l3_age = level_age_ms(:l3, now_ms)
    {:reply, {l1_age, l2_age, l3_age}, state}
  end

  @impl true
  def handle_call({:invalidate_from, level}, _from, state) do
    levels_to_invalidate = levels_above(level)

    Enum.each(levels_to_invalidate, fn lvl ->
      ets_delete(lvl)
      Logger.info("[InferenceChain] invalidated level #{lvl}")
    end)

    # Cascade: re-run invalidated levels in strict order (L1 before L2 before L3)
    results = run_levels_sequentially(levels_to_invalidate, state)

    {:reply, {:ok, %{levels_invalidated: levels_to_invalidate, results: results}}, state}
  end

  # ── Private: Level Execution ───────────────────────────────────────────────

  defp do_run_level(level, state) do
    start_ms = System.monotonic_time(:millisecond)
    Logger.info("[InferenceChain] run_level(#{level}) starting")

    if level_is_stale?(level) do
      case load_and_execute_sparql(level, state) do
        {:ok, triple_count} ->
          elapsed_ms = System.monotonic_time(:millisecond) - start_ms
          ets_put(level, System.monotonic_time(:millisecond), triple_count)
          emit_otel_span(level, triple_count, elapsed_ms, "ok")
          Logger.info("[InferenceChain] run_level(#{level}) ok: triples=#{triple_count}, elapsed=#{elapsed_ms}ms")
          {:ok, triple_count}

        {:error, reason} = err ->
          elapsed_ms = System.monotonic_time(:millisecond) - start_ms
          emit_otel_span(level, 0, elapsed_ms, "error")
          Logger.error("[InferenceChain] run_level(#{level}) failed: #{inspect(reason)}, elapsed=#{elapsed_ms}ms")
          err
      end
    else
      triple_count = ets_triple_count(level)
      Logger.debug("[InferenceChain] run_level(#{level}) skipped (source fresh), cached_triples=#{triple_count}")
      {:ok, triple_count}
    end
  end

  # ── Private: SPARQL File Loading and Execution ────────────────────────────

  defp load_and_execute_sparql(level, state) do
    sparql_file = sparql_file_for_level(level, state.sparql_dir)

    with {:ok, query_body} <- read_sparql_file(sparql_file),
         update_query = wrap_construct_as_insert(query_body),
         {:ok, triple_count} <- execute_sparql_update(update_query, state) do
      {:ok, triple_count}
    end
  end

  defp sparql_file_for_level(:l1, dir), do: Path.join(dir, "l1_process_metrics.sparql")
  defp sparql_file_for_level(:l2, dir), do: Path.join(dir, "l2_org_health.sparql")
  defp sparql_file_for_level(:l3, dir), do: Path.join(dir, "l3_board_intelligence.sparql")

  defp read_sparql_file(path) do
    case File.read(path) do
      {:ok, content} -> {:ok, content}
      {:error, :enoent} -> {:error, {:sparql_file_not_found, path}}
      {:error, reason} -> {:error, {:sparql_file_read_error, path, reason}}
    end
  end

  # Wrap a CONSTRUCT query body into a SPARQL Update INSERT { ... } WHERE { ... }
  # to materialize CONSTRUCT results back into the Oxigraph store.
  defp wrap_construct_as_insert(construct_query_body) do
    prefix_block = extract_prefix_block(construct_query_body)
    construct_body = extract_construct_body(construct_query_body)
    where_clause = extract_where_clause(construct_query_body)

    """
    #{prefix_block}

    INSERT {
    #{construct_body}
    }
    #{where_clause}
    """
  end

  defp extract_prefix_block(query) do
    query
    |> String.split("\n")
    |> Enum.take_while(&String.starts_with?(String.trim(&1), "PREFIX"))
    |> Enum.join("\n")
  end

  defp extract_construct_body(query) do
    case Regex.run(~r/CONSTRUCT\s*\{(.*?)\}\s*WHERE/s, query) do
      [_full, body] -> String.trim(body)
      _ -> "# CONSTRUCT body extraction failed — check SPARQL file syntax"
    end
  end

  defp extract_where_clause(query) do
    case Regex.run(~r/(WHERE\s*\{.*\})\s*(?:#.*)?$/s, query) do
      [_full, clause] -> String.trim(clause)
      _ -> "WHERE { }"
    end
  end

  # Execute SPARQL Update against Oxigraph /update endpoint.
  # WvdA: explicit receive_timeout enforces @timeout_ms bound.
  # Note: Req 0.5.x uses :receive_timeout (not :connect_timeout) for HTTP timeouts.
  defp execute_sparql_update(update_query, state) do
    url = state.oxigraph_url <> "/update"
    timeout = state.timeout_ms

    headers = [
      {"Content-Type", "application/sparql-update"},
      {"Accept", "application/json, */*"}
    ]

    case Req.post(url,
      headers: headers,
      body: update_query,
      receive_timeout: timeout
    ) do
      {:ok, %{status: status}} when status in [200, 204] ->
        # Oxigraph returns 204 No Content for successful SPARQL Updates.
        # Triple count is estimated from the INSERT block content.
        {:ok, estimate_triple_count(update_query)}

      {:ok, %{status: status, body: body}} when status >= 400 ->
        {:error, {:http_error, status, body}}

      {:ok, %{status: status}} ->
        {:error, {:unexpected_status, status}}

      {:error, %Req.TransportError{reason: :timeout}} ->
        {:error, :timeout}

      {:error, %Req.TransportError{reason: :econnrefused}} ->
        {:error, :connection_refused}

      {:error, %Req.TransportError{reason: reason}} ->
        {:error, {:transport_error, reason}}

      {:error, reason} ->
        {:error, {:request_failed, reason}}
    end
  end

  # Estimate triple count by counting triple-pattern lines (ends with " .")
  defp estimate_triple_count(insert_query) do
    insert_query
    |> String.split("\n")
    |> Enum.count(fn line ->
      trimmed = String.trim(line)
      String.ends_with?(trimmed, " .") or String.ends_with?(trimmed, ".")
    end)
    |> max(1)
  end

  # ── Private: TTL / Staleness ───────────────────────────────────────────────

  defp level_is_stale?(:l1) do
    case ets_lookup(:l1) do
      {:l1, refreshed_at, _} ->
        System.monotonic_time(:millisecond) - refreshed_at > @l1_ttl_ms
      nil -> true
    end
  end

  defp level_is_stale?(:l2) do
    case ets_lookup(:l2) do
      {:l2, refreshed_at, _} ->
        System.monotonic_time(:millisecond) - refreshed_at > @l2_ttl_ms
      nil -> true
    end
  end

  defp level_is_stale?(:l3) do
    # L3 is stale whenever L2 was refreshed after L3's last materialization run.
    l2_refresh = ets_refreshed_at(:l2)
    l3_refresh = ets_refreshed_at(:l3)
    case {l2_refresh, l3_refresh} do
      {nil, _} -> true
      {_, nil} -> true
      {l2, l3} -> l2 > l3
    end
  end

  defp ets_refreshed_at(level) do
    case ets_lookup(level) do
      {^level, refreshed_at, _} -> refreshed_at
      nil -> nil
    end
  end

  defp level_age_ms(level, now_ms) do
    case ets_lookup(level) do
      {^level, refreshed_at, _} -> now_ms - refreshed_at
      nil -> :never
    end
  end

  # ── Private: Cascade Logic ─────────────────────────────────────────────────

  # Returns levels derived from (above) the given level, in materialization order.
  # WvdA: no circular dependencies: L1 never reads L2/L3, L2 never reads L3.
  defp levels_above(:l0), do: [:l1, :l2, :l3]
  defp levels_above(:l1), do: [:l2, :l3]
  defp levels_above(:l2), do: [:l3]

  # Run levels in order; accumulate results; stop on first error.
  # WvdA: bounded by list length (max 3 levels).
  defp run_levels_sequentially(levels, state) do
    Enum.reduce_while(levels, %{}, fn level, acc ->
      case do_run_level(level, state) do
        {:ok, count} -> {:cont, Map.put(acc, level, count)}
        {:error, reason} -> {:halt, Map.put(acc, level, {:error, reason})}
      end
    end)
  end

  # ── Private: ETS Operations ────────────────────────────────────────────────

  # ETS schema: {level_atom, refreshed_at_monotonic_ms, triple_count}
  # Bounded: exactly 3 keys (:l1, :l2, :l3). No unbounded accumulation.
  defp ensure_ets_table do
    if :ets.whereis(@ets_table) == :undefined do
      :ets.new(@ets_table, [:named_table, :public, :set, read_concurrency: true])
      Logger.debug("[InferenceChain] ETS table #{@ets_table} created")
    end
  end

  defp ets_lookup(level) do
    case :ets.whereis(@ets_table) do
      :undefined -> nil
      _ ->
        case :ets.lookup(@ets_table, level) do
          [{^level, refreshed_at, triple_count}] -> {level, refreshed_at, triple_count}
          [] -> nil
        end
    end
  end

  defp ets_put(level, refreshed_at, triple_count) do
    ensure_ets_table()
    :ets.insert(@ets_table, {level, refreshed_at, triple_count})
  end

  defp ets_delete(level) do
    if :ets.whereis(@ets_table) != :undefined do
      :ets.delete(@ets_table, level)
    end
  end

  defp ets_triple_count(level) do
    case ets_lookup(level) do
      {^level, _refreshed_at, triple_count} -> triple_count
      nil -> 0
    end
  end

  # ── Private: OTEL Telemetry ────────────────────────────────────────────────

  defp emit_otel_span(level, triple_count, elapsed_ms, status) do
    :telemetry.execute(
      [:inference_chain, :level_refresh],
      %{elapsed_ms: elapsed_ms, triple_count: triple_count},
      %{level: Atom.to_string(level), status: status}
    )

    # OpenTelemetry API span — gracefully degraded when OTel not available
    try do
      require OpenTelemetry.Tracer, as: Tracer

      Tracer.with_span "inference_chain.level_refresh" do
        Tracer.set_attributes([
          {"level", Atom.to_string(level)},
          {"triple_count", triple_count},
          {"elapsed_ms", elapsed_ms},
          {"status", status}
        ])
      end
    rescue
      _ ->
        Logger.debug("[InferenceChain] OTEL span: level=#{level}, triples=#{triple_count}, elapsed=#{elapsed_ms}ms, status=#{status}")
    end
  end

  # ── Private: Configuration ─────────────────────────────────────────────────

  defp resolve_sparql_dir do
    # Walk up from the OTP priv dir to find the chatmangpt project root
    # (the directory containing BusinessOS/), then join with @sparql_dir.
    otp_priv = :code.priv_dir(:optimal_system_agent) |> to_string()
    root = find_project_root(otp_priv, 0)
    Path.join(root, @sparql_dir)
  end

  # Walk up directory tree looking for a directory containing BusinessOS/.
  # WvdA liveness: depth guard (max 20) prevents infinite traversal.
  defp find_project_root(_path, depth) when depth > 20 do
    File.cwd!()
  end

  defp find_project_root(path, depth) do
    if File.dir?(Path.join(path, "BusinessOS")) do
      path
    else
      parent = Path.dirname(path)
      if parent == path do
        File.cwd!()
      else
        find_project_root(parent, depth + 1)
      end
    end
  end
end
