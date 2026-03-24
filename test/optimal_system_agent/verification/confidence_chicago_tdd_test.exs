defmodule OptimalSystemAgent.Verification.ConfidenceChicagoTDDTest do
  @moduledoc """
  Chicago TDD integration tests for Verification.Confidence.

  NO MOCKS. Tests real state transitions with real struct manipulation.
  Pure logic module — no GenServer, no external dependencies.

  Every gap found is a real bug or missing behavior.
  """

  use ExUnit.Case, async: true

  @moduletag :integration

  describe "Confidence — new/1" do
    test "CRASH: new tracker has empty results" do
      tracker = OptimalSystemAgent.Verification.Confidence.new()
      assert tracker.results == []
    end

    test "CRASH: new tracker uses default window of 5" do
      tracker = OptimalSystemAgent.Verification.Confidence.new()
      assert tracker.window == 5
    end

    test "CRASH: new tracker uses default escalate_threshold of 20.0" do
      tracker = OptimalSystemAgent.Verification.Confidence.new()
      assert tracker.escalate_threshold == 20.0
    end

    test "CRASH: custom window and threshold are respected" do
      tracker = OptimalSystemAgent.Verification.Confidence.new(window: 10, escalate_threshold: 50.0)
      assert tracker.window == 10
      assert tracker.escalate_threshold == 50.0
    end
  end

  describe "Confidence — update/2" do
    test "CRASH: update adds result to front of list" do
      tracker = OptimalSystemAgent.Verification.Confidence.new()
      updated = OptimalSystemAgent.Verification.Confidence.update(tracker, :pass)
      assert updated.results == [:pass]
    end

    test "CRASH: update preserves results in newest-first order" do
      tracker = OptimalSystemAgent.Verification.Confidence.new()
      updated =
        tracker
        |> OptimalSystemAgent.Verification.Confidence.update(:pass)
        |> OptimalSystemAgent.Verification.Confidence.update(:fail)
        |> OptimalSystemAgent.Verification.Confidence.update(:pass)

      assert updated.results == [:pass, :fail, :pass]
    end

    test "CRASH: window trims oldest results when exceeded" do
      tracker = OptimalSystemAgent.Verification.Confidence.new(window: 3)
      updated =
        Enum.reduce(1..5, tracker, fn _, acc ->
          OptimalSystemAgent.Verification.Confidence.update(acc, :pass)
        end)

      assert length(updated.results) == 3
      assert updated.results == [:pass, :pass, :pass]
    end

    test "CRASH: window=1 keeps only most recent result" do
      tracker = OptimalSystemAgent.Verification.Confidence.new(window: 1)
      updated =
        tracker
        |> OptimalSystemAgent.Verification.Confidence.update(:pass)
        |> OptimalSystemAgent.Verification.Confidence.update(:fail)

      assert updated.results == [:fail]
      assert length(updated.results) == 1
    end
  end

  describe "Confidence — score/1" do
    test "CRASH: empty tracker returns 0.0" do
      tracker = OptimalSystemAgent.Verification.Confidence.new()
      assert OptimalSystemAgent.Verification.Confidence.score(tracker) == 0.0
    end

    test "CRASH: all passes returns 100.0" do
      tracker =
        OptimalSystemAgent.Verification.Confidence.new()
        |> OptimalSystemAgent.Verification.Confidence.update(:pass)
        |> OptimalSystemAgent.Verification.Confidence.update(:pass)
        |> OptimalSystemAgent.Verification.Confidence.update(:pass)

      assert OptimalSystemAgent.Verification.Confidence.score(tracker) == 100.0
    end

    test "CRASH: all fails returns 0.0" do
      tracker =
        OptimalSystemAgent.Verification.Confidence.new()
        |> OptimalSystemAgent.Verification.Confidence.update(:fail)
        |> OptimalSystemAgent.Verification.Confidence.update(:fail)
        |> OptimalSystemAgent.Verification.Confidence.update(:fail)

      assert OptimalSystemAgent.Verification.Confidence.score(tracker) == 0.0
    end

    test "CRASH: mixed results produce correct ratio" do
      # 2 passes out of 5 = 40.0
      tracker =
        OptimalSystemAgent.Verification.Confidence.new()
        |> OptimalSystemAgent.Verification.Confidence.update(:fail)
        |> OptimalSystemAgent.Verification.Confidence.update(:pass)
        |> OptimalSystemAgent.Verification.Confidence.update(:fail)
        |> OptimalSystemAgent.Verification.Confidence.update(:pass)
        |> OptimalSystemAgent.Verification.Confidence.update(:fail)

      score = OptimalSystemAgent.Verification.Confidence.score(tracker)
      assert_in_delta score, 40.0, 0.001
    end

    test "CRASH: single pass returns 100.0" do
      tracker =
        OptimalSystemAgent.Verification.Confidence.new()
        |> OptimalSystemAgent.Verification.Confidence.update(:pass)

      assert OptimalSystemAgent.Verification.Confidence.score(tracker) == 100.0
    end

    test "CRASH: single fail returns 0.0" do
      tracker =
        OptimalSystemAgent.Verification.Confidence.new()
        |> OptimalSystemAgent.Verification.Confidence.update(:fail)

      assert OptimalSystemAgent.Verification.Confidence.score(tracker) == 0.0
    end
  end

  describe "Confidence — should_escalate?/1" do
    test "CRASH: empty tracker should escalate" do
      tracker = OptimalSystemAgent.Verification.Confidence.new()
      assert OptimalSystemAgent.Verification.Confidence.should_escalate?(tracker) == true
    end

    test "CRASH: all fails should escalate" do
      tracker =
        OptimalSystemAgent.Verification.Confidence.new()
        |> OptimalSystemAgent.Verification.Confidence.update(:fail)
        |> OptimalSystemAgent.Verification.Confidence.update(:fail)

      assert OptimalSystemAgent.Verification.Confidence.should_escalate?(tracker) == true
    end

    test "CRASH: high pass rate should not escalate" do
      tracker =
        OptimalSystemAgent.Verification.Confidence.new()
        |> OptimalSystemAgent.Verification.Confidence.update(:pass)
        |> OptimalSystemAgent.Verification.Confidence.update(:pass)
        |> OptimalSystemAgent.Verification.Confidence.update(:pass)
        |> OptimalSystemAgent.Verification.Confidence.update(:pass)

      assert OptimalSystemAgent.Verification.Confidence.should_escalate?(tracker) == false
    end

    test "CRASH: custom threshold is respected" do
      # 3 passes out of 5 = 60%, which is below 80% threshold
      tracker =
        OptimalSystemAgent.Verification.Confidence.new(escalate_threshold: 80.0)
        |> OptimalSystemAgent.Verification.Confidence.update(:pass)
        |> OptimalSystemAgent.Verification.Confidence.update(:pass)
        |> OptimalSystemAgent.Verification.Confidence.update(:pass)
        |> OptimalSystemAgent.Verification.Confidence.update(:fail)
        |> OptimalSystemAgent.Verification.Confidence.update(:fail)

      assert OptimalSystemAgent.Verification.Confidence.should_escalate?(tracker) == true
    end

    test "CRASH: score exactly at threshold does not escalate" do
      # 1 pass out of 5 = 20%, which equals the default threshold
      tracker =
        OptimalSystemAgent.Verification.Confidence.new(escalate_threshold: 20.0)
        |> OptimalSystemAgent.Verification.Confidence.update(:pass)
        |> OptimalSystemAgent.Verification.Confidence.update(:fail)
        |> OptimalSystemAgent.Verification.Confidence.update(:fail)
        |> OptimalSystemAgent.Verification.Confidence.update(:fail)
        |> OptimalSystemAgent.Verification.Confidence.update(:fail)

      # 20.0 < 20.0 is false, so should not escalate
      assert OptimalSystemAgent.Verification.Confidence.should_escalate?(tracker) == false
    end
  end

  describe "Confidence — trend/1" do
    test "CRASH: empty tracker returns :stable" do
      tracker = OptimalSystemAgent.Verification.Confidence.new()
      assert OptimalSystemAgent.Verification.Confidence.trend(tracker) == :stable
    end

    test "CRASH: single result returns :stable" do
      tracker =
        OptimalSystemAgent.Verification.Confidence.new()
        |> OptimalSystemAgent.Verification.Confidence.update(:pass)

      assert OptimalSystemAgent.Verification.Confidence.trend(tracker) == :stable
    end

    test "CRASH: improving trend when later half has more passes" do
      # chronological: [:fail, :fail, :pass, :pass, :pass]
      # results (newest-first): [:pass, :pass, :pass, :fail, :fail]
      # first_half (chronological): [:fail, :fail] = 0%
      # second_half (chronological): [:pass, :pass, :pass] = 100%
      # 100 > 0 + 10 → :improving
      tracker =
        OptimalSystemAgent.Verification.Confidence.new(window: 5)
        |> OptimalSystemAgent.Verification.Confidence.update(:fail)
        |> OptimalSystemAgent.Verification.Confidence.update(:fail)
        |> OptimalSystemAgent.Verification.Confidence.update(:pass)
        |> OptimalSystemAgent.Verification.Confidence.update(:pass)
        |> OptimalSystemAgent.Verification.Confidence.update(:pass)

      assert OptimalSystemAgent.Verification.Confidence.trend(tracker) == :improving
    end

    test "CRASH: declining trend when earlier half has more passes" do
      # chronological: [:pass, :pass, :pass, :fail, :fail]
      # results (newest-first): [:fail, :fail, :pass, :pass, :pass]
      # first_half (chronological): [:pass, :pass] = 100%
      # second_half (chronological): [:pass, :fail, :fail] = 33.3%
      # 100 > 33.3 + 10 → :declining
      tracker =
        OptimalSystemAgent.Verification.Confidence.new(window: 5)
        |> OptimalSystemAgent.Verification.Confidence.update(:pass)
        |> OptimalSystemAgent.Verification.Confidence.update(:pass)
        |> OptimalSystemAgent.Verification.Confidence.update(:pass)
        |> OptimalSystemAgent.Verification.Confidence.update(:fail)
        |> OptimalSystemAgent.Verification.Confidence.update(:fail)

      assert OptimalSystemAgent.Verification.Confidence.trend(tracker) == :declining
    end

    test "CRASH: stable trend when halves are similar" do
      # chronological: [:pass, :fail, :pass, :fail]
      # results (newest-first): [:fail, :pass, :fail, :pass]
      # first_half: [:pass, :fail] = 50%
      # second_half: [:pass, :fail] = 50%
      tracker =
        OptimalSystemAgent.Verification.Confidence.new(window: 4)
        |> OptimalSystemAgent.Verification.Confidence.update(:pass)
        |> OptimalSystemAgent.Verification.Confidence.update(:fail)
        |> OptimalSystemAgent.Verification.Confidence.update(:pass)
        |> OptimalSystemAgent.Verification.Confidence.update(:fail)

      assert OptimalSystemAgent.Verification.Confidence.trend(tracker) == :stable
    end

    test "CRASH: all passes across window is stable" do
      tracker =
        OptimalSystemAgent.Verification.Confidence.new(window: 4)
        |> OptimalSystemAgent.Verification.Confidence.update(:pass)
        |> OptimalSystemAgent.Verification.Confidence.update(:pass)
        |> OptimalSystemAgent.Verification.Confidence.update(:pass)
        |> OptimalSystemAgent.Verification.Confidence.update(:pass)

      assert OptimalSystemAgent.Verification.Confidence.trend(tracker) == :stable
    end
  end

  describe "Confidence — to_map/1" do
    test "CRASH: to_map returns all expected keys" do
      tracker =
        OptimalSystemAgent.Verification.Confidence.new(window: 5, escalate_threshold: 25.0)
        |> OptimalSystemAgent.Verification.Confidence.update(:pass)
        |> OptimalSystemAgent.Verification.Confidence.update(:fail)

      map = OptimalSystemAgent.Verification.Confidence.to_map(tracker)

      assert Map.has_key?(map, :score)
      assert Map.has_key?(map, :trend)
      assert Map.has_key?(map, :should_escalate)
      assert Map.has_key?(map, :result_count)
      assert Map.has_key?(map, :window)
      assert Map.has_key?(map, :escalate_threshold)
    end

    test "CRASH: to_map result_count matches actual results length" do
      tracker =
        OptimalSystemAgent.Verification.Confidence.new()
        |> OptimalSystemAgent.Verification.Confidence.update(:pass)
        |> OptimalSystemAgent.Verification.Confidence.update(:fail)
        |> OptimalSystemAgent.Verification.Confidence.update(:pass)

      map = OptimalSystemAgent.Verification.Confidence.to_map(tracker)
      assert map.result_count == 3
    end

    test "CRASH: to_map trend is an atom" do
      tracker =
        OptimalSystemAgent.Verification.Confidence.new()
        |> OptimalSystemAgent.Verification.Confidence.update(:pass)
        |> OptimalSystemAgent.Verification.Confidence.update(:fail)

      map = OptimalSystemAgent.Verification.Confidence.to_map(tracker)
      assert map.trend in [:improving, :stable, :declining]
    end

    test "CRASH: to_map score is a float" do
      tracker =
        OptimalSystemAgent.Verification.Confidence.new()
        |> OptimalSystemAgent.Verification.Confidence.update(:pass)
        |> OptimalSystemAgent.Verification.Confidence.update(:fail)

      map = OptimalSystemAgent.Verification.Confidence.to_map(tracker)
      assert is_float(map.score)
    end
  end
end
