defmodule OptimalSystemAgent.Agent.Loop.GuardrailsTest do
  @moduledoc """
  Unit tests for Guardrails module.

  Tests complex task detection, delegation requirements, and safety checks.
  """

  use ExUnit.Case, async: true

  alias OptimalSystemAgent.Agent.Loop.Guardrails

  describe "complex_coding_task?/1" do
    test "returns true for multi-file change requests" do
      assert Guardrails.complex_coding_task?("update the auth module and user service")
    end

    test "returns false for simple queries" do
      refute Guardrails.complex_coding_task?("what time is it?")
    end
  end

  describe "delegation_task?/1" do
    test "returns true for bulleted task lists" do
      # Requires 4+ bullets or delegation keywords
      input = "- Implement feature A for the auth module\n- Implement feature B for the user service\n- Implement feature C for the database layer\n- Implement feature D for the API gateway"
      assert Guardrails.delegation_task?(input)
    end

    test "returns true when delegation keywords present" do
      assert Guardrails.delegation_task?("delegate this task to the team")
    end

    test "returns false for single requests" do
      refute Guardrails.delegation_task?("just do this one thing")
    end
  end
end
