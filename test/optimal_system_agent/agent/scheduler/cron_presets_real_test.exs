defmodule OptimalSystemAgent.Agent.Scheduler.CronPresetsRealTest do
  @moduledoc """
  Chicago TDD integration tests for Agent.Scheduler.CronPresets.

  NO MOCKS. Tests real preset definitions, description generation, next-run calculation.
  Every gap found is a real bug or missing behavior.
  """

  use ExUnit.Case, async: true

  @moduletag :integration

  alias OptimalSystemAgent.Agent.Scheduler.CronPresets

  describe "CronPresets.list_presets/0" do
    test "CRASH: returns list of preset maps" do
      presets = CronPresets.list_presets()
      assert is_list(presets)
      assert length(presets) > 0

      Enum.each(presets, fn preset ->
        assert Map.has_key?(preset, :id)
        assert Map.has_key?(preset, :cron)
        assert Map.has_key?(preset, :label)
      end)
    end

    test "CRASH: includes expected presets" do
      presets = CronPresets.list_presets()
      ids = Enum.map(presets, & &1.id)

      assert "every_minute" in ids
      assert "every_5_minutes" in ids
      assert "hourly" in ids
      assert "daily_9am" in ids
      assert "weekly_monday" in ids
      assert "monthly_first" in ids
    end

    test "CRASH: all preset cron expressions are valid" do
      alias OptimalSystemAgent.Agent.Scheduler.CronEngine

      Enum.each(CronPresets.list_presets(), fn preset ->
        assert {:ok, _fields} = CronEngine.parse(preset.cron),
               "Preset #{preset.id} has invalid cron: #{preset.cron}"
      end)
    end
  end

  describe "CronPresets.describe/1" do
    test "CRASH: known preset returns its label" do
      assert CronPresets.describe("* * * * *") == "Every minute"
      assert CronPresets.describe("*/5 * * * *") == "Every 5 minutes"
      assert CronPresets.describe("0 * * * *") == "Every hour"
      assert CronPresets.describe("0 9 * * *") == "Daily at 9:00 AM"
    end

    test "CRASH: weekly Monday preset has correct label" do
      assert CronPresets.describe("0 9 * * 1") == "Weekly on Monday at 9:00 AM"
    end

    test "CRASH: monthly first preset has correct label" do
      assert CronPresets.describe("0 9 1 * *") == "Monthly on the 1st at 9:00 AM"
    end

    test "CRASH: unknown cron generates description from expression" do
      desc = CronPresets.describe("0 9 15 * *")
      assert is_binary(desc)
      assert desc != "0 9 15 * *"
    end

    test "CRASH: invalid cron returns the raw expression" do
      assert CronPresets.describe("invalid") == "invalid"
    end
  end

  describe "CronPresets.next_run/1" do
    test "CRASH: every_minute returns a time ~1 minute from now" do
      result = CronPresets.next_run("* * * * *")
      assert %DateTime{} = result

      diff = DateTime.diff(result, DateTime.utc_now(), :second)
      # Should be within ~2 minutes (60-120 seconds)
      assert diff > 0
      assert diff < 120
    end

    test "CRASH: hourly returns a time within the hour" do
      result = CronPresets.next_run("0 * * * *")
      assert %DateTime{} = result

      diff = DateTime.diff(result, DateTime.utc_now(), :second)
      assert diff > 0
      assert diff <= 3600
    end

    test "CRASH: invalid cron returns nil" do
      assert CronPresets.next_run("not a cron") == nil
    end

    test "CRASH: daily 9am returns future time" do
      result = CronPresets.next_run("0 9 * * *")
      assert %DateTime{} = result
      assert DateTime.compare(result, DateTime.utc_now()) == :gt
    end
  end

  describe "CronPresets — description generation edge cases" do
    test "CRASH: every 15 minutes preset has correct label" do
      assert CronPresets.describe("*/15 * * * *") == "Every 15 minutes"
    end

    test "CRASH: every 30 minutes preset has correct label" do
      assert CronPresets.describe("*/30 * * * *") == "Every 30 minutes"
    end

    test "CRASH: custom 3-minute interval generates description" do
      desc = CronPresets.describe("*/3 * * * *")
      assert String.contains?(desc, "3")
      assert String.contains?(desc, "minute")
    end

    test "CRASH: specific time generates time description" do
      desc = CronPresets.describe("30 14 * * *")
      assert String.contains?(desc, "14")
      assert String.contains?(desc, "30")
    end
  end
end
