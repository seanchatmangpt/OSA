defmodule OptimalSystemAgent.Sensors.SensorRegistryTest do
  use ExUnit.Case, async: false
  alias OptimalSystemAgent.Sensors.SensorRegistry

  doctest SensorRegistry

  @moduletag :capture_log

  describe "init_tables/0" do
    test "initializes ETS tables" do
      assert :ok = SensorRegistry.init_tables()
      # Use :ets.info/1 to check if table exists
      sensor_exists = case :ets.info(:osa_sensors) do
        [] -> false
        _ -> true
      end
      scan_exists = case :ets.info(:osa_scans) do
        [] -> false
        _ -> true
      end
      assert sensor_exists
      assert scan_exists
    end
  end

  describe "scan_sensor_suite/1" do
    setup do
      OptimalSystemAgent.Sensors.SensorRegistry.init_tables()
      case Process.whereis(OptimalSystemAgent.Sensors.SensorRegistry) do
        nil -> start_supervised({OptimalSystemAgent.Sensors.SensorRegistry, []})
        _   -> :ok
      end

      # Get the pid of the already-running GenServer (started by application)
      pid = Process.whereis(OptimalSystemAgent.Sensors.SensorRegistry)

      File.rm_rf!("tmp/sensor_test")
      File.mkdir_p!("tmp/sensor_test")

      %{pid: pid}
    end

    test "returns error for non-existent codebase path", %{pid: _pid} do
      assert {:error, _reason} = SensorRegistry.scan_sensor_suite(codebase_path: "nonexistent")
    end

    test "scan works for existing directory", %{pid: _pid} do
      assert {:ok, result} = SensorRegistry.scan_sensor_suite(
        codebase_path: "lib",
        output_dir: "tmp/sensor_test"
      )

      assert %{scan_id: _, timestamp: timestamp} = result
      assert timestamp > 0
      assert Map.has_key?(result, :modules)
      assert Map.has_key?(result, :deps)
      assert Map.has_key?(result, :patterns)

      # Verify JSON files were created
      assert File.exists?("tmp/sensor_test/modules.json")
      assert File.exists?("tmp/sensor_test/deps.json")
      assert File.exists?("tmp/sensor_test/patterns.json")
    end
  end

  describe "current_fingerprint/0" do
    setup do
      OptimalSystemAgent.Sensors.SensorRegistry.init_tables()
      case Process.whereis(OptimalSystemAgent.Sensors.SensorRegistry) do
        nil -> start_supervised({OptimalSystemAgent.Sensors.SensorRegistry, []})
        _   -> :ok
      end

      # Clear any existing scan data for clean test state
      try do
        :ets.delete_all_objects(:osa_scans)
      rescue
        ArgumentError -> :ok
      end

      # Get the pid of the already-running GenServer (started by application)
      pid = Process.whereis(OptimalSystemAgent.Sensors.SensorRegistry)

      %{pid: pid}
    end

    test "returns error when no scans exist", %{pid: _pid} do
      assert {:error, :no_scan_data} = SensorRegistry.current_fingerprint()
    end

    test "returns fingerprint after scan", %{pid: _pid} do
      File.rm_rf!("tmp/sensor_test")
      File.mkdir_p!("tmp/sensor_test")

      assert {:ok, _result} = SensorRegistry.scan_sensor_suite(
        codebase_path: "lib",
        output_dir: "tmp/sensor_test"
      )

      assert {:ok, fingerprint} = SensorRegistry.current_fingerprint()
      assert is_binary(fingerprint)
      assert String.length(fingerprint) == 64  # SHA256 hex length
    end
  end

  describe "stale?/1" do
    setup do
      OptimalSystemAgent.Sensors.SensorRegistry.init_tables()
      case Process.whereis(OptimalSystemAgent.Sensors.SensorRegistry) do
        nil -> start_supervised({OptimalSystemAgent.Sensors.SensorRegistry, []})
        _   -> :ok
      end

      # Clear any existing scan data for clean test state
      try do
        :ets.delete_all_objects(:osa_scans)
      rescue
        ArgumentError -> :ok
      end

      # Get the pid of the already-running GenServer (started by application)
      pid = Process.whereis(OptimalSystemAgent.Sensors.SensorRegistry)

      %{pid: pid}
    end

    test "returns true for very small max_age_ms", %{pid: _pid} do
      # Even with a recent scan, a very small max_age_ms should return true
      # after enough time has elapsed (stale? uses > comparison)
      Process.sleep(2)
      assert SensorRegistry.stale?(0) == true
    end

    test "returns false for fresh scan", %{pid: _pid} do
      File.rm_rf!("tmp/sensor_test")
      File.mkdir_p!("tmp/sensor_test")

      # Run a scan
      assert {:ok, _result} = SensorRegistry.scan_sensor_suite(
        codebase_path: "lib",
        output_dir: "tmp/sensor_test"
      )

      # Should not be stale immediately after scan
      refute SensorRegistry.stale?(5000)
    end
  end
end
