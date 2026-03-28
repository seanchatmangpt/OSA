defmodule OptimalSystemAgent.Channels.HTTP.Idempotency do
  @moduledoc """
  Idempotency plug using ETS cache for exactly-once delivery.

  For mutating requests (POST, PATCH, PUT, DELETE), checks Idempotency-Key header.
  If a cached response exists for that key, returns it immediately.
  Otherwise, proceeds with the request and caches the response on success.

  ## Standard

  See: https://github.com/seanchatmangpt/chatmangpt/blob/main/docs/idempotency-standard.md

  - Header: `Idempotency-Key: <UUID v4>`
  - Storage: ETS table `:osa_idempotency_cache`
  - TTL: 24 hours (86,400 seconds)
  - Cacheable: 200, 201, 202, 204 only

  ## Usage

  In `lib/optimal_system_agent/channels/http/api.ex`:

  ```elixir
  plug OptimalSystemAgent.Channels.HTTP.Idempotency
  ```

  ## Excluded Paths

  Health checks and metrics are excluded from idempotency tracking:
  - `/health`
  - `/ready`
  - `/metrics`
  """
  import Plug.Conn
  require Logger

  @table :osa_idempotency_cache
  @ttl_seconds 86_400  # 24 hours

  @excluded_paths [
    "/health",
    "/ready",
    "/metrics"
  ]

  @cacheable_statuses [200, 201, 202, 204]

  def init(opts), do: opts

  def call(conn, _opts) do
    # Skip for excluded paths
    if conn.request_path in @excluded_paths do
      conn
    else
      # Only check idempotency for mutating requests
      if conn.method in ["POST", "PATCH", "PUT", "DELETE"] do
        case get_req_header(conn, "idempotency-key") do
          [key] when key != "" -> handle_idempotency(conn, key)
          _ -> conn
        end
      else
        conn
      end
    end
  end

  defp handle_idempotency(conn, key) do
    case :ets.lookup(@table, key) do
      [{^key, {status, body, headers, timestamp}}] ->
        # Return cached response
        Logger.debug("Idempotency: returning cached response", key: key)

        conn
        |> put_resp_content_type("application/json")
        |> put_resp_header("idempotency-replayed", "true")
        |> put_resp_header("idempotency-original-date", Integer.to_string(timestamp))
        |> then(fn conn ->
          Enum.reduce(headers, conn, fn {k, v}, acc -> put_resp_header(acc, k, v) end)
        end)
        |> send_resp(status, body)
        |> halt()

      [] ->
        # No cached response, proceed and cache on success
        register_before_send(conn, fn conn ->
          if conn.status in @cacheable_statuses do
            body =
              if is_binary(conn.resp_body),
                do: conn.resp_body,
                else: IO.iodata_to_binary(conn.resp_body)

            headers =
              conn.resp_headers
              |> Enum.filter(fn {k, _} ->
                k in ["content-type", "content-length", "location", "etag", "cache-control"]
              end)

            :ets.insert(@table, {key, {conn.status, body, headers, System.system_time(:second)}})
            Logger.debug("Idempotency: cached response", key: key, status: conn.status)
          end

          conn
        end)
    end
  end

  @doc "Get current cache statistics"
  def stats do
    try do
      info = :ets.info(@table)
      %{
        size: Keyword.get(info, :size, 0),
        memory: Keyword.get(info, :memory, 0)
      }
    rescue
      ArgumentError -> %{size: 0, memory: 0, error: "table_not_found"}
    end
  end

  @doc "Manually clear all idempotency cache entries (use with caution)"
  def clear do
    try do
      :ets.delete_all_objects(@table)
      Logger.info("Idempotency cache cleared")
      :ok
    rescue
      ArgumentError ->
        Logger.error("Failed to clear idempotency cache: table not found")
        {:error, :table_not_found}
    end
  end

  @doc "Run expired entry cleanup. Called by background task."
  def cleanup_expired do
    cutoff = System.system_time(:second) - @ttl_seconds

    deleted = :ets.select_delete(@table, [
      {{:"$1", {:"$2", :"$3", :"$4", :"$5"}}, [{:<, :"$5", cutoff}], [true]}
    ])

    if deleted > 0 do
      Logger.info("Idempotency cleanup: deleted #{deleted} expired entries")
    end

    :ok
  end
end
