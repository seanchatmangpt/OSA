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
  import Plug.Conn
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
        send_json_error(conn, 400, "Missing or empty 'events' array")

      true ->
        opts = [process_type: process_type]

        case safe_extract_fingerprint(events, opts) do
          {:ok, fingerprint} ->
            send_json(conn, 200, %{fingerprint: fingerprint})

          {:error, reason} ->
            send_json_error(conn, 400, "Failed to extract fingerprint: #{inspect(reason)}")

          {:service_unavailable, reason} ->
            send_json_error(conn, 503, "Service unavailable: #{inspect(reason)}")
        end
    end
  end

  # ── GET /fingerprint/list — list all stored fingerprints ──────────────

  get "/fingerprint/list" do
    case safe_list_fingerprints() do
      {:ok, fingerprints} ->
        send_json(conn, 200, %{fingerprints: fingerprints, count: length(fingerprints)})

      {:service_unavailable, reason} ->
        send_json_error(conn, 503, "Service unavailable: #{inspect(reason)}")
    end
  end

  # ── GET /fingerprint/:id — retrieve stored fingerprint ───────────────

  get "/fingerprint/:id" do
    case safe_get_fingerprint(id) do
      {:ok, fingerprint} ->
        send_json(conn, 200, %{fingerprint: fingerprint})

      :not_found ->
        send_json_error(conn, 404, "Fingerprint not found")

      {:service_unavailable, reason} ->
        send_json_error(conn, 503, "Service unavailable: #{inspect(reason)}")
    end
  end

  # ── POST /fingerprint/compare — compare two fingerprints ─────────────

  post "/fingerprint/compare" do
    params = conn.body_params
    fp_a = Map.get(params, "fingerprint_a")
    fp_b = Map.get(params, "fingerprint_b")

    cond do
      not is_map(fp_a) or map_size(fp_a) == 0 ->
        send_json_error(conn, 400, "Missing or invalid 'fingerprint_a'")

      not is_map(fp_b) or map_size(fp_b) == 0 ->
        send_json_error(conn, 400, "Missing or invalid 'fingerprint_b'")

      true ->
        fp_a_normalized = normalize_fingerprint_map(fp_a)
        fp_b_normalized = normalize_fingerprint_map(fp_b)

        case safe_compare_fingerprints(fp_a_normalized, fp_b_normalized) do
          {:ok, comparison} ->
            send_json(conn, 200, %{comparison: comparison})

          {:error, reason} ->
            send_json_error(conn, 400, "Failed to compare fingerprints: #{inspect(reason)}")

          {:service_unavailable, reason} ->
            send_json_error(conn, 503, "Service unavailable: #{inspect(reason)}")
        end
    end
  end

  # ── POST /fingerprint/evolution — track fingerprint evolution ────────

  post "/fingerprint/evolution" do
    params = conn.body_params
    fingerprints = Map.get(params, "fingerprints", [])

    cond do
      not is_list(fingerprints) or fingerprints == [] ->
        send_json_error(conn, 400, "Missing or empty 'fingerprints' array")

      true ->
        normalized = Enum.map(fingerprints, &normalize_fingerprint_map/1)

        case safe_evolution_track(normalized) do
          {:ok, evolution} ->
            send_json(conn, 200, %{evolution: evolution})

          {:error, reason} ->
            send_json_error(conn, 400, "Failed to track evolution: #{inspect(reason)}")

          {:service_unavailable, reason} ->
            send_json_error(conn, 503, "Service unavailable: #{inspect(reason)}")
        end
    end
  end

  # ── GET /fingerprint/benchmark/:industry — industry benchmark ────────

  get "/fingerprint/benchmark/:industry" do
    conn = Plug.Conn.fetch_query_params(conn)
    fingerprint_id = conn.query_params["fingerprint_id"]

    if is_nil(fingerprint_id) do
      send_json_error(conn, 400, "Query parameter 'fingerprint_id' is required")
    else
      case safe_get_fingerprint(fingerprint_id) do
        {:ok, fingerprint} ->
          case safe_industry_benchmark(fingerprint, industry) do
            {:ok, benchmark} ->
              send_json(conn, 200, %{benchmark: benchmark})

            {:error, reason} ->
              send_json_error(conn, 400, "Benchmark failed: #{inspect(reason)}")

            {:service_unavailable, reason} ->
              send_json_error(conn, 503, "Service unavailable: #{inspect(reason)}")
          end

        :not_found ->
          send_json_error(conn, 404, "Fingerprint not found")

        {:service_unavailable, reason} ->
          send_json_error(conn, 503, "Service unavailable: #{inspect(reason)}")
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
        send_json_error(conn, 400, "Missing or empty 'process_id'")

      not is_map(metrics) or map_size(metrics) == 0 ->
        send_json_error(conn, 400, "Missing or empty 'metrics' map")

      true ->
        normalized_metrics =
          metrics
          |> Enum.map(fn {k, v} ->
            key = if is_binary(k), do: String.to_atom(k), else: k
            {key, v}
          end)
          |> Map.new()

        case safe_record_snapshot(process_id, normalized_metrics) do
          :ok ->
            send_json(conn, 200, %{
              process_id: process_id,
              status: "recorded",
              recorded_at: DateTime.utc_now() |> DateTime.to_iso8601()
            })

          {:error, reason} ->
            send_json_error(conn, 500, "Failed to record snapshot: #{inspect(reason)}")

          {:service_unavailable, reason} ->
            send_json_error(conn, 503, "Service unavailable: #{inspect(reason)}")
        end
    end
  end

  # ── GET /temporal/velocity/:process_id — process velocity ───────────

  get "/temporal/velocity/:process_id" do
    case safe_process_velocity(process_id) do
      {:ok, velocity} ->
        send_json(conn, 200, %{process_id: process_id, velocity: velocity})

      {:service_unavailable, reason} ->
        send_json_error(conn, 503, "Service unavailable: #{inspect(reason)}")
    end
  end

  # ── GET /temporal/predict/:process_id — predict future state ─────────

  get "/temporal/predict/:process_id" do
    conn = Plug.Conn.fetch_query_params(conn)

    weeks_ahead =
      conn.query_params
      |> Map.get("weeks_ahead", "4")
      |> parse_positive_int(4)

    case safe_predict_state(process_id, weeks_ahead) do
      {:ok, prediction} ->
        send_json(conn, 200, %{process_id: process_id, prediction: prediction})

      {:service_unavailable, reason} ->
        send_json_error(conn, 503, "Service unavailable: #{inspect(reason)}")
    end
  end

  # ── GET /temporal/early-warning/:process_id — early warnings ─────────

  get "/temporal/early-warning/:process_id" do
    case safe_early_warning(process_id) do
      {:ok, warning} ->
        send_json(conn, 200, %{process_id: process_id, early_warning: warning})

      {:service_unavailable, reason} ->
        send_json_error(conn, 503, "Service unavailable: #{inspect(reason)}")
    end
  end

  # ── GET /temporal/stagnation/:process_id — stagnation detection ─────

  get "/temporal/stagnation/:process_id" do
    case safe_stagnation_detect(process_id) do
      {:ok, stagnation} ->
        send_json(conn, 200, %{process_id: process_id, stagnation: stagnation})

      {:service_unavailable, reason} ->
        send_json_error(conn, 503, "Service unavailable: #{inspect(reason)}")
    end
  end

  # ══════════════════════════════════════════════════════════════════════
  # Org Evolution Endpoints
  # ══════════════════════════════════════════════════════════════════════

  # ── POST /org/drift — detect organizational drift ────────────────────

  post "/org/drift" do
    params = conn.body_params
    org_config = Map.get(params, "org_config", params)

    if not is_map(org_config) or map_size(org_config) == 0 do
      send_json_error(conn, 400, "Missing or empty 'org_config'")
    else
      normalized_org_config = atomize_keys(org_config, ~w(teams roles workflows execution_data))

      case safe_detect_drift(normalized_org_config) do
        {:ok, drift} ->
          send_json(conn, 200, %{drift: drift})

        {:error, reason} ->
          Logger.warning("[ProcessRoutes] detect_drift error: #{inspect(reason)}")
          send_json_error(conn, 500, "Drift detection failed: #{inspect(reason)}")

        {:service_unavailable, reason} ->
          send_json_error(conn, 503, "Service unavailable: #{inspect(reason)}")
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
        send_json_error(conn, 400, "Missing or empty 'org_config'")

      not is_map(drift_analysis) ->
        send_json_error(conn, 400, "Invalid 'drift_analysis'")

      true ->
        normalized_org_config = atomize_keys(org_config, ~w(teams roles workflows execution_data))
        normalized_drift = atomize_keys(drift_analysis, ~w(drifts drift_score recommendation analyzed_at))

        case safe_propose_mutation(normalized_org_config, normalized_drift) do
          {:ok, result} ->
            send_json(conn, 200, %{mutation: result})

          {:error, reason} ->
            Logger.warning("[ProcessRoutes] propose_mutation error: #{inspect(reason)}")
            send_json_error(conn, 500, "Mutation proposal failed: #{inspect(reason)}")

          {:service_unavailable, reason} ->
            send_json_error(conn, 503, "Service unavailable: #{inspect(reason)}")
        end
    end
  end

  # ── POST /org/optimize/:workflow_id — optimize workflow ──────────────

  post "/org/optimize/:workflow_id" do
    params = conn.body_params
    execution_history = Map.get(params, "execution_history", [])

    if not is_list(execution_history) do
      send_json_error(conn, 400, "'execution_history' must be an array")
    else
      case safe_optimize_workflow(workflow_id, execution_history) do
        {:ok, result} ->
          send_json(conn, 200, %{optimization: result})

        {:error, reason} ->
          Logger.warning("[ProcessRoutes] optimize_workflow error: #{inspect(reason)}")
          send_json_error(conn, 500, "Workflow optimization failed: #{inspect(reason)}")

        {:service_unavailable, reason} ->
          send_json_error(conn, 503, "Service unavailable: #{inspect(reason)}")
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
        send_json_error(conn, 400, "Missing or empty 'process_id'")

      not is_list(executions) ->
        send_json_error(conn, 400, "'executions' must be an array")

      true ->
        case safe_generate_sop(process_id, executions) do
          {:ok, sop} ->
            send_json(conn, 200, %{sop: sop})

          {:error, reason} ->
            Logger.warning("[ProcessRoutes] generate_sop error: #{inspect(reason)}")
            send_json_error(conn, 500, "SOP generation failed: #{inspect(reason)}")

          {:service_unavailable, reason} ->
            send_json_error(conn, 503, "Service unavailable: #{inspect(reason)}")
        end
    end
  end

  # ── GET /org/health — org health assessment ──────────────────────────

  get "/org/health" do
    org_config = %{}

    case safe_org_health(org_config) do
      {:ok, health} ->
        send_json(conn, 200, %{health: health})

      {:error, reason} ->
        Logger.warning("[ProcessRoutes] org_health error: #{inspect(reason)}")
        send_json_error(conn, 500, "Health assessment failed: #{inspect(reason)}")

      {:service_unavailable, reason} ->
        send_json_error(conn, 503, "Service unavailable: #{inspect(reason)}")
    end
  end

  # ── catch-all ────────────────────────────────────────────────────────

  match _ do
    send_json_error(conn, 404, "Process intelligence endpoint not found")
  end

  # ══════════════════════════════════════════════════════════════════════
  # JSON Response Helpers (local — no dependency on Shared module)
  # ══════════════════════════════════════════════════════════════════════

  defp send_json(conn, status, data) do
    body = Jason.encode!(data)

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, body)
  end

  defp send_json_error(conn, status, message) do
    body = Jason.encode!(%{error: message})

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, body)
  end

  # ══════════════════════════════════════════════════════════════════════
  # Fingerprint Safe Wrappers
  # ══════════════════════════════════════════════════════════════════════

  defp safe_extract_fingerprint(events, opts) do
    result = Fingerprint.extract_fingerprint(events, opts)
    handle_result(result)
  rescue
    e ->
      Logger.error("[ProcessRoutes] extract_fingerprint error: #{Exception.message(e)}")
      {:error, "Internal error: #{Exception.message(e)}"}
  catch
    :exit, reason ->
      Logger.error("[ProcessRoutes] extract_fingerprint exit: #{inspect(reason)}")
      {:service_unavailable, "Service unavailable: #{inspect(reason)}"}
  end

  defp safe_get_fingerprint(id) do
    result = Fingerprint.get_fingerprint(id)

    case result do
      nil -> :not_found
      fingerprint -> {:ok, fingerprint}
    end
  rescue
    e ->
      Logger.error("[ProcessRoutes] get_fingerprint error: #{Exception.message(e)}")
      {:service_unavailable, "Service unavailable: #{Exception.message(e)}"}
  catch
    :exit, reason ->
      Logger.error("[ProcessRoutes] get_fingerprint exit: #{inspect(reason)}")
      {:service_unavailable, "Service unavailable: #{inspect(reason)}"}
  end

  defp safe_list_fingerprints do
    fingerprints = Fingerprint.list_all()
    {:ok, fingerprints}
  rescue
    e ->
      Logger.error("[ProcessRoutes] list_fingerprints error: #{Exception.message(e)}")
      {:service_unavailable, "Service unavailable: #{Exception.message(e)}"}
  catch
    :exit, reason ->
      Logger.error("[ProcessRoutes] list_fingerprints exit: #{inspect(reason)}")
      {:service_unavailable, "Service unavailable: #{inspect(reason)}"}
  end

  defp safe_compare_fingerprints(fp_a, fp_b) do
    result = Fingerprint.compare_fingerprints(fp_a, fp_b)
    handle_result(result)
  rescue
    e ->
      Logger.error("[ProcessRoutes] compare_fingerprints error: #{Exception.message(e)}")
      {:error, "Internal error: #{Exception.message(e)}"}
  catch
    :exit, reason ->
      Logger.error("[ProcessRoutes] compare_fingerprints exit: #{inspect(reason)}")
      {:service_unavailable, "Service unavailable: #{inspect(reason)}"}
  end

  defp safe_evolution_track(fingerprints) do
    result = Fingerprint.evolution_track(fingerprints)
    handle_result(result)
  rescue
    e ->
      Logger.error("[ProcessRoutes] evolution_track error: #{Exception.message(e)}")
      {:error, "Internal error: #{Exception.message(e)}"}
  catch
    :exit, reason ->
      Logger.error("[ProcessRoutes] evolution_track exit: #{inspect(reason)}")
      {:service_unavailable, "Service unavailable: #{inspect(reason)}"}
  end

  defp safe_industry_benchmark(fingerprint, industry) do
    result = Fingerprint.industry_benchmark(fingerprint, industry)
    handle_result(result)
  rescue
    e ->
      Logger.error("[ProcessRoutes] industry_benchmark error: #{Exception.message(e)}")
      {:error, "Internal error: #{Exception.message(e)}"}
  catch
    :exit, reason ->
      Logger.error("[ProcessRoutes] industry_benchmark exit: #{inspect(reason)}")
      {:service_unavailable, "Service unavailable: #{inspect(reason)}"}
  end

  # ══════════════════════════════════════════════════════════════════════
  # Temporal Safe Wrappers
  # ══════════════════════════════════════════════════════════════════════

  defp safe_record_snapshot(process_id, metrics) do
    result = ProcessMining.record_snapshot(process_id, metrics)

    case result do
      :ok -> :ok
      other -> handle_result(other)
    end
  rescue
    e ->
      Logger.error("[ProcessRoutes] record_snapshot error: #{Exception.message(e)}")
      {:error, "Internal error: #{Exception.message(e)}"}
  catch
    :exit, reason ->
      Logger.error("[ProcessRoutes] record_snapshot exit: #{inspect(reason)}")
      {:service_unavailable, "Service unavailable: #{inspect(reason)}"}
  end

  defp safe_process_velocity(process_id) do
    result = ProcessMining.process_velocity(process_id)
    handle_result(result)
  rescue
    e ->
      Logger.error("[ProcessRoutes] process_velocity error: #{Exception.message(e)}")
      {:service_unavailable, "Service unavailable: #{Exception.message(e)}"}
  catch
    :exit, reason ->
      Logger.error("[ProcessRoutes] process_velocity exit: #{inspect(reason)}")
      {:service_unavailable, "Service unavailable: #{inspect(reason)}"}
  end

  defp safe_predict_state(process_id, weeks_ahead) do
    result = ProcessMining.predict_state(process_id, weeks_ahead)
    handle_result(result)
  rescue
    e ->
      Logger.error("[ProcessRoutes] predict_state error: #{Exception.message(e)}")
      {:service_unavailable, "Service unavailable: #{Exception.message(e)}"}
  catch
    :exit, reason ->
      Logger.error("[ProcessRoutes] predict_state exit: #{inspect(reason)}")
      {:service_unavailable, "Service unavailable: #{inspect(reason)}"}
  end

  defp safe_early_warning(process_id) do
    result = ProcessMining.early_warning(process_id)
    handle_result(result)
  rescue
    e ->
      Logger.error("[ProcessRoutes] early_warning error: #{Exception.message(e)}")
      {:service_unavailable, "Service unavailable: #{Exception.message(e)}"}
  catch
    :exit, reason ->
      Logger.error("[ProcessRoutes] early_warning exit: #{inspect(reason)}")
      {:service_unavailable, "Service unavailable: #{inspect(reason)}"}
  end

  defp safe_stagnation_detect(process_id) do
    result = ProcessMining.stagnation_detect(process_id)
    handle_result(result)
  rescue
    e ->
      Logger.error("[ProcessRoutes] stagnation_detect error: #{Exception.message(e)}")
      {:service_unavailable, "Service unavailable: #{Exception.message(e)}"}
  catch
    :exit, reason ->
      Logger.error("[ProcessRoutes] stagnation_detect exit: #{inspect(reason)}")
      {:service_unavailable, "Service unavailable: #{inspect(reason)}"}
  end

  # ══════════════════════════════════════════════════════════════════════
  # OrgEvolution Safe Wrappers
  # ══════════════════════════════════════════════════════════════════════

  defp safe_detect_drift(org_config) do
    result = OrgEvolution.detect_drift(org_config)

    case result do
      drift when is_map(drift) -> {:ok, drift}
      other -> handle_result(other)
    end
  rescue
    e ->
      Logger.error("[ProcessRoutes] detect_drift error: #{Exception.message(e)}")
      {:error, "Internal error: #{Exception.message(e)}"}
  catch
    :exit, reason ->
      Logger.error("[ProcessRoutes] detect_drift exit: #{inspect(reason)}")
      {:service_unavailable, "Service unavailable: #{inspect(reason)}"}
  end

  defp safe_propose_mutation(org_config, drift_analysis) do
    result = OrgEvolution.propose_mutation(org_config, drift_analysis)

    case result do
      mutation when is_map(mutation) -> {:ok, mutation}
      other -> handle_result(other)
    end
  rescue
    e ->
      Logger.error("[ProcessRoutes] propose_mutation error: #{Exception.message(e)}")
      {:error, "Internal error: #{Exception.message(e)}"}
  catch
    :exit, reason ->
      Logger.error("[ProcessRoutes] propose_mutation exit: #{inspect(reason)}")
      {:service_unavailable, "Service unavailable: #{inspect(reason)}"}
  end

  defp safe_optimize_workflow(workflow_id, execution_history) do
    result = OrgEvolution.optimize_workflow(workflow_id, execution_history)

    case result do
      optimization when is_map(optimization) -> {:ok, optimization}
      other -> handle_result(other)
    end
  rescue
    e ->
      Logger.error("[ProcessRoutes] optimize_workflow error: #{Exception.message(e)}")
      {:error, "Internal error: #{Exception.message(e)}"}
  catch
    :exit, reason ->
      Logger.error("[ProcessRoutes] optimize_workflow exit: #{inspect(reason)}")
      {:service_unavailable, "Service unavailable: #{inspect(reason)}"}
  end

  defp safe_generate_sop(process_id, executions) do
    result = OrgEvolution.generate_sop(process_id, executions)

    case result do
      sop when is_map(sop) -> {:ok, sop}
      other -> handle_result(other)
    end
  rescue
    e ->
      Logger.error("[ProcessRoutes] generate_sop error: #{Exception.message(e)}")
      {:error, "Internal error: #{Exception.message(e)}"}
  catch
    :exit, reason ->
      Logger.error("[ProcessRoutes] generate_sop exit: #{inspect(reason)}")
      {:service_unavailable, "Service unavailable: #{inspect(reason)}"}
  end

  defp safe_org_health(org_config) do
    result = OrgEvolution.org_health(org_config)

    case result do
      health when is_map(health) -> {:ok, health}
      other -> handle_result(other)
    end
  rescue
    e ->
      Logger.error("[ProcessRoutes] org_health error: #{Exception.message(e)}")
      {:error, "Internal error: #{Exception.message(e)}"}
  catch
    :exit, reason ->
      Logger.error("[ProcessRoutes] org_health exit: #{inspect(reason)}")
      {:service_unavailable, "Service unavailable: #{inspect(reason)}"}
  end

  # ══════════════════════════════════════════════════════════════════════
  # Result Normalization
  # ══════════════════════════════════════════════════════════════════════

  # Normalizes the various return shapes from backend modules into tagged tuples.
  # Handles GenServer-style {:ok, ...}, {:error, ...}, raw maps, and unknown values.
  defp handle_result({:ok, data}) when is_map(data), do: {:ok, data}
  defp handle_result({:ok, data}) when is_list(data), do: {:ok, data}
  defp handle_result({:error, reason}), do: {:error, reason}
  defp handle_result(data) when is_map(data), do: {:ok, data}
  defp handle_result(data) when is_list(data), do: {:ok, data}
  defp handle_result(other), do: {:error, "Unexpected result: #{inspect(other)}"}

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

  # ══════════════════════════════════════════════════════════════════════
  # Shared Parsers
  # ══════════════════════════════════════════════════════════════════════

  defp parse_positive_int(nil, default), do: default

  defp parse_positive_int(val, default) when is_binary(val) do
    case Integer.parse(val) do
      {n, ""} when n > 0 -> n
      _ -> default
    end
  end

  defp parse_positive_int(_, default), do: default
end
