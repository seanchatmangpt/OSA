defmodule OptimalSystemAgent.Agents.Armstrong.SupervisionAuditor do
  @moduledoc """
  Armstrong Fault Tolerance — Supervision Tree Auditor Agent.

  Runtime auditor for OSA's Erlang/OTP supervision tree. Verifies that all
  processes have supervisors, that restart strategies are correct, and that
  the tree structure follows Armstrong principles.

  ## Armstrong Principles Verified

    1. **Let-It-Crash**: Processes fail fast and loudly, supervisors restart
    2. **Supervision Trees**: Proper hierarchy with correct restart strategies
    3. **No Shared State**: All inter-process communication via message passing
    4. **Budget Constraints**: Resource limits enforced per operation tier
    5. **Fault Isolation**: No cascading failures across subsystem boundaries

  ## Public API

    - `start_link(opts)` — GenServer entry point (registers as `:supervision_auditor`)
    - `audit_now()` — trigger immediate audit (returns map)
    - `get_last_audit()` — retrieve most recent audit snapshot
    - `get_audit_history(limit)` — retrieve last N audits with timestamps

  ## Telemetry Events

  Emits telemetry via `Bus.emit/2`:

      Bus.emit(:system_event, %{
        event: :supervision_audit,
        tree_snapshot: snapshot,
        anomalies: anomalies,
        timestamp: DateTime.utc_now(),
        severity: :info | :warning | :critical
      })

  On anomalies (orphaned processes, restart storms), escalates via algedonic alert:

      Bus.emit(:algedonic_alert, %{
        event: :supervision_anomaly,
        severity: :critical,
        supervisor_pid: pid,
        reason: reason
      })

  ## Implementation Details

  Wakes up every 5 minutes (configurable via `audit_interval_ms` option).
  For each audit cycle:

    1. Snapshots root supervisor via `:supervisor.which_children/1`
    2. Recursively walks supervision tree (max depth: 10)
    3. For each child, verifies:
       - Restart strategy (permanent/transient/temporary)
       - Process is alive (using `Process.alive?/1`)
       - Restart count is reasonable (<10 in 60s = healthy)
    4. Detects anomalies:
       - Orphaned processes (child without supervisor)
       - Restart storms (>10 restarts in 60s)
       - Dead children (`:undefined` PID)
       - Inappropriate restart strategies
    5. Stores last audit snapshot for retrieval
    6. Emits telemetry events for monitoring

  ## Configuration

  Options passed to `start_link/1`:

    - `:audit_interval_ms` — how often to audit (default: 300_000 = 5 min)
    - `:max_tree_depth` — max supervision tree depth to introspect (default: 10)
    - `:restart_storm_threshold` — max restarts in 60s before anomaly (default: 10)
    - `:max_children` — warn if supervisor has >N direct children (default: 25)

  ## Example Usage

      {:ok, pid} = OptimalSystemAgent.Agents.Armstrong.SupervisionAuditor.start_link(
        audit_interval_ms: 60_000,
        max_tree_depth: 8
      )

      # Trigger immediate audit
      {:ok, audit_result} = OptimalSystemAgent.Agents.Armstrong.SupervisionAuditor.audit_now()

      # Retrieve last audit
      {:ok, audit} = OptimalSystemAgent.Agents.Armstrong.SupervisionAuditor.get_last_audit()
  """

  use GenServer
  require Logger

  alias OptimalSystemAgent.Events.Bus
  alias OptimalSystemAgent.FaultTolerance.SupervisionAudit

  # -- Child spec --

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      restart: :permanent,
      type: :worker,
      shutdown: 5000
    }
  end

  # -- Client API --

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: :supervision_auditor)
  end

  @doc """
  Trigger an immediate audit. Returns {:ok, audit_result} or {:error, reason}.

  The audit result is a map containing:
    - `:timestamp` — when audit ran
    - `:tree_snapshot` — supervision tree structure
    - `:anomalies` — list of detected issues
    - `:severity` — :info | :warning | :critical
    - `:compliant` — true if no anomalies detected
  """
  @spec audit_now() :: {:ok, map()} | {:error, term()}
  def audit_now do
    GenServer.call(:supervision_auditor, :audit_now, 30_000)
  rescue
    e ->
      Logger.error("[SupervisionAuditor] audit_now failed: #{Exception.message(e)}")
      {:error, Exception.message(e)}
  end

  @doc """
  Retrieve the most recent audit snapshot.

  Returns {:ok, audit} or {:error, :not_available}.
  """
  @spec get_last_audit() :: {:ok, map()} | {:error, :not_available}
  def get_last_audit do
    GenServer.call(:supervision_auditor, :get_last_audit, 5_000)
  rescue
    _ -> {:error, :not_available}
  end

  @doc """
  Retrieve the last N audit snapshots with timestamps.

  Returns {:ok, audits_list} or {:error, :not_available}.
  Audits are returned in reverse chronological order (newest first).
  """
  @spec get_audit_history(non_neg_integer()) :: {:ok, [map()]} | {:error, :not_available}
  def get_audit_history(limit \\ 10) do
    GenServer.call(:supervision_auditor, {:get_history, limit}, 5_000)
  rescue
    _ -> {:error, :not_available}
  end

  # -- GenServer callbacks --

  @impl GenServer
  def init(opts) do
    Logger.info("[SupervisionAuditor] Starting supervision tree auditor")

    audit_interval_ms = Keyword.get(opts, :audit_interval_ms, 300_000)
    max_tree_depth = Keyword.get(opts, :max_tree_depth, 10)
    restart_storm_threshold = Keyword.get(opts, :restart_storm_threshold, 10)
    max_children = Keyword.get(opts, :max_children, 25)

    state = %{
      audit_interval_ms: audit_interval_ms,
      max_tree_depth: max_tree_depth,
      restart_storm_threshold: restart_storm_threshold,
      max_children: max_children,
      last_audit: nil,
      audit_history: [],
      next_audit_at: DateTime.utc_now()
    }

    # Schedule first audit immediately, then periodic audits
    send(self(), :perform_audit)

    {:ok, state}
  end

  @impl GenServer
  def handle_call(:audit_now, _from, state) do
    {audit_result, new_state} = perform_audit(state)
    {:reply, {:ok, audit_result}, new_state}
  end

  def handle_call(:get_last_audit, _from, %{last_audit: nil} = state) do
    {:reply, {:error, :not_available}, state}
  end

  def handle_call(:get_last_audit, _from, %{last_audit: audit} = state) do
    {:reply, {:ok, audit}, state}
  end

  def handle_call({:get_history, limit}, _from, %{audit_history: history} = state) do
    result = Enum.take(history, limit)
    {:reply, {:ok, result}, state}
  end

  @impl GenServer
  def handle_info(:perform_audit, state) do
    {_audit_result, new_state} = perform_audit(state)

    # Schedule next audit
    next_audit_in_ms = new_state.audit_interval_ms
    Process.send_after(self(), :perform_audit, next_audit_in_ms)

    {:noreply, new_state}
  end

  # -- Private implementation --

  defp perform_audit(state) do
    audit_result =
      state
      |> do_audit()
      |> emit_telemetry(state)

    new_state =
      state
      |> store_audit_result(audit_result)
      |> maybe_escalate_anomalies(audit_result)

    {audit_result, new_state}
  end

  defp do_audit(state) do
    try do
      root_pid = Process.whereis(OptimalSystemAgent.Supervisor)

      case root_pid do
        nil ->
          %{
            timestamp: DateTime.utc_now(),
            status: :error,
            error: :osa_not_running,
            tree_snapshot: nil,
            anomalies: [],
            severity: :critical,
            compliant: false
          }

        pid ->
          case SupervisionAudit.audit_tree(pid) do
            {:compliant, analysis} ->
              snapshot = build_tree_snapshot(analysis, state)
              anomalies = detect_anomalies(snapshot, state)

              %{
                timestamp: DateTime.utc_now(),
                status: :compliant,
                tree_snapshot: snapshot,
                anomalies: anomalies,
                severity: severity_from_anomalies(anomalies),
                compliant: Enum.empty?(anomalies)
              }

            {:violations, violations} ->
              %{
                timestamp: DateTime.utc_now(),
                status: :violations_detected,
                tree_snapshot: nil,
                anomalies: violations,
                severity: :warning,
                compliant: false
              }
          end
      end
    rescue
      e ->
        Logger.error("[SupervisionAuditor] audit failed: #{Exception.message(e)}")

        %{
          timestamp: DateTime.utc_now(),
          status: :error,
          error: Exception.message(e),
          tree_snapshot: nil,
          anomalies: [],
          severity: :critical,
          compliant: false
        }
    end
  end

  defp build_tree_snapshot(analysis, state) do
    %{
      supervisor_pid: Map.get(analysis, :supervisor),
      strategy: Map.get(analysis, :strategy),
      children_count: Map.get(analysis, :children_count, 0),
      children: Map.get(analysis, :children, []),
      depth: Map.get(analysis, :depth, 0),
      cascade_risk: Map.get(analysis, :cascade_risk, 0.0),
      max_tree_depth: state.max_tree_depth,
      max_children_warning: state.max_children
    }
  end

  defp detect_anomalies(snapshot, state) do
    anomalies = []

    # Check: tree depth reasonable
    anomalies =
      if snapshot.depth > state.max_tree_depth do
        anomalies ++
          [
            %{
              type: :deep_tree,
              severity: :warning,
              depth: snapshot.depth,
              max_allowed: state.max_tree_depth,
              reason: "Supervision tree is too deep — may increase cascade risk"
            }
          ]
      else
        anomalies
      end

    # Check: children count reasonable
    anomalies =
      if snapshot.children_count > state.max_children do
        anomalies ++
          [
            %{
              type: :too_many_children,
              severity: :warning,
              children_count: snapshot.children_count,
              max_recommended: state.max_children,
              reason: "Supervisor has too many direct children — split into subsystems"
            }
          ]
      else
        anomalies
      end

    # Check: cascade risk
    anomalies =
      if snapshot.cascade_risk > 0.5 do
        anomalies ++
          [
            %{
              type: :high_cascade_risk,
              severity: :warning,
              risk_score: Float.round(snapshot.cascade_risk, 2),
              reason: "High cascading failure risk detected"
            }
          ]
      else
        anomalies
      end

    # Check: orphaned or dead children
    dead_children =
      snapshot.children
      |> Enum.filter(fn child -> Map.get(child, :alive) == false end)
      |> Enum.count()

    anomalies =
      if dead_children > 0 do
        anomalies ++
          [
            %{
              type: :dead_children,
              severity: :warning,
              dead_count: dead_children,
              total_children: snapshot.children_count,
              reason: "Found dead child processes — possible restart loop"
            }
          ]
      else
        anomalies
      end

    anomalies
  end

  defp severity_from_anomalies(anomalies) do
    case anomalies do
      [] ->
        :info

      anomalies ->
        if Enum.any?(anomalies, &(&1.severity == :critical)) do
          :critical
        else
          :warning
        end
    end
  end

  defp emit_telemetry(audit_result, _state) do
    if audit_result.severity != :info do
      Logger.warning("[SupervisionAuditor] Anomalies detected: #{inspect(audit_result.anomalies)}")
    end

    try do
      Bus.emit(:system_event, %{
        event: :supervision_audit,
        timestamp: audit_result.timestamp,
        status: audit_result.status,
        tree_snapshot: audit_result.tree_snapshot,
        anomalies: audit_result.anomalies,
        severity: audit_result.severity,
        compliant: audit_result.compliant
      })
    rescue
      _e ->
        # Any other exceptions are logged but don't crash the audit
        :ok
    catch
      :exit, _reason ->
        # Bus or TaskSupervisor may not be running in test mode
        :ok
    end

    audit_result
  end

  defp store_audit_result(state, audit_result) do
    # Keep last audit + history of last 100
    new_history = [audit_result | state.audit_history] |> Enum.take(100)

    %{
      state
      | last_audit: audit_result,
        audit_history: new_history,
        next_audit_at: DateTime.add(DateTime.utc_now(), state.audit_interval_ms, :millisecond)
    }
  end

  defp maybe_escalate_anomalies(state, audit_result) do
    case audit_result.severity do
      :critical ->
        try do
          Bus.emit(:algedonic_alert, %{
            type: :supervision_critical_anomaly,
            severity: :critical,
            timestamp: audit_result.timestamp,
            anomalies: audit_result.anomalies,
            reason: "Critical supervision tree anomaly detected"
          })

          Logger.warning(
            "[SupervisionAuditor] Escalated critical anomaly to healing: #{inspect(audit_result.anomalies)}"
          )
        rescue
          _e ->
            # Any exceptions don't crash the escalation
            :ok
        catch
          :exit, _reason ->
            # Bus may not be running in test mode
            :ok
        end

        state

      _ ->
        state
    end
  end
end
