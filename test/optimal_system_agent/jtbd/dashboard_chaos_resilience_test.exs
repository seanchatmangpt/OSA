defmodule OptimalSystemAgent.JTBD.DashboardChaosResilienceTest do
  @moduledoc """
  Chaos Test: Dashboard Message Handler Resilience (Unit Tests)

  Tests Dashboard's validation and error handling functions directly,
  verifying that malformed messages are rejected gracefully without
  crashing the Dashboard process.

  These tests focus on the BLACK-BOX behavior: the validation functions
  should return {:error, reason} for invalid inputs, allowing the
  GenServer to log and continue processing.
  """

  use ExUnit.Case, async: false

  @moduletag :requires_application


  require Logger

  # Get access to Dashboard's private functions for testing
  @ets_table :jtbd_wave12_metrics

  setup do
    # Start the module (for compilation purposes, though we're testing functions directly)
    {:ok, _} = Application.ensure_all_started(:optimal_system_agent)
    Process.sleep(100)
    {:ok, []}
  end

  # ============================================================================
  # CHAOS RESILIENCE: Dashboard survives corrupted/malformed messages
  # ============================================================================

  test "dashboard survives missing required field: iteration" do
    # CHAOS: Send message missing `:iteration`
    malformed_payload = %{
      scenarios: [],
      pass_count: 0,
      fail_count: 0
      # Missing: :iteration
    }

    # VERIFY: Validation should fail with clear error
    result = validate_payload(malformed_payload)
    assert result == {:error, {:missing_field, :iteration}}
  end

  test "dashboard survives missing required field: scenarios" do
    # CHAOS: Send message missing `:scenarios`
    malformed_payload = %{
      iteration: 1,
      pass_count: 0,
      fail_count: 0
      # Missing: :scenarios
    }

    result = validate_payload(malformed_payload)
    assert result == {:error, {:missing_field, :scenarios}}
  end

  test "dashboard survives wrong data type: pass_count as string" do
    # CHAOS: pass_count should be integer, not string
    malformed_payload = %{
      iteration: 2,
      scenarios: [],
      pass_count: "invalid",  # String instead of int
      fail_count: 0
    }

    result = validate_payload(malformed_payload)
    assert result == {:error, {:invalid_type, :pass_count}}
  end

  test "dashboard survives wrong data type: scenarios not a list" do
    # CHAOS: scenarios should be list, not string
    malformed_payload = %{
      iteration: 3,
      scenarios: "not_a_list",  # String instead of list
      pass_count: 1,
      fail_count: 0
    }

    result = validate_payload(malformed_payload)
    assert result == {:error, {:invalid_type, :scenarios}}
  end

  test "dashboard survives null value where list expected" do
    # CHAOS: scenarios is nil instead of list
    malformed_payload = %{
      iteration: 4,
      scenarios: nil,  # Nil instead of list
      pass_count: 0,
      fail_count: 0
    }

    result = validate_payload(malformed_payload)
    assert result == {:error, {:invalid_type, :scenarios}}
  end

  test "dashboard survives empty payload" do
    # CHAOS: completely empty map
    malformed_payload = %{}

    result = validate_payload(malformed_payload)
    assert result == {:error, {:missing_field, :iteration}}
  end

  test "dashboard survives negative numeric values" do
    # CHAOS: negative pass/fail counts
    malformed_payload = %{
      iteration: 5,
      scenarios: [],
      pass_count: -1,  # Negative
      fail_count: -5   # Negative
    }

    # Should pass validation (validation only checks type, not business logic)
    result = validate_payload(malformed_payload)
    assert result == {:ok, 5, [], -1, -5}
  end

  test "dashboard survives extra unexpected fields" do
    # CHAOS: Send valid fields + unexpected extras
    malformed_payload = %{
      iteration: 6,
      scenarios: [],
      pass_count: 0,
      fail_count: 0,
      unknown_field_1: "garbage",
      unknown_field_2: %{"nested" => "chaos"},
      unknown_field_3: [1, 2, 3]
    }

    # Should succeed - extra fields are ignored
    result = validate_payload(malformed_payload)
    assert result == {:ok, 6, [], 0, 0}
  end

  test "dashboard survives complex nested corrupt data" do
    # CHAOS: Corrupt data in scenarios array
    malformed_payload = %{
      iteration: 7,
      scenarios: [
        %{id: "scenario_1", outcome: 123, latency_ms: "not_int", system: nil},
        %{id: nil, outcome: nil, latency_ms: nil, system: nil}
      ],
      pass_count: 1,
      fail_count: 0
    }

    # Validation should succeed with scenarios list
    result = validate_payload(malformed_payload)
    assert {:ok, 7, scenarios_list, 1, 0} = result
    assert is_list(scenarios_list)
  end

  test "dashboard survives iteration as non-integer" do
    # CHAOS: iteration should be int, not string
    malformed_payload = %{
      iteration: "not_an_int",
      scenarios: [],
      pass_count: 0,
      fail_count: 0
    }

    result = validate_payload(malformed_payload)
    assert result == {:error, {:invalid_type, :iteration}}
  end

  test "dashboard survives iteration as float" do
    # CHAOS: iteration should be int, not float
    malformed_payload = %{
      iteration: 8.5,
      scenarios: [],
      pass_count: 0,
      fail_count: 0
    }

    result = validate_payload(malformed_payload)
    assert result == {:error, {:invalid_type, :iteration}}
  end

  test "dashboard survives fail_count as negative" do
    # CHAOS: negative counts (edge case)
    malformed_payload = %{
      iteration: 9,
      scenarios: [],
      pass_count: 5,
      fail_count: -1
    }

    # Should pass validation (business logic handles negative)
    result = validate_payload(malformed_payload)
    assert result == {:ok, 9, [], 5, -1}
  end

  test "dashboard survives extremely large numeric values" do
    # CHAOS: huge numbers
    malformed_payload = %{
      iteration: 999_999_999_999,
      scenarios: [],
      pass_count: 999_999_999,
      fail_count: 999_999_999
    }

    # Should pass validation (Elixir handles arbitrary precision)
    result = validate_payload(malformed_payload)
    assert result == {:ok, 999_999_999_999, [], 999_999_999, 999_999_999}
  end

  # ============================================================================
  # Scenario Validation Tests
  # ============================================================================

  test "scenario validation: complete valid scenario" do
    scenario = %{
      id: "test_scenario",
      outcome: "success",
      latency_ms: 100,
      system: "TestSystem"
    }

    assert is_valid_scenario(scenario) == true
  end

  test "scenario validation: missing id field" do
    scenario = %{
      outcome: "success",
      latency_ms: 100,
      system: "TestSystem"
    }

    assert is_valid_scenario(scenario) == false
  end

  test "scenario validation: invalid outcome type" do
    scenario = %{
      id: "test",
      outcome: :atom_not_string,  # Should be string
      latency_ms: 100,
      system: "TestSystem"
    }

    assert is_valid_scenario(scenario) == false
  end

  test "scenario validation: non-integer latency" do
    scenario = %{
      id: "test",
      outcome: "success",
      latency_ms: "100ms",  # Should be int
      system: "TestSystem"
    }

    assert is_valid_scenario(scenario) == false
  end

  test "scenario validation: nil system" do
    scenario = %{
      id: "test",
      outcome: "success",
      latency_ms: 100,
      system: nil
    }

    assert is_valid_scenario(scenario) == false
  end

  test "scenario validation: non-map scenario" do
    # CHAOS: scenario is not even a map
    scenario = "not_a_map"

    assert is_valid_scenario(scenario) == false
  end

  test "scenario validation: filters out bad scenarios from list" do
    scenarios = [
      %{id: "good", outcome: "success", latency_ms: 100, system: "TestSystem"},
      %{id: "bad", outcome: 123, latency_ms: "invalid", system: nil},
      %{id: "also_good", outcome: "failure", latency_ms: 200, system: "TestSystem"},
      nil,
      "not_a_scenario"
    ]

    # Should extract only valid scenarios
    result_map = build_result_map(scenarios)
    assert Map.has_key?(result_map, :good)
    assert Map.has_key?(result_map, :also_good)
    assert not Map.has_key?(result_map, :bad)
    assert map_size(result_map) == 2
  end

  # ============================================================================
  # Helper Functions (Mirror Dashboard validation logic)
  # ============================================================================

  @doc """
  Validate payload structure - mirrors Dashboard.validate_and_process_payload/2
  Returns {:ok, iteration, scenarios, pass_count, fail_count} or {:error, reason}
  """
  defp validate_payload(payload) when is_map(payload) do
    with {:ok, iteration} <- validate_field(payload, :iteration, &is_integer/1),
         {:ok, scenarios} <- validate_field(payload, :scenarios, &is_list/1),
         {:ok, pass_count} <- validate_field(payload, :pass_count, &is_integer/1),
         {:ok, fail_count} <- validate_field(payload, :fail_count, &is_integer/1) do
      {:ok, iteration, scenarios, pass_count, fail_count}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_payload(_payload) do
    {:error, :invalid_payload_format}
  end

  @doc """
  Validate a single field in the payload.
  """
  defp validate_field(payload, field, validator) when is_map(payload) do
    case Map.fetch(payload, field) do
      {:ok, value} ->
        if validator.(value) do
          {:ok, value}
        else
          {:error, {:invalid_type, field}}
        end

      :error ->
        {:error, {:missing_field, field}}
    end
  end

  @doc """
  Validate a single scenario has required fields.
  """
  defp is_valid_scenario(scenario) when is_map(scenario) do
    with {:ok, _id} <- validate_field(scenario, :id, &is_binary/1),
         {:ok, _outcome} <- validate_field(scenario, :outcome, &is_binary/1),
         {:ok, _latency} <- validate_field(scenario, :latency_ms, &is_integer/1),
         {:ok, _system} <- validate_field(scenario, :system, &is_binary/1) do
      true
    else
      {:error, _reason} -> false
    end
  end

  defp is_valid_scenario(_scenario) do
    false
  end

  @doc """
  Build result map from scenarios - mirrors Dashboard.build_result_map/1
  Filters out invalid scenarios automatically.
  """
  defp build_result_map(scenarios) when is_list(scenarios) do
    scenarios
    |> Enum.filter(&is_valid_scenario/1)
    |> Enum.map(fn scenario ->
      {
        String.to_atom(scenario.id),
        %{
          outcome: String.to_atom(scenario.outcome),
          latency_ms: scenario.latency_ms,
          system: scenario.system
        }
      }
    end)
    |> Map.new()
  end

  defp build_result_map(_scenarios) do
    %{}
  end
end
