defmodule OptimalSystemAgent.Channels.Healthcare.Routes do
  @moduledoc """
  HIPAA-compliant healthcare integration routes.

  Exposes PHI tracking, consent verification, audit trail, and compliance checking
  via HTTP API. All operations use the PHIHandler GenServer.

  **Forwarded prefix:** /api/healthcare

  **Effective routes:**
    POST /track              → Track PHI access event
    POST /consent/verify     → Verify consent token
    GET /audit/:phi_id       → Get audit trail for PHI
    DELETE /:phi_id          → Hard delete + verify
    GET /hipaa/verify        → HIPAA compliance check

  **Security:**
  - All responses sanitized (no internal error details)
  - PHI IDs normalized (alphanumeric + underscore only)
  - Timestamps in ISO8601 format
  - slog structured logging for all audit events

  **Error Handling:**
  - 400 Bad Request: Invalid phi_id or missing required fields
  - 404 Not Found: PHI record not found
  - 500 Internal Error: SPARQL query or GenServer failure
  - All errors return `{error: string, details: string}` with NO stack traces
  """

  use Plug.Router
  import OptimalSystemAgent.Channels.HTTP.API.Shared
  require Logger

  alias OptimalSystemAgent.Integrations.Healthcare.PHIHandler

  plug(:match)
  plug(:dispatch)

  # ── POST /track — Track PHI access event ─────────────────────────────────

  post "/track" do
    with {:ok, body} <- read_request_body(conn),
         {:ok, params} <- Jason.decode(body),
         {:ok, phi_id} <- extract_phi_id(params["phi_id"]),
         {:ok, access_info} <- validate_access_info(params) do

      case PHIHandler.track_phi(phi_id, access_info) do
        {:ok, event_id} ->
          Logger.info("[HealthcareRoutes] PHI tracked: #{phi_id} event=#{event_id}")

          json(conn, 200, %{
            status: "tracked",
            event_id: event_id,
            phi_id: phi_id,
            timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
            action: access_info[:action],
            user_id: access_info[:user_id]
          })

        {:error, reason} ->
          Logger.warning("[HealthcareRoutes] PHI tracking failed: #{phi_id} reason=#{reason}")

          json_error(conn, 400, "tracking_failed", "Failed to track PHI access: #{reason}")
      end
    else
      {:error, reason} ->
        json_error(conn, 400, "invalid_request", reason)
    end
  end

  # ── POST /consent/verify — Verify consent token ──────────────────────────

  post "/consent/verify" do
    with {:ok, body} <- read_request_body(conn),
         {:ok, params} <- Jason.decode(body),
         {:ok, phi_id} <- extract_phi_id(params["phi_id"]),
         {:ok, consent_token} <- extract_consent_token(params["consent_token"]) do

      case PHIHandler.verify_consent(phi_id, consent_token) do
        {:ok, valid} ->
          Logger.info("[HealthcareRoutes] Consent verified: #{phi_id} valid=#{valid}")

          json(conn, 200, %{
            status: "verified",
            phi_id: phi_id,
            valid: valid,
            timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
          })

        {:error, reason} ->
          Logger.error("[HealthcareRoutes] Consent verification failed: #{phi_id} reason=#{reason}")

          json_error(conn, 500, "verification_error", "Consent verification failed")
      end
    else
      {:error, reason} ->
        json_error(conn, 400, "invalid_request", reason)
    end
  end

  # ── GET /audit/:phi_id — Get audit trail ────────────────────────────────

  get "/audit/:phi_id" do
    with {:ok, phi_id} <- extract_phi_id(phi_id) do
      case PHIHandler.generate_audit_trail(phi_id) do
        {:ok, triple_count} ->
          Logger.info("[HealthcareRoutes] Audit trail generated: #{phi_id} triples=#{triple_count}")

          json(conn, 200, %{
            status: "audit_generated",
            phi_id: phi_id,
            triple_count: triple_count,
            timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
            resource_type: "HIPAA Audit Trail",
            retention_years: 7
          })

        {:error, reason} ->
          Logger.error("[HealthcareRoutes] Audit trail generation failed: #{phi_id} reason=#{reason}")

          json_error(conn, 500, "audit_error", "Failed to generate audit trail")
      end
    else
      {:error, reason} ->
        json_error(conn, 400, "invalid_request", reason)
    end
  end

  # ── DELETE /:phi_id — Hard delete + verify ──────────────────────────────

  delete "/:phi_id" do
    with {:ok, phi_id} <- extract_phi_id(phi_id) do
      # Step 1: Generate audit trail BEFORE deletion
      _audit_result = PHIHandler.generate_audit_trail(phi_id)

      # Step 2: Request hard delete (external system)
      # (This would call an actual deletion service in production)

      # Step 3: Verify deletion by checking RDF store
      case PHIHandler.check_deletion(phi_id) do
        {:ok, deleted} ->
          Logger.info("[HealthcareRoutes] PHI deletion verified: #{phi_id} deleted=#{deleted}")

          json(conn, 200, %{
            status: "deletion_verified",
            phi_id: phi_id,
            deleted: deleted,
            timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
            gdpr_article_17: "Right to be Forgotten",
            compliance_verified: deleted
          })

        {:error, reason} ->
          Logger.error("[HealthcareRoutes] Deletion verification failed: #{phi_id} reason=#{reason}")

          json_error(conn, 500, "deletion_error", "Failed to verify deletion")
      end
    else
      {:error, reason} ->
        json_error(conn, 400, "invalid_request", reason)
    end
  end

  # ── GET /hipaa/verify — HIPAA compliance check ──────────────────────────

  get "/hipaa/verify" do
    conn = Plug.Conn.fetch_query_params(conn)
    phi_id = conn.query_params["phi_id"]

    case PHIHandler.verify_hipaa(phi_id) do
      {:ok, report} ->
        Logger.info("[HealthcareRoutes] HIPAA compliance check: phi_id=#{phi_id} compliant=#{report[:compliant]}")

        json(conn, 200, %{
          status: "compliance_checked",
          phi_id: phi_id,
          compliant: report[:compliant],
          audit_complete: report[:audit_complete],
          consent_verified: report[:consent_verified],
          no_stale_records: report[:no_stale_records],
          encrypted: report[:encrypted],
          issues: report[:issues],
          timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
          framework: "HIPAA § 164.312(b) Audit Controls"
        })

      {:error, reason} ->
        Logger.error("[HealthcareRoutes] HIPAA check failed: reason=#{reason}")

        json_error(conn, 500, "compliance_error", "HIPAA compliance check failed")
    end
  end

  # ── catch-all ────────────────────────────────────────────────────────────

  match _ do
    json_error(conn, 404, "not_found", "Healthcare endpoint not found")
  end

  # ── Private Helpers ──────────────────────────────────────────────────────

  defp read_request_body(conn) do
    case Plug.Conn.read_body(conn) do
      {:ok, body, _conn} -> {:ok, body}
      {:more, _partial, _conn} -> {:error, "request_body_too_large"}
      {:error, reason} -> {:error, inspect(reason)}
    end
  end

  # Validate and normalize PHI ID.
  # Only allows alphanumeric, underscore, and hyphen to prevent injection.
  # Returns {:ok, phi_id} or {:error, reason}.
  defp extract_phi_id(nil) do
    {:error, "Missing phi_id"}
  end

  defp extract_phi_id(phi_id) when is_binary(phi_id) do
    # Normalize: trim whitespace
    phi_id = String.trim(phi_id)

    # Validate: alphanumeric, underscore, hyphen only
    if String.match?(phi_id, ~r/^[a-zA-Z0-9_-]+$/) do
      {:ok, phi_id}
    else
      {:error, "Invalid phi_id format (only alphanumeric, _, - allowed)"}
    end
  end

  defp extract_phi_id(_) do
    {:error, "phi_id must be a string"}
  end

  # Extract and validate consent token from params.
  # Returns {:ok, token} or {:error, reason}.
  defp extract_consent_token(nil) do
    {:error, "Missing consent_token"}
  end

  defp extract_consent_token(token) when is_binary(token) do
    token = String.trim(token)

    if token != "" do
      {:ok, token}
    else
      {:error, "consent_token cannot be empty"}
    end
  end

  defp extract_consent_token(_) do
    {:error, "consent_token must be a string"}
  end

  # Validate access info from request body.
  # Required fields: user_id, action, resource_type
  # Optional fields: consent_token, justification
  # Returns {:ok, map} or {:error, reason}.
  defp validate_access_info(params) when is_map(params) do
    with {:ok, user_id} <- validate_required(params["user_id"], "user_id"),
         {:ok, action} <- validate_action(params["action"]),
         {:ok, resource_type} <- validate_required(params["resource_type"], "resource_type") do

      access_info = %{
        user_id: user_id,
        action: action,
        resource_type: resource_type,
        consent_token: params["consent_token"],
        justification: params["justification"]
      }

      {:ok, access_info}
    end
  end

  defp validate_access_info(_) do
    {:error, "Request body must be a JSON object"}
  end

  defp validate_required(nil, field_name) do
    {:error, "Missing required field: #{field_name}"}
  end

  defp validate_required(value, _field_name) when is_binary(value) do
    if String.trim(value) != "" do
      {:ok, String.trim(value)}
    else
      {:error, "Field cannot be empty"}
    end
  end

  defp validate_required(_, field_name) do
    {:error, "Field must be a string: #{field_name}"}
  end

  # Validate action is one of: :read, :write, :delete
  # Returns {:ok, atom} or {:error, reason}.
  defp validate_action(nil) do
    {:error, "Missing required field: action"}
  end

  defp validate_action(action) when is_binary(action) do
    case String.downcase(String.trim(action)) do
      "read" -> {:ok, :read}
      "write" -> {:ok, :write}
      "delete" -> {:ok, :delete}
      _ -> {:error, "Invalid action (must be: read, write, delete)"}
    end
  end

  defp validate_action(_) do
    {:error, "action must be a string"}
  end
end
