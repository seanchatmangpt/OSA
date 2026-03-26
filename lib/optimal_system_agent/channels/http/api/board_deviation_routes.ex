defmodule OptimalSystemAgent.Channels.HTTP.API.BoardDeviationRoutes do
  @moduledoc """
  Board Chair Intelligence System — deviation intake endpoint.

  Receives process deviation reports from pm4py-rust (port 8090) and
  routes them to HealingBridge for autonomous healing.

  Routes:
    POST /deviation   — receive deviation from pm4py-rust, forward to HealingBridge
    GET  /status      — current healing status for all tracked processes

  Forwarded prefix: /board
  """

  use Plug.Router
  import Plug.Conn
  require Logger

  alias OptimalSystemAgent.Board.HealingBridge

  plug(Plug.Parsers,
    parsers: [:json],
    pass: ["application/json"],
    json_decoder: Jason,
    length: 1_000_000
  )

  plug(:match)
  plug(:dispatch)

  # ── POST /deviation ──────────────────────────────────────────────────────────

  post "/deviation" do
    params = conn.body_params

    process_id = Map.get(params, "process_id")
    fitness_raw = Map.get(params, "fitness")
    deviation_type = Map.get(params, "deviation_type", "conformance")
    detected_at = Map.get(params, "detected_at", DateTime.to_iso8601(DateTime.utc_now()))

    cond do
      is_nil(process_id) or process_id == "" ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(422, Jason.encode!(%{error: "process_id is required"}))

      not is_number(fitness_raw) and not is_binary(fitness_raw) ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(422, Jason.encode!(%{error: "fitness must be a number between 0.0 and 1.0"}))

      true ->
        fitness =
          case fitness_raw do
            f when is_float(f) -> f
            f when is_integer(f) -> f / 1.0
            s when is_binary(s) ->
              case Float.parse(s) do
                {f, ""} -> f
                _ -> nil
              end
          end

        if is_nil(fitness) or fitness < 0.0 or fitness > 1.0 do
          conn
          |> put_resp_content_type("application/json")
          |> send_resp(422, Jason.encode!(%{error: "fitness must be between 0.0 and 1.0"}))
        else
          deviation = %{
            process_id: process_id,
            fitness: fitness,
            deviation_type: deviation_type,
            detected_at: detected_at
          }

          HealingBridge.report_deviation(deviation)

          Logger.info(
            "[BoardDeviationRoutes] Deviation accepted: process_id=#{process_id} " <>
              "fitness=#{fitness} type=#{deviation_type}"
          )

          conn
          |> put_resp_content_type("application/json")
          |> send_resp(202, Jason.encode!(%{
            status: "accepted",
            process_id: process_id,
            fitness: fitness,
            healing_triggered: fitness < 0.8
          }))
        end
    end
  end

  # ── GET /status ───────────────────────────────────────────────────────────────

  get "/status" do
    status =
      try do
        HealingBridge.healing_status()
        |> Enum.map(fn
          {process_id, status, timestamp} ->
            %{
              process_id: process_id,
              status: status,
              timestamp: DateTime.to_iso8601(timestamp)
            }

          {process_id, status, timestamp, span_id} ->
            %{
              process_id: process_id,
              status: status,
              timestamp: DateTime.to_iso8601(timestamp),
              proof_span_id: span_id
            }
        end)
      rescue
        e ->
          Logger.warning("[BoardDeviationRoutes] healing_status failed: #{Exception.message(e)}")
          []
      end

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(%{healing_status: status, count: length(status)}))
  end

  # ── Catch-all ─────────────────────────────────────────────────────────────────

  match _ do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(404, Jason.encode!(%{error: "not_found"}))
  end
end
