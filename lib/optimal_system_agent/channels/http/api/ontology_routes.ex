defmodule OptimalSystemAgent.Channels.HTTP.API.OntologyRoutes do
  @moduledoc """
  HTTP endpoints for ontology management operations.

  POST /ontology/inference-chain/invalidate
    body: {"from_level": "l0"|"l1"|"l2"}
    response: {"status": "ok", "levels_invalidated": [...], "results": {...}}

  Called by Canopy webhooks after a BusinessOS discovery result is written to
  the L0 Oxigraph named graph. Triggers L1 → L2 → L3 re-materialization so the
  Board Chair Intelligence System reflects the latest process mining data.

  Armstrong: bounded — each level has @timeout_ms HTTP call + 4× GenServer timeout.
  WvdA: non-blocking for caller; L0 is already written before this is called.
  """

  use Plug.Router
  import Plug.Conn
  require Logger

  alias OptimalSystemAgent.Ontology.InferenceChain

  plug(Plug.Parsers,
    parsers: [:json],
    pass: ["application/json"],
    json_decoder: Jason,
    length: 10_000
  )

  plug(:match)
  plug(:dispatch)

  @valid_levels ["l0", "l1", "l2"]

  post "/inference-chain/invalidate" do
    from_level = conn.body_params["from_level"]

    if from_level not in @valid_levels do
      body =
        Jason.encode!(%{
          error: "invalid_level",
          details: "from_level must be one of: #{Enum.join(@valid_levels, ", ")}",
          received: from_level
        })

      conn
      |> put_resp_content_type("application/json")
      |> send_resp(400, body)
    else
      level_atom = String.to_existing_atom(from_level)

      case InferenceChain.invalidate_from(level_atom) do
        {:ok, result} ->
          Logger.info(
            "[OntologyRoutes] inference-chain invalidated from #{from_level}, " <>
              "levels: #{inspect(result[:levels_invalidated])}"
          )

          body =
            Jason.encode!(%{
              status: "ok",
              from_level: from_level,
              levels_invalidated: result[:levels_invalidated] || [],
              results: result[:results] || %{}
            })

          conn
          |> put_resp_content_type("application/json")
          |> send_resp(200, body)

        {:error, :timeout} ->
          Logger.warning("[OntologyRoutes] inference-chain invalidate timed out")

          body =
            Jason.encode!(%{
              error: "timeout",
              details: "Inference chain re-materialization timed out — L0 write is complete"
            })

          conn
          |> put_resp_content_type("application/json")
          |> send_resp(202, body)

        {:error, reason} ->
          Logger.error("[OntologyRoutes] inference-chain invalidate failed: #{inspect(reason)}")

          body =
            Jason.encode!(%{
              error: "inference_chain_error",
              details: inspect(reason)
            })

          conn
          |> put_resp_content_type("application/json")
          |> send_resp(500, body)
      end
    end
  end

  match _ do
    body = Jason.encode!(%{error: "not_found", details: "Ontology endpoint not found"})

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(404, body)
  end
end
