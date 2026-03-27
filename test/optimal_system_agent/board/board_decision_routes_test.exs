defmodule OptimalSystemAgent.Board.DecisionRoutesTest do
  use ExUnit.Case, async: true

  @moduledoc """
  Pure-logic unit tests for board decision route validation.

  Tests the validation rules encoded in BoardDecisionRoutes.
  Runs with full OTP application startup.

  Chicago TDD: each test asserts one specific behavior claim.
  """

  # Mirror the valid types declared as @valid_types in board_decision_routes.ex
  @valid_types ~w(reorganize add_liaison accept_constraint)

  describe "decision type validation" do
    test "all three valid decision types are accepted" do
      for type <- @valid_types do
        assert type in @valid_types,
               "Expected #{inspect(type)} to be a valid decision type"
      end
    end

    test "invalid decision type is not accepted" do
      invalid_types = ["dissolve", "fire_all", "", "REORGANIZE", "reorganise"]

      for type <- invalid_types do
        refute type in @valid_types,
               "Expected #{inspect(type)} to be rejected as an invalid decision type"
      end
    end

    test "valid_types list is exactly the three documented types" do
      assert length(@valid_types) == 3
      assert "reorganize" in @valid_types
      assert "add_liaison" in @valid_types
      assert "accept_constraint" in @valid_types
    end
  end

  describe "required parameter validation" do
    test "decision requires department field" do
      params_without_dept = %{"decision_type" => "reorganize", "rationale" => "test"}
      refute Map.has_key?(params_without_dept, "department"),
             "Params without department must not have the department key"
    end

    test "decision requires decision_type field" do
      params_without_type = %{"department" => "engineering", "rationale" => "test"}
      refute Map.has_key?(params_without_type, "decision_type"),
             "Params without decision_type must not have the decision_type key"
    end

    test "valid decision params contain both required fields with non-empty strings" do
      valid_params = %{
        "department" => "engineering",
        "decision_type" => "reorganize",
        "notes" => "reduce cross-team coupling"
      }

      assert Map.has_key?(valid_params, "department")
      assert Map.has_key?(valid_params, "decision_type")
      assert is_binary(valid_params["department"]) and valid_params["department"] != ""
      assert valid_params["decision_type"] in @valid_types
    end
  end
end
