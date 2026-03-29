defmodule OptimalSystemAgent.Monitoring.ProcessMonitoringSchedulerTest do
  use ExUnit.Case, async: true

  alias OptimalSystemAgent.Monitoring.ProcessMonitoringScheduler

  @table :osa_process_monitoring

  # Ensure the ETS table exists (idempotent — if it was created by another test
  # process or by the scheduler itself, we skip creation).
  defp ensure_table do
    if :ets.whereis(@table) == :undefined do
      :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])
    end
  end

  describe "get_baseline/0" do
    test "returns error when no baseline exists" do
      ensure_table()
      :ets.delete(@table, :baseline)

      assert ProcessMonitoringScheduler.get_baseline() == {:error, :no_baseline}
    end

    test "returns baseline when one is stored" do
      ensure_table()

      metrics = %{"variant_count" => 5, "case_count" => 100}
      :ets.insert(@table, {:baseline, metrics})

      assert ProcessMonitoringScheduler.get_baseline() == {:ok, metrics}
    end

    test "returns the most recently stored baseline" do
      ensure_table()

      :ets.insert(@table, {:baseline, %{"variant_count" => 3}})
      :ets.insert(@table, {:baseline, %{"variant_count" => 7, "case_count" => 50}})

      assert {:ok, %{"variant_count" => 7, "case_count" => 50}} =
               ProcessMonitoringScheduler.get_baseline()
    end
  end
end
