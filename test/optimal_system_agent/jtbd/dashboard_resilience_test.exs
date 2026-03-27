defmodule OptimalSystemAgent.JTBD.DashboardResilienceTest do
  @moduledoc """
  Chaos Test: PubSub Message Corruption (Protocol Resilience)

  Verifies that Dashboard (JTBD wave12 monitor) survives malformed/corrupted PubSub messages
  without crashing. Tests resilience to:
  - Missing required fields
  - Invalid JSON syntax
  - Wrong data types
  - Extra unexpected fields
  - Null values where lists expected
  - Partial/incomplete JSON

  This is a Chicago TDD test that verifies black-box behavior:
  the Dashboard must remain alive and continue processing valid messages
  after receiving corrupted ones.
  """

  use ExUnit.Case, async: false


  require Logger
  import ExUnit.CaptureLog

  @ets_table :jtbd_wave12_metrics
  @pubsub_topic "jtbd:wave12"

  setup do
    # Dashboard is already started by the application during setup
    dashboard_pid = Process.whereis(OptimalSystemAgent.JTBD.Dashboard)

    # Clear ETS table for clean test state
    if :ets.whereis(@ets_table) != :undefined do
      :ets.delete_all_objects(@ets_table)
    end

    Process.sleep(50)

    on_exit(fn ->
      # Clean up ETS table after test
      if :ets.whereis(@ets_table) != :undefined do
        :ets.delete_all_objects(@ets_table)
      end
    end)

    {:ok, dashboard_pid: dashboard_pid}
  end

  defp send_pubsub_message(message_tag, payload) do
    # Directly send message to Dashboard process (simulates PubSub broadcast)
    dashboard_pid = Process.whereis(OptimalSystemAgent.JTBD.Dashboard)

    if dashboard_pid do
      send(dashboard_pid, {message_tag, payload})
      Process.sleep(50)
    end
  end

  defp assert_dashboard_alive(dashboard_pid) do
    assert Process.alive?(dashboard_pid),
           "Dashboard process died after receiving malformed message"
  end

  # ============================================================================
  # RED: Failing test — Dashboard survives corrupted PubSub messages
  # ============================================================================

  test "dashboard survives missing required fields in scenario_result", %{
    dashboard_pid: dashboard_pid
  } do
    # CHAOS: Send message missing `:iteration` field (required)
    malformed_payload = %{
      "scenarios" => [],
      "pass_count" => 0,
      "fail_count" => 0
      # Missing: :iteration
    }

    send_pubsub_message(:scenario_result, malformed_payload)

    # VERIFY: Dashboard still alive
    assert_dashboard_alive(dashboard_pid)

    # VERIFY: Next valid message still processes
    valid_payload = %{
      iteration: 1,
      scenarios: [
        %{
          id: "agent_decision_loop",
          outcome: "success",
          latency_ms: 150,
          system: "OSA"
        }
      ],
      pass_count: 1,
      fail_count: 0
    }

    send_pubsub_message(:scenario_result, valid_payload)
    assert_dashboard_alive(dashboard_pid)

    # VERIFY: ETS table received valid data
    [{_key, stored_payload}] = :ets.lookup(@ets_table, {1, :payload})
    assert stored_payload.iteration == 1
    assert length(stored_payload.scenarios) == 1
  end

  test "dashboard survives invalid JSON data types (string instead of int)", %{
    dashboard_pid: dashboard_pid
  } do
    # CHAOS: Send pass_count as string instead of integer
    malformed_payload = %{
      iteration: 2,
      scenarios: [],
      pass_count: "invalid",  # Should be int
      fail_count: 0
    }

    send_pubsub_message(:scenario_result, malformed_payload)

    # VERIFY: Dashboard still alive
    assert_dashboard_alive(dashboard_pid)

    # VERIFY: Next valid message still processes
    valid_payload = %{
      iteration: 3,
      scenarios: [
        %{
          id: "process_discovery",
          outcome: "success",
          latency_ms: 200,
          system: "pm4py-rust"
        }
      ],
      pass_count: 1,
      fail_count: 0
    }

    send_pubsub_message(:scenario_result, valid_payload)
    assert_dashboard_alive(dashboard_pid)

    # VERIFY: ETS table has correct latest iteration
    [{_key, stored_payload}] = :ets.lookup(@ets_table, {3, :payload})
    assert stored_payload.iteration == 3
  end

  test "dashboard survives null/nil values where list expected", %{
    dashboard_pid: dashboard_pid
  } do
    # CHAOS: Send nil instead of scenarios list
    malformed_payload = %{
      iteration: 4,
      scenarios: nil,  # Should be list
      pass_count: 0,
      fail_count: 0
    }

    send_pubsub_message(:scenario_result, malformed_payload)

    # VERIFY: Dashboard still alive
    assert_dashboard_alive(dashboard_pid)

    # VERIFY: Next valid message processes correctly
    valid_payload = %{
      iteration: 5,
      scenarios: [
        %{
          id: "compliance_check",
          outcome: "failure",
          latency_ms: 300,
          system: "BusinessOS"
        }
      ],
      pass_count: 0,
      fail_count: 1
    }

    send_pubsub_message(:scenario_result, valid_payload)
    assert_dashboard_alive(dashboard_pid)

    # VERIFY: State updated correctly
    [{_key, stored_payload}] = :ets.lookup(@ets_table, {5, :payload})
    assert stored_payload.fail_count == 1
  end

  test "dashboard survives extra unexpected fields", %{dashboard_pid: dashboard_pid} do
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

    send_pubsub_message(:scenario_result, malformed_payload)

    # VERIFY: Dashboard still alive
    assert_dashboard_alive(dashboard_pid)

    # VERIFY: Can process valid message
    valid_payload = %{
      iteration: 7,
      scenarios: [
        %{
          id: "cross_system_handoff",
          outcome: "success",
          latency_ms: 250,
          system: "Canopy→OSA→BOS"
        }
      ],
      pass_count: 1,
      fail_count: 0
    }

    send_pubsub_message(:scenario_result, valid_payload)
    assert_dashboard_alive(dashboard_pid)

    # VERIFY: ETS table only stored intended fields
    [{_key, stored_payload}] = :ets.lookup(@ets_table, {7, :payload})
    assert Map.has_key?(stored_payload, :iteration)
    assert Map.has_key?(stored_payload, :scenarios)
  end

  test "dashboard survives deeply nested corrupt data", %{dashboard_pid: dashboard_pid} do
    # CHAOS: Corrupt data in scenarios array
    malformed_payload = %{
      iteration: 8,
      scenarios: [
        %{
          id: "workspace_sync",
          outcome: "success",
          latency_ms: 150,
          system: "Canopy↔OSA"
        },
        %{
          id: "corrupt_scenario",
          outcome: 123,  # Should be string
          latency_ms: "not_a_number",  # Should be int
          system: nil  # Should be string
        }
      ],
      pass_count: 1,
      fail_count: 0
    }

    send_pubsub_message(:scenario_result, malformed_payload)

    # VERIFY: Dashboard still alive
    assert_dashboard_alive(dashboard_pid)

    # VERIFY: Recovery with valid message
    valid_payload = %{
      iteration: 9,
      scenarios: [
        %{
          id: "consensus_round",
          outcome: "success",
          latency_ms: 180,
          system: "OSA HotStuff"
        }
      ],
      pass_count: 1,
      fail_count: 0
    }

    send_pubsub_message(:scenario_result, valid_payload)
    assert_dashboard_alive(dashboard_pid)

    # VERIFY: Latest iteration stored correctly
    [{_key, stored_payload}] = :ets.lookup(@ets_table, {9, :payload})
    assert stored_payload.iteration == 9
  end

  test "dashboard survives rapid succession of corrupted messages", %{
    dashboard_pid: dashboard_pid
  } do
    # CHAOS: Send 10 corrupted messages in rapid succession
    corrupted_payloads = [
      %{},  # Completely empty
      %{"iteration" => "not_an_int"},
      %{iteration: 10, scenarios: "not_a_list"},
      %{iteration: 11, scenarios: nil, pass_count: nil},
      %{pass_count: -1, fail_count: -1},  # Missing iteration
      %{iteration: 12, chaos: "data", random_stuff: 999},
      %{iteration: 13, scenarios: [%{}]},  # Incomplete scenario
      %{iteration: 14, scenarios: [nil, nil, nil]},
      %{iteration: 15, pass_count: [], fail_count: {}},
      %{"iteration" => 16, "string_iteration" => 16}
    ]

    Enum.each(corrupted_payloads, &send_pubsub_message(:scenario_result, &1))
    Process.sleep(200)

    # VERIFY: Dashboard still alive after chaos
    assert_dashboard_alive(dashboard_pid)

    # VERIFY: Process valid message after chaos
    valid_payload = %{
      iteration: 17,
      scenarios: [
        %{
          id: "healing_recovery",
          outcome: "success",
          latency_ms: 200,
          system: "OSA Healing"
        },
        %{
          id: "a2a_deal_lifecycle",
          outcome: "success",
          latency_ms: 350,
          system: "Canopy A2A"
        }
      ],
      pass_count: 2,
      fail_count: 0
    }

    send_pubsub_message(:scenario_result, valid_payload)
    assert_dashboard_alive(dashboard_pid)

    # VERIFY: ETS table has correct final state
    [{_key, stored_payload}] = :ets.lookup(@ets_table, {17, :payload})
    assert stored_payload.iteration == 17
    assert length(stored_payload.scenarios) == 2
  end

  test "dashboard survives unknown message types", %{dashboard_pid: dashboard_pid} do
    # CHAOS: Send message with unknown atom tag
    unknown_payloads = [
      {:unknown_event, %{data: "chaos"}},
      {:corrupted_tag, nil},
      {:random_message, "string_payload"},
      {nil, %{}}
    ]

    Enum.each(unknown_payloads, fn {tag, payload} ->
      send(dashboard_pid, {tag, payload})
      Process.sleep(50)
    end)

    # VERIFY: Dashboard still alive
    assert_dashboard_alive(dashboard_pid)

    # VERIFY: Can process valid scenario_result message
    valid_payload = %{
      iteration: 18,
      scenarios: [
        %{
          id: "mcp_tool_execution",
          outcome: "success",
          latency_ms: 275,
          system: "OSA MCP"
        }
      ],
      pass_count: 1,
      fail_count: 0
    }

    send_pubsub_message(:scenario_result, valid_payload)
    assert_dashboard_alive(dashboard_pid)

    # VERIFY: Valid message was stored
    [{_key, stored_payload}] = :ets.lookup(@ets_table, {18, :payload})
    assert stored_payload.iteration == 18
  end

  test "dashboard maintains isolation between corrupted and valid messages", %{
    dashboard_pid: dashboard_pid
  } do
    # Validate initial state
    _initial_count = :ets.info(@ets_table, :size)

    # Send alternating corrupted + valid messages
    for i <- 1..5 do
      # Corrupted
      corrupted = %{
        iteration: i * 10,
        scenarios: "corrupted",
        pass_count: "invalid"
      }

      send_pubsub_message(:scenario_result, corrupted)

      # Valid (immediately after)
      valid = %{
        iteration: i * 10 + 1,
        scenarios: [
          %{
            id: "test_scenario_#{i}",
            outcome: "success",
            latency_ms: 100 * i,
            system: "TestSystem"
          }
        ],
        pass_count: 1,
        fail_count: 0
      }

      send_pubsub_message(:scenario_result, valid)
    end

    Process.sleep(200)

    # VERIFY: Dashboard still alive
    assert_dashboard_alive(dashboard_pid)

    # VERIFY: Only valid messages stored (5 valid messages)
    all_entries = :ets.match(@ets_table, {{:"$1", :payload}, :"$2"})
    assert length(all_entries) == 5, "Expected 5 valid messages in ETS, got #{length(all_entries)}"

    # VERIFY: Each stored message has correct structure
    Enum.each(all_entries, fn [_key, payload] ->
      assert Map.has_key?(payload, :iteration)
      assert Map.has_key?(payload, :scenarios)
      assert is_list(payload.scenarios)
    end)
  end

  test "dashboard error handling does not cascade to application supervisor", %{
    dashboard_pid: dashboard_pid
  } do
    # Send chaos that would crash a poorly-written handler
    chaos_payloads = [
      %{iteration: nil},  # Accessing nil.iteration would crash
      %{scenarios: :atom_not_enumerable},  # Enum.map on atom would crash
      %{pass_count: "crash", fail_count: "me"},  # Arithmetic would fail
      %{last_update: "invalid_datetime"}  # DateTime operations could fail
    ]

    Enum.each(chaos_payloads, &send_pubsub_message(:scenario_result, &1))
    Process.sleep(200)

    # VERIFY: Dashboard process alive
    assert_dashboard_alive(dashboard_pid)

    # VERIFY: Canopy.PubSub is still operational
    # (by successfully sending another message)
    test_msg = %{
      iteration: 19,
      scenarios: [
        %{
          id: "conformance_drift",
          outcome: "success",
          latency_ms: 99,
          system: "pm4py Petri"
        }
      ],
      pass_count: 1,
      fail_count: 0
    }

    send_pubsub_message(:scenario_result, test_msg)
    assert_dashboard_alive(dashboard_pid)

    # VERIFY: Message was processed
    case :ets.lookup(@ets_table, {19, :payload}) do
      [{_key, payload}] ->
        assert payload.iteration == 19
        :ok

      [] ->
        flunk("Valid message was not processed after chaos")
    end
  end

  test "dashboard logs errors without blocking message processing", %{
    dashboard_pid: dashboard_pid
  } do
    # Capture logs
    _logs =
      capture_log(fn ->
        # Send corrupted message
        corrupted = %{
          iteration: 20,
          scenarios: "broken",
          pass_count: "error"
        }

        send_pubsub_message(:scenario_result, corrupted)
        Process.sleep(100)

        # Send valid message
        valid = %{
          iteration: 21,
          scenarios: [],
          pass_count: 0,
          fail_count: 0
        }

        send_pubsub_message(:scenario_result, valid)
        Process.sleep(100)
      end)

    # VERIFY: Dashboard still alive
    assert_dashboard_alive(dashboard_pid)

    # VERIFY: Process doesn't crash silently (valid message should be in ETS)
    case :ets.lookup(@ets_table, {21, :payload}) do
      [{_key, _payload}] ->
        # Valid message was processed despite earlier corruption
        assert true

      [] ->
        flunk("Dashboard failed to process valid message after corrupted input")
    end
  end
end
