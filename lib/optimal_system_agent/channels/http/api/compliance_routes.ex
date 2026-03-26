defmodule OptimalSystemAgent.Channels.HTTP.API.ComplianceRoutes do
  @moduledoc """
  Fortune 5 compliance verification routes.

  Endpoints for SOC2, GDPR, HIPAA, SOX, and CUSTOM framework verification.
  Leverages the Compliance.Verifier GenServer with 5-minute cache and 15-second
  per-framework timeout.

  Forwarded prefix: /compliance

  Effective routes:
    POST /verify/:framework     → Verify specific framework (soc2|gdpr|hipaa|sox)
    GET  /report                → Full compliance report (all frameworks)
    POST /reload                → Clear cache and reload (admin)
    GET  /cache-stats           → Cache statistics
    POST /invalidate/:framework → Invalidate specific framework cache
  """

  use Plug.Router
  import OptimalSystemAgent.Channels.HTTP.API.Shared
  require Logger

  alias OptimalSystemAgent.Integrations.Compliance.Verifier

  plug(:match)
  plug(:dispatch)

  # ── POST /verify/:framework — verify single framework ──────────────────

  post "/verify/:framework" do
    framework = safe_framework_atom(framework)

    case verify_framework(framework) do
      {:ok, result} ->
        json(conn, 200, %{
          framework: Atom.to_string(framework),
          compliant: result.compliant,
          violations: result.violations,
          cached: result.cached,
          verified_at: DateTime.utc_now() |> DateTime.to_iso8601()
        })

      {:error, reason} ->
        Logger.warning("[ComplianceRoutes] Verification failed for #{framework}: #{inspect(reason)}")

        json_error(conn, 500, "verification_failed", "Failed to verify #{framework} compliance")

      :timeout ->
        Logger.warning("[ComplianceRoutes] Verification timeout for #{framework}")

        json_error(conn, 504, "verification_timeout", "Framework verification timed out")
    end
  end

  # ── GET /report — full compliance report ──────────────────────────────

  get "/report" do
    case generate_full_report() do
      {:ok, report} ->
        json(conn, 200, %{
          overall_compliant: report.overall_compliant,
          frameworks: report.frameworks,
          verified_at: report.verified_at,
          cache_stats: report.cache_stats
        })

      {:error, reason} ->
        Logger.error("[ComplianceRoutes] Report generation failed: #{inspect(reason)}")

        json_error(conn, 500, "report_failed", "Failed to generate compliance report")
    end
  end

  # ── POST /reload — clear cache and reload ────────────────────────────

  post "/reload" do
    case clear_compliance_cache() do
      :ok ->
        json(conn, 200, %{
          status: "reloaded",
          message: "Compliance cache cleared and ready for reload",
          reloaded_at: DateTime.utc_now() |> DateTime.to_iso8601()
        })

      {:error, reason} ->
        Logger.error("[ComplianceRoutes] Cache reload failed: #{inspect(reason)}")

        json_error(conn, 500, "reload_failed", "Failed to reload compliance cache")
    end
  end

  # ── GET /cache-stats — cache statistics ──────────────────────────────

  get "/cache-stats" do
    stats = safe_get_cache_stats()

    json(conn, 200, %{
      hits: stats.hits,
      misses: stats.misses,
      entries: stats.entries,
      queried_at: DateTime.utc_now() |> DateTime.to_iso8601()
    })
  end

  # ── POST /invalidate/:framework — invalidate framework cache ─────────

  post "/invalidate/:framework" do
    framework = safe_framework_atom(framework)

    case invalidate_framework_cache(framework) do
      :ok ->
        json(conn, 200, %{
          framework: Atom.to_string(framework),
          status: "invalidated",
          invalidated_at: DateTime.utc_now() |> DateTime.to_iso8601()
        })

      {:error, reason} ->
        Logger.warning("[ComplianceRoutes] Cache invalidation failed for #{framework}: #{inspect(reason)}")

        json_error(conn, 500, "invalidation_failed", "Failed to invalidate cache")
    end
  end

  # ── catch-all ────────────────────────────────────────────────────────

  match _ do
    json_error(conn, 404, "not_found", "Compliance endpoint not found")
  end

  # ── Private helpers ──────────────────────────────────────────────────

  defp safe_framework_atom(name) when is_binary(name) do
    case String.downcase(name) do
      "soc2" -> :soc2
      "gdpr" -> :gdpr
      "hipaa" -> :hipaa
      "sox" -> :sox
      _ -> :unknown
    end
  end

  defp safe_framework_atom(_), do: :unknown

  defp verify_framework(:unknown) do
    {:error, "Unknown framework"}
  end

  defp verify_framework(framework) do
    verifier_ref = get_verifier_ref()

    case framework do
      :soc2 -> Verifier.verify_soc2(verifier_ref)
      :gdpr -> Verifier.verify_gdpr(verifier_ref)
      :hipaa -> Verifier.verify_hipaa(verifier_ref)
      :sox -> Verifier.verify_sox(verifier_ref)
      _ -> {:error, "Unknown framework"}
    end
  rescue
    e ->
      Logger.error("[ComplianceRoutes] verify_framework error: #{Exception.message(e)}")
      {:error, Exception.message(e)}
  catch
    :exit, reason -> {:error, {:exit, reason}}
  end

  defp generate_full_report do
    verifier_ref = get_verifier_ref()

    Verifier.generate_report(verifier_ref)
  rescue
    e ->
      Logger.error("[ComplianceRoutes] generate_report error: #{Exception.message(e)}")
      {:error, Exception.message(e)}
  catch
    :exit, reason -> {:error, {:exit, reason}}
  end

  defp safe_get_cache_stats do
    verifier_ref = get_verifier_ref()

    Verifier.cache_stats(verifier_ref)
  rescue
    e ->
      Logger.error("[ComplianceRoutes] cache_stats error: #{Exception.message(e)}")
      %{hits: 0, misses: 0, entries: 0}
  catch
    :exit, _ -> %{hits: 0, misses: 0, entries: 0}
  end

  defp clear_compliance_cache do
    verifier_ref = get_verifier_ref()

    Verifier.clear_cache(verifier_ref)
  rescue
    e ->
      Logger.error("[ComplianceRoutes] clear_cache error: #{Exception.message(e)}")
      {:error, Exception.message(e)}
  catch
    :exit, reason -> {:error, {:exit, reason}}
  end

  defp invalidate_framework_cache(framework) do
    verifier_ref = get_verifier_ref()

    Verifier.invalidate_cache(verifier_ref, framework)
  rescue
    e ->
      Logger.error("[ComplianceRoutes] invalidate_cache error: #{Exception.message(e)}")
      {:error, Exception.message(e)}
  catch
    :exit, reason -> {:error, {:exit, reason}}
  end

  defp get_verifier_ref do
    case GenServer.whereis(:compliance_verifier) do
      nil ->
        # Try to start verifier if not running
        {:ok, pid} = Verifier.start_link(name: :compliance_verifier)
        pid

      pid ->
        pid
    end
  rescue
    _ -> :compliance_verifier
  end
end
