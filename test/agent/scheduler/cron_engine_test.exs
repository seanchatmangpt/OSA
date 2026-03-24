defmodule OptimalSystemAgent.Agent.Scheduler.CronEngineTest do
  @moduledoc """
  Chicago TDD unit tests for CronEngine module.

  Tests cron expression parsing and datetime matching.
  """

  use ExUnit.Case, async: true

  alias OptimalSystemAgent.Agent.Scheduler.CronEngine

  describe "parse/1" do
    test "parses valid 5-field cron expression" do
      assert {:ok, fields} = CronEngine.parse("0 9 * * *")
      assert MapSet.member?(fields.minute, 0)
      assert MapSet.member?(fields.hour, 9)
      assert MapSet.size(fields.dom) == 31
      assert MapSet.size(fields.month) == 12
      assert MapSet.size(fields.dow) == 7
    end

    test "parses wildcard expressions" do
      assert {:ok, fields} = CronEngine.parse("* * * * *")
      assert MapSet.size(fields.minute) == 60
      assert MapSet.size(fields.hour) == 24
    end

    test "parses step expressions" do
      assert {:ok, fields} = CronEngine.parse("*/5 * * * *")
      assert MapSet.member?(fields.minute, 0)
      assert MapSet.member?(fields.minute, 5)
      assert MapSet.member?(fields.minute, 55)
      refute MapSet.member?(fields.minute, 3)
    end

    test "parses comma-separated values" do
      assert {:ok, fields} = CronEngine.parse("0,15,30,45 * * * *")
      assert MapSet.member?(fields.minute, 0)
      assert MapSet.member?(fields.minute, 15)
      assert MapSet.member?(fields.minute, 30)
      assert MapSet.member?(fields.minute, 45)
      assert MapSet.size(fields.minute) == 4
    end

    test "parses range expressions" do
      assert {:ok, fields} = CronEngine.parse("0 9-17 * * *")
      assert MapSet.member?(fields.hour, 9)
      assert MapSet.member?(fields.hour, 17)
      refute MapSet.member?(fields.hour, 8)
      refute MapSet.member?(fields.hour, 18)
    end

    test "returns error for invalid field count" do
      assert {:error, msg} = CronEngine.parse("* * * *")
      assert msg =~ "expected 5 fields, got 4"
    end

    test "returns error for out of range values" do
      assert {:error, _} = CronEngine.parse("99 * * * *")
      assert {:error, _} = CronEngine.parse("0 25 * * *")
    end

    test "returns error for invalid step value" do
      assert {:error, _} = CronEngine.parse("*/abc * * * *")
    end

    test "returns error for non-string input" do
      assert {:error, _} = CronEngine.parse(nil)
      assert {:error, _} = CronEngine.parse(123)
    end
  end

  describe "matches?/2" do
    test "matches exact time" do
      {:ok, fields} = CronEngine.parse("30 14 15 1 *")
      dt = DateTime.from_naive!(~N[2026-01-15 14:30:00], "Etc/UTC")

      assert CronEngine.matches?(fields, dt)
    end

    test "does not match different time" do
      {:ok, fields} = CronEngine.parse("30 14 15 1 *")
      dt = DateTime.from_naive!(~N[2026-01-15 14:31:00], "Etc/UTC")

      refute CronEngine.matches?(fields, dt)
    end

    test "matches wildcard minute" do
      {:ok, fields} = CronEngine.parse("* 14 15 1 *")
      dt = DateTime.from_naive!(~N[2026-01-15 14:30:00], "Etc/UTC")

      assert CronEngine.matches?(fields, dt)
    end

    test "matches step values" do
      {:ok, fields} = CronEngine.parse("*/5 * * * *")
      dt1 = DateTime.from_naive!(~N[2026-01-15 14:30:00], "Etc/UTC")
      dt2 = DateTime.from_naive!(~N[2026-01-15 14:31:00], "Etc/UTC")

      assert CronEngine.matches?(fields, dt1)
      refute CronEngine.matches?(fields, dt2)
    end

    test "matches comma-separated values" do
      {:ok, fields} = CronEngine.parse("0,15,30,45 * * * *")
      dt1 = DateTime.from_naive!(~N[2026-01-15 14:15:00], "Etc/UTC")
      dt2 = DateTime.from_naive!(~N[2026-01-15 14:20:00], "Etc/UTC")

      assert CronEngine.matches?(fields, dt1)
      refute CronEngine.matches?(fields, dt2)
    end

    test "matches ranges" do
      {:ok, fields} = CronEngine.parse("0 9-17 * * *")
      dt1 = DateTime.from_naive!(~N[2026-01-15 12:00:00], "Etc/UTC")
      dt2 = DateTime.from_naive!(~N[2026-01-15 08:00:00], "Etc/UTC")

      assert CronEngine.matches?(fields, dt1)
      refute CronEngine.matches?(fields, dt2)
    end

    test "matches day of week (Sunday = 0)" do
      {:ok, fields} = CronEngine.parse("0 9 * * 0")
      # Sunday Jan 4, 2026
      dt = DateTime.from_naive!(~N[2026-01-04 09:00:00], "Etc/UTC")

      assert CronEngine.matches?(fields, dt)
    end

    test "matches day of week (Monday = 1)" do
      {:ok, fields} = CronEngine.parse("0 9 * * 1")
      # Monday Jan 5, 2026
      dt = DateTime.from_naive!(~N[2026-01-05 09:00:00], "Etc/UTC")

      assert CronEngine.matches?(fields, dt)
    end

    test "matches combined day and month" do
      {:ok, fields} = CronEngine.parse("0 9 15 1 *")
      dt = DateTime.from_naive!(~N[2026-01-15 09:00:00], "Etc/UTC")

      assert CronEngine.matches?(fields, dt)
    end
  end
end
