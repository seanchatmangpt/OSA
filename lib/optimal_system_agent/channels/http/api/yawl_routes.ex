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
  alias OptimalSystemAgent.Yawl.Simulator

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

  # ── POST /simulate ──────────────────────────────────────────────────
  # Body (all optional): {"spec_set":"basic_wcp","user_count":3,"timeout_ms":30000,
  #                       "max_steps":50,"max_concurrency":10}
  # Returns: SimulationResult as JSON.
  # WvdA: outer request gets a 60s timeout guard so it never hangs the caller.
  post "/simulate" do
    spec_set_raw = Map.get(conn.body_params, "spec_set", "basic_wcp")
    user_count = Map.get(conn.body_params, "user_count", 3)
    timeout_ms = Map.get(conn.body_params, "timeout_ms", 30_000)
    max_steps = Map.get(conn.body_params, "max_steps", 50)
    max_concurrency = Map.get(conn.body_params, "max_concurrency", 10)

    spec_set =
      case spec_set_raw do
        "wcp_patterns" -> :wcp_patterns
        "real_data" -> :real_data
        "all" -> :all
        _ -> :basic_wcp
      end

    opts = [
      spec_set: spec_set,
      user_count: user_count,
      timeout_ms: timeout_ms,
      max_steps: max_steps,
      max_concurrency: max_concurrency
    ]

    result = Simulator.run(opts)

    body = %{
      spec_set: to_string(result.spec_set),
      user_count: result.user_count,
      total_duration_ms: result.total_duration_ms,
      completed_count: result.completed_count,
      error_count: result.error_count,
      timeout_count: result.timeout_count,
      summary: result.summary,
      results: Enum.map(result.results, &user_result_to_map/1)
    }

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(body))
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

  # ── Private helpers ─────────────────────────────────────────────────

  defp user_result_to_map(%Simulator.UserResult{} = r) do
    %{
      user_id: r.user_id,
      case_id: r.case_id,
      spec_id: r.spec_id,
      status: to_string(r.status),
      steps_completed: r.steps_completed,
      duration_ms: r.duration_ms,
      error: if(r.error, do: inspect(r.error), else: nil)
    }
  end

  # ── Catch-all ────────────────────────────────────────────────────────
  match _ do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(404, Jason.encode!(%{error: "not_found"}))
  end
end
