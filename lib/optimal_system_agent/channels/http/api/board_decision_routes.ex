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

  # ── Catch-all ─────────────────────────────────────────────────────────────────

  match _ do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(404, Jason.encode!(%{error: "not_found"}))
  end

  # ── Private helpers ──────────────────────────────────────────────────────────

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
