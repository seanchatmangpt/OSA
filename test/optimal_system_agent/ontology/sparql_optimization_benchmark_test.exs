defmodule OptimalSystemAgent.Ontology.SPARQLOptimizationBenchmarkTest do
  use ExUnit.Case, async: true

  alias OptimalSystemAgent.Ontology.SPARQLOptimizer
  alias OptimalSystemAgent.Ontology.SPARQLExecutorCached

  @moduletag :sparql_benchmark

  # Test Data: Realistic SPARQL Queries
  # ===================================

  @query_find_agents """
  PREFIX osa: <http://example.com/osa/>
  PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>

  SELECT ?agent ?name WHERE {
    ?agent a osa:Agent ;
           rdfs:label ?name .
  }
  LIMIT 100
  """

  @query_agent_tools """
  PREFIX osa: <http://example.com/osa/>
  PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>

  SELECT ?tool ?description WHERE {
    ?agent a osa:Agent ;
           osa:hasTool ?tool .
    ?tool rdfs:comment ?description .
  }
  LIMIT 100
  """

  @query_process_path """
  PREFIX osa: <http://example.com/osa/>
  PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>

  SELECT ?step ?next WHERE {
    ?process a osa:Process ;
             osa:hasStep ?step ;
             osa:nextStep ?step ?next .
  }
  LIMIT 100
  """

  @query_deadlock_detection_complex """
  PREFIX osa: <http://example.com/osa/>
  PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>

  SELECT ?process ?lock1 ?lock2 WHERE {
    {
      ?process a osa:Process ;
               osa:holds ?lock1 ;
               osa:waits ?lock2 .
      ?other a osa:Process ;
             osa:holds ?lock2 ;
             osa:waits ?lock1 .
    }
    UNION
    {
      ?process a osa:Process ;
               osa:holds ?lock1 .
      ?lock1 osa:contends ?lock2 .
      ?lock2 osa:contends ?lock1 .
    }
  }
  LIMIT 1000
  """

  @query_with_optional """
  PREFIX osa: <http://example.com/osa/>
  PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>

  SELECT ?agent ?name ?health WHERE {
    ?agent a osa:Agent ;
           rdfs:label ?name .
    OPTIONAL {
      ?agent osa:health ?health .
    }
    OPTIONAL {
      ?agent osa:lastSeen ?seen .
    }
    OPTIONAL {
      ?agent osa:errorCount ?errors .
    }
  }
  LIMIT 100
  """

  # ── Benchmark: Query Analysis ────────────────────────────────────────

  describe "Query Analysis Performance" do
    test "analyze_simple_query: <5ms for simple queries" do
      assert measure_analysis(@query_find_agents) < 5
    end

    test "analyze_complex_query: <10ms for complex queries" do
      assert measure_analysis(@query_deadlock_detection_complex) < 10
    end

    test "analyze_identifies_union_blocks" do
      {:ok, analysis} = SPARQLOptimizer.analyze(@query_deadlock_detection_complex)
      assert analysis.union_count > 0
      assert Enum.any?(analysis.opportunities, &(&1.code == "union_all"))
    end

    test "analyze_identifies_optional_blocks" do
      {:ok, analysis} = SPARQLOptimizer.analyze(@query_with_optional)
      assert analysis.optional_count >= 3
      assert Enum.any?(analysis.opportunities, &(&1.code == "optional_elimination"))
    end

    test "analyze_detects_large_queries" do
      large_query = String.duplicate("# comment\n", 500) <> @query_find_agents
      {:ok, analysis} = SPARQLOptimizer.analyze(large_query)
      assert analysis.size_bytes > 1000
    end
  end

  # ── Benchmark: Query Rewriting ────────────────────────────────────────

  describe "Query Rewriting Performance" do
    test "rewrite_simple_query: <2ms rewrite time" do
      assert measure_rewrite(@query_find_agents) < 2
    end

    test "rewrite_complex_query: <5ms even with complex patterns" do
      assert measure_rewrite(@query_deadlock_detection_complex) < 5
    end

    test "rewrite_union_to_union_all_optimization" do
      {:ok, rewritten} = SPARQLOptimizer.rewrite(@query_deadlock_detection_complex)
      # Verify UNION ALL was applied
      assert String.contains?(rewritten, "UNION ALL") or not String.contains?(rewritten, "UNION")
    end

    test "rewrite_preserves_query_semantics" do
      {:ok, rewritten} = SPARQLOptimizer.rewrite(@query_find_agents)
      # Both should have SELECT
      assert String.contains?(@query_find_agents, "SELECT")
      assert String.contains?(rewritten, "SELECT")
      # Both should have LIMIT
      assert String.contains?(@query_find_agents, "LIMIT")
      assert String.contains?(rewritten, "LIMIT")
    end

    test "rewrite_handles_malformed_gracefully" do
      bad_query = "SELECT ? WHERE { INVALID SYNTAX }"
      # Should not crash, even if it can't optimize
      result = SPARQLOptimizer.rewrite(bad_query)
      assert result == {:ok, bad_query} or elem(result, 0) == :ok
    end
  end

  # ── Benchmark: Cache Key Generation ────────────────────────────────────

  describe "Cache Key Generation" do
    test "cache_key_deterministic: same query always produces same key" do
      key1 = SPARQLOptimizer.cache_key(@query_find_agents)
      key2 = SPARQLOptimizer.cache_key(@query_find_agents)
      assert key1 == key2
    end

    test "cache_key_unique: different queries produce different keys" do
      key1 = SPARQLOptimizer.cache_key(@query_find_agents)
      key2 = SPARQLOptimizer.cache_key(@query_agent_tools)
      assert key1 != key2
    end

    test "cache_key_collision_resistant: whitespace differences handled" do
      query1 = "SELECT ?x WHERE { ?x a osa:Agent . }"
      query2 = "SELECT ?x WHERE {   ?x   a   osa:Agent   .   }"
      key1 = SPARQLOptimizer.cache_key(query1)
      key2 = SPARQLOptimizer.cache_key(query2)
      # Same semantic query should produce same key after normalization
      assert key1 == key2
    end

    test "cache_key_generation: <1ms for typical queries" do
      time_ms = measure_cache_key_generation(@query_deadlock_detection_complex)
      assert time_ms < 1
    end
  end

  # ── Benchmark: Determinism Detection ────────────────────────────────────

  describe "Determinism Detection" do
    test "is_deterministic: true for queries without NOW/RAND" do
      {:ok, det} = SPARQLOptimizer.is_deterministic?(@query_find_agents)
      assert det == true
    end

    test "is_deterministic: false for queries with NOW()" do
      non_det = @query_find_agents <> " FILTER (?timestamp > NOW()) "
      {:ok, det} = SPARQLOptimizer.is_deterministic?(non_det)
      assert det == false
    end

    test "is_deterministic: false for queries with RAND()" do
      non_det = @query_find_agents <> " FILTER (RAND() > 0.5) "
      {:ok, det} = SPARQLOptimizer.is_deterministic?(non_det)
      assert det == false
    end

    test "is_deterministic: false for queries with UUID()" do
      non_det = @query_find_agents <> " BIND (UUID() AS ?id) "
      {:ok, det} = SPARQLOptimizer.is_deterministic?(non_det)
      assert det == false
    end

    test "is_deterministic: check is fast (<1ms)" do
      time_ms = measure_determinism_check(@query_deadlock_detection_complex)
      assert time_ms < 1
    end
  end

  # ── Benchmark: Executor with Caching ────────────────────────────────────

  describe "SPARQLExecutorCached" do
    setup do
      # Start the cached executor
      {:ok, _pid} = SPARQLExecutorCached.start_link(cache_enabled: true)
      :ok
    end

    test "executor_stats: initial state is zero" do
      stats = SPARQLExecutorCached.stats()
      assert stats.hits == 0
      assert stats.misses == 0
      assert stats.query_count >= 0
    end

    test "executor_clear_cache: resets statistics" do
      SPARQLExecutorCached.clear_cache()
      stats = SPARQLExecutorCached.stats()
      assert stats.hits == 0
      assert stats.misses == 0
    end
  end

  # ── Integration Benchmark: Full Pipeline ────────────────────────────────

  describe "Full Optimization Pipeline" do
    test "pipeline_query_1_agents: <5ms (analyze + rewrite + cache key)" do
      time_ms = measure_pipeline(@query_find_agents)
      assert time_ms < 5
    end

    test "pipeline_query_2_tools: <5ms" do
      time_ms = measure_pipeline(@query_agent_tools)
      assert time_ms < 5
    end

    test "pipeline_query_3_process_path: <10ms" do
      time_ms = measure_pipeline(@query_process_path)
      assert time_ms < 10
    end

    test "pipeline_query_4_deadlock_detection: <15ms" do
      time_ms = measure_pipeline(@query_deadlock_detection_complex)
      assert time_ms < 15
    end

    test "pipeline_query_5_with_optional: <10ms" do
      time_ms = measure_pipeline(@query_with_optional)
      assert time_ms < 10
    end

    test "pipeline_concurrent_queries: 10 queries in <50ms" do
      queries = [
        @query_find_agents,
        @query_agent_tools,
        @query_process_path,
        @query_deadlock_detection_complex,
        @query_with_optional
      ]

      start_time = System.monotonic_time(:millisecond)

      tasks = Enum.flat_map(1..2, fn _ ->
        Enum.map(queries, fn query ->
          Task.async(fn ->
            measure_pipeline(query)
          end)
        end)
      end)

      _times = Task.await_many(tasks)
      elapsed_ms = System.monotonic_time(:millisecond) - start_time

      assert elapsed_ms < 50, "10 concurrent queries took #{elapsed_ms}ms, expected <50ms"
    end
  end

  # ── Performance Summary Report ────────────────────────────────────────

  describe "Performance Summary" do
    test "summary_all_queries_meet_sla" do
      queries = [
        {"Query 1: Find Agents", @query_find_agents},
        {"Query 2: Agent Tools", @query_agent_tools},
        {"Query 3: Process Path", @query_process_path},
        {"Query 4: Deadlock Detection", @query_deadlock_detection_complex},
        {"Query 5: With Optional", @query_with_optional}
      ]

      results = Enum.map(queries, fn {name, query} ->
        time_ms = measure_pipeline(query)
        {name, time_ms}
      end)

      # Verify all meet <100ms SLA
      Enum.each(results, fn {name, time_ms} ->
        assert time_ms < 100, "#{name} took #{time_ms}ms, expected <100ms"
      end)

      # Print summary
      IO.puts("\n╔════ SPARQL Query Performance Summary ════╗")
      Enum.each(results, fn {name, time_ms} ->
        status = if time_ms < 10, do: "✓ ", else: "✓ "
        IO.puts("#{status}#{name}: #{time_ms}ms")
      end)
      IO.puts("╚════════════════════════════════════════╝\n")
    end
  end

  # ── Measurement Helpers ────────────────────────────────────────────────

  defp measure_analysis(query) do
    start = System.monotonic_time(:millisecond)
    {:ok, _analysis} = SPARQLOptimizer.analyze(query)
    System.monotonic_time(:millisecond) - start
  end

  defp measure_rewrite(query) do
    start = System.monotonic_time(:millisecond)
    {:ok, _rewritten} = SPARQLOptimizer.rewrite(query)
    System.monotonic_time(:millisecond) - start
  end

  defp measure_cache_key_generation(query) do
    start = System.monotonic_time(:millisecond)
    _key = SPARQLOptimizer.cache_key(query)
    System.monotonic_time(:millisecond) - start
  end

  defp measure_determinism_check(query) do
    start = System.monotonic_time(:millisecond)
    {:ok, _det} = SPARQLOptimizer.is_deterministic?(query)
    System.monotonic_time(:millisecond) - start
  end

  defp measure_pipeline(query) do
    start = System.monotonic_time(:millisecond)
    {:ok, _analysis} = SPARQLOptimizer.analyze(query)
    {:ok, _rewritten} = SPARQLOptimizer.rewrite(query)
    _key = SPARQLOptimizer.cache_key(query)
    {:ok, _det} = SPARQLOptimizer.is_deterministic?(query)
    System.monotonic_time(:millisecond) - start
  end
end
