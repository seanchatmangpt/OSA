defmodule OptimalSystemAgent.Channels.HTTP.API.YawlRoutes do
  @moduledoc """
  YAWL engine integration HTTP routes.

  GET  /patterns            — list available WCP patterns from ~/yawlv6/exampleSpecs
  POST /check-conformance   — proxy conformance check to the YAWL engine
  GET  /health              — proxy health check to the YAWL engine

  Forwarded prefix: /yawl  (mounted at /api/v1/yawl in the main API router)

  WvdA: All engine calls have explicit timeouts; unavailability returns 503, not panic.
  Armstrong: YAWL engine down is a transient fault — the route degrades gracefully.
  """

  use Plug.Router
  import Plug.Conn
  require Logger

  alias OptimalSystemAgent.Yawl.Client, as: YawlClient
  alias OptimalSystemAgent.Yawl.SpecLibrary

  plug Plug.Parsers,
    parsers: [:json],
    pass: ["application/json"],
    json_decoder: Jason

  plug :match
  plug :dispatch

  # ── GET /patterns ────────────────────────────────────────────────────
  # Returns all WCP patterns found in ~/yawlv6/exampleSpecs/wcp-patterns.
  # Returns [] when the directory does not exist (engine not installed).
  get "/patterns" do
    patterns = SpecLibrary.list_patterns()

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(patterns))
  end

  # ── POST /check-conformance ──────────────────────────────────────────
  # Body: {"spec_xml": "<.../>", "event_log": "[...]"}
  # Returns 200 with conformance result, 503 when engine is unavailable.
  post "/check-conformance" do
    spec_xml = Map.get(conn.body_params, "spec_xml", "")
    event_log = Map.get(conn.body_params, "event_log", "[]")

    result =
      try do
        YawlClient.check_conformance(spec_xml, event_log)
      catch
        :exit, _ ->
          Logger.warning("[YawlRoutes] YAWL client process unavailable")
          {:error, :yawl_unavailable}
      end

    case result do
      {:ok, conformance} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, Jason.encode!(conformance))

      {:error, :yawl_unavailable} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(503, Jason.encode!(%{error: "yawl_unavailable"}))

      {:error, reason} ->
        Logger.error("[YawlRoutes] Conformance check error: #{inspect(reason)}")

        conn
        |> put_resp_content_type("application/json")
        |> send_resp(503, Jason.encode!(%{error: inspect(reason)}))
    end
  end

  # ── GET /health ──────────────────────────────────────────────────────
  # Proxies a health check to the YAWL engine.
  # Returns 200 {"status":"ok"} or 503 {"status":"unavailable"}.
  get "/health" do
    result =
      try do
        YawlClient.health()
      catch
        :exit, _ -> {:error, :yawl_unavailable}
      end

    case result do
      :ok ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, Jason.encode!(%{status: "ok"}))

      {:error, _} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(503, Jason.encode!(%{status: "unavailable"}))
    end
  end

  # ── Catch-all ────────────────────────────────────────────────────────
  match _ do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(404, Jason.encode!(%{error: "not_found"}))
  end
end
