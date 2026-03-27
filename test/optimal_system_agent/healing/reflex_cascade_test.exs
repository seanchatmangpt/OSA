defmodule OptimalSystemAgent.Healing.ReflexCascadeTest do
  use ExUnit.Case, async: true

  alias OptimalSystemAgent.Healing.ReflexArcs

  describe "detect_cascade/2" do
    test "detects cycle when proposed next already in chain" do
      assert {:error, :cascade_detected} = ReflexArcs.detect_cascade(["reflex_a", "reflex_b"], "reflex_a")
    end

    test "allows new reflex not in chain" do
      assert :ok = ReflexArcs.detect_cascade(["reflex_a"], "reflex_b")
    end

    test "detects max depth when chain reaches 5 or more" do
      chain = Enum.map(1..5, fn i -> "reflex_#{i}" end)
      assert {:error, :max_depth} = ReflexArcs.detect_cascade(chain, "reflex_6")
    end

    test "empty chain allows any next reflex" do
      assert :ok = ReflexArcs.detect_cascade([], "reflex_a")
    end

    test "chain of 4 is still allowed (below max depth)" do
      chain = Enum.map(1..4, fn i -> "reflex_#{i}" end)
      assert :ok = ReflexArcs.detect_cascade(chain, "reflex_5")
    end
  end
end
