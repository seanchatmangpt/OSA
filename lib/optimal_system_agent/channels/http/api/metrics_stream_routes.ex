defmodule OptimalSystemAgent.Channels.HTTP.API.MetricsStreamRoutes do
  @moduledoc """
  SSE stream of Wave 12 process metrics for the BusinessOS frontend.

  Endpoints:
    GET /stream — Server-Sent Events stream of Wave 12 DMAIC process metrics.

  This router is forwarded to from the parent API at /metrics/stream.

  The stream subscribes to the `"pm4py:metrics"` topic on
  `OptimalSystemAgent.PubSub`. Events are emitted by
  `OptimalSystemAgent.JTBD.Wave12Scenario.broadcast_result/1` whenever a
  Wave 12 tool execution completes.

  SSE event format:
    event: metrics_update
    data: {"scenarios":[...],"pass_count":1,"fail_count":0}

  WvdA — Liveness: The SSE loop sends a keepalive every 30 seconds so
  the connection is not silently dropped by proxies. Each receive/2 has a
  bounded 30_000 ms timeout — no infinite blocking wait.

  Armstrong — Let-It-Crash: If the client disconnects (chunk/2 returns
  {:error, _}), the connection process exits cleanly. The supervisor
  does not restart it (temporary child per HTTP request).

  Usage:
    curl -N http://localhost:8089/api/v1/metrics/stream
  """
  use Plug.Router
  import OptimalSystemAgent.Channels.HTTP.API.Shared
  require Logger

  plug :match
  plug :dispatch

  # ── GET /stream — SSE stream of Wave12 process metrics ─────────────────

  get "/stream" do
    Phoenix.PubSub.subscribe(OptimalSystemAgent.PubSub, "pm4py:metrics")

    conn =
      conn
      |> put_resp_content_type("text/event-stream")
      |> put_resp_header("cache-control", "no-cache")
      |> put_resp_header("connection", "keep-alive")
      |> put_resp_header("x-accel-buffering", "no")
      |> send_chunked(200)

    {:ok, conn} = chunk(conn, "event: connected\ndata: {\"topic\": \"pm4py:metrics\"}\n\n")

    Logger.debug("[MetricsStream] SSE client connected | user=#{conn.assigns[:user_id]}")

    sse_loop(conn)
  end

  # ── Catch-all ─────────────────────────────────────────────────────────

  match _ do
    json_error(conn, 404, "not_found", "Metrics stream endpoint not found")
  end

  # ── SSE Loop ──────────────────────────────────────────────────────────

  # WvdA liveness: 30 s keepalive timeout — no infinite blocking.
  defp sse_loop(conn) do
    receive do
      {:metrics_update, payload} ->
        case Jason.encode(payload) do
          {:ok, data} ->
            case chunk(conn, "event: metrics_update\ndata: #{data}\n\n") do
              {:ok, conn} ->
                sse_loop(conn)

              {:error, _reason} ->
                Logger.debug("[MetricsStream] Client disconnected")
                conn
            end

          {:error, reason} ->
            Logger.warning("[MetricsStream] Failed to encode metrics payload: #{inspect(reason)}")
            sse_loop(conn)
        end
    after
      # WvdA liveness budget: send keepalive comment every 30 s so the
      # connection is not silently killed by reverse proxies (nginx, Caddy).
      30_000 ->
        case chunk(conn, ": keepalive\n\n") do
          {:ok, conn} -> sse_loop(conn)
          {:error, _} -> conn
        end
    end
  end
end
