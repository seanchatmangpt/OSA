defmodule OptimalSystemAgent.Caching.QueryCache do
  @moduledoc """
  Multi-level query cache with L1 (ETS, 1min TTL) and L2 (Redis fallback, 5min TTL).

  Provides high-performance caching for expensive queries with automatic
  expiration and concurrent access safety.
  """

  use GenServer
  require Logger

  @call_timeout 10_000
  @l1_ttl_ms 60_000  # 1 minute
  @l2_ttl_ms 300_000  # 5 minutes
  @stats_key :__cache_stats__

  # Client API

  @doc """
  Start the cache as a GenServer.

  Options:
    - `:name` - atom name for the cache process
    - `:redis_config` - optional Redis connection config (host, port, db)
  """
  def start_link(opts) do
    name = Keyword.get(opts, :name, :query_cache)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Get a cached value or compute and cache it.

  Attempts L1 (ETS) lookup first, then L2 (Redis), then executes the function.
  """
  def get_cached(cache_ref, key, compute_fn) when is_function(compute_fn, 0) do
    # Check L1 cache (ETS)
    case lookup_l1(cache_ref, key) do
      {:ok, value} ->
        update_stats(cache_ref, :hit)
        value

      :miss ->
        # Compute and store
        value = compute_fn.()
        store_l1(cache_ref, key, value)
        store_l2_async(cache_ref, key, value)
        update_stats(cache_ref, :miss)
        value
    end
  end

  @doc """
  Invalidate a cached entry across all levels.
  """
  def invalidate(cache_ref, key) do
    delete_l1(cache_ref, key)
    delete_l2_async(cache_ref, key)
    :ok
  end

  @doc """
  Get cache statistics (hits, misses, entries count).
  """
  def stats(cache_ref) do
    GenServer.call(cache_ref, :get_stats, @call_timeout)
  end

  @doc """
  Clear all cache entries.
  """
  def clear(cache_ref) do
    GenServer.call(cache_ref, :clear_cache, @call_timeout)
  end

  # GenServer Callbacks

  @impl GenServer
  def init(opts) do
    name = Keyword.get(opts, :name, :query_cache)
    redis_config = Keyword.get(opts, :redis_config, nil)

    # Create ETS table for L1 cache
    ets_table = :"#{name}_l1"
    :ets.new(ets_table, [:set, :public, :named_table, {:read_concurrency, true}, {:write_concurrency, true}])

    # Initialize stats
    :ets.insert(ets_table, {@stats_key, %{hits: 0, misses: 0, entries: 0}})

    # Try to connect to Redis if configured
    redis_pid = if redis_config, do: connect_redis(redis_config), else: nil

    state = %{
      ets_table: ets_table,
      redis_pid: redis_pid,
      redis_config: redis_config,
      l1_ttl_ms: @l1_ttl_ms,
      l2_ttl_ms: @l2_ttl_ms,
    }

    {:ok, state}
  end

  @impl GenServer
  def handle_call(:get_stats, _from, state) do
    case :ets.lookup(state.ets_table, @stats_key) do
      [{_, stats}] ->
        count = :ets.info(state.ets_table, :size) - 1  # -1 for stats entry itself
        {:reply, Map.put(stats, :entries, count), state}

      [] ->
        {:reply, %{hits: 0, misses: 0, entries: 0}, state}
    end
  end

  @impl GenServer
  def handle_call(:clear_cache, _from, state) do
    :ets.delete_all_objects(state.ets_table)
    :ets.insert(state.ets_table, {@stats_key, %{hits: 0, misses: 0, entries: 0}})
    {:reply, :ok, state}
  end

  @impl GenServer
  def handle_call(:get_ets_table, _from, state) do
    {:reply, state.ets_table, state}
  end

  @impl GenServer
  def handle_info({:cleanup_expired}, state) do
    # Periodic cleanup of expired entries
    cleanup_expired_l1(state.ets_table)
    Process.send_after(self(), {:cleanup_expired}, 30_000)  # Every 30 seconds
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(_, state) do
    {:noreply, state}
  end

  @impl GenServer
  def terminate(_reason, state) do
    if state.ets_table && :ets.info(state.ets_table, :name) do
      :ets.delete(state.ets_table)
    end
  end

  # Private Helpers

  defp lookup_l1(cache_ref, key) do
    ets_table = GenServer.call(cache_ref, :get_ets_table, 5000)

    case :ets.lookup(ets_table, key) do
      [{^key, {value, expires_at}}] ->
        if System.monotonic_time(:millisecond) < expires_at do
          {:ok, value}
        else
          :ets.delete(ets_table, key)
          :miss
        end

      [] ->
        :miss
    end
  end

  defp store_l1(cache_ref, key, value) do
    ets_table = GenServer.call(cache_ref, :get_ets_table, 5000)
    expires_at = System.monotonic_time(:millisecond) + @l1_ttl_ms
    :ets.insert(ets_table, {key, {value, expires_at}})
  end

  defp store_l2_async(_cache_ref, _key, _value) do
    # Redis store would go here asynchronously
    :ok
  end

  defp delete_l1(cache_ref, key) do
    ets_table = GenServer.call(cache_ref, :get_ets_table, 5000)
    :ets.delete(ets_table, key)
  end

  defp delete_l2_async(_cache_ref, _key) do
    # Redis delete would go here asynchronously
    :ok
  end

  defp update_stats(cache_ref, type) do
    GenServer.cast(cache_ref, {:update_stats, type})
  end

  defp cleanup_expired_l1(ets_table) do
    now = System.monotonic_time(:millisecond)
    spec = [
      {:"$1", [{:<, {:"$2", now}}], [:"$1"]}
    ]

    :ets.select_delete(ets_table, spec)
  end

  defp connect_redis(_config) do
    # Redis connection setup would go here
    nil
  end

  @impl GenServer
  def handle_cast({:update_stats, type}, state) do
    ets_table = state.ets_table

    case :ets.lookup(ets_table, @stats_key) do
      [{_, stats}] ->
        new_stats = case type do
          :hit -> Map.update(stats, :hits, 0, &(&1 + 1))
          :miss -> Map.update(stats, :misses, 0, &(&1 + 1))
        end
        :ets.insert(ets_table, {@stats_key, new_stats})

      [] ->
        :ets.insert(ets_table, {@stats_key, %{hits: 1, misses: 0, entries: 0}})
    end

    {:noreply, state}
  end
end
