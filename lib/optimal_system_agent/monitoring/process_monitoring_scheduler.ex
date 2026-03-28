defmodule OptimalSystemAgent.Monitoring.ProcessMonitoringScheduler do
  @moduledoc """
  Autonomous process monitoring scheduler (GenServer).

  Runs on a configurable interval (default: 1 hour) to:
  1. Fetch the most recent event log from pm4py-rust
  2. Compute drift metrics against the baseline stored in ETS
  3. Emit :process_drift_detected system events when drift is detected
  4. Update the ETS baseline after each check

  ETS table: :osa_process_monitoring
  Armstrong compliance: all blocking ops have bounded timeouts.
  WvdA soundness: bounded loop via Process.send_after (no busy-wait).
  """
  use GenServer
  require Logger

  @table :osa_process_monitoring
  @check_interval_ms 60 * 60 * 1000
  # WvdA: 25s budget for pm4py round-trip (matches conformance tool limit)
  @fetch_timeout_ms 25_000
  @drift_threshold 0.15

  # ── Public API ─────────────────────────────────────────────────────────────

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Trigger an immediate check (useful for testing and manual invocation)."
  def check_now do
    GenServer.cast(__MODULE__, :check_now)
  end

  @doc "Retrieve the current baseline metrics from ETS."
  def get_baseline do
    case :ets.lookup(@table, :baseline) do
      [{:baseline, metrics}] -> {:ok, metrics}
      [] -> {:error, :no_baseline}
    end
  end

  # ── GenServer callbacks ────────────────────────────────────────────────────

  @impl true
  def init(_opts) do
    ensure_table()
    schedule_check()
    {:ok, %{last_check_at: nil, consecutive_failures: 0}}
  end

  @impl true
  def handle_cast(:check_now, state) do
    new_state = run_check(state)
    {:noreply, new_state}
  end

  @impl true
  def handle_info(:scheduled_check, state) do
    new_state = run_check(state)
    schedule_check()
    {:noreply, new_state}
  end

  # ── Private ────────────────────────────────────────────────────────────────

  defp run_check(state) do
    Logger.debug("[ProcessMonitoringScheduler] Running scheduled process check")

    task = Task.async(fn -> fetch_process_metrics() end)

    case Task.yield(task, @fetch_timeout_ms) || Task.shutdown(task) do
      {:ok, {:ok, metrics}} ->
        detect_and_emit_drift(metrics)
        update_baseline(metrics)
        %{state | last_check_at: DateTime.utc_now(), consecutive_failures: 0}

      {:ok, {:error, reason}} ->
        Logger.warning("[ProcessMonitoringScheduler] Fetch failed: #{inspect(reason)}")
        %{state | consecutive_failures: state.consecutive_failures + 1}

      nil ->
        Logger.warning("[ProcessMonitoringScheduler] Fetch timed out after #{@fetch_timeout_ms}ms")
        %{state | consecutive_failures: state.consecutive_failures + 1}
    end
  end

  defp fetch_process_metrics do
    url = pm4py_url() <> "/api/process-mining/statistics"

    case :httpc.request(:post, {String.to_charlist(url), [], ~c"application/json", ~c"{}"}, [{:timeout, @fetch_timeout_ms}], []) do
      {:ok, {{_, 200, _}, _headers, body}} ->
        case Jason.decode(List.to_string(body)) do
          {:ok, data} -> {:ok, data}
          err -> {:error, {:json_decode, err}}
        end

      {:ok, {{_, status, _}, _, _}} ->
        {:error, {:http_status, status}}

      {:error, reason} ->
        {:error, {:http_error, reason}}
    end
  rescue
    e -> {:error, {:exception, Exception.message(e)}}
  end

  defp detect_and_emit_drift(new_metrics) do
    case get_baseline() do
      {:ok, baseline} ->
        drift = compute_drift(baseline, new_metrics)

        if drift > @drift_threshold do
          Logger.info("[ProcessMonitoringScheduler] Drift detected: #{Float.round(drift, 3)}")

          OptimalSystemAgent.Events.Bus.emit(:system_event, %{
            type: :process_drift_detected,
            drift_score: drift,
            threshold: @drift_threshold,
            detected_at: DateTime.utc_now(),
            baseline_snapshot: baseline,
            current_snapshot: new_metrics
          })
        end

      {:error, :no_baseline} ->
        Logger.debug("[ProcessMonitoringScheduler] No baseline yet — skipping drift check")
    end
  end

  defp compute_drift(baseline, current) do
    baseline_variants = Map.get(baseline, "variant_count", 0)
    current_variants = Map.get(current, "variant_count", 0)

    if baseline_variants == 0 do
      0.0
    else
      abs(current_variants - baseline_variants) / max(baseline_variants, 1)
    end
  end

  defp update_baseline(metrics) do
    :ets.insert(@table, {:baseline, metrics})
  end

  defp ensure_table do
    if :ets.whereis(@table) == :undefined do
      :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])
    end
  end

  defp schedule_check do
    Process.send_after(self(), :scheduled_check, @check_interval_ms)
  end

  defp pm4py_url do
    System.get_env("PM4PY_RUST_URL", "http://localhost:8090")
  end
end
