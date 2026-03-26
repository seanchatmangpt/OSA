defmodule OptimalSystemAgent.Integrations.Compliance.Verifier do
  @moduledoc """
  Fortune 5 compliance verification via SPARQL ASK queries.

  Manages verification of SOC2, GDPR, HIPAA, SOX, and CUSTOM frameworks
  with 5-minute caching and 15-second timeout per framework.

  Uses GenServer with ETS-backed L1 cache. Executes compliance queries
  via `bos` CLI wrapper around SPARQL ASK.

  ## Supervision

  Add to your supervisor tree:

      children = [
        {OptimalSystemAgent.Integrations.Compliance.Verifier, [name: :compliance_verifier]}
      ]

  ## Usage

      {:ok, pid} = OptimalSystemAgent.Integrations.Compliance.Verifier.start_link([])

      # Verify single framework (5s timeout, 5min cache)
      {:ok, result} = Verifier.verify_soc2(pid)
      # result = %{compliant: true, violations: [], cached: false}

      # Generate full report
      {:ok, report} = Verifier.generate_report(pid)
      # report = %{frameworks: [...], verified_at: ..., cache_stats: ...}

      # Clear cache
      :ok = Verifier.clear_cache(pid)
  """

  use GenServer
  require Logger

  @verify_timeout_ms 15_000
  @cache_ttl_ms 300_000  # 5 minutes
  @cache_stats_key :__cache_stats__

  # ── Client API ───────────────────────────────────────────────────────

  @doc """
  Start the compliance verifier GenServer.

  Options:
    - `:name` - atom name for the process (default: :compliance_verifier)
    - `:bos_path` - path to bos CLI (default: "bos")
    - `:max_concurrent` - max concurrent verifications (default: 2)
  """
  def start_link(opts) do
    name = Keyword.get(opts, :name, :compliance_verifier)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Verify SOC2 compliance (5-minute cache, 15s timeout).

  Returns:
    - `{:ok, %{compliant: bool, violations: [string], cached: bool}}`
    - `{:error, reason}` on timeout or internal error
  """
  def verify_soc2(verifier_ref) do
    GenServer.call(verifier_ref, {:verify, :soc2}, @verify_timeout_ms + 1000)
  end

  @doc "Verify GDPR compliance (5-minute cache, 15s timeout)."
  def verify_gdpr(verifier_ref) do
    GenServer.call(verifier_ref, {:verify, :gdpr}, @verify_timeout_ms + 1000)
  end

  @doc "Verify HIPAA compliance (5-minute cache, 15s timeout)."
  def verify_hipaa(verifier_ref) do
    GenServer.call(verifier_ref, {:verify, :hipaa}, @verify_timeout_ms + 1000)
  end

  @doc "Verify SOX compliance (5-minute cache, 15s timeout)."
  def verify_sox(verifier_ref) do
    GenServer.call(verifier_ref, {:verify, :sox}, @verify_timeout_ms + 1000)
  end

  @doc """
  Generate full compliance report across all frameworks.

  Returns:
    - `{:ok, %{frameworks: [...], verified_at: iso8601, cache_stats: map}}`
  """
  def generate_report(verifier_ref) do
    GenServer.call(verifier_ref, :generate_report, @verify_timeout_ms * 5 + 2000)
  end

  @doc """
  Get current cache statistics (hits, misses, entries).
  """
  def cache_stats(verifier_ref) do
    GenServer.call(verifier_ref, :cache_stats)
  end

  @doc """
  Invalidate cache entry for a framework.
  """
  def invalidate_cache(verifier_ref, framework) do
    GenServer.call(verifier_ref, {:invalidate, framework})
  end

  @doc """
  Clear all cache entries.
  """
  def clear_cache(verifier_ref) do
    GenServer.call(verifier_ref, :clear_all)
  end

  # ── GenServer Callbacks ──────────────────────────────────────────────

  @impl GenServer
  def init(opts) do
    name = Keyword.get(opts, :name, :compliance_verifier)
    bos_path = Keyword.get(opts, :bos_path, "bos")
    max_concurrent = Keyword.get(opts, :max_concurrent, 2)

    # Create ETS table for L1 cache
    ets_table = :"#{name}_cache"

    :ets.new(ets_table, [
      :set,
      :public,
      :named_table,
      {:read_concurrency, true},
      {:write_concurrency, true}
    ])

    # Initialize stats
    :ets.insert(ets_table, {
      @cache_stats_key,
      %{hits: 0, misses: 0, entries: 0}
    })

    state = %{
      ets_table: ets_table,
      bos_path: bos_path,
      max_concurrent: max_concurrent,
      in_flight: %{},
      ttl_ms: @cache_ttl_ms
    }

    {:ok, state}
  end

  @impl GenServer
  def handle_call({:verify, framework}, _from, state) do
    case lookup_cache(state.ets_table, framework) do
      {:hit, result} ->
        update_stats(state.ets_table, :hit)
        {:reply, {:ok, Map.put(result, :cached, true)}, state}

      :miss ->
        update_stats(state.ets_table, :miss)

        case verify_framework(framework, state.bos_path) do
          {:ok, result} ->
            store_cache(state.ets_table, framework, result, state.ttl_ms)
            {:reply, {:ok, Map.put(result, :cached, false)}, state}

          {:error, reason} ->
            Logger.warning("[Compliance] #{framework} verification failed: #{inspect(reason)}")
            {:reply, {:error, reason}, state}

          :timeout ->
            Logger.warning("[Compliance] #{framework} verification timed out")
            {:reply, {:error, :timeout}, state}
        end
    end
  end

  @impl GenServer
  def handle_call(:generate_report, _from, state) do
    frameworks = [:soc2, :gdpr, :hipaa, :sox]
    verified_at = DateTime.utc_now() |> DateTime.to_iso8601()

    results =
      Enum.map(frameworks, fn framework ->
        case verify_framework_internal(framework, state.ets_table, state.bos_path, state.ttl_ms) do
          {:ok, result} ->
            %{
              framework: Atom.to_string(framework),
              compliant: result.compliant,
              violation_count: length(result.violations),
              violations: result.violations,
              verified_at: verified_at,
              cached: result.cached
            }

          {:error, reason} ->
            %{
              framework: Atom.to_string(framework),
              compliant: false,
              violation_count: 1,
              violations: [inspect(reason)],
              verified_at: verified_at,
              cached: false
            }
        end
      end)

    overall_compliant = Enum.all?(results, & &1.compliant)

    stats = get_stats(state.ets_table)

    report = %{
      overall_compliant: overall_compliant,
      frameworks: results,
      verified_at: verified_at,
      cache_stats: stats
    }

    {:reply, {:ok, report}, state}
  end

  @impl GenServer
  def handle_call(:cache_stats, _from, state) do
    stats = get_stats(state.ets_table)
    {:reply, stats, state}
  end

  @impl GenServer
  def handle_call({:invalidate, framework}, _from, state) do
    :ets.delete(state.ets_table, framework)
    Logger.info("[Compliance] Cache invalidated for #{framework}")
    {:reply, :ok, state}
  end

  @impl GenServer
  def handle_call(:clear_all, _from, state) do
    :ets.delete_all_objects(state.ets_table)
    :ets.insert(state.ets_table, {@cache_stats_key, %{hits: 0, misses: 0, entries: 0}})
    Logger.info("[Compliance] Cache cleared")
    {:reply, :ok, state}
  end

  # ── Private helpers ──────────────────────────────────────────────────

  defp verify_framework_internal(framework, ets_table, bos_path, ttl_ms) do
    case lookup_cache(ets_table, framework) do
      {:hit, result} ->
        update_stats(ets_table, :hit)
        {:ok, Map.put(result, :cached, true)}

      :miss ->
        update_stats(ets_table, :miss)

        case verify_framework(framework, bos_path) do
          {:ok, result} ->
            store_cache(ets_table, framework, result, ttl_ms)
            {:ok, Map.put(result, :cached, false)}

          error ->
            error
        end
    end
  end

  defp verify_framework(framework, bos_path) do
    query_name = compliance_query_name(framework)

    case execute_bos_query(bos_path, query_name) do
      {:ok, result} ->
        parse_verification_result(result)

      error ->
        error
    end
  end

  defp execute_bos_query(bos_path, query_name) do
    case System.cmd(bos_path, ["sparql", "ask", "--query", query_name], [
      {:timeout, @verify_timeout_ms},
      :return_all
    ]) do
      {output, 0} ->
        {:ok, output}

      {error_output, _exit_code} ->
        {:error, {:sparql_error, String.trim(error_output)}}
    end
  rescue
    e ->
      # Catch timeout or execution errors
      if Exception.message(e) =~ "timeout" or Exception.message(e) =~ "timed out" do
        :timeout
      else
        Logger.error("[Compliance] System.cmd error: #{Exception.message(e)}")
        {:error, {:execution_error, Exception.message(e)}}
      end
  end

  defp compliance_query_name(:soc2), do: "soc2_compliance"
  defp compliance_query_name(:gdpr), do: "gdpr_compliance"
  defp compliance_query_name(:hipaa), do: "hipaa_compliance"
  defp compliance_query_name(:sox), do: "sox_compliance"

  defp parse_verification_result(output) when is_binary(output) do
    output = String.trim(output)

    case output do
      "true" ->
        {:ok, %{compliant: true, violations: []}}

      "false" ->
        # When false, we expect additional violation details
        # Format: "false\nViolation 1\nViolation 2\n..."
        lines = String.split(output, "\n")

        violations =
          case lines do
            ["false" | rest] -> Enum.filter(rest, &(&1 != ""))
            _ -> ["Unknown violation detected"]
          end

        {:ok, %{compliant: false, violations: violations}}

      _ ->
        Logger.warning("[Compliance] Unexpected SPARQL result: #{output}")
        {:error, {:parse_error, "Invalid SPARQL response: #{output}"}}
    end
  rescue
    e ->
      Logger.error("[Compliance] Parse error: #{Exception.message(e)}")
      {:error, {:parse_error, Exception.message(e)}}
  end

  defp lookup_cache(ets_table, key) do
    case :ets.lookup(ets_table, key) do
      [{^key, {result, expiry_at}}] ->
        if DateTime.compare(DateTime.utc_now(), expiry_at) == :lt do
          {:hit, result}
        else
          :ets.delete(ets_table, key)
          :miss
        end

      [] ->
        :miss
    end
  end

  defp store_cache(ets_table, key, value, ttl_ms) do
    expiry_at = DateTime.add(DateTime.utc_now(), ttl_ms, :millisecond)
    :ets.insert(ets_table, {key, {value, expiry_at}})
  end

  defp update_stats(ets_table, event) do
    case :ets.lookup(ets_table, @cache_stats_key) do
      [{_, stats}] ->
        updated = case event do
          :hit -> Map.update(stats, :hits, 1, &(&1 + 1))
          :miss -> Map.update(stats, :misses, 1, &(&1 + 1))
        end

        :ets.insert(ets_table, {@cache_stats_key, updated})

      [] ->
        :ets.insert(ets_table, {@cache_stats_key, %{hits: 1, misses: 0, entries: 0}})
    end
  end

  defp get_stats(ets_table) do
    case :ets.lookup(ets_table, @cache_stats_key) do
      [{_, stats}] ->
        count = :ets.info(ets_table, :size) - 1
        Map.put(stats, :entries, max(0, count))

      [] ->
        %{hits: 0, misses: 0, entries: 0}
    end
  end
end
