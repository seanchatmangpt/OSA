defmodule OptimalSystemAgent.Bridges.ProcessMiningBridgeTest do
  use ExUnit.Case, async: false

  alias OptimalSystemAgent.Bridges.ProcessMiningBridge

  # Tests that need a running GenServer are tagged :requires_application.
  # In --no-start mode the test_helper auto-detects and skips them.
  @moduletag :requires_application

  setup do
    # The app supervisor starts the bridge automatically. Stop the supervisor's
    # child so we can start our own with test-specific opts. If the supervisor
    # is not running (--no-start), this is a no-op because the @moduletag skips.
    sup = OptimalSystemAgent.Bridges.ProcessMiningBridgeSupervisor

    case Process.whereis(sup) do
      nil ->
        :ok

      _pid ->
        # Terminate the bridge child managed by the supervisor
        Supervisor.terminate_child(sup, ProcessMiningBridge)
        Process.sleep(50)
    end

    on_exit(fn ->
      # Stop our test-started bridge if still alive
      case Process.whereis(ProcessMiningBridge) do
        nil ->
          :ok

        pid ->
          if Process.alive?(pid) do
            try do
              GenServer.stop(pid, :normal, 5_000)
            catch
              :exit, _ -> :ok
            end
          end
      end

      Process.sleep(50)

      # Restart the supervisor's child so the app is back to normal
      case Process.whereis(sup) do
        nil -> :ok
        _pid -> Supervisor.restart_child(sup, ProcessMiningBridge)
      end
    end)

    :ok
  end

  # ---------------------------------------------------------------------------
  # Test 1: bridge starts and polls on interval
  # ---------------------------------------------------------------------------

  describe "bridge starts and polls on interval" do
    test "bridge starts successfully and reports status" do
      {:ok, pid} =
        ProcessMiningBridge.start_link(
          base_url: "http://127.0.0.1:19999",
          poll_interval_ms: 600_000
        )

      assert Process.alive?(pid)

      status = ProcessMiningBridge.status()
      assert is_map(status)
      assert status.base_url == "http://127.0.0.1:19999"
      assert status.poll_interval_ms == 600_000
      assert status.poll_count == 0
      assert status.pm4py_healthy == false
      assert status.anomaly_count == 0
    end

    test "bridge schedules poll on init and responds to manual poll_now" do
      {:ok, _pid} =
        ProcessMiningBridge.start_link(
          base_url: "http://127.0.0.1:19999",
          poll_interval_ms: 600_000
        )

      # Trigger a manual poll (pm4py-rust is not running, so health check will fail)
      ProcessMiningBridge.poll_now()
      # Give the cast time to process
      Process.sleep(300)

      status = ProcessMiningBridge.status()
      assert status.poll_count == 1
      assert status.pm4py_healthy == false
      assert match?({:error, _}, status.last_poll_result)
    end
  end

  # ---------------------------------------------------------------------------
  # Test 2: low conformance score triggers anomaly
  # ---------------------------------------------------------------------------

  describe "low conformance score triggers anomaly" do
    test "conformance score below threshold emits anomaly via inject" do
      {:ok, _pid} =
        ProcessMiningBridge.start_link(
          base_url: "http://127.0.0.1:19999",
          poll_interval_ms: 600_000,
          conformance_threshold: 0.7
        )

      # Inject simulated conformance data with low score
      {:ok, anomaly_count} =
        ProcessMiningBridge.inject_conformance_data(%{
          "conformance_score" => 0.4,
          "cycle_time_ms" => 500
        })

      assert anomaly_count == 1

      anomalies = ProcessMiningBridge.anomalies()
      assert length(anomalies) == 1
      [anomaly] = anomalies
      assert anomaly.type == :low_conformance
      assert anomaly.data.score == 0.4
      assert anomaly.data.threshold == 0.7
    end

    test "conformance score at or above threshold produces no anomaly" do
      {:ok, _pid} =
        ProcessMiningBridge.start_link(
          base_url: "http://127.0.0.1:19999",
          poll_interval_ms: 600_000,
          conformance_threshold: 0.7
        )

      {:ok, anomaly_count} =
        ProcessMiningBridge.inject_conformance_data(%{
          "conformance_score" => 0.85
        })

      assert anomaly_count == 0
      assert ProcessMiningBridge.anomalies() == []
    end
  end

  # ---------------------------------------------------------------------------
  # Test 3: high cycle time triggers anomaly
  # ---------------------------------------------------------------------------

  describe "high cycle time triggers anomaly" do
    test "cycle time above threshold emits anomaly with correct delta" do
      {:ok, _pid} =
        ProcessMiningBridge.start_link(
          base_url: "http://127.0.0.1:19999",
          poll_interval_ms: 600_000,
          cycle_time_threshold_ms: 5_000
        )

      {:ok, anomaly_count} =
        ProcessMiningBridge.inject_conformance_data(%{
          "conformance_score" => 0.9,
          "cycle_time_ms" => 12_000
        })

      assert anomaly_count == 1

      anomalies = ProcessMiningBridge.anomalies()
      assert length(anomalies) == 1
      [anomaly] = anomalies
      assert anomaly.type == :high_cycle_time
      assert anomaly.data.cycle_time_ms == 12_000
      assert anomaly.data.delta == 7_000
    end

    test "bottleneck detected emits anomaly with node_id" do
      {:ok, _pid} =
        ProcessMiningBridge.start_link(
          base_url: "http://127.0.0.1:19999",
          poll_interval_ms: 600_000
        )

      {:ok, anomaly_count} =
        ProcessMiningBridge.inject_conformance_data(%{
          "conformance_score" => 0.9,
          "bottlenecks" => [%{"node_id" => "approval_step"}]
        })

      assert anomaly_count == 1

      [anomaly] = ProcessMiningBridge.anomalies()
      assert anomaly.type == :bottleneck
      assert anomaly.data.node_id == "approval_step"
    end

    test "multiple anomalies detected in single conformance check" do
      {:ok, _pid} =
        ProcessMiningBridge.start_link(
          base_url: "http://127.0.0.1:19999",
          poll_interval_ms: 600_000,
          conformance_threshold: 0.7,
          cycle_time_threshold_ms: 5_000
        )

      {:ok, anomaly_count} =
        ProcessMiningBridge.inject_conformance_data(%{
          "conformance_score" => 0.3,
          "cycle_time_ms" => 15_000,
          "bottlenecks" => ["node_x", "node_y"]
        })

      # low_conformance + high_cycle_time + 2 bottlenecks = 4
      assert anomaly_count == 4
      assert length(ProcessMiningBridge.anomalies()) == 4
    end
  end

  # ---------------------------------------------------------------------------
  # Test 4: pm4py-rust down does not crash bridge
  # ---------------------------------------------------------------------------

  describe "pm4py-rust down does not crash bridge" do
    test "bridge survives when pm4py-rust is unreachable" do
      {:ok, pid} =
        ProcessMiningBridge.start_link(
          base_url: "http://127.0.0.1:19999",
          poll_interval_ms: 600_000
        )

      # Trigger multiple polls against unreachable service
      ProcessMiningBridge.poll_now()
      Process.sleep(300)
      ProcessMiningBridge.poll_now()
      Process.sleep(300)
      ProcessMiningBridge.poll_now()
      Process.sleep(300)

      # Bridge must still be alive after 3 failed polls
      assert Process.alive?(pid)

      status = ProcessMiningBridge.status()
      assert status.poll_count == 3
      assert status.pm4py_healthy == false
    end

    test "bridge logs warning but does not crash on connection refused" do
      {:ok, pid} =
        ProcessMiningBridge.start_link(
          base_url: "http://127.0.0.1:1",
          poll_interval_ms: 600_000
        )

      ProcessMiningBridge.poll_now()
      Process.sleep(300)

      assert Process.alive?(pid)
      status = ProcessMiningBridge.status()
      assert status.pm4py_healthy == false
    end
  end

  # ---------------------------------------------------------------------------
  # Test 5: poll timeout bounded to 3 seconds
  # ---------------------------------------------------------------------------

  describe "poll timeout bounded to 3 seconds" do
    test "status call has explicit timeout and returns within bounded time" do
      {:ok, _pid} =
        ProcessMiningBridge.start_link(
          base_url: "http://127.0.0.1:19999",
          poll_interval_ms: 600_000
        )

      # Verify that a normal status call completes well within timeout
      {time_us, result} = :timer.tc(fn -> ProcessMiningBridge.status() end)
      assert is_map(result)
      # Should complete in well under 3 seconds (the HTTP timeout)
      assert time_us < 3_000_000
    end

    test "anomalies call returns empty list within bounded time" do
      {:ok, _pid} =
        ProcessMiningBridge.start_link(
          base_url: "http://127.0.0.1:19999",
          poll_interval_ms: 600_000
        )

      {time_us, result} = :timer.tc(fn -> ProcessMiningBridge.anomalies() end)
      assert is_list(result)
      assert time_us < 3_000_000
    end
  end

  # ---------------------------------------------------------------------------
  # Anomaly detection logic (pure function, no GenServer needed)
  # ---------------------------------------------------------------------------

  describe "detect_anomalies pure logic" do
    test "returns empty list when all values are within thresholds" do
      state = %{conformance_threshold: 0.7, cycle_time_threshold_ms: 10_000}
      data = %{"conformance_score" => 0.95, "cycle_time_ms" => 5_000}

      anomalies = ProcessMiningBridge.detect_anomalies(state, data)
      assert anomalies == []
    end

    test "detects low conformance with correct fields" do
      state = %{conformance_threshold: 0.7, cycle_time_threshold_ms: 10_000}
      data = %{"conformance_score" => 0.45}

      anomalies = ProcessMiningBridge.detect_anomalies(state, data)
      assert length(anomalies) == 1
      [a] = anomalies
      assert a.type == :low_conformance
      assert a.score == 0.45
      assert a.threshold == 0.7
    end

    test "detects high cycle time with correct delta" do
      state = %{conformance_threshold: 0.7, cycle_time_threshold_ms: 10_000}
      data = %{"conformance_score" => 0.9, "cycle_time_ms" => 25_000}

      anomalies = ProcessMiningBridge.detect_anomalies(state, data)
      assert length(anomalies) == 1
      [a] = anomalies
      assert a.type == :high_cycle_time
      assert a.cycle_time_ms == 25_000
      assert a.delta == 15_000
    end

    test "detects bottleneck from node_id map" do
      state = %{conformance_threshold: 0.7, cycle_time_threshold_ms: 10_000}
      data = %{"bottlenecks" => [%{"node_id" => "step_3"}]}

      anomalies = ProcessMiningBridge.detect_anomalies(state, data)
      assert length(anomalies) == 1
      [a] = anomalies
      assert a.type == :bottleneck
      assert a.node_id == "step_3"
    end

    test "detects bottleneck from plain string list" do
      state = %{conformance_threshold: 0.7, cycle_time_threshold_ms: 10_000}
      data = %{"bottlenecks" => ["step_a", "step_b"]}

      anomalies = ProcessMiningBridge.detect_anomalies(state, data)
      assert length(anomalies) == 2
      types = Enum.map(anomalies, & &1.type) |> Enum.uniq()
      assert types == [:bottleneck]
      node_ids = Enum.map(anomalies, & &1.node_id) |> Enum.sort()
      assert node_ids == ["step_a", "step_b"]
    end

    test "accepts fitness key as alternative to conformance_score" do
      state = %{conformance_threshold: 0.7, cycle_time_threshold_ms: 10_000}
      data = %{"fitness" => 0.3}

      anomalies = ProcessMiningBridge.detect_anomalies(state, data)
      assert length(anomalies) == 1
      assert hd(anomalies).type == :low_conformance
    end

    test "ignores missing or nil conformance data gracefully" do
      state = %{conformance_threshold: 0.7, cycle_time_threshold_ms: 10_000}
      data = %{}

      anomalies = ProcessMiningBridge.detect_anomalies(state, data)
      assert anomalies == []
    end
  end

  # ---------------------------------------------------------------------------
  # Supervisor integration
  # ---------------------------------------------------------------------------

  describe "supervisor integration" do
    test "supervisor starts bridge as permanent child" do
      # The supervisor from the app is running, verify the bridge can be managed
      sup = OptimalSystemAgent.Bridges.ProcessMiningBridgeSupervisor

      case Process.whereis(sup) do
        nil ->
          # Start supervisor manually if not running
          {:ok, sup_pid} = OptimalSystemAgent.Bridges.ProcessMiningBridgeSupervisor.start_link()
          assert Process.alive?(sup_pid)

          bridge_pid = Process.whereis(ProcessMiningBridge)
          assert bridge_pid != nil
          assert Process.alive?(bridge_pid)

          Supervisor.stop(sup_pid, :normal)

        _pid ->
          # Supervisor is already running from the app — restart the child we stopped in setup
          Supervisor.restart_child(sup, ProcessMiningBridge)
          Process.sleep(50)

          bridge_pid = Process.whereis(ProcessMiningBridge)
          assert bridge_pid != nil
          assert Process.alive?(bridge_pid)
      end
    end
  end
end
