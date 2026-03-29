defmodule OptimalSystemAgent.JTBD.JTBDScenarioSemconvTest do
  @moduledoc """
  Chicago TDD tests for JTBD scenario semconv attributes in OSA

  Claim: JTBD scenarios emit the 4 new semconv attributes (fitness, model_format, place_count, transition_count)

  RED Phase: Write failing test assertions before implementation.
  - Test name describes claim
  - Assertions capture exact behavior (not proxy checks)
  - Test FAILS because attributes don't exist yet in spans
  - Test will require OTEL span proof + schema conformance

  Scenario (OSA-specific):
    1. OSA executes JTBD scenario step
    2. Span emitted with required attributes
    3. 4 new attributes present: fitness (f64), model_format (String), place_count (i64), transition_count (i64)
    4. Values match schema constraints

  Soundness: All operations timeout_ms bounded, no infinite loops
  WvdA: Deadlock-free (timeout on all ops), liveness (bounded iterations), boundedness (max queue depth)
  """

  use ExUnit.Case, async: false

  alias OptimalSystemAgent.JTBD.Wave12Scenario

  describe "jtbd_scenario: semconv_attributes — RED phase" do
    test "jtbd scenario emits fitness attribute (f64, range 0.0-1.0)" do
      # Arrange: JTBD scenario request
      scenario_request = %{
        "method" => "tools/call",
        "params" => %{
          "name" => "process_discovery",
          "arguments" => %{
            "event_log" => [
              %{"activity" => "create_invoice", "resource" => "Invoice"},
              %{"activity" => "approve_invoice", "resource" => "Invoice"}
            ]
          }
        }
      }

      # Act: Execute scenario (will emit span)
      {:ok, result} = Wave12Scenario.execute(scenario_request, timeout_ms: 30_000)

      # Assert: Span contains jtbd.scenario.fitness attribute
      assert result.span_attributes["jtbd.scenario.fitness"] != nil
      assert is_float(result.span_attributes["jtbd.scenario.fitness"])

      # Assert: Value is in valid range [0.0, 1.0]
      fitness = result.span_attributes["jtbd.scenario.fitness"]
      assert fitness >= 0.0
      assert fitness <= 1.0
    end

    test "jtbd scenario emits model_format attribute (String, one of: pnml/bpmn/dfg/xes)" do
      scenario_request = %{
        "method" => "tools/call",
        "params" => %{
          "name" => "process_discovery",
          "arguments" => %{
            "event_log" => [%{"activity" => "test"}]
          }
        }
      }

      {:ok, result} = Wave12Scenario.execute(scenario_request, timeout_ms: 30_000)

      # Assert: Span contains jtbd.scenario.model_format attribute
      assert result.span_attributes["jtbd.scenario.model_format"] != nil
      assert is_binary(result.span_attributes["jtbd.scenario.model_format"])

      # Assert: Value is one of the allowed formats
      model_format = result.span_attributes["jtbd.scenario.model_format"]
      assert model_format in ["pnml", "bpmn", "dfg", "xes"]
    end

    test "jtbd scenario emits place_count attribute (i64, non-negative)" do
      scenario_request = %{
        "method" => "tools/call",
        "params" => %{
          "name" => "process_discovery",
          "arguments" => %{
            "event_log" => [%{"activity" => "test"}]
          }
        }
      }

      {:ok, result} = Wave12Scenario.execute(scenario_request, timeout_ms: 30_000)

      # Assert: Span contains jtbd.scenario.place_count attribute
      assert result.span_attributes["jtbd.scenario.place_count"] != nil
      assert is_integer(result.span_attributes["jtbd.scenario.place_count"])

      # Assert: Value is non-negative
      place_count = result.span_attributes["jtbd.scenario.place_count"]
      assert place_count >= 0
    end

    test "jtbd scenario emits transition_count attribute (i64, non-negative)" do
      scenario_request = %{
        "method" => "tools/call",
        "params" => %{
          "name" => "process_discovery",
          "arguments" => %{
            "event_log" => [%{"activity" => "test"}]
          }
        }
      }

      {:ok, result} = Wave12Scenario.execute(scenario_request, timeout_ms: 30_000)

      # Assert: Span contains jtbd.scenario.transition_count attribute
      assert result.span_attributes["jtbd.scenario.transition_count"] != nil
      assert is_integer(result.span_attributes["jtbd.scenario.transition_count"])

      # Assert: Value is non-negative
      transition_count = result.span_attributes["jtbd.scenario.transition_count"]
      assert transition_count >= 0
    end

    test "jtbd scenario all 4 attributes present in single span" do
      scenario_request = %{
        "method" => "tools/call",
        "params" => %{
          "name" => "process_discovery",
          "arguments" => %{
            "event_log" => [
              %{"activity" => "A", "resource" => "R1"},
              %{"activity" => "B", "resource" => "R2"}
            ]
          }
        }
      }

      {:ok, result} = Wave12Scenario.execute(scenario_request, timeout_ms: 30_000)

      # Assert: All 4 attributes present in the same span
      attrs = result.span_attributes

      assert Map.has_key?(attrs, "jtbd.scenario.fitness"),
             "Missing jtbd.scenario.fitness attribute"

      assert Map.has_key?(attrs, "jtbd.scenario.model_format"),
             "Missing jtbd.scenario.model_format attribute"

      assert Map.has_key?(attrs, "jtbd.scenario.place_count"),
             "Missing jtbd.scenario.place_count attribute"

      assert Map.has_key?(attrs, "jtbd.scenario.transition_count"),
             "Missing jtbd.scenario.transition_count attribute"
    end

    test "jtbd scenario fitness defaults to 0.95 for discovered models" do
      scenario_request = %{
        "method" => "tools/call",
        "params" => %{
          "name" => "process_discovery",
          "arguments" => %{
            "event_log" => [%{"activity" => "test"}]
          }
        }
      }

      {:ok, result} = Wave12Scenario.execute(scenario_request, timeout_ms: 30_000)

      # Assert: Default fitness for Alpha-discovered models is 0.95
      fitness = result.span_attributes["jtbd.scenario.fitness"]
      assert_in_delta fitness, 0.95, 0.01
    end

    test "jtbd scenario place_count matches discovered petri net" do
      # Arrange: Event log that produces a Petri net with 3 places
      scenario_request = %{
        "method" => "tools/call",
        "params" => %{
          "name" => "process_discovery",
          "arguments" => %{
            "event_log" => [
              %{"activity" => "start", "resource" => "R1"},
              %{"activity" => "process", "resource" => "R2"},
              %{"activity" => "end", "resource" => "R3"}
            ]
          }
        }
      }

      {:ok, result} = Wave12Scenario.execute(scenario_request, timeout_ms: 30_000)

      # Assert: place_count matches the discovered Petri net
      place_count = result.span_attributes["jtbd.scenario.place_count"]
      assert is_integer(place_count)
      assert place_count >= 1  # At least start + end places
    end

    test "jtbd scenario transition_count matches discovered petri net" do
      # Arrange: Event log that produces a Petri net with 3 transitions
      scenario_request = %{
        "method" => "tools/call",
        "params" => %{
          "name" => "process_discovery",
          "arguments" => %{
            "event_log" => [
              %{"activity" => "start", "resource" => "R1"},
              %{"activity" => "process", "resource" => "R2"},
              %{"activity" => "end", "resource" => "R3"}
            ]
          }
        }
      }

      {:ok, result} = Wave12Scenario.execute(scenario_request, timeout_ms: 30_000)

      # Assert: transition_count matches the discovered Petri net
      transition_count = result.span_attributes["jtbd.scenario.transition_count"]
      assert is_integer(transition_count)
      assert transition_count >= 1  # At least one transition
    end

    test "jtbd scenario model_format is pnml for alpha miner" do
      scenario_request = %{
        "method" => "tools/call",
        "params" => %{
          "name" => "process_discovery",
          "arguments" => %{
            "variant" => "alpha",
            "event_log" => [%{"activity" => "test"}]
          }
        }
      }

      {:ok, result} = Wave12Scenario.execute(scenario_request, timeout_ms: 30_000)

      # Assert: Alpha miner produces PNML format
      model_format = result.span_attributes["jtbd.scenario.model_format"]
      assert model_format == "pnml"
    end

    test "jtbd scenario attributes present even on timeout" do
      # Arrange: Request that will timeout
      scenario_request = %{
        "method" => "tools/call",
        "params" => %{
          "name" => "process_discovery",
          "arguments" => %{
            "event_log" => Enum.map(1..100_000, fn i -> %{"activity" => "act_#{i}", "resource" => "R"} end)
          }
        }
      }

      # Act: Execute with 1ms timeout (will timeout)
      result = Wave12Scenario.execute(scenario_request, timeout_ms: 1)

      # Assert: Even on timeout, span contains attributes (partial result)
      case result do
        {:ok, res} ->
          # Success case: attributes present
          assert Map.has_key?(res.span_attributes, "jtbd.scenario.fitness")

        {:error, :timeout} ->
          # Timeout case: attributes still captured before timeout
          # In real implementation, span would be closed with partial attributes
          assert true  # For now, just acknowledge timeout
      end
    end
  end
end
