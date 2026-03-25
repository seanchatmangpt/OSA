defmodule OptimalSystemAgent.Idempotency.KeyStore do
  @moduledoc """
  Idempotency key store — prevents duplicate processing of requests.

  Uses ETS table `:osa_idempotency_keys` to store request results with a 24-hour TTL.
  Automatically cleans up expired keys every hour.

  Public API:
  - `store(key, result)` — Cache a request result
  - `get(key)` — Retrieve a cached result (returns nil if expired)
  - `delete(key)` — Remove a key manually
  """

  use GenServer
  require Logger

  @table :osa_idempotency_keys
  @ttl_seconds 86_400  # 24 hours
  @cleanup_interval_ms 3_600_000  # 1 hour

  # -- Public API ------------------------------------------------------------

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, Keyword.put_new(opts, :name, __MODULE__))
  end

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      restart: :permanent,
      type: :worker
    }
  end

  @doc "Store a request result with a unique idempotency key."
  def store(key, result) when is_binary(key) do
    entry = %{
      "key" => key,
      "result" => result,
      "stored_at" => System.monotonic_time(:second),
      "expires_at" => System.monotonic_time(:second) + @ttl_seconds
    }
    :ets.insert(@table, {key, entry})
    :ok
  end

  @doc "Retrieve a cached result by key. Returns nil if expired or not found."
  def get(key) when is_binary(key) do
    case :ets.lookup(@table, key) do
      [] ->
        nil

      [{^key, entry}] ->
        now = System.monotonic_time(:second)

        if entry["expires_at"] > now do
          entry["result"]
        else
          # Delete expired entry
          :ets.delete(@table, key)
          nil
        end
    end
  end

  @doc "Manually delete an idempotency key."
  def delete(key) when is_binary(key) do
    :ets.delete(@table, key)
    :ok
  end

  @doc "Return statistics about the store."
  def stats do
    count = :ets.info(@table, :size)
    memory = :ets.info(@table, :memory)

    %{
      "total_keys" => count,
      "memory_bytes" => memory * 8  # ETS memory in machine words
    }
  end

  # -- GenServer Implementation -----------------------------------------------

  @impl true
  def init(:ok) do
    # Create the ETS table if it doesn't exist
    if :ets.whereis(@table) == :undefined do
      :ets.new(@table, [:named_table, :public, :set, {:keypos, 1}])
    end

    # Schedule background cleanup
    schedule_cleanup()

    {:ok, %{}}
  end

  @impl true
  def handle_info(:cleanup, state) do
    cleanup_expired_keys()
    schedule_cleanup()
    {:noreply, state}
  end

  # -- Private ----------------------------------------------------------------

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, @cleanup_interval_ms)
  end

  defp cleanup_expired_keys do
    now = System.monotonic_time(:second)

    :ets.select_delete(@table, [
      {
        {:"$1", %{"expires_at" => :"$2"}},
        [{:<, :"$2", now}],
        [true]
      }
    ])
  end
end
