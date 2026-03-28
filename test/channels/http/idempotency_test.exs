defmodule OptimalSystemAgent.Channels.HTTP.IdempotencyTest do
  use ExUnit.Case, async: false
  use Plug.Test

  alias OptimalSystemAgent.Channels.HTTP.Idempotency

  @opts Idempotency.init([])

  setup do
    # Ensure ETS table exists
    try do
      :ets.delete_all_objects(:osa_idempotency_cache)
    rescue
      ArgumentError ->
        # Table doesn't exist yet, create it
        :ets.new(:osa_idempotency_cache, [:named_table, :public, read_concurrency: true])
    end

    :ok
  end

  describe "GET requests" do
    test "passes through without idempotency check" do
      conn =
        conn(:get, "/api/test")
        |> put_req_header("idempotency-key", "some-key")
        |> Idempotency.call(@opts)

      # Should not halt, should proceed to handler
      refute conn.halted
    end
  end

  describe "POST without idempotency key" do
    test "passes through normally" do
      conn =
        conn(:post, "/api/test", %{data: "test"})
        |> Idempotency.call(@opts)

      refute conn.halted
    end
  end

  describe "POST with idempotency key (first request)" do
    test "caches successful response (200)" do
      key = "test-key-200"

      # Simulate a handler that returns 200
      conn =
        conn(:post, "/api/test", %{data: "test"})
        |> put_req_header("idempotency-key", key)
        |> Idempotency.call(@opts)
        |> send_resp(200, ~s({"result":"success"}))

      # First request should proceed
      assert conn.status == 200

      # Verify cached response
      assert [{^key, {200, ~s({"result":"success"}), _headers, _timestamp}}] =
        :ets.lookup(:osa_idempotency_cache, key)
    end

    test "caches successful response (201)" do
      key = "test-key-201"

      conn =
        conn(:post, "/api/test", %{data: "test"})
        |> put_req_header("idempotency-key", key)
        |> Idempotency.call(@opts)
        |> send_resp(201, ~s({"id":"123"}))

      assert conn.status == 201

      assert [{^key, {201, ~s({"id":"123"}), _headers, _timestamp}}] =
        :ets.lookup(:osa_idempotency_cache, key)
    end

    test "does not cache error responses (400)" do
      key = "test-key-400"

      conn =
        conn(:post, "/api/test", %{data: "invalid"})
        |> put_req_header("idempotency-key", key)
        |> Idempotency.call(@opts)
        |> send_resp(400, ~s({"error":"bad request"}))

      assert conn.status == 400

      # Should not be cached
      assert [] = :ets.lookup(:osa_idempotency_cache, key)
    end

    test "does not cache error responses (500)" do
      key = "test-key-500"

      conn =
        conn(:post, "/api/test", %{data: "test"})
        |> put_req_header("idempotency-key", key)
        |> Idempotency.call(@opts)
        |> send_resp(500, ~s({"error":"internal error"}))

      assert conn.status == 500

      # Should not be cached
      assert [] = :ets.lookup(:osa_idempotency_cache, key)
    end
  end

  describe "POST with idempotency key (cached response)" do
    test "returns cached response immediately" do
      key = "cached-key"

      # Pre-populate cache
      headers = [{"content-type", "application/json"}]
      timestamp = System.system_time(:second)
      :ets.insert(:osa_idempotency_cache, {key, {201, ~s({"id":"123"}), headers, timestamp}})

      # Make request with same key
      conn =
        conn(:post, "/api/test", %{data: "test"})
        |> put_req_header("idempotency-key", key)
        |> Idempotency.call(@opts)

      # Should return cached response and halt
      assert conn.halted
      assert conn.status == 201

      assert ["true"] = get_resp_header(conn, "idempotency-replayed")
      assert [timestamp_str] = get_resp_header(conn, "idempotency-original-date")
      assert timestamp_str == Integer.to_string(timestamp)
    end
  end

  describe "excluded paths" do
    test "health endpoint is excluded" do
      key = "health-key"

      conn =
        conn(:post, "/health", %{data: "test"})
        |> put_req_header("idempotency-key", key)
        |> Idempotency.call(@opts)
        |> send_resp(200, ~s({"status":"ok"}))

      # Should proceed normally (not cached)
      refute conn.halted
      assert [] = :ets.lookup(:osa_idempotency_cache, key)
    end

    test "metrics endpoint is excluded" do
      key = "metrics-key"

      conn =
        conn(:post, "/metrics", %{data: "test"})
        |> put_req_header("idempotency-key", key)
        |> Idempotency.call(@opts)
        |> send_resp(200, ~s({"metrics":"data"}))

      # Should proceed normally (not cached)
      refute conn.halted
      assert [] = :ets.lookup(:osa_idempotency_cache, key)
    end

    test "ready endpoint is excluded" do
      key = "ready-key"

      conn =
        conn(:post, "/ready", %{data: "test"})
        |> put_req_header("idempotency-key", key)
        |> Idempotency.call(@opts)
        |> send_resp(200, ~s({"ready":"true"}))

      # Should proceed normally (not cached)
      refute conn.halted
      assert [] = :ets.lookup(:osa_idempotency_cache, key)
    end
  end

  describe "PATCH requests" do
    test "caches successful response" do
      key = "patch-key"

      conn =
        conn(:patch, "/api/test/123", %{name: "updated"})
        |> put_req_header("idempotency-key", key)
        |> Idempotency.call(@opts)
        |> send_resp(200, ~s({"id":"123","name":"updated"}))

      assert conn.status == 200

      assert [{^key, {200, ~s({"id":"123","name":"updated"}), _headers, _timestamp}}] =
        :ets.lookup(:osa_idempotency_cache, key)
    end
  end

  describe "PUT requests" do
    test "caches successful response" do
      key = "put-key"

      conn =
        conn(:put, "/api/test/123", %{name: "replaced"})
        |> put_req_header("idempotency-key", key)
        |> Idempotency.call(@opts)
        |> send_resp(200, ~s({"id":"123","name":"replaced"}))

      assert conn.status == 200

      assert [{^key, {200, ~s({"id":"123","name":"replaced"}), _headers, _timestamp}}] =
        :ets.lookup(:osa_idempotency_cache, key)
    end
  end

  describe "DELETE requests" do
    test "caches successful response" do
      key = "delete-key"

      conn =
        conn(:delete, "/api/test/123")
        |> put_req_header("idempotency-key", key)
        |> Idempotency.call(@opts)
        |> send_resp(204, "")

      assert conn.status == 204

      assert [{^key, {204, "", _headers, _timestamp}}] =
        :ets.lookup(:osa_idempotency_cache, key)
    end
  end

  describe "cache statistics" do
    test "returns current cache size" do
      # Clear cache
      :ets.delete_all_objects(:osa_idempotency_cache)

      # Add some entries
      for i <- 1..3 do
        key = "stats-key-#{i}"
        :ets.insert(:osa_idempotency_cache, {key, {200, ~s({"id":"#{i}"}), [], System.system_time(:second)}})
      end

      stats = Idempotency.stats()
      assert stats.size == 3
      assert is_integer(stats.memory)
      assert stats.memory > 0
    end
  end

  describe "cleanup_expired" do
    test "removes expired entries" do
      # Add an expired entry
      key_old = "old-key"
      timestamp_old = System.system_time(:second) - (86_400 * 2)  # 2 days ago
      :ets.insert(:osa_idempotency_cache, {key_old, {200, ~s({"old":"data"}), [], timestamp_old}})

      # Add a fresh entry
      key_new = "new-key"
      timestamp_new = System.system_time(:second)
      :ets.insert(:osa_idempotency_cache, {key_new, {200, ~s({"new":"data"}), [], timestamp_new}})

      # Run cleanup
      :ok = Idempotency.cleanup_expired()

      # Old entry should be removed
      assert [] = :ets.lookup(:osa_idempotency_cache, key_old)

      # New entry should remain
      assert [{^key_new, _}] = :ets.lookup(:osa_idempotency_cache, key_new)
    end
  end

  describe "clear" do
    test "removes all cache entries" do
      # Add entries
      for i <- 1..5 do
        key = "clear-key-#{i}"
        :ets.insert(:osa_idempotency_cache, {key, {200, ~s({"id":"#{i}"}), [], System.system_time(:second)}})
      end

      stats_before = Idempotency.stats()
      assert stats_before.size == 5

      # Clear cache
      :ok = Idempotency.clear()

      stats_after = Idempotency.stats()
      assert stats_after.size == 0
    end
  end

  describe "header extraction" do
    test "extracts relevant headers for caching" do
      key = "headers-key"

      # Simulate a response with multiple headers
      conn =
        conn(:post, "/api/test", %{data: "test"})
        |> put_req_header("idempotency-key", key)
        |> Idempotency.call(@opts)
        |> put_resp_header("content-type", "application/json")
        |> put_resp_header("content-length", "42")
        |> put_resp_header("location", "/api/test/123")
        |> put_resp_header("x-custom", "should-not-cache")
        |> send_resp(201, ~s({"id":"123"}))

      assert conn.status == 201

      # Verify cached headers
      assert [{^key, {201, _body, headers, _timestamp}}] =
        :ets.lookup(:osa_idempotency_cache, key)

      # Should contain cacheable headers
      header_keys = headers |> Enum.map(fn {k, _v} -> k end) |> MapSet.new()
      assert "content-type" in header_keys
      assert "content-length" in header_keys
      assert "location" in header_keys

      # Should NOT contain custom headers
      refute "x-custom" in header_keys
    end
  end
end
