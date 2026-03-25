defmodule OptimalSystemAgent.Caching.QueryCacheTest do
  use ExUnit.Case
  doctest OptimalSystemAgent.Caching.QueryCache

  alias OptimalSystemAgent.Caching.QueryCache

  setup do
    # Cleanup any existing cache
    if Process.whereis(TestQueryCache), do: GenServer.stop(TestQueryCache)
    :timer.sleep(10)

    {:ok, cache_pid} = QueryCache.start_link(name: TestQueryCache)
    {:ok, cache_pid: cache_pid}
  end

  describe "get_cached/2" do
    test "returns cached value on hit", %{cache_pid: _cache_pid} do
      value = "test_result"
      key = "query:test:1"

      result = QueryCache.get_cached(TestQueryCache, key, fn ->
        value
      end)

      assert result == value
    end

    test "executes function on cache miss", %{cache_pid: _cache_pid} do
      key = "query:test:2"
      {:ok, call_count} = Agent.start_link(fn -> 0 end)

      result1 = QueryCache.get_cached(TestQueryCache, key, fn ->
        Agent.update(call_count, &(&1 + 1))
        "expensive_computation"
      end)

      result2 = QueryCache.get_cached(TestQueryCache, key, fn ->
        Agent.update(call_count, &(&1 + 1))
        "expensive_computation"
      end)

      count = Agent.get(call_count, & &1)

      assert result1 == "expensive_computation"
      assert result2 == "expensive_computation"
      assert count == 1, "Function should be called only once"
    end
  end

  describe "invalidate/2" do
    test "removes cached entry", %{cache_pid: _cache_pid} do
      key = "query:test:3"

      # First call caches the result
      result1 = QueryCache.get_cached(TestQueryCache, key, fn -> "value1" end)
      assert result1 == "value1"

      # Invalidate the cache
      QueryCache.invalidate(TestQueryCache, key)

      # Next call should recompute
      result2 = QueryCache.get_cached(TestQueryCache, key, fn -> "value2" end)
      assert result2 == "value2"
    end
  end

  describe "stats/1" do
    test "returns cache statistics", %{cache_pid: _cache_pid} do
      key1 = "query:test:4"
      key2 = "query:test:5"

      QueryCache.get_cached(TestQueryCache, key1, fn -> "value1" end)
      QueryCache.get_cached(TestQueryCache, key2, fn -> "value2" end)

      # Hit the cache
      QueryCache.get_cached(TestQueryCache, key1, fn -> "value1" end)
      QueryCache.get_cached(TestQueryCache, key1, fn -> "value1" end)

      stats = QueryCache.stats(TestQueryCache)

      assert is_map(stats)
      assert stats.hits >= 2
      assert stats.misses >= 2
      assert stats.entries >= 2
    end
  end

  describe "concurrent access" do
    test "handles concurrent cache access safely", %{cache_pid: _cache_pid} do
      key = "query:test:6"

      tasks = for _i <- 1..10 do
        Task.async(fn ->
          QueryCache.get_cached(TestQueryCache, key, fn ->
            :timer.sleep(10)
            "concurrent_result"
          end)
        end)
      end

      results = Task.await_many(tasks)

      assert Enum.all?(results, &(&1 == "concurrent_result"))
      assert length(results) == 10
    end
  end
end
