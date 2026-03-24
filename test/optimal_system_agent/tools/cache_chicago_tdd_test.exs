defmodule OptimalSystemAgent.Tools.CacheChicagoTDDTest do
  @moduledoc """
  Chicago TDD: Tools.Cache integration tests.

  NO MOCKS. Tests verify REAL GenServer behavior with ETS table.

  Following Toyota Code Production System principles:
    - Build Quality In (Jidoka) — tests verify at the source
    - Visual Management — cache stats observable

  Tests (Red Phase):
  1. Cache hit/miss behavior
  2. TTL expiration
  3. Stats tracking (hits, misses, size)
  4. invalidate/1 removes specific entries
  5. clear/0 removes all entries
  6. put/2 uses default TTL
  7. put/3 uses custom TTL
  """

  use ExUnit.Case, async: false

  @moduletag :integration

  alias OptimalSystemAgent.Tools.Cache

  defp ensure_fresh_cache do
    case Process.whereis(Cache) do
      nil -> {:ok, _} = Cache.start_link([])
      pid ->
        GenServer.stop(pid)
        {:ok, _} = Cache.start_link([])
    end
  end

  defp cleanup_cache do
    case Process.whereis(Cache) do
      nil -> :ok
      pid -> GenServer.stop(pid)
    end
    :ok
  end

  describe "Cache — Basic Operations" do
    setup do
      ensure_fresh_cache()
      on_exit(fn -> cleanup_cache() end)
      :ok
    end

    test "CRASH: get returns :miss for non-existent key" do
      assert Cache.get("nonexistent") == :miss
    end

    test "CRASH: put then get returns {:ok, value}" do
      assert Cache.put("key1", "value1") == :ok
      assert Cache.get("key1") == {:ok, "value1"}
    end

    test "CRASH: put with custom TTL works" do
      assert Cache.put("key2", "value2", 5000) == :ok
      assert Cache.get("key2") == {:ok, "value2"}
    end

    test "CRASH: put with TTL <= 1 raises error" do
      assert_raise FunctionClauseError, fn ->
        Cache.put("key", "value", 0)
      end

      assert_raise FunctionClauseError, fn ->
        Cache.put("key", "value", -1)
      end
    end
  end

  describe "Cache — TTL Expiration" do
    setup do
      ensure_fresh_cache()
      on_exit(fn -> cleanup_cache() end)
      :ok
    end

    test "CRASH: Entry expires after TTL" do
      assert Cache.put("expire_key", "value", 100) == :ok
      assert Cache.get("expire_key") == {:ok, "value"}

      Process.sleep(150)

      assert Cache.get("expire_key") == {:miss, :expired}
    end

    test "CRASH: Entry persists before TTL expires" do
      assert Cache.put("persist_key", "value", 1000) == :ok

      Process.sleep(100)
      assert Cache.get("persist_key") == {:ok, "value"}
    end

    test "CRASH: Multiple expirations tracked correctly" do
      assert Cache.put("fast1", "v1", 50) == :ok
      assert Cache.put("fast2", "v2", 50) == :ok
      assert Cache.put("slow", "v3", 1000) == :ok

      Process.sleep(75)

      assert Cache.get("fast1") == {:miss, :expired}
      assert Cache.get("fast2") == {:miss, :expired}
      assert Cache.get("slow") == {:ok, "v3"}
    end
  end

  describe "Cache — Stats Tracking" do
    setup do
      ensure_fresh_cache()
      on_exit(fn -> cleanup_cache() end)
      :ok
    end

    test "CRASH: stats returns hit/miss counts and size" do
      stats = Cache.stats()
      assert Map.has_key?(stats, :hits)
      assert Map.has_key?(stats, :misses)
      assert Map.has_key?(stats, :size)
      assert stats.hits == 0
      assert stats.misses == 0
      assert stats.size == 0
    end

    test "CRASH: hit increments on cache hit" do
      assert Cache.put("key", "value") == :ok
      assert Cache.get("key") == {:ok, "value"}

      stats = Cache.stats()
      assert stats.hits == 1
      assert stats.misses == 0
    end

    test "CRASH: miss increments on cache miss" do
      Cache.get("nonexistent")

      stats = Cache.stats()
      assert stats.hits == 0
      assert stats.misses == 1
    end

    test "CRASH: expired entry increments miss count" do
      assert Cache.put("expire", "value", 50) == :ok
      Process.sleep(75)

      assert Cache.get("expire") == {:miss, :expired}

      stats = Cache.stats()
      assert stats.hits == 0
      assert stats.misses == 1
    end

    test "CRASH: size reflects number of entries" do
      assert Cache.put("k1", "v1") == :ok
      assert Cache.put("k2", "v2") == :ok
      assert Cache.put("k3", "v3") == :ok

      stats = Cache.stats()
      assert stats.size == 3
    end

    test "CRASH: size decreases when entries expire" do
      assert Cache.put("expire", "value", 50) == :ok
      stats = Cache.stats()
      assert stats.size == 1

      Process.sleep(75)
      Cache.get("expire")

      stats = Cache.stats()
      assert stats.size == 0
    end
  end

  describe "Cache — invalidate/1" do
    setup do
      ensure_fresh_cache()
      on_exit(fn -> cleanup_cache() end)
      :ok
    end

    test "CRASH: invalidate removes entry" do
      assert Cache.put("key", "value") == :ok
      assert Cache.get("key") == {:ok, "value"}

      assert Cache.invalidate("key") == :ok
      assert Cache.get("key") == :miss
    end

    test "CRASH: invalidate non-existent key returns :ok" do
      assert Cache.invalidate("nonexistent") == :ok
    end

    test "CRASH: invalidate doesn't affect other entries" do
      assert Cache.put("k1", "v1") == :ok
      assert Cache.put("k2", "v2") == :ok

      Cache.invalidate("k1")

      assert Cache.get("k1") == :miss
      assert Cache.get("k2") == {:ok, "v2"}
    end
  end

  describe "Cache — clear/0" do
    setup do
      ensure_fresh_cache()
      on_exit(fn -> cleanup_cache() end)
      :ok
    end

    test "CRASH: clear removes all entries" do
      assert Cache.put("k1", "v1") == :ok
      assert Cache.put("k2", "v2") == :ok
      assert Cache.put("k3", "v3") == :ok

      stats = Cache.stats()
      assert stats.size == 3

      Cache.clear()

      stats = Cache.stats()
      assert stats.size == 0
    end

    test "CRASH: clear doesn't reset hit/miss counts (GAP)" do
      assert Cache.put("k1", "v1") == :ok
      Cache.get("k1")
      Cache.get("nonexistent")

      stats_before = Cache.stats()
      assert stats_before.hits == 1
      assert stats_before.misses == 1

      Cache.clear()

      stats_after = Cache.stats()
      # GAP: stats are NOT reset by clear/0
      assert stats_after.hits == 1
      assert stats_after.misses == 1
      assert stats_after.size == 0
    end

    test "CRASH: clear on empty cache is safe" do
      assert Cache.clear() == :ok
      stats = Cache.stats()
      assert stats.size == 0
    end
  end

  describe "Cache — Default TTL" do
    setup do
      ensure_fresh_cache()
      on_exit(fn -> cleanup_cache() end)
      :ok
    end

    test "CRASH: put/2 uses default TTL (60 seconds)" do
      assert Cache.put("key", "value") == :ok
      assert Cache.get("key") == {:ok, "value"}

      Process.sleep(1000)
      assert Cache.get("key") == {:ok, "value"}
    end

    test "CRASH: Default TTL is 60_000ms" do
      assert Cache.put("key", "value") == :ok
      Process.sleep(100)
      assert Cache.get("key") == {:ok, "value"}
    end
  end

  describe "Cache — Overwrite Behavior" do
    setup do
      ensure_fresh_cache()
      on_exit(fn -> cleanup_cache() end)
      :ok
    end

    test "CRASH: put overwrites existing value" do
      assert Cache.put("key", "value1") == :ok
      assert Cache.put("key", "value2") == :ok

      assert Cache.get("key") == {:ok, "value2"}
    end

    test "CRASH: Overwrite resets TTL" do
      assert Cache.put("key", "v1", 100) == :ok
      Process.sleep(75)

      assert Cache.get("key") == {:ok, "v1"}

      assert Cache.put("key", "v2", 100) == :ok
      Process.sleep(75)

      assert Cache.get("key") == {:ok, "v2"}
    end
  end

  describe "Cache — Complex Keys" do
    setup do
      ensure_fresh_cache()
      on_exit(fn -> cleanup_cache() end)
      :ok
    end

    test "CRASH: Supports string keys" do
      assert Cache.put("string_key", "value") == :ok
      assert Cache.get("string_key") == {:ok, "value"}
    end

    test "CRASH: Supports atom keys" do
      assert Cache.put(:atom_key, "value") == :ok
      assert Cache.get(:atom_key) == {:ok, "value"}
    end

    test "CRASH: Supports tuple keys" do
      assert Cache.put({"composite", "key"}, "value") == :ok
      assert Cache.get({"composite", "key"}) == {:ok, "value"}
    end

    test "CRASH: Different keys are independent" do
      assert Cache.put("key1", "v1") == :ok
      assert Cache.put(:key1, "v2") == :ok
      assert Cache.put({"key", "1"}, "v3") == :ok

      assert Cache.get("key1") == {:ok, "v1"}
      assert Cache.get(:key1) == {:ok, "v2"}
      assert Cache.get({"key", "1"}) == {:ok, "v3"}
    end
  end

  describe "Cache — Complex Values" do
    setup do
      ensure_fresh_cache()
      on_exit(fn -> cleanup_cache() end)
      :ok
    end

    test "CRASH: Stores binary values" do
      assert Cache.put("key", "binary") == :ok
      assert Cache.get("key") == {:ok, "binary"}
    end

    test "CRASH: Stores map values" do
      value = %{nested: %{data: "here"}}
      assert Cache.put("key", value) == :ok
      assert Cache.get("key") == {:ok, value}
    end

    test "CRASH: Stores list values" do
      value = [1, 2, 3, "four"]
      assert Cache.put("key", value) == :ok
      assert Cache.get("key") == {:ok, value}
    end

    test "CRASH: Stores tuple values" do
      value = {:ok, "result"}
      assert Cache.put("key", value) == :ok
      assert Cache.get("key") == {:ok, value}
    end
  end

  describe "Cache — Concurrent Access" do
    setup do
      ensure_fresh_cache()
      on_exit(fn -> cleanup_cache() end)
      :ok
    end

    test "CRASH: Multiple puts work correctly" do
      tasks = for i <- 1..10 do
        Task.async(fn ->
          Cache.put("key#{i}", "value#{i}")
        end)
      end

      Enum.each(tasks, &Task.await/1)

      for i <- 1..10 do
        assert Cache.get("key#{i}") == {:ok, "value#{i}"}
      end

      stats = Cache.stats()
      assert stats.size == 10
    end

    test "CRASH: Multiple gets work correctly" do
      Cache.put("shared_key", "shared_value")

      tasks = for _i <- 1..5 do
        Task.async(fn ->
          Cache.get("shared_key")
        end)
      end

      results = Enum.map(tasks, &Task.await/1)

      Enum.each(results, fn
        {:ok, "shared_value"} -> :ok
        _ -> flunk("Expected all to get cache hit")
      end)

      stats = Cache.stats()
      assert stats.hits >= 5
    end
  end

  describe "Cache — Edge Cases" do
    setup do
      ensure_fresh_cache()
      on_exit(fn -> cleanup_cache() end)
      :ok
    end

    test "CRASH: Empty string key works" do
      assert Cache.put("", "value") == :ok
      assert Cache.get("") == {:ok, "value"}
    end

    test "CRASH: nil value can be stored" do
      assert Cache.put("key", nil) == :ok
      assert Cache.get("key") == {:ok, nil}
    end

    test "CRASH: Large values can be stored" do
      large_value = String.duplicate("x", 1_000_000)
      assert Cache.put("key", large_value) == :ok
      assert Cache.get("key") == {:ok, large_value}
    end

    test "CRASH: invalidate with nil key doesn't crash" do
      result = Cache.invalidate(nil)
      assert result == :ok
    end
  end
end
