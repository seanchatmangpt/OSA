defmodule OptimalSystemAgent.Channels.NoiseFilterRealTest do
  @moduledoc """
  Chicago TDD integration tests for Channels.NoiseFilter.

  NO MOCKS. Tests real regex-based noise detection and threshold logic.
  Every gap found is a real bug or missing behavior.
  """

  use ExUnit.Case, async: true

  @moduletag :integration

  alias OptimalSystemAgent.Channels.NoiseFilter

  describe "NoiseFilter.check/2 — Tier 1 deterministic" do
    test "CRASH: empty string returns filtered" do
      assert {:filtered, ""} = NoiseFilter.check("")
    end

    test "CRASH: single character returns filtered" do
      assert {:filtered, ack} = NoiseFilter.check("a")
      assert is_binary(ack)
      assert byte_size(ack) > 0
    end

    test "CRASH: 'ok' returns filtered" do
      assert {:filtered, _ack} = NoiseFilter.check("ok")
    end

    test "CRASH: 'yes' returns filtered" do
      assert {:filtered, _ack} = NoiseFilter.check("yes")
    end

    test "CRASH: 'no' returns filtered" do
      assert {:filtered, _ack} = NoiseFilter.check("no")
    end

    test "CRASH: 'k' returns filtered" do
      assert {:filtered, _ack} = NoiseFilter.check("k")
    end

    test "CRASH: 'lol' returns filtered" do
      assert {:filtered, _ack} = NoiseFilter.check("lol")
    end

    test "CRASH: 'hmm' returns filtered" do
      assert {:filtered, _ack} = NoiseFilter.check("hmm")
    end

    test "CRASH: 'no problem' returns filtered" do
      assert {:filtered, _ack} = NoiseFilter.check("no problem")
    end

    test "CRASH: 'ok!' returns filtered" do
      assert {:filtered, _ack} = NoiseFilter.check("ok!")
    end

    test "CRASH: '...' returns filtered" do
      assert {:filtered, _ack} = NoiseFilter.check("...")
    end

    test "CRASH: '!!!' returns filtered" do
      assert {:filtered, _ack} = NoiseFilter.check("!!!")
    end

    test "CRASH: substantive message passes" do
      assert :pass = NoiseFilter.check("Can you help me fix the authentication bug?")
    end

    test "CRASH: whitespace-only returns filtered" do
      assert {:filtered, _ack} = NoiseFilter.check("   ")
    end

    test "CRASH: emoji-only returns filtered" do
      assert {:filtered, _ack} = NoiseFilter.check("👍")
    end
  end

  describe "NoiseFilter.check/2 — Tier 2 signal weight" do
    test "CRASH: low weight returns filtered" do
      assert {:filtered, _ack} = NoiseFilter.check("something", 0.1)
    end

    test "CRASH: medium weight returns clarify" do
      assert {:clarify, prompt} = NoiseFilter.check("something", 0.5)
      assert is_binary(prompt)
      assert String.contains?(prompt, "something")
    end

    test "CRASH: high weight passes" do
      assert :pass = NoiseFilter.check("something", 0.8)
    end

    test "CRASH: no weight passes" do
      assert :pass = NoiseFilter.check("something", nil)
    end

    test "CRASH: weight 0.0 returns filtered" do
      assert {:filtered, _ack} = NoiseFilter.check("anything", 0.0)
    end

    test "CRASH: weight 1.0 passes" do
      assert :pass = NoiseFilter.check("anything", 1.0)
    end
  end

  describe "NoiseFilter.weight_thresholds/0" do
    test "CRASH: returns map with all 3 thresholds" do
      thresholds = NoiseFilter.weight_thresholds()
      assert Map.has_key?(thresholds, :definitely_noise)
      assert Map.has_key?(thresholds, :likely_noise)
      assert Map.has_key?(thresholds, :uncertain)
    end

    test "CRASH: default thresholds are ordered" do
      thresholds = NoiseFilter.weight_thresholds()
      assert thresholds.definitely_noise < thresholds.likely_noise
      assert thresholds.likely_noise < thresholds.uncertain
    end
  end

  describe "NoiseFilter.calibrate_weights/2" do
    test "CRASH: insufficient data returns current thresholds" do
      result = NoiseFilter.calibrate_weights(%{"0.0-0.2": 10, "0.2-0.5": 5})
      assert result == NoiseFilter.weight_thresholds()
    end

    test "CRASH: high low ratio tightens threshold" do
      stats = %{"0.0-0.2": 50, "0.2-0.5": 10, "0.5-0.8": 5, "0.8-1.0": 2}
      result = NoiseFilter.calibrate_weights(stats)
      assert result.definitely_noise > NoiseFilter.weight_thresholds().definitely_noise
    end

    test "CRASH: low low ratio loosens threshold" do
      stats = %{"0.0-0.2": 5, "0.2-0.5": 40, "0.5-0.8": 30, "0.8-1.0": 20}
      result = NoiseFilter.calibrate_weights(stats)
      assert result.definitely_noise < NoiseFilter.weight_thresholds().definitely_noise
    end

    test "CRASH: respects min bound" do
      stats = %{"0.0-0.2": 5, "0.2-0.5": 40, "0.5-0.8": 30, "0.8-1.0": 20}
      opts = %{min_definitely_noise: 0.20, step: 0.50}
      result = NoiseFilter.calibrate_weights(stats, opts)
      assert result.definitely_noise >= 0.20
    end
  end

  describe "NoiseFilter.filter_and_reply/3" do
    test "CRASH: returns false for passing message" do
      refute NoiseFilter.filter_and_reply("real message", nil, fn _ -> nil end)
    end

    test "CRASH: returns true and calls reply for filtered" do
      assert NoiseFilter.filter_and_reply("ok", nil, fn msg ->
        assert is_binary(msg)
        assert byte_size(msg) > 0
      end)
    end

    test "CRASH: returns true for clarify" do
      result = NoiseFilter.filter_and_reply("test", 0.5, fn _ -> :ok end)
      assert result == true
    end

    test "CRASH: empty message returns true without calling reply" do
      result = NoiseFilter.filter_and_reply("", nil, fn _ -> flunk("should not be called") end)
      assert result == true
    end
  end
end
