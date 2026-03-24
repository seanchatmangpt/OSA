defmodule OptimalSystemAgent.Agent.Scheduler.CronEngineRealTest do
  @moduledoc """
  Chicago TDD integration tests for Agent.Scheduler.CronEngine.

  NO MOCKS. Tests real cron parsing and matching against real DateTime values.
  Every gap found is a real bug or missing behavior.
  """

  use ExUnit.Case, async: true

  @moduletag :integration

  alias OptimalSystemAgent.Agent.Scheduler.CronEngine

  describe "CronEngine.parse/1 — wildcard" do
    test "CRASH: * * * * * matches all values" do
      assert {:ok, %{minute: m, hour: h, dom: d, month: mo, dow: w}} = CronEngine.parse("* * * * *")
      assert MapSet.size(m) == 60
      assert MapSet.size(h) == 24
      assert MapSet.size(d) == 31
      assert MapSet.size(mo) == 12
      assert MapSet.size(w) == 7
    end
  end

  describe "CronEngine.parse/1 — step values" do
    test "CRASH: */5 on minutes yields 12 values (0,5,10...55)" do
      assert {:ok, %{minute: m}} = CronEngine.parse("*/5 * * * *")
      assert MapSet.size(m) == 12
      assert MapSet.member?(m, 0)
      assert MapSet.member?(m, 55)
      refute MapSet.member?(m, 3)
    end

    test "CRASH: */15 on minutes yields 4 values" do
      assert {:ok, %{minute: m}} = CronEngine.parse("*/15 * * * *")
      assert MapSet.new([0, 15, 30, 45]) == m
    end

    test "CRASH: */2 on hours yields 12 values" do
      assert {:ok, %{hour: h}} = CronEngine.parse("0 */2 * * *")
      assert MapSet.size(h) == 12
      assert MapSet.member?(h, 0)
      assert MapSet.member?(h, 22)
    end

    test "CRASH: */1 is equivalent to *" do
      assert {:ok, %{minute: m1}} = CronEngine.parse("*/1 * * * *")
      assert {:ok, %{minute: m2}} = CronEngine.parse("* * * * *")
      assert MapSet.equal?(m1, m2)
    end
  end

  describe "CronEngine.parse/1 — exact values" do
    test "CRASH: single minute value" do
      assert {:ok, %{minute: m}} = CronEngine.parse("30 * * * *")
      assert MapSet.new([30]) == m
    end

    test "CRASH: single hour value" do
      assert {:ok, %{hour: h}} = CronEngine.parse("0 14 * * *")
      assert MapSet.new([14]) == h
    end
  end

  describe "CronEngine.parse/1 — comma-separated lists" do
    test "CRASH: comma-separated minutes" do
      assert {:ok, %{minute: m}} = CronEngine.parse("0,15,30,45 * * * *")
      assert MapSet.new([0, 15, 30, 45]) == m
    end

    test "CRASH: comma-separated hours" do
      assert {:ok, %{hour: h}} = CronEngine.parse("0 9,12,17 * * *")
      assert MapSet.new([9, 12, 17]) == h
    end
  end

  describe "CronEngine.parse/1 — ranges" do
    test "CRASH: minute range 1-5" do
      assert {:ok, %{minute: m}} = CronEngine.parse("1-5 * * * *")
      assert MapSet.new([1, 2, 3, 4, 5]) == m
    end

    test "CRASH: hour range 9-17" do
      assert {:ok, %{hour: h}} = CronEngine.parse("0 9-17 * * *")
      assert MapSet.size(h) == 9
      assert MapSet.member?(h, 9)
      assert MapSet.member?(h, 17)
    end
  end

  describe "CronEngine.parse/1 — mixed syntax" do
    test "CRASH: range + list combination" do
      assert {:ok, %{minute: m}} = CronEngine.parse("1-3,15,30 * * * *")
      assert MapSet.new([1, 2, 3, 15, 30]) == m
    end

    test "CRASH: step + exact in different fields" do
      assert {:ok, fields} = CronEngine.parse("*/10 9,17 * * *")
      assert MapSet.size(fields.minute) == 6
      assert MapSet.new([9, 17]) == fields.hour
    end
  end

  describe "CronEngine.parse/1 — error cases" do
    test "CRASH: non-string input returns error" do
      assert {:error, msg} = CronEngine.parse(nil)
      assert is_binary(msg)
    end

    test "CRASH: wrong number of fields returns error" do
      assert {:error, msg} = CronEngine.parse("* * *")
      assert String.contains?(msg, "expected 5 fields")
    end

    test "CRASH: invalid step value returns error" do
      assert {:error, _msg} = CronEngine.parse("*/0 * * * *")
    end

    test "CRASH: out-of-range minute returns error" do
      assert {:error, _msg} = CronEngine.parse("60 * * * *")
    end

    test "CRASH: out-of-range month returns error" do
      assert {:error, _msg} = CronEngine.parse("0 0 1 13 *")
    end
  end

  describe "CronEngine.matches?/2" do
    test "CRASH: every-minute cron matches any DateTime" do
      {:ok, fields} = CronEngine.parse("* * * * *")
      dt = ~U[2026-03-24 14:30:00Z]
      assert CronEngine.matches?(fields, dt)
    end

    test "CRASH: exact minute matches" do
      {:ok, fields} = CronEngine.parse("30 14 * * *")
      assert CronEngine.matches?(fields, ~U[2026-03-24 14:30:00Z])
      refute CronEngine.matches?(fields, ~U[2026-03-24 14:31:00Z])
    end

    test "CRASH: specific month matches" do
      {:ok, fields} = CronEngine.parse("0 0 1 3 *")
      assert CronEngine.matches?(fields, ~U[2026-03-01 00:00:00Z])
      refute CronEngine.matches?(fields, ~U[2026-04-01 00:00:00Z])
    end

    test "CRASH: day-of-week mapping (Sunday=0)" do
      # 2026-03-22 is a Sunday
      {:ok, fields} = CronEngine.parse("0 0 * * 0")
      assert CronEngine.matches?(fields, ~U[2026-03-22 00:00:00Z])
      # 2026-03-23 is a Monday
      refute CronEngine.matches?(fields, ~U[2026-03-23 00:00:00Z])
    end

    test "CRASH: day-of-week Monday=1" do
      # 2026-03-23 is a Monday
      {:ok, fields} = CronEngine.parse("0 0 * * 1")
      assert CronEngine.matches?(fields, ~U[2026-03-23 00:00:00Z])
    end

    test "CRASH: day-of-week Saturday=6" do
      # 2026-03-28 is a Saturday
      {:ok, fields} = CronEngine.parse("0 0 * * 6")
      assert CronEngine.matches?(fields, ~U[2026-03-28 00:00:00Z])
    end

    test "CRASH: step on minutes matches correctly" do
      {:ok, fields} = CronEngine.parse("*/15 * * * *")
      assert CronEngine.matches?(fields, ~U[2026-03-24 14:00:00Z])
      assert CronEngine.matches?(fields, ~U[2026-03-24 14:30:00Z])
      refute CronEngine.matches?(fields, ~U[2026-03-24 14:07:00Z])
    end
  end
end
