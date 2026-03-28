defmodule OptimalSystemAgent.Idempotency.KeyStoreTest do
  use ExUnit.Case, async: false


  setup do
    # Stop any existing KeyStore and start a fresh one for each test.
    # This ensures the ETS table always exists and is owned by a live process
    # for the duration of each test — preventing state leakage across tests.
    case Process.whereis(OptimalSystemAgent.Idempotency.KeyStore) do
      nil -> :ok
      pid -> GenServer.stop(pid, :normal, 5_000)
    end

    {:ok, _pid} = OptimalSystemAgent.Idempotency.KeyStore.start_link()
    :ok
  end

  describe "store/2" do
    test "stores a result by idempotency key" do
      key = "test-key-123"
      result = %{"status" => "success", "data" => "test"}

      assert :ok = OptimalSystemAgent.Idempotency.KeyStore.store(key, result)
      assert ^result = OptimalSystemAgent.Idempotency.KeyStore.get(key)
    end

    test "overwrites existing key with new result" do
      key = "test-key-456"
      result1 = %{"status" => "v1"}
      result2 = %{"status" => "v2"}

      OptimalSystemAgent.Idempotency.KeyStore.store(key, result1)
      OptimalSystemAgent.Idempotency.KeyStore.store(key, result2)

      assert ^result2 = OptimalSystemAgent.Idempotency.KeyStore.get(key)
    end

    test "stores results with various data types" do
      test_cases = [
        {"key1", "string result"},
        {"key2", 42},
        {"key3", %{"nested" => ["array", "of", "values"]}},
        {"key4", nil}
      ]

      Enum.each(test_cases, fn {key, result} ->
        OptimalSystemAgent.Idempotency.KeyStore.store(key, result)
        assert result == OptimalSystemAgent.Idempotency.KeyStore.get(key)
      end)
    end
  end

  describe "get/1" do
    test "returns nil for non-existent key" do
      assert nil == OptimalSystemAgent.Idempotency.KeyStore.get("non-existent")
    end

    test "returns nil for expired key" do
      key = "expiring-key"
      result = %{"status" => "success"}

      OptimalSystemAgent.Idempotency.KeyStore.store(key, result)

      # Manually expire the key by modifying ETS entry
      # (This is a test helper only; in production TTL is 24h)
      now = System.monotonic_time(:second)
      :ets.update_element(:osa_idempotency_keys, key, {
        2,
        %{
          "key" => key,
          "result" => result,
          "stored_at" => now - 100_000,
          "expires_at" => now - 1
        }
      })

      assert nil == OptimalSystemAgent.Idempotency.KeyStore.get(key)
    end

    test "removes expired keys when retrieved" do
      key = "cleanup-key"
      result = %{"status" => "test"}

      OptimalSystemAgent.Idempotency.KeyStore.store(key, result)

      # Expire the key
      now = System.monotonic_time(:second)
      :ets.update_element(:osa_idempotency_keys, key, {
        2,
        %{
          "key" => key,
          "result" => result,
          "stored_at" => now - 100_000,
          "expires_at" => now - 1
        }
      })

      # Get should return nil and remove the key
      assert nil == OptimalSystemAgent.Idempotency.KeyStore.get(key)

      # Key should be deleted from ETS
      assert [] == :ets.lookup(:osa_idempotency_keys, key)
    end
  end

  describe "delete/1" do
    test "removes a key from the store" do
      key = "delete-key"
      result = %{"status" => "test"}

      OptimalSystemAgent.Idempotency.KeyStore.store(key, result)
      assert result == OptimalSystemAgent.Idempotency.KeyStore.get(key)

      OptimalSystemAgent.Idempotency.KeyStore.delete(key)
      assert nil == OptimalSystemAgent.Idempotency.KeyStore.get(key)
    end

    test "delete is idempotent" do
      key = "idempotent-delete"
      OptimalSystemAgent.Idempotency.KeyStore.store(key, "data")

      assert :ok = OptimalSystemAgent.Idempotency.KeyStore.delete(key)
      assert :ok = OptimalSystemAgent.Idempotency.KeyStore.delete(key)
    end
  end

  describe "stats/0" do
    test "returns store statistics" do
      # Clear table first
      :ets.delete_all_objects(:osa_idempotency_keys)

      OptimalSystemAgent.Idempotency.KeyStore.store("key1", "result1")
      OptimalSystemAgent.Idempotency.KeyStore.store("key2", "result2")
      OptimalSystemAgent.Idempotency.KeyStore.store("key3", "result3")

      stats = OptimalSystemAgent.Idempotency.KeyStore.stats()

      assert stats["total_keys"] == 3
      assert is_integer(stats["memory_bytes"])
      assert stats["memory_bytes"] > 0
    end
  end

  describe "concurrent access" do
    test "handles concurrent stores and gets safely" do
      keys = Enum.map(1..100, &Integer.to_string/1)

      tasks_store =
        Enum.map(keys, fn key ->
          Task.async(fn ->
            result = %{"key" => key, "data" => "value#{key}"}
            OptimalSystemAgent.Idempotency.KeyStore.store(key, result)
          end)
        end)

      Task.await_many(tasks_store)

      tasks_get =
        Enum.map(keys, fn key ->
          Task.async(fn ->
            OptimalSystemAgent.Idempotency.KeyStore.get(key)
          end)
        end)

      results = Task.await_many(tasks_get)

      # All keys should be retrievable
      assert Enum.all?(results, &is_map/1)
      assert length(results) == 100
    end

    test "handles concurrent deletes safely" do
      keys = Enum.map(1..50, &Integer.to_string/1)

      Enum.each(keys, fn key ->
        OptimalSystemAgent.Idempotency.KeyStore.store(key, %{"data" => key})
      end)

      tasks_delete =
        Enum.map(keys, fn key ->
          Task.async(fn ->
            OptimalSystemAgent.Idempotency.KeyStore.delete(key)
          end)
        end)

      Task.await_many(tasks_delete)

      # All keys should be deleted
      Enum.each(keys, fn key ->
        assert nil == OptimalSystemAgent.Idempotency.KeyStore.get(key)
      end)
    end
  end

  describe "TTL validation" do
    test "keys are stored with correct TTL" do
      key = "ttl-test-key"
      result = %{"status" => "test"}

      OptimalSystemAgent.Idempotency.KeyStore.store(key, result)

      # Retrieve the entry to check expiry time
      [{^key, entry}] = :ets.lookup(:osa_idempotency_keys, key)

      stored_at = entry["stored_at"]
      expires_at = entry["expires_at"]

      # TTL should be approximately 24 hours (86400 seconds)
      ttl_actual = expires_at - stored_at
      assert ttl_actual >= 86_400 - 1
      assert ttl_actual <= 86_400 + 1
    end
  end
end
