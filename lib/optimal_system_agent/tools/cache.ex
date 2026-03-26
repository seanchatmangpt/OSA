defmodule OptimalSystemAgent.Tools.Cache do
  @moduledoc """
  ETS-backed tool result cache with per-entry TTL and bounded size.

  Each cache entry stores `{key, value, expires_at_monotonic_ms, accessed_at_monotonic_ms}`.
  Expired entries are lazily evicted on `get/1`.
  LRU (Least Recently Used) eviction triggered when size exceeds @max_cache_size.

  Tracks hit/miss counts and eviction counts in GenServer state for `stats/0`.
  """
  use GenServer
  require Logger

  @table :tool_result_cache
  @default_ttl_ms 60_000
  @max_cache_size 1000
  @eviction_target 950

  # ── Public API ──────────────────────────────────────────────────────

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Fetch a cached value. Returns `{:ok, value}`, `:miss`, or `{:miss, :expired}`."
  def get(key) do
    GenServer.call(__MODULE__, {:get, key})
  end

  @doc "Store a value with the default TTL."
  def put(key, value) do
    put(key, value, @default_ttl_ms)
  end

  @doc "Store a value with a custom TTL in milliseconds."
  def put(key, value, ttl_ms) when is_integer(ttl_ms) and ttl_ms > 0 do
    now = System.monotonic_time(:millisecond)
    expires_at = now + ttl_ms

    # Check size and evict if needed BEFORE inserting
    size = :ets.info(@table, :size)
    if size >= @max_cache_size do
      GenServer.cast(__MODULE__, :evict_lru)
    end

    :ets.insert(@table, {key, value, expires_at, now})
    GenServer.cast(__MODULE__, :put)
    :ok
  end

  @doc "Remove a specific entry."
  def invalidate(key) do
    :ets.delete(@table, key)
    :ok
  end

  @doc "Remove all entries."
  def clear do
    :ets.delete_all_objects(@table)
    :ok
  end

  @doc "Return cache statistics."
  def stats do
    GenServer.call(__MODULE__, :stats)
  end

  # ── GenServer callbacks ─────────────────────────────────────────────

  @impl true
  def init(_opts) do
    :ets.new(@table, [:named_table, :public, :set])
    {:ok, %{hits: 0, misses: 0, evictions: 0, max_size_observed: 0}}
  end

  @impl true
  def handle_call({:get, key}, _from, state) do
    now = System.monotonic_time(:millisecond)

    case :ets.lookup(@table, key) do
      [] ->
        {:reply, :miss, %{state | misses: state.misses + 1}}

      [{^key, _value, expires_at, _accessed_at}] when expires_at <= now ->
        :ets.delete(@table, key)
        {:reply, {:miss, :expired}, %{state | misses: state.misses + 1}}

      [{^key, value, _expires_at, _accessed_at}] ->
        # Update accessed_at timestamp for LRU tracking
        :ets.update_element(@table, key, {4, now})
        {:reply, {:ok, value}, %{state | hits: state.hits + 1}}
    end
  end

  @impl true
  def handle_call(:stats, _from, state) do
    size = :ets.info(@table, :size)
    new_state = %{state | max_size_observed: max(state.max_size_observed, size)}
    {:reply, Map.put(new_state, :size, size), new_state}
  end

  @impl true
  def handle_cast(:put, state) do
    {:noreply, state}
  end

  @impl true
  def handle_cast(:evict_lru, state) do
    size = :ets.info(@table, :size)

    if size >= @max_cache_size do
      # Get all entries sorted by accessed_at (oldest first)
      all_entries = :ets.tab2list(@table)

      entries_to_evict =
        all_entries
        |> Enum.sort_by(fn {_k, _v, _exp, accessed_at} -> accessed_at end)
        |> Enum.take(size - @eviction_target)

      Enum.each(entries_to_evict, fn {key, _v, _exp, _accessed_at} ->
        :ets.delete(@table, key)
      end)

      evicted_count = length(entries_to_evict)
      Logger.debug(
        "tool_result_cache: evicted #{evicted_count} entries (size #{size} -> #{@eviction_target})"
      )

      {:noreply, %{state | evictions: state.evictions + evicted_count}}
    else
      {:noreply, state}
    end
  end
end
