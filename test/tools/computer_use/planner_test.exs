defmodule OptimalSystemAgent.Tools.Builtins.ComputerUse.PlannerTest do
  use ExUnit.Case, async: true

  alias OptimalSystemAgent.Tools.Builtins.ComputerUse.Planner

  # ---------------------------------------------------------------------------
  # Creation
  # ---------------------------------------------------------------------------

  describe "new/2" do
    test "creates planner in :perceive phase" do
      planner = Planner.new("click the Save button", [])
      assert planner.phase == :perceive
      assert planner.goal == "click the Save button"
      assert planner.replan_count == 0
      assert planner.actions == []
      assert planner.history == []
    end
  end

  # ---------------------------------------------------------------------------
  # State transitions
  # ---------------------------------------------------------------------------

  describe "step/1" do
    test "perceive → plan transition" do
      planner = Planner.new("click Save", [])

      # Simulate perceive: inject tree state
      planner = Planner.set_perception(planner, "[e0] button \"Save\" (500,300)")

      assert planner.phase == :plan
      assert planner.current_tree =~ "Save"
    end

    test "plan → execute transition" do
      planner =
        Planner.new("click Save", [])
        |> Planner.set_perception("[e0] button \"Save\" (500,300)")
        |> Planner.set_plan([
          %{"action" => "click", "x" => 500, "y" => 300}
        ])

      assert planner.phase == :execute
      assert length(planner.actions) == 1
    end

    test "execute → verify transition" do
      planner =
        Planner.new("click Save", [])
        |> Planner.set_perception("[e0] button \"Save\" (500,300)")
        |> Planner.set_plan([%{"action" => "click", "x" => 500, "y" => 300}])
        |> Planner.mark_executed(%{"action" => "click", "x" => 500, "y" => 300}, :ok)

      assert planner.phase == :verify
      assert length(planner.history) == 1
    end

    test "verify success with no more actions → done" do
      planner =
        Planner.new("click Save", [])
        |> Planner.set_perception("[e0] button \"Save\" (500,300)")
        |> Planner.set_plan([%{"action" => "click", "x" => 500, "y" => 300}])

      {action, planner} = Planner.next_action(planner)
      planner = Planner.mark_executed(planner, action, :ok)
      planner = Planner.verify_success(planner)

      assert planner.phase == :done
    end

    test "verify failure triggers replan" do
      planner =
        Planner.new("click Save", [])
        |> Planner.set_perception("[e0] button \"Save\" (500,300)")
        |> Planner.set_plan([%{"action" => "click", "x" => 500, "y" => 300}])
        |> Planner.mark_executed(%{"action" => "click", "x" => 500, "y" => 300}, :ok)
        |> Planner.verify_failure("Button not found after click")

      assert planner.phase == :perceive
      assert planner.replan_count == 1
    end

    test "verify with remaining actions continues execution" do
      planner =
        Planner.new("fill form", [])
        |> Planner.set_perception("[e0] textfield \"Email\" (200,150)")
        |> Planner.set_plan([
          %{"action" => "click", "x" => 200, "y" => 150},
          %{"action" => "type", "text" => "test@test.com"}
        ])

      # Pop first action, execute, verify
      {action, planner} = Planner.next_action(planner)
      planner = Planner.mark_executed(planner, action, :ok)
      planner = Planner.verify_success(planner)

      # Still has 1 action left
      assert planner.phase == :execute
      assert length(planner.actions) == 1
    end
  end

  # ---------------------------------------------------------------------------
  # Stuck detection
  # ---------------------------------------------------------------------------

  describe "stuck?/1" do
    test "not stuck with 0 replans" do
      planner = Planner.new("goal", [])
      refute Planner.stuck?(planner)
    end

    test "not stuck with 2 replans" do
      planner = %{Planner.new("goal", []) | replan_count: 2}
      refute Planner.stuck?(planner)
    end

    test "stuck after 3 replans" do
      planner = %{Planner.new("goal", []) | replan_count: 3}
      assert Planner.stuck?(planner)
    end
  end

  # ---------------------------------------------------------------------------
  # Next action
  # ---------------------------------------------------------------------------

  describe "next_action/1" do
    test "returns next action from plan" do
      planner =
        Planner.new("goal", [])
        |> Planner.set_perception("tree")
        |> Planner.set_plan([
          %{"action" => "click", "x" => 100, "y" => 200},
          %{"action" => "type", "text" => "hello"}
        ])

      {action, _planner} = Planner.next_action(planner)
      assert action == %{"action" => "click", "x" => 100, "y" => 200}
    end

    test "returns nil when no actions left" do
      planner =
        Planner.new("goal", [])
        |> Planner.set_perception("tree")
        |> Planner.set_plan([])

      assert {nil, _} = Planner.next_action(planner)
    end
  end

  # ---------------------------------------------------------------------------
  # Summary
  # ---------------------------------------------------------------------------

  describe "summary/1" do
    test "returns readable summary" do
      planner =
        Planner.new("click Save", [])
        |> Planner.set_perception("[e0] button \"Save\" (500,300)")
        |> Planner.set_plan([%{"action" => "click", "x" => 500, "y" => 300}])

      {action, planner} = Planner.next_action(planner)
      planner = Planner.mark_executed(planner, action, :ok)
      planner = Planner.verify_success(planner)

      summary = Planner.summary(planner)
      assert summary =~ "click Save"
      assert summary =~ "done"
    end
  end
end
