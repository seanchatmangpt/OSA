defmodule OptimalSystemAgent.Channels.HTTP.API.OcelRoutes do
  @moduledoc """
  OCEL 2.0 HTTP export routes.

  GET  /export              — full OCEL 2.0 JSON log (all sessions)
  GET  /export/:session_id  — OCEL 2.0 JSON log filtered by session_id
  GET  /status              — event and object counts from ETS tables

  Forwarded prefix: /ocel  (mounted at /api/v1/ocel in the main API router)

  WvdA: OcelCollector GenServer calls have implicit 5000ms timeout from GenServer.call default.
  Armstrong: If OcelCollector is not running, errors bubble up visibly as 500 (let-it-crash).
  """

  use Plug.Router
  import Plug.Conn
  require Logger

  alias OptimalSystemAgent.ProcessMining.OcelCollector

  plug Plug.Parsers,
    parsers: [:json],
    pass: ["application/json"],
    json_decoder: Jason

  plug :match
  plug :dispatch

  # ── GET /export ───────────────────────────────────────────────────────────────
  # Returns the full OCEL 2.0 JSON log for all sessions.
  get "/export" do
    json = OcelCollector.export_ocel_json()

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(json))
  end

  # ── GET /export/:session_id ───────────────────────────────────────────────────
  # Returns the OCEL 2.0 JSON log filtered to the given session_id.
  get "/export/:session_id" do
    json = OcelCollector.export_ocel_json(session_id)

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(json))
  end

  # ── GET /status ───────────────────────────────────────────────────────────────
  # Returns current event and object counts from the ETS backing tables.
  get "/status" do
    event_count = :ets.info(:ocel_events, :size)
    object_count = :ets.info(:ocel_objects, :size)

    body = %{
      "event_count" => event_count || 0,
      "object_count" => object_count || 0
    }

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(body))
  end

  # ── Catch-all ────────────────────────────────────────────────────────────────
  match _ do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(404, Jason.encode!(%{"error" => "not_found"}))
  end
end
