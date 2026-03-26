defmodule OptimalSystemAgent.Board.ConwayLittleMonitor do
  @moduledoc """
  Conway's Law + Little's Law Monitor — routes structural vs operational violations.

  ## Routing Logic (WvdA + Armstrong)

  **Conway violation** (conwayScore > 0.4):
    - Org boundary consuming >40% of cycle time
    - Structural problem: org chart IS the process topology
    - Cannot be auto-healed — requires board chair org restructuring decision
    - Routes to: Events.Bus emit :board_escalation
    - NOT passed to HealingBridge or ReflexArcs

  **Little's Law violation** (actual WIP > 1.5x predicted WIP = λW):
    - Unbounded queue growth — WvdA boundedness property violated
    - Operational problem: transient overload
    - CAN be auto-healed: reduce arrival rate, prioritize completions
    - Routes to: Events.Bus emit :conformance_violation → HealingBridge → ReflexArcs

  ## WvdA Soundness

  - conwayScore bounded [0.0, 1.0] by construction (boundary/total ≤ 1.0)
  - stabilityRatio guarded: IF(λ > 0, WIP/λW, 1.0) — no division by zero
  - Periodic check bounded: 30min interval, resets AFTER run (no overlap)
  - Max 10s query timeout for L2 Oxigraph reads

  ## Armstrong Fault Tolerance

  - GenServer registered as `__MODULE__` — restartable by supervisor
  - Conway violations route to board escalation — escalate, never auto-heal
  - Little's Law critical routes to healing — transient, system handles
  - No shared mutable state — all via Events.Bus message passing

  ## Registration

  Added as :permanent child in OptimalSystemAgent.Board.Supervisor.
  """

  use GenServer
  require Logger

  alias OptimalSystemAgent.Events.Bus
  alias OptimalSystemAgent.Observability.Telemetry

  @conway_threshold 0.4
  @littles_law_critical 1.5
  @check_interval_ms 30 * 60 * 1000
  @query_timeout_ms 10_000
  @oxigraph_url Application.compile_env(:optimal_system_agent, :oxigraph_url, "http://localhost:7878")
  @ets_table :osa_conway_little_status

  # Public API

  @doc "Start the ConwayLittleMonitor GenServer."
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Current monitor status — Conway violations and Little's Law alerts.

  Returns map with:
  - `:last_check` — DateTime of last check
  - `:conway_violations` — list of %{department, score, message}
  - `:littles_law_alerts` — list of %{department, stability_ratio, message}
  - `:escalations_sent` — count of :board_escalation events emitted
  - `:healings_triggered` — count of :conformance_violation events emitted
  """
  @spec monitor_status() :: map()
  def monitor_status do
    GenServer.call(__MODULE__, :status, @query_timeout_ms)
  catch
    :exit, {:timeout, _} ->
      Logger.error("[ConwayLittleMonitor] status query timeout")
      %{error: :timeout}
  end

  # GenServer callbacks

  @impl true
  def init(_opts) do
    if :ets.whereis(@ets_table) == :undefined do
      :ets.new(@ets_table, [:named_table, :public, :set])
    end

    Logger.info("[ConwayLittleMonitor] Starting — check interval #{@check_interval_ms}ms")

    # Register handler for system_event — filter for :l2_materialized inside callback
    Bus.register_handler(:system_event, fn raw ->
      payload = Map.get(raw, :data, raw)
      event = Map.get(payload, :event)

      if event == :l2_materialized do
        GenServer.cast(__MODULE__, :l2_materialized)
      end
    end)

    # Schedule first check
    timer = schedule_check()

    state = %{
      timer: timer,
      last_check: nil,
      conway_violations: [],
      littles_law_alerts: [],
      escalations_sent: 0,
      healings_triggered: 0
    }

    {:ok, state}
  end

  @impl true
  def handle_call(:status, _from, state) do
    status = %{
      last_check: state.last_check,
      conway_violations: state.conway_violations,
      littles_law_alerts: state.littles_law_alerts,
      escalations_sent: state.escalations_sent,
      healings_triggered: state.healings_triggered
    }

    {:reply, status, state}
  end

  @impl true
  def handle_info(:check, state) do
    Logger.debug("[ConwayLittleMonitor] Running periodic check")

    {conway_violations, littles_law_alerts, escalations, healings} = run_check()

    # Update ETS for fast reads
    :ets.insert(@ets_table, {:status, %{
      last_check: DateTime.utc_now(),
      conway_violations: conway_violations,
      littles_law_alerts: littles_law_alerts
    }})

    new_state = %{state |
      last_check: DateTime.utc_now(),
      conway_violations: conway_violations,
      littles_law_alerts: littles_law_alerts,
      escalations_sent: state.escalations_sent + escalations,
      healings_triggered: state.healings_triggered + healings,
      timer: schedule_check()
    }

    {:noreply, new_state}
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  @impl true
  def handle_cast(:l2_materialized, state) do
    # L2 just refreshed — run check immediately (cancel pending timer, run now)
    if state.timer do
      Process.cancel_timer(state.timer)
    end

    send(self(), :check)

    {:noreply, %{state | timer: nil}}
  end

  # Private

  defp schedule_check do
    Process.send_after(self(), :check, @check_interval_ms)
  end

  defp run_check do
    {:ok, span} = Telemetry.start_span("board.conway_check", %{
      "component" => "conway_little_monitor"
    })

    case query_l2_metrics() do
      {:ok, metrics} ->
        conway_violations = Enum.filter(metrics, fn m ->
          Map.get(m, :conway_violation, false) ||
            (Map.get(m, :conway_score) || 0.0) > @conway_threshold
        end)

        littles_law_alerts = Enum.filter(metrics, fn m ->
          Map.get(m, :stability_ratio, 1.0) > @littles_law_critical
        end)

        # Route Conway violations to board escalation (NOT healing)
        escalations = Enum.count(conway_violations, fn violation ->
          emit_board_escalation(violation)
          true
        end)

        # Route Little's Law criticals to healing
        healings = Enum.count(littles_law_alerts, fn alert ->
          emit_littles_law_healing(alert)
          true
        end)

        Telemetry.end_span(
          Map.merge(span, %{
            "attributes" => Map.merge(span["attributes"], %{
              "conway_violation_count" => length(conway_violations),
              "littles_law_alert_count" => length(littles_law_alerts),
              "escalations_emitted" => escalations,
              "healings_triggered" => healings
            })
          }),
          :ok
        )

        {conway_violations, littles_law_alerts, escalations, healings}

      {:error, reason} ->
        Logger.warning("[ConwayLittleMonitor] L2 query failed: #{inspect(reason)}")

        Telemetry.end_span(
          Map.merge(span, %{
            "attributes" => Map.merge(span["attributes"], %{
              "conway_violation_count" => 0,
              "littles_law_alert_count" => 0,
              "escalations_emitted" => 0,
              "healings_triggered" => 0
            })
          }),
          :error,
          inspect(reason)
        )

        {[], [], 0, 0}
    end
  end

  defp query_l2_metrics do
    sparql = """
    PREFIX bos: <http://businessos.local/ontology#>
    SELECT ?dept ?conwayViolation ?conwayScore ?stabilityRatio ?wipCount ?littlesLawWip
    WHERE {
      ?indicator a bos:OrgHealthIndicator ;
                 bos:department ?dept .
      OPTIONAL { ?indicator bos:conwayViolation ?conwayViolation }
      OPTIONAL { ?indicator bos:conwayScore ?conwayScore }
      OPTIONAL { ?indicator bos:queueStabilityRatio ?stabilityRatio }
      OPTIONAL { ?indicator bos:wipCount ?wipCount }
      OPTIONAL { ?indicator bos:littlesLawWip ?littlesLawWip }
    }
    """

    endpoint = "#{@oxigraph_url}/query"

    case Req.post(endpoint,
      body: sparql,
      headers: [{"content-type", "application/sparql-query"}, {"accept", "application/sparql-results+json"}],
      receive_timeout: @query_timeout_ms
    ) do
      {:ok, %{status: 200, body: body}} ->
        metrics = parse_sparql_results(body)
        {:ok, metrics}

      {:ok, %{status: status, body: body}} ->
        {:error, {:http, status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp parse_sparql_results(%{"results" => %{"bindings" => bindings}}) do
    Enum.map(bindings, fn binding ->
      %{
        department: get_binding_value(binding, "dept"),
        conway_violation: get_binding_bool(binding, "conwayViolation"),
        conway_score: get_binding_float(binding, "conwayScore"),
        stability_ratio: get_binding_float(binding, "stabilityRatio"),
        wip_count: get_binding_float(binding, "wipCount"),
        littles_law_wip: get_binding_float(binding, "littlesLawWip")
      }
    end)
  end

  defp parse_sparql_results(_), do: []

  defp get_binding_value(binding, key) do
    case Map.get(binding, key) do
      %{"value" => value} -> value
      _ -> nil
    end
  end

  defp get_binding_float(binding, key) do
    case get_binding_value(binding, key) do
      nil -> nil
      str ->
        case Float.parse(str) do
          {f, _} -> f
          :error -> nil
        end
    end
  end

  defp get_binding_bool(binding, key) do
    case get_binding_value(binding, key) do
      "true" -> true
      "1" -> true
      _ -> false
    end
  end

  defp emit_board_escalation(%{department: dept, conway_score: score} = _violation) do
    pct = if score, do: round(score * 100), else: "?"

    Logger.info("[ConwayLittleMonitor] Conway violation in #{dept} (score=#{score}), escalating to board")

    Bus.emit(:system_event, %{
      event: :board_escalation,
      process_id: dept,
      escalation_type: :conway_violation,
      conway_score: score,
      message: "Org boundary consuming #{pct}% of cycle time in #{dept}. Requires org restructuring decision.",
      timestamp: DateTime.utc_now()
    }, source: "conway_little_monitor")
  end

  defp emit_littles_law_healing(%{department: dept, stability_ratio: ratio, wip_count: wip, littles_law_wip: predicted} = _alert) do
    Logger.info("[ConwayLittleMonitor] Little's Law violation in #{dept} (ratio=#{ratio}), triggering healing")

    Bus.emit(:system_event, %{
      event: :conformance_violation,
      process_id: dept,
      violation_type: :littles_law,
      stability_ratio: ratio,
      actual_wip: wip,
      predicted_wip: predicted,
      message: "WIP #{wip} exceeds predicted #{predicted} by #{Float.round((ratio - 1.0) * 100, 1)}% in #{dept}.",
      timestamp: DateTime.utc_now()
    }, source: "conway_little_monitor")
  end
end
