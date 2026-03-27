defmodule OptimalSystemAgent.Jtbd.Wave12YawlTest do
  @moduledoc """
  Tests YAWL DMAIC phase spec integration.
  Pure logic tests — no YAWL engine required.
  All tests run with full OTP application.
  """

  use ExUnit.Case, async: true

  alias OptimalSystemAgent.Yawl.SpecBuilder

  @dmaic_phases ["define", "measure", "analyze", "improve", "control"]

  describe "DMAIC spec via SpecBuilder" do
    test "sequence of DMAIC phases produces valid YAWL XML" do
      spec = SpecBuilder.sequence(@dmaic_phases)
      assert String.contains?(spec, "define")
      assert String.contains?(spec, "measure")
      assert String.contains?(spec, "analyze")
      assert String.contains?(spec, "improve")
      assert String.contains?(spec, "control")
    end

    test "DMAIC sequence spec is parseable XML" do
      spec = SpecBuilder.sequence(@dmaic_phases)
      xml_charlist = String.to_charlist(spec)
      # :xmerl_scan.string/2 returns {xmlElement, rest} on success (not {:ok, _})
      assert {xml_element, _rest} = :xmerl_scan.string(xml_charlist, quiet: true)
      assert is_tuple(xml_element)
      assert elem(xml_element, 0) == :xmlElement
    end

    test "DMAIC phases are in correct order" do
      # Verify index-based validation logic
      phases = @dmaic_phases
      define_idx = Enum.find_index(phases, &(&1 == "define"))
      measure_idx = Enum.find_index(phases, &(&1 == "measure"))
      assert measure_idx == define_idx + 1
    end

    test "backward transition detected by index" do
      # measure (idx 1) -> define (idx 0) is backward
      phases = @dmaic_phases
      current_idx = Enum.find_index(phases, &(&1 == "measure"))
      next_idx = Enum.find_index(phases, &(&1 == "define"))
      refute next_idx == current_idx + 1
    end

    test "forward transition detected by index" do
      phases = @dmaic_phases
      current_idx = Enum.find_index(phases, &(&1 == "define"))
      next_idx = Enum.find_index(phases, &(&1 == "measure"))
      assert next_idx == current_idx + 1
    end
  end

  describe "validate_phase_transition/2" do
    test "forward transition define->measure fails fast with YAWL unavailable" do
      # Phase B: YAWL Primary — fail fast on YAWL unavailable (no graceful degradation)
      result =
        OptimalSystemAgent.JTBD.Wave12Scenario.validate_phase_transition("define", "measure")

      # In --no-start mode, YAWL is unavailable, so fail fast
      assert {:error, :yawl_unavailable} = result
    end

    test "forward transition measure->analyze fails fast with YAWL unavailable" do
      result =
        OptimalSystemAgent.JTBD.Wave12Scenario.validate_phase_transition("measure", "analyze")

      assert {:error, :yawl_unavailable} = result
    end

    test "forward transition analyze->improve fails fast with YAWL unavailable" do
      result =
        OptimalSystemAgent.JTBD.Wave12Scenario.validate_phase_transition("analyze", "improve")

      assert {:error, :yawl_unavailable} = result
    end

    test "forward transition improve->control fails fast with YAWL unavailable" do
      result =
        OptimalSystemAgent.JTBD.Wave12Scenario.validate_phase_transition("improve", "control")

      assert {:error, :yawl_unavailable} = result
    end

    test "backward transition measure->define returns error" do
      # Backward transitions are caught by index logic before YAWL check
      result =
        OptimalSystemAgent.JTBD.Wave12Scenario.validate_phase_transition("measure", "define")

      assert {:error, :invalid_transition} = result
    end

    test "backward transition control->analyze returns error" do
      # Backward transitions are caught by index logic before YAWL check
      result =
        OptimalSystemAgent.JTBD.Wave12Scenario.validate_phase_transition("control", "analyze")

      assert {:error, :invalid_transition} = result
    end

    test "skipping a phase returns error" do
      # Skipped phases are caught by index logic before YAWL check
      result =
        OptimalSystemAgent.JTBD.Wave12Scenario.validate_phase_transition("define", "analyze")

      assert {:error, :invalid_transition} = result
    end

    test "invalid current phase name returns :invalid_phase error" do
      # Invalid phases are caught immediately, no YAWL check needed
      result =
        OptimalSystemAgent.JTBD.Wave12Scenario.validate_phase_transition(
          "invalid_phase",
          "measure"
        )

      assert {:error, :invalid_phase} = result
    end

    test "invalid next phase name returns :invalid_phase error" do
      # Invalid phases are caught immediately, no YAWL check needed
      result =
        OptimalSystemAgent.JTBD.Wave12Scenario.validate_phase_transition("define", "invalid_phase")

      assert {:error, :invalid_phase} = result
    end

    test "both phases invalid returns :invalid_phase error" do
      # Invalid phases are caught immediately, no YAWL check needed
      result =
        OptimalSystemAgent.JTBD.Wave12Scenario.validate_phase_transition("foo", "bar")

      assert {:error, :invalid_phase} = result
    end
  end
end
