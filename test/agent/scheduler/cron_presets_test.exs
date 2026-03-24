defmodule OptimalSystemAgent.Agent.Scheduler.CronPresetsTest do
  @moduledoc """
  Unit tests for CronPresets module.

  Tests preset listing, descriptions, and next-run calculation.
  """

  use ExUnit.Case, async: true

  alias OptimalSystemAgent.Agent.Scheduler.CronPresets

  describe "list_presets/0" do
    test "returns list of preset maps" do
      presets = CronPresets.list_presets()

      assert is_list(presets)
      assert length(presets) > 0

      Enum.each(presets, fn preset ->
        assert Map.has_key?(preset, :id)
        assert Map.has_key?(preset, :cron)
        assert Map.has_key?(preset, :label)
      end)
    end

    test "includes common presets" do
      presets = CronPresets.list_presets()
      ids = Enum.map(presets, & &1.id)

      assert "every_minute" in ids
      assert "hourly" in ids
      assert "daily_9am" in ids
    end
  end

  describe "describe/1" do
    test "returns label for known preset" do
      assert CronPresets.describe("* * * * *") == "Every minute"
      assert CronPresets.describe("0 * * * *") == "Every hour"
      assert CronPresets.describe("0 9 * * *") == "Daily at 9:00 AM"
    end

    test "describes every minute pattern" do
      assert CronPresets.describe("* * * * *") == "Every minute"
    end

    test "describes step patterns" do
      assert CronPresets.describe("*/5 * * * *") == "Every 5 minutes"
    end

    test "describes hourly pattern" do
      assert CronPresets.describe("0 * * * *") == "Every hour"
    end

    test "describes specific time" do
      assert CronPresets.describe("30 14 * * *") == "at 14:30"
    end

    test "describes day of month" do
      assert CronPresets.describe("0 9 1 * *") == "Monthly on the 1st at 9:00 AM"
    end

    test "describes day of week" do
      assert CronPresets.describe("0 9 * * 1") == "Weekly on Monday at 9:00 AM"
      assert CronPresets.describe("0 9 * * 5") == "on Friday at 09:00"
    end

    test "describes unknown cron expression" do
      # Unknown expressions get a generated description
      result = CronPresets.describe("7 3 * * *")
      assert is_binary(result)
      assert String.length(result) > 0
    end

    test "returns expression for invalid format" do
      assert CronPresets.describe("not a cron") == "not a cron"
    end
  end

  describe "next_run/1" do
    test "returns DateTime for valid cron" do
      result = CronPresets.next_run("0 9 * * *")

      assert %DateTime{} = result
      assert result.hour == 9
      assert result.minute == 0
    end

    test "returns nil for invalid cron" do
      assert CronPresets.next_run("invalid cron") == nil
    end

    test "next run is in the future" do
      now = DateTime.utc_now()
      result = CronPresets.next_run("* * * * *")

      assert DateTime.compare(result, now) == :gt
    end

    test "every minute preset returns next minute" do
      now = DateTime.utc_now()
      result = CronPresets.next_run("* * * * *")

      # Should be approximately 1 minute from now
      diff = DateTime.diff(result, now, :second)
      assert diff > 0
      assert diff < 120
    end

    test "hourly preset returns next hour" do
      result = CronPresets.next_run("0 * * * *")

      assert result.minute == 0
      assert result.second == 0
    end
  end
end
