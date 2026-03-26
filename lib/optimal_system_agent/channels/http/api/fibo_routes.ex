defmodule OptimalSystemAgent.Channels.HTTP.API.FIBORoutes do
  @moduledoc """
  FIBO HTTP Routes (Agent 16) — REST API for financial deal management.

  Endpoints:
    POST   /api/fibo/deals                     Create a new deal
    GET    /api/fibo/deals                     List all deals
    GET    /api/fibo/deals/:id                 Retrieve a deal by ID
    POST   /api/fibo/deals/:id/verify         Verify deal compliance

  All responses are JSON with standard envelope:
    {
      "status": "ok" | "error",
      "data": {...},
      "error": "error message (if status=error)"
    }

  Timeouts: All operations have 10s backend timeout. Clients should use appropriate
  socket timeouts.
  """

  use Plug.Router
  import OptimalSystemAgent.Channels.HTTP.API.Shared
  require Logger

  alias OptimalSystemAgent.Integrations.FIBO.{DealCoordinator, Deal}

  plug :match
  plug :dispatch

  # ===========================================================================
  # POST /api/fibo/deals
  # ===========================================================================

  post "/deals" do
    input = %{
      name: conn.body_params["name"],
      counterparty: conn.body_params["counterparty"],
      amount_usd: conn.body_params["amount_usd"],
      currency: conn.body_params["currency"],
      settlement_date: parse_datetime(conn.body_params["settlement_date"])
    }

    cond do
      is_nil(input.name) or input.name == "" ->
        json_error(conn, 400, "invalid_request", "Missing required field: name")

      is_nil(input.counterparty) or input.counterparty == "" ->
        json_error(conn, 400, "invalid_request", "Missing required field: counterparty")

      is_nil(input.amount_usd) or input.amount_usd <= 0 ->
        json_error(conn, 400, "invalid_request", "Missing or invalid required field: amount_usd")

      true ->
        case DealCoordinator.create_deal(input) do
          {:ok, deal} ->
            json(conn, 201, %{
              "status" => "ok",
              "data" => Deal.to_json(deal)
            })

          {:error, reason} ->
            json_error(conn, 422, "deal_creation_failed", reason)
        end
    end
  end

  # ===========================================================================
  # GET /api/fibo/deals
  # ===========================================================================

  get "/deals" do
    deals = DealCoordinator.list_deals()

    json(conn, 200, %{
      "status" => "ok",
      "data" => %{
        "total" => Enum.count(deals),
        "deals" => Enum.map(deals, &Deal.to_json/1)
      }
    })
  end

  # ===========================================================================
  # GET /api/fibo/deals/:id
  # ===========================================================================

  get "/deals/:id" do
    case DealCoordinator.get_deal(id) do
      {:ok, deal} ->
        json(conn, 200, %{
          "status" => "ok",
          "data" => Deal.to_json(deal)
        })

      {:error, :not_found} ->
        json_error(conn, 404, "not_found", "Deal not found")

      {:error, reason} ->
        json_error(conn, 500, "internal_error", to_string(reason))
    end
  end

  # ===========================================================================
  # POST /api/fibo/deals/:id/verify
  # ===========================================================================

  post "/deals/:id/verify" do
    case DealCoordinator.verify_compliance(id) do
      {:ok, deal} ->
        json(conn, 200, %{
          "status" => "ok",
          "data" => Deal.to_json(deal)
        })

      {:error, :not_found} ->
        json_error(conn, 404, "not_found", "Deal not found")

      {:error, reason} ->
        json_error(conn, 422, "verification_failed", to_string(reason))
    end
  end

  # ===========================================================================
  # Catch-all for unmatched routes
  # ===========================================================================

  match _ do
    json_error(conn, 404, "not_found", "Route not found")
  end

  # ───────────────────────────────────────────────────────────────────────────
  # Helpers
  # ───────────────────────────────────────────────────────────────────────────

  defp parse_datetime(nil), do: nil

  defp parse_datetime(iso_string) when is_binary(iso_string) do
    case DateTime.from_iso8601(iso_string) do
      {:ok, dt, _offset} -> dt
      :error -> nil
    end
  end

  defp parse_datetime(_), do: nil
end
