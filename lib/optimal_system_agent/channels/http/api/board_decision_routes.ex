defmodule OptimalSystemAgent.Channels.HTTP.API.BoardDecisionRoutes do
  @moduledoc """
  HTTP endpoints for board chair decision recording and briefing retrieval.

  GET /board/briefing
    response: {"text": "...", "generated_at": "...", "l3_freshness": "fresh|stale|unknown",
               "structural_issue_count": 0}

  POST /board/decision
    body: {"department": "Engineering", "decision_type": "reorganize", "notes": "..."}
    response: {"status": "recorded", "department": "Engineering"}

  GET /board/decisions
    response: [{"department": "...", "type": "...", "notes": "...", "recorded_at": "..."}]

  Forwarded prefix: /board  (shared with BoardDeviationRoutes via forward order in API)
  """

  use Plug.Router
  import Plug.Conn
  require Logger

  alias OptimalSystemAgent.Board.BriefingGenerator
  alias OptimalSystemAgent.Board.DecisionRecorder
  alias OptimalSystemAgent.Board.ConwayLittleMonitor
  alias OptimalSystemAgent.Observability.Telemetry

  @table :osa_board_briefings

  plug(Plug.Parsers,
    parsers: [:json],
    pass: ["application/json"],
    json_decoder: Jason,
    length: 100_000
  )

  plug(:match)
  plug(:dispatch)

  @valid_types ~w(reorganize add_liaison accept_constraint)

  # ── GET /briefing ─────────────────────────────────────────────────────────────

  get "/briefing" do
    result =
      case :ets.lookup(@table, :last) do
        [{:last, text, generated_at, l3_freshness}] ->
          structural_issue_count = extract_structural_issue_count(text)

          body = Jason.encode!(%{
            text: text,
            generated_at: DateTime.to_iso8601(generated_at),
            l3_freshness: Atom.to_string(l3_freshness),
            structural_issue_count: structural_issue_count,
            has_structural_issues: structural_issue_count > 0
          })

          {200, body}

        [] ->
          # No briefing yet — attempt a fresh generate if BriefingGenerator is alive
          case Process.whereis(BriefingGenerator) do
            nil ->
              body = Jason.encode!(%{error: "No briefing available", hint: "BriefingGenerator not started"})
              {404, body}

            _pid ->
              body = Jason.encode!(%{
                error: "No briefing generated yet",
                hint: "Call BriefingGenerator.generate/0 first"
              })
              {404, body}
          end
      end

    {status, body} = result

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, body)
  end

  # ── POST /decision ────────────────────────────────────────────────────────────

  post "/decision" do
    params = conn.body_params

    case params do
      %{"department" => dept, "decision_type" => type_str}
      when is_binary(dept) and dept != "" and is_binary(type_str) ->
        if type_str in @valid_types do
          decision_type = String.to_existing_atom(type_str)
          notes = Map.get(params, "notes", "")

          case DecisionRecorder.record_decision(dept, decision_type, notes) do
            :ok ->
              Logger.info(
                "[BoardDecisionRoutes] Decision recorded: dept=#{dept} type=#{type_str}"
              )

              conn
              |> put_resp_content_type("application/json")
              |> send_resp(
                200,
                Jason.encode!(%{status: "recorded", department: dept, decision_type: type_str})
              )

            {:error, reason} ->
              conn
              |> put_resp_content_type("application/json")
              |> send_resp(500, Jason.encode!(%{error: inspect(reason)}))
          end
        else
          conn
          |> put_resp_content_type("application/json")
          |> send_resp(
            400,
            Jason.encode!(%{
              error: "invalid decision_type",
              valid_types: @valid_types
            })
          )
        end

      _ ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(
          400,
          Jason.encode!(%{
            error: "department and decision_type are required",
            valid_types: @valid_types
          })
        )
    end
  end

  # ── GET /decisions ────────────────────────────────────────────────────────────

  get "/decisions" do
    decisions =
      DecisionRecorder.list_decisions()
      |> Enum.map(fn d ->
        %{
          department: d.department,
          type: Atom.to_string(d.type),
          notes: d.notes,
          recorded_at: DateTime.to_iso8601(d.recorded_at)
        }
      end)

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(decisions))
  end

  # ── POST /intelligence ───────────────────────────────────────────────────────

  post "/intelligence" do
    params = conn.body_params
    received_at = DateTime.utc_now() |> DateTime.to_iso8601()

    with {:ok, intel} <- validate_intelligence(params) do
      # Emit board.kpi_compute span via telemetry.
      conformance_score = Map.get(intel, "conformance_score", 0.0)
      conway_violations = Map.get(intel, "conway_violations", 0)
      intelligence_source = Map.get(intel, "intelligence_source", "business_os")

      Telemetry.start_span("board.kpi_compute", %{
        "board.process_id" => "aggregated",
        "board.kpi_conformance_score" => conformance_score,
        "board.kpi_bottleneck_count" => conway_violations,
        "board.intelligence_source" => intelligence_source,
        "board.intelligence_received_at" => received_at,
        "board.kpi_cycle_time_avg_ms" => 0.0,
        "board.kpi_variant_count" => 0,
        "board.kpi_events_processed" => Map.get(intel, "case_count", 0),
        "board.kpi_truncated" => false
      })

      # Inject into ConwayLittleMonitor (may be unavailable in degraded mode).
      result =
        case Process.whereis(ConwayLittleMonitor) do
          nil ->
            Logger.warning("[BoardDecisionRoutes] ConwayLittleMonitor not running")
            {:error, :monitor_unavailable}

          _pid ->
            intel_map = %{
              health_summary: Map.get(intel, "health_summary", 1.0),
              conformance_score: conformance_score,
              top_risk: Map.get(intel, "top_risk", "none"),
              conway_violations: conway_violations,
              case_count: Map.get(intel, "case_count", 0),
              handoff_count: Map.get(intel, "handoff_count", 0),
              received_at: received_at
            }

            try do
              ConwayLittleMonitor.inject_board_intelligence(intel_map)
            catch
              :exit, _ -> {:error, :monitor_unavailable}
            end
        end

      case result do
        :ok ->
          conn
          |> put_resp_content_type("application/json")
          |> send_resp(200, Jason.encode!(%{
            status: "accepted",
            intelligence_source: intelligence_source,
            received_at: received_at
          }))

        {:error, :monitor_unavailable} ->
          # Degraded — intelligence stored in span but monitor not available.
          conn
          |> put_resp_content_type("application/json")
          |> send_resp(202, Jason.encode!(%{
            status: "stored",
            intelligence_source: intelligence_source,
            received_at: received_at,
            hint: "ConwayLittleMonitor unavailable — intelligence recorded in telemetry"
          }))
      end
    else
      {:error, errors} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(422, Jason.encode!(%{error: "validation_failed", details: errors}))
    end
  end

  # ── Catch-all ─────────────────────────────────────────────────────────────────

  match _ do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(404, Jason.encode!(%{error: "not_found"}))
  end

  # ── Private helpers ──────────────────────────────────────────────────────────

  defp validate_intelligence(params) do
    errors = []

    errors =
      case Map.get(params, "health_summary") do
        v when is_number(v) and v >= 0 and v <= 1 -> errors
        nil -> ["health_summary is required" | errors]
        _ -> ["health_summary must be a float in [0, 1]" | errors]
      end

    errors =
      case Map.get(params, "conformance_score") do
        v when is_number(v) and v >= 0 and v <= 1 -> errors
        nil -> ["conformance_score is required" | errors]
        _ -> ["conformance_score must be a float in [0, 1]" | errors]
      end

    errors =
      case Map.get(params, "top_risk") do
        v when is_binary(v) and byte_size(v) > 0 -> errors
        nil -> ["top_risk is required" | errors]
        _ -> ["top_risk must be a non-empty string" | errors]
      end

    errors =
      case Map.get(params, "conway_violations") do
        v when is_integer(v) and v >= 0 -> errors
        nil -> ["conway_violations is required" | errors]
        _ -> ["conway_violations must be a non-negative integer" | errors]
      end

    if errors == [] do
      {:ok, params}
    else
      {:error, Enum.reverse(errors)}
    end
  end

  # Count structural issues by scanning the briefing text for known marker phrases.
  # The briefing template uses "Conway violation" or "org boundary bottleneck" when
  # structural decisions are required.
  defp extract_structural_issue_count(text) when is_binary(text) do
    patterns = [
      ~r/Conway violation/i,
      ~r/org boundary bottleneck/i,
      ~r/structural decision required/i,
      ~r/cross-team dependency/i
    ]

    patterns
    |> Enum.map(fn pattern -> length(Regex.scan(pattern, text)) end)
    |> Enum.sum()
  end

  defp extract_structural_issue_count(_), do: 0
end
