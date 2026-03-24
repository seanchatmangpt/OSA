defmodule OptimalSystemAgent.Channels.HTTP.API.AuditRoutes do
  @moduledoc """
  Audit trail routes for the OSA HTTP API.

  Exposes the hash-chain audit trail (Innovation 3) for compliance verification.

  Forwarded prefix: /audit-trail

  Effective routes:
    GET /:session_id         → Full hash chain for a session
    GET /:session_id/verify  → Verify chain integrity
    GET /:session_id/merkle  → Merkle root hash
  """

  use Plug.Router
  import OptimalSystemAgent.Channels.HTTP.API.Shared
  require Logger

  alias OptimalSystemAgent.Agent.Hooks.AuditTrail

  plug(:match)
  plug(:dispatch)

  # ── GET /:session_id — full hash chain ───────────────────────────────

  get "/:session_id" do
    entries = safe_export_chain(session_id)

    json(conn, 200, %{
      session_id: session_id,
      entry_count: length(entries),
      entries: entries
    })
  end

  # ── GET /:session_id/verify — chain integrity check ──────────────────

  get "/:session_id/verify" do
    case safe_verify_chain(session_id) do
      {:ok, valid} ->
        json(conn, 200, %{
          session_id: session_id,
          valid: valid,
          verified_at: DateTime.utc_now() |> DateTime.to_iso8601()
        })

      {:error, reason} ->
        Logger.warning("[AuditRoutes] Verification error for session #{session_id}: #{inspect(reason)}")
        json_error(conn, 500, "verification_error", "Failed to verify audit chain")
    end
  end

  # ── GET /:session_id/merkle — Merkle root hash ───────────────────────

  get "/:session_id/merkle" do
    root = safe_merkle_root(session_id)

    json(conn, 200, %{
      session_id: session_id,
      merkle_root: root,
      computed_at: DateTime.utc_now() |> DateTime.to_iso8601()
    })
  end

  # ── catch-all ────────────────────────────────────────────────────────

  match _ do
    json_error(conn, 404, "not_found", "Audit trail endpoint not found")
  end

  # ── Private helpers ──────────────────────────────────────────────────

  defp safe_export_chain(session_id) do
    AuditTrail.export_chain(session_id)
  rescue
    e ->
      Logger.error("[AuditRoutes] export_chain error: #{Exception.message(e)}")
      []
  catch
    :exit, _ -> []
  end

  defp safe_verify_chain(session_id) do
    AuditTrail.verify_chain(session_id)
  rescue
    e ->
      Logger.error("[AuditRoutes] verify_chain error: #{Exception.message(e)}")
      {:error, :internal_error}
  catch
    :exit, reason -> {:error, {:exit, reason}}
  end

  defp safe_merkle_root(session_id) do
    AuditTrail.merkle_root(session_id)
  rescue
    e ->
      Logger.error("[AuditRoutes] merkle_root error: #{Exception.message(e)}")
      nil
  catch
    :exit, _ -> nil
  end
end
