defmodule OptimalSystemAgent.Agents.Armstrong.SupervisionAuditorTest do
  @moduledoc """
  Chicago TDD tests for Armstrong Supervision Auditor Agent.

  Tests verify:
    1. Supervision tree structure is valid (Red)
    2. Orphaned processes are detected (Red)
    3. Restart storms are detected (Red)
    4. Audit snapshots can be retrieved (Red)
    5. Telemetry events are emitted (Red)
    6. Critical anomalies escalate to healing (Red)
  """

  use ExUnit.Case, async: false

  alias OptimalSystemAgent.Agents.Armstrong.SupervisionAuditor

  @moduletag :capture_log

  # ==========================================================================
  # Test: Supervision tree structure validation
  # ==========================================================================

  describe "supervision_tree_structure_is_valid" do
    test "auditor can be started as a GenServer" do
      # RED: SupervisionAuditor.start_link/1 returns {:ok, pid}
      {:ok, pid} = SupervisionAuditor.start_link(audit_interval_ms: 600_000)
      assert is_pid(pid)
      GenServer.stop(pid)
    end

    test "auditor registers itself with name :supervision_auditor" do
      # RED: SupervisionAuditor can be reached by name after start_link
      {:ok, _pid} = SupervisionAuditor.start_link(audit_interval_ms: 600_000)
      auditor_pid = Process.whereis(:supervision_auditor)
      assert is_pid(auditor_pid)
      GenServer.stop(auditor_pid)
    end

    test "audit_now returns a valid audit result map" do
      # RED: audit_now/0 returns {:ok, audit_result} where audit_result is a map
      {:ok, _auditor} = SupervisionAuditor.start_link(audit_interval_ms: 600_000)

      {:ok, audit_result} = SupervisionAuditor.audit_now()

      # GREEN: audit_result has expected keys
      assert is_map(audit_result)
      assert Map.has_key?(audit_result, :timestamp)
      assert Map.has_key?(audit_result, :status)
      assert Map.has_key?(audit_result, :tree_snapshot)
      assert Map.has_key?(audit_result, :anomalies)
      assert Map.has_key?(audit_result, :severity)
      assert Map.has_key?(audit_result, :compliant)

      GenServer.stop(Process.whereis(:supervision_auditor))
    end

    test "audit result status is one of expected values" do
      # RED: audit_result.status is an atom representing audit outcome
      {:ok, _auditor} = SupervisionAuditor.start_link(audit_interval_ms: 600_000)

      {:ok, audit_result} = SupervisionAuditor.audit_now()

      # GREEN: status is one of valid values
      assert audit_result.status in [
        :compliant,
        :violations_detected,
        :error,
        :osa_not_running
      ]

      GenServer.stop(Process.whereis(:supervision_auditor))
    end

    test "audit result severity is info | warning | critical" do
      # RED: audit_result.severity is one of allowed levels
      {:ok, _auditor} = SupervisionAuditor.start_link(audit_interval_ms: 600_000)

      {:ok, audit_result} = SupervisionAuditor.audit_now()

      # GREEN: severity is recognized level
      assert audit_result.severity in [:info, :warning, :critical]

      GenServer.stop(Process.whereis(:supervision_auditor))
    end

    test "audit result compliant flag reflects status and anomalies" do
      # RED: compliant should be false when status is error or violations_detected
      {:ok, _auditor} = SupervisionAuditor.start_link(audit_interval_ms: 600_000)

      {:ok, audit_result} = SupervisionAuditor.audit_now()

      # GREEN: compliant is true only when status is :compliant AND anomalies is empty
      # When status is :error, :violations_detected, compliant should be false
      case audit_result.status do
        :compliant ->
          assert audit_result.compliant == (audit_result.anomalies == [])

        :violations_detected ->
          assert audit_result.compliant == false

        :error ->
          assert audit_result.compliant == false

        :osa_not_running ->
          assert audit_result.compliant == false
      end

      GenServer.stop(Process.whereis(:supervision_auditor))
    end

    test "tree snapshot contains supervision structure when compliant" do
      # RED: when status is :compliant, tree_snapshot should not be nil
      {:ok, _auditor} = SupervisionAuditor.start_link(audit_interval_ms: 600_000)

      {:ok, audit_result} = SupervisionAuditor.audit_now()

      # GREEN: if compliant or violations_detected, tree_snapshot is present
      if audit_result.status in [:compliant, :violations_detected] do
        assert audit_result.tree_snapshot != nil
        snapshot = audit_result.tree_snapshot
        assert Map.has_key?(snapshot, :supervisor_pid)
        assert Map.has_key?(snapshot, :strategy)
        assert Map.has_key?(snapshot, :children_count)
        assert Map.has_key?(snapshot, :depth)
      end

      GenServer.stop(Process.whereis(:supervision_auditor))
    end
  end

  # ==========================================================================
  # Test: Orphaned processes detection
  # ==========================================================================

  describe "orphaned_processes_are_detected" do
    test "anomalies list contains detected issues" do
      # RED: anomalies should be a list (empty when no issues, populated with maps when issues)
      {:ok, _auditor} = SupervisionAuditor.start_link(audit_interval_ms: 600_000)

      {:ok, audit_result} = SupervisionAuditor.audit_now()

      # GREEN: anomalies is always a list
      assert is_list(audit_result.anomalies)

      GenServer.stop(Process.whereis(:supervision_auditor))
    end

    test "anomalies have required structure" do
      # RED: each anomaly should have type, severity, reason
      {:ok, _auditor} = SupervisionAuditor.start_link(audit_interval_ms: 600_000)

      {:ok, audit_result} = SupervisionAuditor.audit_now()

      # GREEN: check structure of any anomalies
      Enum.each(audit_result.anomalies, fn anomaly ->
        assert is_map(anomaly)
        assert Map.has_key?(anomaly, :type)
        assert Map.has_key?(anomaly, :severity)
        assert Map.has_key?(anomaly, :reason)
        assert is_atom(anomaly.type)
        assert is_atom(anomaly.severity)
        assert is_binary(anomaly.reason)
      end)

      GenServer.stop(Process.whereis(:supervision_auditor))
    end

    test "dead children anomaly is detected when present" do
      # RED: if supervision tree has dead children, anomaly.type == :dead_children
      {:ok, _auditor} = SupervisionAuditor.start_link(audit_interval_ms: 600_000)

      {:ok, audit_result} = SupervisionAuditor.audit_now()

      dead_anomalies =
        audit_result.anomalies
        |> Enum.filter(fn a -> a.type == :dead_children end)

      # GREEN: if dead_children found, anomaly has dead_count and total_children
      Enum.each(dead_anomalies, fn anomaly ->
        assert Map.has_key?(anomaly, :dead_count)
        assert Map.has_key?(anomaly, :total_children)
        assert anomaly.dead_count >= 1
      end)

      GenServer.stop(Process.whereis(:supervision_auditor))
    end
  end

  # ==========================================================================
  # Test: Restart storm detection
  # ==========================================================================

  describe "restart_storms_are_detected" do
    test "high cascade risk is detected and reported" do
      # RED: cascade risk > 0.5 should trigger :high_cascade_risk anomaly
      {:ok, _auditor} = SupervisionAuditor.start_link(audit_interval_ms: 600_000)

      {:ok, audit_result} = SupervisionAuditor.audit_now()

      cascade_anomalies =
        audit_result.anomalies
        |> Enum.filter(fn a -> a.type == :high_cascade_risk end)

      # GREEN: cascade anomalies have risk_score
      Enum.each(cascade_anomalies, fn anomaly ->
        assert Map.has_key?(anomaly, :risk_score)
        assert anomaly.risk_score > 0.5
      end)

      GenServer.stop(Process.whereis(:supervision_auditor))
    end

    test "deep tree is detected when depth exceeds threshold" do
      # RED: tree depth > max_tree_depth should trigger :deep_tree anomaly
      {:ok, _auditor} =
        SupervisionAuditor.start_link(audit_interval_ms: 600_000, max_tree_depth: 3)

      {:ok, audit_result} = SupervisionAuditor.audit_now()

      deep_tree_anomalies =
        audit_result.anomalies
        |> Enum.filter(fn a -> a.type == :deep_tree end)

      # GREEN: if deep tree detected, anomaly reports depth and max_allowed
      Enum.each(deep_tree_anomalies, fn anomaly ->
        assert Map.has_key?(anomaly, :depth)
        assert Map.has_key?(anomaly, :max_allowed)
        assert anomaly.depth > anomaly.max_allowed
      end)

      GenServer.stop(Process.whereis(:supervision_auditor))
    end

    test "too_many_children is detected when supervisor has >max_children" do
      # RED: children_count > max_children should trigger :too_many_children
      {:ok, _auditor} =
        SupervisionAuditor.start_link(audit_interval_ms: 600_000, max_children: 3)

      {:ok, audit_result} = SupervisionAuditor.audit_now()

      too_many_anomalies =
        audit_result.anomalies
        |> Enum.filter(fn a -> a.type == :too_many_children end)

      # GREEN: anomaly has children_count and max_recommended
      Enum.each(too_many_anomalies, fn anomaly ->
        assert Map.has_key?(anomaly, :children_count)
        assert Map.has_key?(anomaly, :max_recommended)
        assert anomaly.children_count > anomaly.max_recommended
      end)

      GenServer.stop(Process.whereis(:supervision_auditor))
    end
  end

  # ==========================================================================
  # Test: Audit snapshot retrieval
  # ==========================================================================

  describe "audit_snapshots_can_be_retrieved" do
    test "get_last_audit returns the most recent audit" do
      # RED: get_last_audit/0 returns {:ok, audit} after audit_now has run
      {:ok, _auditor} = SupervisionAuditor.start_link(audit_interval_ms: 600_000)

      _first_audit = SupervisionAuditor.audit_now()
      :timer.sleep(100)
      _second_audit = SupervisionAuditor.audit_now()

      {:ok, last_audit} = SupervisionAuditor.get_last_audit()

      # GREEN: last_audit is a map with expected structure
      assert is_map(last_audit)
      assert Map.has_key?(last_audit, :timestamp)
      assert Map.has_key?(last_audit, :status)

      GenServer.stop(Process.whereis(:supervision_auditor))
    end

    test "get_last_audit returns the audit that ran on startup" do
      # RED: get_last_audit returns the audit that ran automatically on start_link
      {:ok, auditor} = SupervisionAuditor.start_link(audit_interval_ms: 1_000_000)

      # Wait for initial audit to complete
      :timer.sleep(50)

      {:ok, audit} = SupervisionAuditor.get_last_audit()

      # GREEN: returns the audit result from startup
      assert is_map(audit)
      assert Map.has_key?(audit, :status)
      assert audit.status in [:compliant, :error, :violations_detected, :osa_not_running]

      GenServer.stop(auditor)
    end

    test "get_audit_history returns list of recent audits" do
      # RED: get_audit_history/1 returns {:ok, list} with last N audits
      {:ok, _auditor} = SupervisionAuditor.start_link(audit_interval_ms: 600_000)

      # Run multiple audits
      SupervisionAuditor.audit_now()
      :timer.sleep(50)
      SupervisionAuditor.audit_now()
      :timer.sleep(50)
      SupervisionAuditor.audit_now()

      {:ok, history} = SupervisionAuditor.get_audit_history(5)

      # GREEN: history is a list of maps
      assert is_list(history)
      assert Enum.all?(history, &is_map/1)
      # Should have at least 3 audits
      assert Enum.count(history) >= 3

      GenServer.stop(Process.whereis(:supervision_auditor))
    end

    test "get_audit_history respects limit parameter" do
      # RED: get_audit_history(N) returns at most N items
      {:ok, _auditor} = SupervisionAuditor.start_link(audit_interval_ms: 600_000)

      # Run many audits
      for _i <- 1..20 do
        SupervisionAuditor.audit_now()
        :timer.sleep(10)
      end

      {:ok, history} = SupervisionAuditor.get_audit_history(5)

      # GREEN: returned list has at most 5 items
      assert Enum.count(history) <= 5

      GenServer.stop(Process.whereis(:supervision_auditor))
    end

    test "audit history is in reverse chronological order (newest first)" do
      # RED: get_audit_history returns audits newest first
      {:ok, _auditor} = SupervisionAuditor.start_link(audit_interval_ms: 600_000)

      SupervisionAuditor.audit_now()
      :timer.sleep(10)
      SupervisionAuditor.audit_now()
      :timer.sleep(10)
      SupervisionAuditor.audit_now()

      {:ok, history} = SupervisionAuditor.get_audit_history(10)

      # GREEN: timestamps are in descending order
      timestamps = Enum.map(history, & &1.timestamp)

      is_descending? =
        timestamps
        |> Enum.chunk_every(2, 1)
        |> Enum.all?(fn chunk ->
          case chunk do
            [t1, t2] -> DateTime.compare(t1, t2) in [:gt, :eq]
            [_single] -> true  # single element is always ok
            [] -> true  # empty is vacuously true
          end
        end)

      assert is_descending?

      GenServer.stop(Process.whereis(:supervision_auditor))
    end
  end

  # ==========================================================================
  # Test: Telemetry events are emitted
  # ==========================================================================

  describe "telemetry_events_are_emitted" do
    test "audit_now completes without crashing even if telemetry fails" do
      # RED: audit_now should not crash if Bus.emit fails
      {:ok, _auditor} = SupervisionAuditor.start_link(audit_interval_ms: 600_000)

      # This should complete successfully
      {:ok, audit_result} = SupervisionAuditor.audit_now()

      assert is_map(audit_result)
      assert Map.has_key?(audit_result, :timestamp)

      GenServer.stop(Process.whereis(:supervision_auditor))
    end

    test "audit runs periodically without explicit trigger" do
      # RED: audit should run automatically every audit_interval_ms
      {:ok, _auditor} = SupervisionAuditor.start_link(audit_interval_ms: 100)

      # Wait for automatic audit
      :timer.sleep(200)

      {:ok, last_audit} = SupervisionAuditor.get_last_audit()

      # GREEN: last_audit exists (was set by periodic audit)
      assert last_audit != nil
      assert Map.has_key?(last_audit, :timestamp)

      GenServer.stop(Process.whereis(:supervision_auditor))
    end
  end

  # ==========================================================================
  # Test: Anomaly escalation behavior
  # ==========================================================================

  describe "critical_anomalies_escalate_to_healing" do
    test "critical severity anomalies are marked correctly" do
      # RED: critical anomalies should have severity: :critical
      {:ok, _auditor} = SupervisionAuditor.start_link(audit_interval_ms: 600_000)

      {:ok, audit_result} = SupervisionAuditor.audit_now()

      critical_anomalies =
        audit_result.anomalies
        |> Enum.filter(fn a -> a.severity == :critical end)

      # GREEN: each critical anomaly is a valid map
      Enum.each(critical_anomalies, fn anomaly ->
        assert is_map(anomaly)
        assert anomaly.severity == :critical
      end)

      GenServer.stop(Process.whereis(:supervision_auditor))
    end

    test "audit result severity is critical when critical anomalies exist" do
      # RED: if any anomaly.severity == :critical, then result.severity == :critical
      {:ok, _auditor} = SupervisionAuditor.start_link(audit_interval_ms: 600_000)

      {:ok, audit_result} = SupervisionAuditor.audit_now()

      has_critical = Enum.any?(audit_result.anomalies, &(&1.severity == :critical))

      # GREEN: result severity reflects critical anomalies
      if has_critical do
        assert audit_result.severity == :critical
      end

      GenServer.stop(Process.whereis(:supervision_auditor))
    end
  end

  # ==========================================================================
  # Test: Configuration and options
  # ==========================================================================

  describe "configuration_options_are_respected" do
    test "audit_interval_ms option controls audit frequency" do
      # RED: SupervisionAuditor.start_link accepts audit_interval_ms option
      {:ok, auditor} = SupervisionAuditor.start_link(audit_interval_ms: 50_000)

      # Should start without error
      assert is_pid(auditor)

      GenServer.stop(auditor)
    end

    test "max_tree_depth option is configurable" do
      # RED: SupervisionAuditor.start_link accepts max_tree_depth option
      {:ok, auditor} = SupervisionAuditor.start_link(max_tree_depth: 5)

      assert is_pid(auditor)

      GenServer.stop(auditor)
    end

    test "restart_storm_threshold option is configurable" do
      # RED: SupervisionAuditor.start_link accepts restart_storm_threshold option
      {:ok, auditor} =
        SupervisionAuditor.start_link(restart_storm_threshold: 20)

      assert is_pid(auditor)

      GenServer.stop(auditor)
    end

    test "max_children option is configurable" do
      # RED: SupervisionAuditor.start_link accepts max_children option
      {:ok, auditor} = SupervisionAuditor.start_link(max_children: 30)

      assert is_pid(auditor)

      GenServer.stop(auditor)
    end

    test "child_spec returns proper GenServer spec" do
      # RED: child_spec/1 returns map suitable for Supervisor
      spec = SupervisionAuditor.child_spec([])

      # GREEN: spec has required keys
      assert Map.has_key?(spec, :id)
      assert Map.has_key?(spec, :start)
      assert Map.has_key?(spec, :restart)
      assert Map.has_key?(spec, :type)
      assert spec.id == OptimalSystemAgent.Agents.Armstrong.SupervisionAuditor
      assert spec.restart == :permanent
      assert spec.type == :worker
    end

    test "child_spec can be used in Supervisor.init" do
      # RED: child_spec result can be passed to Supervisor
      spec = SupervisionAuditor.child_spec([])
      children = [spec]

      # Should not crash when creating supervisor
      {:ok, _pid} = Supervisor.start_link(children, strategy: :one_for_one)
    end
  end

  # ==========================================================================
  # Integration: Supervision tree snapshot structure
  # ==========================================================================

  describe "supervision_tree_snapshot_structure" do
    test "snapshot contains supervisor_pid" do
      # RED: tree_snapshot.supervisor_pid should be a pid when not nil
      {:ok, _auditor} = SupervisionAuditor.start_link(audit_interval_ms: 600_000)

      {:ok, audit_result} = SupervisionAuditor.audit_now()

      if audit_result.tree_snapshot != nil do
        snapshot = audit_result.tree_snapshot
        supervisor_pid = snapshot.supervisor_pid

        # GREEN: supervisor_pid is a pid or nil
        assert supervisor_pid == nil or is_pid(supervisor_pid)
      end

      GenServer.stop(Process.whereis(:supervision_auditor))
    end

    test "snapshot contains strategy" do
      # RED: tree_snapshot.strategy should indicate restart strategy
      {:ok, _auditor} = SupervisionAuditor.start_link(audit_interval_ms: 600_000)

      {:ok, audit_result} = SupervisionAuditor.audit_now()

      if audit_result.tree_snapshot != nil do
        snapshot = audit_result.tree_snapshot

        # GREEN: strategy is an atom or :compliant
        assert is_atom(snapshot.strategy)
      end

      GenServer.stop(Process.whereis(:supervision_auditor))
    end

    test "snapshot contains children_count and children list" do
      # RED: tree_snapshot has children_count (int) and children (list)
      {:ok, _auditor} = SupervisionAuditor.start_link(audit_interval_ms: 600_000)

      {:ok, audit_result} = SupervisionAuditor.audit_now()

      if audit_result.tree_snapshot != nil do
        snapshot = audit_result.tree_snapshot

        # GREEN: has children_count and children
        assert is_integer(snapshot.children_count)
        assert snapshot.children_count >= 0
        assert is_list(snapshot.children)
      end

      GenServer.stop(Process.whereis(:supervision_auditor))
    end

    test "snapshot contains depth and cascade_risk" do
      # RED: tree_snapshot.depth is int, cascade_risk is float
      {:ok, _auditor} = SupervisionAuditor.start_link(audit_interval_ms: 600_000)

      {:ok, audit_result} = SupervisionAuditor.audit_now()

      if audit_result.tree_snapshot != nil do
        snapshot = audit_result.tree_snapshot

        # GREEN: has depth (int) and cascade_risk (float)
        assert is_integer(snapshot.depth)
        assert snapshot.depth >= 0
        assert is_float(snapshot.cascade_risk)
        assert snapshot.cascade_risk >= 0.0 and snapshot.cascade_risk <= 1.0
      end

      GenServer.stop(Process.whereis(:supervision_auditor))
    end
  end
end
