defmodule OptimalSystemAgent.Channels.HTTP.API.ProcessRoutes do
  @moduledoc """
  Process intelligence routes for the OSA HTTP API.

  Exposes three process intelligence modules:
  - Fingerprint (Innovation 4): process DNA fingerprinting
  - Temporal (Innovation 7): temporal process mining
  - OrgEvolution (Innovation 2): self-evolving organization

  Forwarded prefix: /process

  Fingerprint routes:
    POST /fingerprint              → Extract fingerprint from process events
    GET  /fingerprint/:id          → Get stored fingerprint
    POST /fingerprint/compare      → Compare two fingerprints
    POST /fingerprint/evolution    → Track fingerprint evolution
    GET  /fingerprint/benchmark/:industry → Industry benchmark

  Temporal routes:
    POST /temporal/snapshot        → Record a metric snapshot
    GET  /temporal/velocity/:process_id → Process velocity
    GET  /temporal/predict/:process_id  → Predict future state
    GET  /temporal/early-warning/:process_id → Early warnings
    GET  /temporal/stagnation/:process_id → Stagnation detection

  Org Evolution routes:
    POST /org/drift                → Detect org drift
    POST /org/mutate               → Propose mutations
    POST /org/optimize/:workflow_id → Optimize workflow
    POST /org/sop                  → Generate SOP
    GET  /org/health               → Org health assessment
  """

  use Plug.Router
  import OptimalSystemAgent.Channels.HTTP.API.Shared
  require Logger

  alias OptimalSystemAgent.Process.Fingerprint
  alias OptimalSystemAgent.Process.ProcessMining
  alias OptimalSystemAgent.Process.OrgEvolution

  plug(Plug.Parsers,
    parsers: [:json],
    pass: ["application/json"],
    json_decoder: Jason,
    length: 1_000_000
  )

  plug(:match)
  plug(:dispatch)

  # ══════════════════════════════════════════════════════════════════════
  # Fingerprint Endpoints
  # ══════════════════════════════════════════════════════════════════════

  # ── POST /fingerprint — extract fingerprint from events ──────────────

  post "/fingerprint" do
    params = conn.body_params

    events = Map.get(params, "events", [])
    process_type = Map.get(params, "process_type", "unknown")

    cond do
      not is_list(events) or events == [] ->
        json_error(conn, 400, "invalid_request", "Missing or empty 'events' array")

      true ->
        opts = [process_type: process_type]

        case safe_extract_fingerprint(events, opts) do
          {:ok, fingerprint} ->
            json(conn, 200, %{fingerprint: fingerprint})

          {:error, reason} ->
            json_error(conn, 400, "fingerprint_error", "Failed to extract fingerprint: #{inspect(reason)}")
        end
    end
  end

  # ── GET /fingerprint/:id — retrieve stored fingerprint ───────────────

  get "/fingerprint/:id" do
    case safe_get_fingerprint(id) do
      nil ->
        json_error(conn, 404, "not_found", "Fingerprint not found")

      fingerprint ->
        json(conn, 200, %{fingerprint: fingerprint})
    end
  end

  # ── POST /fingerprint/compare — compare two fingerprints ─────────────

  post "/fingerprint/compare" do
    params = conn.body_params
    fp_a = Map.get(params, "fingerprint_a")
    fp_b = Map.get(params, "fingerprint_b")

    cond do
      not is_map(fp_a) or map_size(fp_a) == 0 ->
        json_error(conn, 400, "invalid_request", "Missing or invalid 'fingerprint_a'")

      not is_map(fp_b) or map_size(fp_b) == 0 ->
        json_error(conn, 400, "invalid_request", "Missing or invalid 'fingerprint_b'")

      true ->
        # Convert string keys to atom keys for the Fingerprint module
        fp_a_normalized = normalize_fingerprint_map(fp_a)
        fp_b_normalized = normalize_fingerprint_map(fp_b)

        case safe_compare_fingerprints(fp_a_normalized, fp_b_normalized) do
          {:ok, comparison} ->
            json(conn, 200, %{comparison: comparison})

          {:error, reason} ->
            json_error(conn, 400, "compare_error", "Failed to compare fingerprints: #{inspect(reason)}")
        end
    end
  end

  # ── POST /fingerprint/evolution — track fingerprint evolution ────────

  post "/fingerprint/evolution" do
    params = conn.body_params
    fingerprints = Map.get(params, "fingerprints", [])

    cond do
      not is_list(fingerprints) or fingerprints == [] ->
        json_error(conn, 400, "invalid_request", "Missing or empty 'fingerprints' array")

      true ->
        normalized =
          Enum.map(fingerprints, &normalize_fingerprint_map/1)

        case safe_evolution_track(normalized) do
          {:ok, evolution} ->
            json(conn, 200, %{evolution: evolution})

          {:error, reason} ->
            json_error(conn, 400, "evolution_error", "Failed to track evolution: #{inspect(reason)}")
        end
    end
  end

  # ── GET /fingerprint/benchmark/:industry — industry benchmark ────────

  get "/fingerprint/benchmark/:industry" do
    # Require a fingerprint_id query param to look up a stored fingerprint
    conn = Plug.Conn.fetch_query_params(conn)
    fingerprint_id = conn.query_params["fingerprint_id"]

    if is_nil(fingerprint_id) do
      json_error(conn, 400, "invalid_request", "Query parameter 'fingerprint_id' is required")
    else
      case safe_get_fingerprint(fingerprint_id) do
        nil ->
          json_error(conn, 404, "not_found", "Fingerprint not found")

        fingerprint ->
          case safe_industry_benchmark(fingerprint, industry) do
            {:ok, benchmark} ->
              json(conn, 200, %{benchmark: benchmark})

            {:error, reason} ->
              json_error(conn, 400, "benchmark_error", "Benchmark failed: #{inspect(reason)}")
          end
      end
    end
  end

  # ══════════════════════════════════════════════════════════════════════
  # Temporal Endpoints
  # ══════════════════════════════════════════════════════════════════════

  # ── POST /temporal/snapshot — record a metric snapshot ───────────────

  post "/temporal/snapshot" do
    params = conn.body_params

    process_id = Map.get(params, "process_id")
    metrics = Map.get(params, "metrics", %{})

    cond do
      not is_binary(process_id) or process_id == "" ->
        json_error(conn, 400, "invalid_request", "Missing or empty 'process_id'")

      not is_map(metrics) or map_size(metrics) == 0 ->
        json_error(conn, 400, "invalid_request", "Missing or empty 'metrics' map")

      true ->
        # Convert string keys to atoms for the Temporal module
        normalized_metrics =
          metrics
          |> Enum.map(fn {k, v} ->
            key = if is_binary(k), do: String.to_atom(k), else: k
            {key, v}
          end)
          |> Map.new()

        :ok = safe_record_snapshot(process_id, normalized_metrics)

        json(conn, 200, %{
          process_id: process_id,
          status: "recorded",
          recorded_at: DateTime.utc_now() |> DateTime.to_iso8601()
        })
    end
  end

  # ── GET /temporal/velocity/:process_id — process velocity ───────────

  get "/temporal/velocity/:process_id" do
    velocity = safe_process_velocity(process_id)

    json(conn, 200, %{
      process_id: process_id,
      velocity: velocity
    })
  end

  # ── GET /temporal/predict/:process_id — predict future state ─────────

  get "/temporal/predict/:process_id" do
    conn = Plug.Conn.fetch_query_params(conn)

    weeks_ahead =
      conn.query_params
      |> Map.get("weeks_ahead", "4")
      |> parse_positive_int(4)

    prediction = safe_predict_state(process_id, weeks_ahead)

    json(conn, 200, %{
      process_id: process_id,
      prediction: prediction
    })
  end

  # ── GET /temporal/early-warning/:process_id — early warnings ─────────

  get "/temporal/early-warning/:process_id" do
    warning = safe_early_warning(process_id)

    json(conn, 200, %{
      process_id: process_id,
      early_warning: warning
    })
  end

  # ── GET /temporal/stagnation/:process_id — stagnation detection ─────

  get "/temporal/stagnation/:process_id" do
    stagnation = safe_stagnation_detect(process_id)

    json(conn, 200, %{
      process_id: process_id,
      stagnation: stagnation
    })
  end

  # ══════════════════════════════════════════════════════════════════════
  # Org Evolution Endpoints
  # ══════════════════════════════════════════════════════════════════════

  # ── POST /org/drift — detect organizational drift ────────────────────

  post "/org/drift" do
    params = conn.body_params
    org_config = Map.get(params, "org_config", params)

    if not is_map(org_config) or map_size(org_config) == 0 do
      json_error(conn, 400, "invalid_request", "Missing or empty 'org_config'")
    else
      normalized_org_config = atomize_keys(org_config, ~w(teams roles workflows execution_data))

      case safe_detect_drift(normalized_org_config) do
        drift when is_map(drift) ->
          json(conn, 200, %{drift: drift})

        {:error, reason} ->
          Logger.warning("[ProcessRoutes] detect_drift error: #{inspect(reason)}")
          json_error(conn, 500, "internal_error", "Drift detection failed")
      end
    end
  end

  # ── POST /org/mutate — propose mutations ─────────────────────────────

  post "/org/mutate" do
    params = conn.body_params
    org_config = Map.get(params, "org_config", %{})
    drift_analysis = Map.get(params, "drift_analysis", %{})

    cond do
      not is_map(org_config) or map_size(org_config) == 0 ->
        json_error(conn, 400, "invalid_request", "Missing or empty 'org_config'")

      not is_map(drift_analysis) ->
        json_error(conn, 400, "invalid_request", "Invalid 'drift_analysis'")

      true ->
        normalized_org_config = atomize_keys(org_config, ~w(teams roles workflows execution_data))
        normalized_drift = atomize_keys(drift_analysis, ~w(drifts drift_score recommendation analyzed_at))

        case safe_propose_mutation(normalized_org_config, normalized_drift) do
          result when is_map(result) ->
            json(conn, 200, %{mutation: result})

          {:error, reason} ->
            Logger.warning("[ProcessRoutes] propose_mutation error: #{inspect(reason)}")
            json_error(conn, 500, "internal_error", "Mutation proposal failed")
        end
    end
  end

  # ── POST /org/optimize/:workflow_id — optimize workflow ──────────────

  post "/org/optimize/:workflow_id" do
    params = conn.body_params
    execution_history = Map.get(params, "execution_history", [])

    if not is_list(execution_history) do
      json_error(conn, 400, "invalid_request", "'execution_history' must be an array")
    else
      case safe_optimize_workflow(workflow_id, execution_history) do
        result when is_map(result) ->
          json(conn, 200, %{optimization: result})

        {:error, reason} ->
          Logger.warning("[ProcessRoutes] optimize_workflow error: #{inspect(reason)}")
          json_error(conn, 500, "internal_error", "Workflow optimization failed")
      end
    end
  end

  # ── POST /org/sop — generate SOP ─────────────────────────────────────

  post "/org/sop" do
    params = conn.body_params

    process_id = Map.get(params, "process_id")
    executions = Map.get(params, "executions", [])

    cond do
      not is_binary(process_id) or process_id == "" ->
        json_error(conn, 400, "invalid_request", "Missing or empty 'process_id'")

      not is_list(executions) ->
        json_error(conn, 400, "invalid_request", "'executions' must be an array")

      true ->
        case safe_generate_sop(process_id, executions) do
          sop when is_map(sop) ->
            json(conn, 200, %{sop: sop})

          {:error, reason} ->
            Logger.warning("[ProcessRoutes] generate_sop error: #{inspect(reason)}")
            json_error(conn, 500, "internal_error", "SOP generation failed")
        end
    end
  end

  # ── GET /org/health — org health assessment ──────────────────────────

  get "/org/health" do
    conn = Plug.Conn.fetch_query_params(conn)

    # Accept org_config as a JSON string query param for simple health checks.
    # For full assessments, POST /org/drift + POST /org/mutate provide richer data.
    org_config = %{}

    case safe_org_health(org_config) do
      health when is_map(health) ->
        json(conn, 200, %{health: health})

      {:error, reason} ->
        Logger.warning("[ProcessRoutes] org_health error: #{inspect(reason)}")
        json_error(conn, 500, "internal_error", "Health assessment failed")
    end
  end

  # ── catch-all ────────────────────────────────────────────────────────

  match _ do
    json_error(conn, 404, "not_found", "Process intelligence endpoint not found")
  end

  # ══════════════════════════════════════════════════════════════════════
  # Fingerprint Safe Wrappers
  # ══════════════════════════════════════════════════════════════════════

  defp safe_extract_fingerprint(events, opts) do
    Fingerprint.extract_fingerprint(events, opts)
  rescue
    e ->
      Logger.error("[ProcessRoutes] extract_fingerprint error: #{Exception.message(e)}")
      {:error, :internal_error}
  catch
    :exit, _ -> {:error, :service_unavailable}
  end

  defp safe_get_fingerprint(id) do
    Fingerprint.get_fingerprint(id)
  rescue
    e ->
      Logger.error("[ProcessRoutes] get_fingerprint error: #{Exception.message(e)}")
      nil
  catch
    :exit, _ -> nil
  end

  defp safe_compare_fingerprints(fp_a, fp_b) do
    Fingerprint.compare_fingerprints(fp_a, fp_b)
  rescue
    e ->
      Logger.error("[ProcessRoutes] compare_fingerprints error: #{Exception.message(e)}")
      {:error, :internal_error}
  catch
    :exit, _ -> {:error, :service_unavailable}
  end

  defp safe_evolution_track(fingerprints) do
    Fingerprint.evolution_track(fingerprints)
  rescue
    e ->
      Logger.error("[ProcessRoutes] evolution_track error: #{Exception.message(e)}")
      {:error, :internal_error}
  catch
    :exit, _ -> {:error, :service_unavailable}
  end

  defp safe_industry_benchmark(fingerprint, industry) do
    Fingerprint.industry_benchmark(fingerprint, industry)
  rescue
    e ->
      Logger.error("[ProcessRoutes] industry_benchmark error: #{Exception.message(e)}")
      {:error, :internal_error}
  catch
    :exit, _ -> {:error, :service_unavailable}
  end

  # ══════════════════════════════════════════════════════════════════════
  # Temporal Safe Wrappers
  # ══════════════════════════════════════════════════════════════════════

  defp safe_record_snapshot(process_id, metrics) do
    ProcessMining.record_snapshot(process_id, metrics)
  rescue
    e ->
      Logger.error("[ProcessRoutes] record_snapshot error: #{Exception.message(e)}")
      :ok
  catch
    :exit, _ -> :ok
  end

  defp safe_process_velocity(process_id) do
    ProcessMining.process_velocity(process_id)
  rescue
    e ->
      Logger.error("[ProcessRoutes] process_velocity error: #{Exception.message(e)}")
      %{
        pattern_velocity: 0.0,
        metric_velocity: %{},
        overall_velocity: 0.0,
        trend: :stable,
        data_points: 0,
        error: "service_unavailable"
      }
  catch
    :exit, _ ->
      %{
        pattern_velocity: 0.0,
        metric_velocity: %{},
        overall_velocity: 0.0,
        trend: :stable,
        data_points: 0,
        error: "service_unavailable"
      }
  end

  defp safe_predict_state(process_id, weeks_ahead) do
    ProcessMining.predict_state(process_id, weeks_ahead)
  rescue
    e ->
      Logger.error("[ProcessRoutes] predict_state error: #{Exception.message(e)}")
      %{
        predicted_at: DateTime.add(DateTime.utc_now(), weeks_ahead * 7 * 24 * 3600, :second),
        metrics: %{},
        confidence: 0.0,
        method: :error,
        warning_threshold: false,
        error: "service_unavailable"
      }
  catch
    :exit, _ ->
      %{
        predicted_at: DateTime.add(DateTime.utc_now(), weeks_ahead * 7 * 24 * 3600, :second),
        metrics: %{},
        confidence: 0.0,
        method: :error,
        warning_threshold: false,
        error: "service_unavailable"
      }
  end

  defp safe_early_warning(process_id) do
    ProcessMining.early_warning(process_id)
  rescue
    e ->
      Logger.error("[ProcessRoutes] early_warning error: #{Exception.message(e)}")
      %{
        warnings: [],
        health_score: 0.0,
        risk_level: :critical,
        data_points: 0,
        error: "service_unavailable"
      }
  catch
    :exit, _ ->
      %{
        warnings: [],
        health_score: 0.0,
        risk_level: :critical,
        data_points: 0,
        error: "service_unavailable"
      }
  end

  defp safe_stagnation_detect(process_id) do
    ProcessMining.stagnation_detect(process_id)
  rescue
    e ->
      Logger.error("[ProcessRoutes] stagnation_detect error: #{Exception.message(e)}")
      %{
        is_stagnant: false,
        stagnation_score: 0.0,
        last_improvement: nil,
        recommended_action: "Unable to assess -- service unavailable",
        error: "service_unavailable"
      }
  catch
    :exit, _ ->
      %{
        is_stagnant: false,
        stagnation_score: 0.0,
        last_improvement: nil,
        recommended_action: "Unable to assess -- service unavailable",
        error: "service_unavailable"
      }
  end

  # ══════════════════════════════════════════════════════════════════════
  # OrgEvolution Safe Wrappers
  # ══════════════════════════════════════════════════════════════════════

  defp safe_detect_drift(org_config) do
    OrgEvolution.detect_drift(org_config)
  rescue
    e ->
      Logger.error("[ProcessRoutes] detect_drift error: #{Exception.message(e)}")
      {:error, :internal_error}
  catch
    :exit, _ -> {:error, :service_unavailable}
  end

  defp safe_propose_mutation(org_config, drift_analysis) do
    OrgEvolution.propose_mutation(org_config, drift_analysis)
  rescue
    e ->
      Logger.error("[ProcessRoutes] propose_mutation error: #{Exception.message(e)}")
      {:error, :internal_error}
  catch
    :exit, _ -> {:error, :service_unavailable}
  end

  defp safe_optimize_workflow(workflow_id, execution_history) do
    OrgEvolution.optimize_workflow(workflow_id, execution_history)
  rescue
    e ->
      Logger.error("[ProcessRoutes] optimize_workflow error: #{Exception.message(e)}")
      {:error, :internal_error}
  catch
    :exit, _ -> {:error, :service_unavailable}
  end

  defp safe_generate_sop(process_id, executions) do
    OrgEvolution.generate_sop(process_id, executions)
  rescue
    e ->
      Logger.error("[ProcessRoutes] generate_sop error: #{Exception.message(e)}")
      {:error, :internal_error}
  catch
    :exit, _ -> {:error, :service_unavailable}
  end

  defp safe_org_health(org_config) do
    OrgEvolution.org_health(org_config)
  rescue
    e ->
      Logger.error("[ProcessRoutes] org_health error: #{Exception.message(e)}")
      {:error, :internal_error}
  catch
    :exit, _ -> {:error, :service_unavailable}
  end

  # ══════════════════════════════════════════════════════════════════════
  # Key Normalization Helpers
  # ══════════════════════════════════════════════════════════════════════

  # Normalize a fingerprint map received via JSON (string keys) to the
  # atom-keyed format the Fingerprint module expects.
  defp normalize_fingerprint_map(fp) when is_map(fp) do
    fp
    |> Enum.map(fn
      {k, v} when is_binary(k) and k in ~w(id process_type pattern_hash signature sample_size) ->
        {String.to_atom(k), v}

      {k, v} when is_binary(k) and k == "extracted_at" ->
        # Parse ISO8601 string back to DateTime
        parsed =
          case v do
            s when is_binary(s) ->
              case DateTime.from_iso8601(s) do
                {:ok, dt, _} -> dt
                _ -> nil
              end

            _ -> nil
          end

        {:extracted_at, parsed}

      {k, v} when is_binary(k) and k in ~w(signal_vector metrics) ->
        {String.to_atom(k), normalize_inner_map(v)}

      {_k, v} ->
        {nil, v}
    end)
    |> Enum.reject(fn {k, _} -> is_nil(k) end)
    |> Map.new()
  end

  defp normalize_fingerprint_map(_), do: %{}

  defp normalize_inner_map(m) when is_map(m) do
    m
    |> Enum.map(fn {k, v} ->
      key = if is_binary(k), do: String.to_atom(k), else: k
      {key, v}
    end)
    |> Map.new()
  end

  defp normalize_inner_map(other), do: other

  # Atomize top-level keys in a map for OrgEvolution (which expects
  # atom keys like :teams, :roles, :workflows, etc.)
  defp atomize_keys(map, allowed_keys) when is_map(map) do
    map
    |> Enum.map(fn {k, v} ->
      atom =
        if is_binary(k) and k in allowed_keys do
          String.to_atom(k)
        else
          k
        end

      {atom, v}
    end)
    |> Map.new()
  end

  defp atomize_keys(other, _allowed_keys), do: other
end
