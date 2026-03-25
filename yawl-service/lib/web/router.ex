defmodule YawlService.Web.Router do
  @moduledoc """
  HTTP API router for YAWL verification service.
  """

  use Plug.Router

  plug Plug.Parsers, parsers: [:json], pass: ["application/json"], json_decoder: Jason
  plug :match
  plug :dispatch

  # ═══════════════════════════════════════════════════════════════════════════════
  # ROUTES
  # ═══════════════════════════════════════════════════════════════════════════════

  get "/" do
    send_resp(conn, 200, "YAWL Verification Service v1.0.0")
  end

  get "/health" do
    send_resp(conn, 200, Jason.encode!(%{status: "healthy"}))
  end

  # Verify single workflow
  post "/api/v1/verify/workflow" do
    YawlService.Web.Handlers.Verify.handle(conn, conn.body_params)
  end

  # Verify batch of workflows
  post "/api/v1/verify/batch" do
    YawlService.Web.Handlers.Verify.handle_batch(conn, conn.body_params)
  end

  # Retrieve certificate
  get "/api/v1/verify/certificate/:id" do
    YawlService.Web.Handlers.Cert.retrieve(conn, id)
  end

  # Get verification status
  get "/api/v1/verify/status/:id" do
    YawlService.Web.Handlers.Verify.status(conn, id)
  end

  # 404 handler
  match _ do
    send_resp(conn, 404, Jason.encode!(%{error: "Not found"}))
  end
end
