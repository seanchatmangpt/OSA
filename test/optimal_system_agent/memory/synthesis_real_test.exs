defmodule OptimalSystemAgent.Memory.SynthesisRealTest do
  @moduledoc """
  Chicago TDD integration tests for Memory.Synthesis (check_threshold/2 only).

  NO MOCKS. Tests real token threshold classification.
  Every gap found is a real bug or missing behavior.
  """

  use ExUnit.Case, async: true

  @moduletag :integration

  alias OptimalSystemAgent.Memory.Synthesis

  describe "Synthesis.check_threshold/2" do
    test "CRASH: below warn returns :ok" do
      # Default warn is 0.80 * max_tokens
      # 100 / 1000 = 0.1 → below warn
      assert Synthesis.check_threshold(100, 1000) == :ok
    end

    test "CRASH: at warn threshold returns :warn" do
      # Default warn is 0.80 * max_tokens
      # 800 / 1000 = 0.80 → at warn
      assert Synthesis.check_threshold(800, 1000) == :warn
    end

    test "CRASH: at aggressive threshold returns :compact" do
      # Default aggressive is 0.85 * max_tokens
      # 850 / 1000 = 0.85 → at aggressive
      assert Synthesis.check_threshold(850, 1000) == :compact
    end

    test "CRASH: at emergency threshold returns :emergency" do
      # Default emergency is 0.95 * max_tokens
      # 950 / 1000 = 0.95 → at emergency
      assert Synthesis.check_threshold(950, 1000) == :emergency
    end

    test "CRASH: max_tokens 0 returns :ok" do
      # Guard: max_tokens > 0 required, else fallback returns :ok
      assert Synthesis.check_threshold(0, 0) == :ok
    end

    test "CRASH: negative usage returns :ok" do
      # -100 / 1000 = -0.1, below warn → :ok
      assert Synthesis.check_threshold(-100, 1000) == :ok
    end

    test "CRASH: nil usage returns :ok (gap fixed)" do
      # GAP FIXED: guard now requires is_integer, so nil falls through to catch-all :ok
      assert Synthesis.check_threshold(nil, 1000) == :ok
    end

    test "CRASH: nil max_tokens returns :ok" do
      # nil doesn't pass is_integer guard → falls through to catch-all :ok
      assert Synthesis.check_threshold(500, nil) == :ok
    end

    test "CRASH: both nil returns :ok" do
      assert Synthesis.check_threshold(nil, nil) == :ok
    end

    test "CRASH: above emergency returns :emergency" do
      assert Synthesis.check_threshold(999, 1000) == :emergency
    end

    test "CRASH: zero current_tokens returns :ok" do
      assert Synthesis.check_threshold(0, 1000) == :ok
    end
  end
end
