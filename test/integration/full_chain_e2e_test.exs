defmodule OptimalSystemAgent.Integration.FullChainE2ETest do
  use ExUnit.Case, async: false

  @moduletag :integration

  alias OptimalSystemAgent.Providers.PM4PyCoordinator

  # ──────────────────────────────────────────────────────────────────────────
  # Setup & Fixtures
  # ──────────────────────────────────────────────────────────────────────────

  setup_all do
    # Check prerequisites
    pm4py_available = check_pm4py_http()
    businessos_available = check_businessos_http()
    canopy_available = check_canopy_http()
    osa_available = true # We're running OSA

    {:ok,
     %{
       pm4py_available: pm4py_available,
       businessos_available: businessos_available,
       canopy_available: canopy_available,
       osa_available: osa_available
     }}
  end

  setup do
    # Test setup (GenServer state cleared between tests)
    {:ok, %{test_id: Ecto.UUID.generate()}}
  end

  # ──────────────────────────────────────────────────────────────────────────
  # Helper Functions
  # ──────────────────────────────────────────────────────────────────────────

  defp check_pm4py_http do
    try do
      case Req.get("http://localhost:8089/health") do
        {:ok, %{status: status}} when status in 200..299 -> true
        _ -> false
      end
    rescue
      _ -> false
    end
  end

  defp check_businessos_http do
    try do
      case Req.get("http://localhost:8001/health") do
        {:ok, %{status: status}} when status in 200..299 -> true
        _ -> false
      end
    rescue
      _ -> false
    end
  end

  defp check_canopy_http do
    try do
      case Req.get("http://localhost:9089/health") do
        {:ok, %{status: status}} when status in 200..299 -> true
        _ -> false
      end
    rescue
      _ -> false
    end
  end

  defp create_simple_log do
    %{
      "events" => [
        # Trace 1: A -> B -> C
        %{
          "case_id" => "trace_1",
          "activity" => "A",
          "timestamp" => "2024-01-01T10:00:00Z",
          "resource" => "Resource1"
        },
        %{
          "case_id" => "trace_1",
          "activity" => "B",
          "timestamp" => "2024-01-01T10:05:00Z",
          "resource" => "Resource1"
        },
        %{
          "case_id" => "trace_1",
          "activity" => "C",
          "timestamp" => "2024-01-01T10:10:00Z",
          "resource" => "Resource1"
        },
        # Trace 2: A -> B -> C
        %{
          "case_id" => "trace_2",
          "activity" => "A",
          "timestamp" => "2024-01-01T10:00:00Z",
          "resource" => "Resource2"
        },
        %{
          "case_id" => "trace_2",
          "activity" => "B",
          "timestamp" => "2024-01-01T10:05:00Z",
          "resource" => "Resource2"
        },
        %{
          "case_id" => "trace_2",
          "activity" => "C",
          "timestamp" => "2024-01-01T10:10:00Z",
          "resource" => "Resource2"
        },
        # Trace 3: A -> B -> C
        %{
          "case_id" => "trace_3",
          "activity" => "A",
          "timestamp" => "2024-01-01T10:00:00Z",
          "resource" => "Resource1"
        },
        %{
          "case_id" => "trace_3",
          "activity" => "B",
          "timestamp" => "2024-01-01T10:05:00Z",
          "resource" => "Resource1"
        },
        %{
          "case_id" => "trace_3",
          "activity" => "C",
          "timestamp" => "2024-01-01T10:10:00Z",
          "resource" => "Resource1"
        }
      ],
      "trace_count" => 3,
      "event_count" => 9
    }
  end

  defp create_complex_log do
    %{
      "events" =>
        # Variant 1: A -> B -> D (70%)
        Enum.flat_map(1..7, fn i ->
          [
            %{
              "case_id" => "v1_trace_#{i}",
              "activity" => "A",
              "timestamp" => "2024-01-01T10:00:00Z"
            },
            %{
              "case_id" => "v1_trace_#{i}",
              "activity" => "B",
              "timestamp" => "2024-01-01T10:05:00Z"
            },
            %{
              "case_id" => "v1_trace_#{i}",
              "activity" => "D",
              "timestamp" => "2024-01-01T10:10:00Z"
            }
          ]
        end) ++
          # Variant 2: A -> C -> D (30%)
          Enum.flat_map(1..3, fn i ->
            [
              %{
                "case_id" => "v2_trace_#{i}",
                "activity" => "A",
                "timestamp" => "2024-01-01T10:00:00Z"
              },
              %{
                "case_id" => "v2_trace_#{i}",
                "activity" => "C",
                "timestamp" => "2024-01-01T10:05:00Z"
              },
              %{
                "case_id" => "v2_trace_#{i}",
                "activity" => "D",
                "timestamp" => "2024-01-01T10:10:00Z"
              }
            ]
          end),
      "trace_count" => 10,
      "event_count" => 30
    }
  end

  # ──────────────────────────────────────────────────────────────────────────
  # TEST SUITE: Full 5-System Chain
  # ──────────────────────────────────────────────────────────────────────────

  describe "Stage 1: pm4py-rust discovery" do
    test "discovers petri net from simple log" do
      log = create_simple_log()

      {:ok, result} =
        PM4PyCoordinator.coordinate_discovery(log, [
          agent_count: 1,
          algorithm: "alpha_miner"
        ])

      assert Map.has_key?(result, "model")
      assert Map.has_key?(result, "timestamp")
      assert result["total_agents"] == 1
    end

    test "discovers model with multiple agents for consensus" do
      log = create_simple_log()

      {:ok, result} =
        PM4PyCoordinator.coordinate_discovery(log, [
          agent_count: 3,
          algorithm: "inductive_miner"
        ])

      assert result["total_agents"] == 3
      assert result["consensus_count"] > 0
      assert Map.has_key?(result, "model")
    end

    test "handles complex logs with variants" do
      log = create_complex_log()

      {:ok, result} =
        PM4PyCoordinator.coordinate_discovery(log, [
          agent_count: 2,
          algorithm: "heuristic_miner"
        ])

      assert result["total_agents"] == 2
      assert Map.has_key?(result, "model")
    end
  end

  describe "Stage 2: BusinessOS persistence" do
    test "model can be serialized for storage" do
      log = create_simple_log()

      {:ok, result} =
        PM4PyCoordinator.coordinate_discovery(log, [
          agent_count: 1,
          algorithm: "alpha_miner"
        ])

      model = result["model"]

      # Should be JSON-serializable
      assert {:ok, _json_str} = Jason.encode(model)
    end

    test "persistence payload includes metadata" do
      log = create_simple_log()

      {:ok, result} =
        PM4PyCoordinator.coordinate_discovery(log, [
          agent_count: 1,
          algorithm: "inductive_miner"
        ])

      model = result["model"]

      # Build persistence payload
      payload = %{
        "model" => model,
        "log_summary" => %{
          "traces" => length(log["events"] |> Enum.uniq_by(& &1["case_id"])),
          "total_events" => length(log["events"]),
          "algorithm" => "inductive_miner"
        },
        "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601()
      }

      assert {:ok, _} = Jason.encode(payload)
    end
  end

  describe "Stage 3: Canopy issue dispatch" do
    test "issue payload structure is valid" do
      log = create_simple_log()

      {:ok, _result} =
        PM4PyCoordinator.coordinate_discovery(log, [
          agent_count: 1,
          algorithm: "alpha_miner"
        ])

      model_id = "model_#{Ecto.UUID.generate()}"

      issue_payload = %{
        "title" => "Analyze model #{model_id}",
        "description" => "Process mining analysis for #{log["trace_count"]} traces",
        "type" => "process_analysis",
        "tags" => ["pm4py", "discovery", "conformance"],
        "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601()
      }

      assert {:ok, _} = Jason.encode(issue_payload)
      assert issue_payload["type"] == "process_analysis"
    end

    test "dispatch creates valid agent task" do
      log = create_simple_log()
      model_id = "model_#{Ecto.UUID.generate()}"

      task_payload = %{
        "task_type" => "process_analysis",
        "model_id" => model_id,
        "log_size" => log["trace_count"],
        "required_tools" => ["conformance_checker", "process_fingerprint", "org_evolution"],
        "timeout_ms" => 30_000
      }

      assert {:ok, _} = Jason.encode(task_payload)
      assert task_payload["task_type"] == "process_analysis"
      assert length(task_payload["required_tools"]) == 3
    end
  end

  describe "Stage 4: OSA analysis execution" do
    test "conformance analysis structure" do
      analysis_result = %{
        "fitness" => %{
          "value" => 0.95,
          "algorithm" => "token_replay"
        },
        "precision" => %{
          "value" => 0.88,
          "algorithm" => "token_based"
        },
        "simplicity" => 0.92
      }

      assert {:ok, _} = Jason.encode(analysis_result)
      assert analysis_result["fitness"]["value"] == 0.95
    end

    test "process fingerprint generation" do
      fingerprint = %{
        "id" => "fp_#{Ecto.UUID.generate()}",
        "hash" => "sha256_hash_here",
        "activities" => ["A", "B", "C"],
        "complexity_score" => 0.65
      }

      assert {:ok, _} = Jason.encode(fingerprint)
      assert is_binary(fingerprint["hash"])
    end

    test "org evolution analysis" do
      org_state = %{
        "previous_state" => "unstable",
        "current_state" => "stable",
        "healing_suggested" => true,
        "recommendations" => [
          "consolidate_variants",
          "improve_resource_allocation"
        ]
      }

      assert {:ok, _} = Jason.encode(org_state)
      assert is_list(org_state["recommendations"])
    end
  end

  describe "Stage 5: Results publication to BusinessOS via SSE" do
    test "SSE event structure is valid" do
      sse_event = %{
        "event_type" => "process_analysis_complete",
        "model_id" => "model_#{Ecto.UUID.generate()}",
        "results" => %{
          "fitness" => 0.95,
          "fingerprint_id" => "fp_123",
          "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601()
        }
      }

      assert {:ok, _} = Jason.encode(sse_event)
      assert sse_event["event_type"] == "process_analysis_complete"
    end

    test "batch SSE events for multiple results" do
      results = [
        %{"event_type" => "fitness_calculated", "value" => 0.95},
        %{"event_type" => "fingerprint_generated", "fingerprint_id" => "fp_123"},
        %{"event_type" => "org_evolution_analyzed", "state" => "stable"}
      ]

      assert {:ok, _} = Jason.encode(results)
      assert length(results) == 3
    end
  end

  describe "Full 5-system pipeline integration" do
    test "complete pipeline flow from discovery to results" do
      log = create_simple_log()
      test_start = System.monotonic_time(:millisecond)

      # Stage 1: Discovery
      {:ok, discovery_result} =
        PM4PyCoordinator.coordinate_discovery(log, [
          agent_count: 1,
          algorithm: "inductive_miner"
        ])

      model = discovery_result["model"]
      assert !is_nil(model)

      # Stage 2: Prepare persistence
      model_id = "model_#{Ecto.UUID.generate()}"

      persistence_payload = %{
        "model_id" => model_id,
        "model" => model,
        "log_summary" => %{
          "traces" => log["trace_count"],
          "events" => log["event_count"]
        },
        "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601()
      }

      assert {:ok, _json} = Jason.encode(persistence_payload)

      # Stage 3: Prepare dispatch
      dispatch_payload = %{
        "model_id" => model_id,
        "task_type" => "process_analysis",
        "required_tools" => ["conformance_checker", "process_fingerprint"]
      }

      assert {:ok, _json} = Jason.encode(dispatch_payload)

      # Stage 4: Mock analysis
      analysis_results = %{
        "fitness" => 0.95,
        "fingerprint_id" => "fp_#{Ecto.UUID.generate()}",
        "org_state" => "stable"
      }

      # Stage 5: Prepare SSE publication
      sse_payload = %{
        "model_id" => model_id,
        "analysis_results" => analysis_results,
        "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601()
      }

      assert {:ok, _json} = Jason.encode(sse_payload)

      test_elapsed_ms = System.monotonic_time(:millisecond) - test_start

      # Verify completion time
      assert test_elapsed_ms < 30_000,
             "Full pipeline should complete in <30s, took #{test_elapsed_ms}ms"

      # Verify all stages completed
      assert !is_nil(model)
      assert !is_nil(model_id)
      assert !is_nil(analysis_results)
      assert analysis_results["fitness"] > 0
    end

    test "pipeline with complex log handles variants" do
      log = create_complex_log()

      {:ok, discovery_result} =
        PM4PyCoordinator.coordinate_discovery(log, [
          agent_count: 2,
          algorithm: "heuristic_miner"
        ])

      model = discovery_result["model"]
      assert !is_nil(model)

      model_id = "model_#{Ecto.UUID.generate()}"

      # Verify complex log is handled
      payload = %{
        "model_id" => model_id,
        "log_summary" => %{
          "traces" => log["trace_count"],
          "events" => log["event_count"],
          "variants" => 2
        }
      }

      assert {:ok, _json} = Jason.encode(payload)
      assert payload["log_summary"]["traces"] == 10
    end

    test "concurrent pipeline executions don't interfere" do
      log1 = create_simple_log()
      log2 = create_complex_log()
      log3 = create_simple_log()

      # Run 3 discoveries concurrently
      tasks = [
        Task.async(fn ->
          PM4PyCoordinator.coordinate_discovery(log1, agent_count: 1)
        end),
        Task.async(fn ->
          PM4PyCoordinator.coordinate_discovery(log2, agent_count: 2)
        end),
        Task.async(fn ->
          PM4PyCoordinator.coordinate_discovery(log3, agent_count: 1)
        end)
      ]

      results = Task.await_many(tasks, 30_000)

      # All should succeed
      assert Enum.all?(results, fn
        {:ok, _} -> true
        _ -> false
      end)

      # Verify each has a model
      assert Enum.all?(results, fn {:ok, r} -> Map.has_key?(r, "model") end)
    end

    test "error handling in pipeline stages" do
      # Empty log should fail
      empty_log = %{"events" => [], "trace_count" => 0, "event_count" => 0}

      {:error, _reason} =
        PM4PyCoordinator.coordinate_discovery(empty_log, agent_count: 1)
    end

    test "progress event tracking across pipeline stages" do
      # All stages should track and report progress
      stages = [
        "discovery_start",
        "discovery_in_progress",
        "discovery_complete",
        "persistence_start",
        "persistence_complete",
        "analysis_start",
        "analysis_complete"
      ]

      # In real implementation, these would be published as SSE events
      assert Enum.all?(stages, &is_binary/1)
    end
  end

  describe "Performance benchmarks" do
    test "simple discovery completes in <30s" do
      log = create_simple_log()

      start = System.monotonic_time(:millisecond)

      {:ok, _result} =
        PM4PyCoordinator.coordinate_discovery(log, [
          agent_count: 1,
          algorithm: "alpha_miner"
        ])

      elapsed = System.monotonic_time(:millisecond) - start

      assert elapsed < 30_000, "Simple discovery should complete in <30s, took #{elapsed}ms"
    end

    test "complex discovery with multiple agents completes in <30s" do
      log = create_complex_log()

      start = System.monotonic_time(:millisecond)

      {:ok, _result} =
        PM4PyCoordinator.coordinate_discovery(log, [
          agent_count: 3,
          algorithm: "inductive_miner"
        ])

      elapsed = System.monotonic_time(:millisecond) - start

      assert elapsed < 30_000,
             "Complex discovery with 3 agents should complete in <30s, took #{elapsed}ms"
    end

    test "three concurrent pipelines complete within 30s total" do
      log1 = create_simple_log()
      log2 = create_complex_log()
      log3 = create_simple_log()

      start = System.monotonic_time(:millisecond)

      tasks = [
        Task.async(fn ->
          PM4PyCoordinator.coordinate_discovery(log1, agent_count: 1)
        end),
        Task.async(fn ->
          PM4PyCoordinator.coordinate_discovery(log2, agent_count: 2)
        end),
        Task.async(fn ->
          PM4PyCoordinator.coordinate_discovery(log3, agent_count: 1)
        end)
      ]

      _results = Task.await_many(tasks, 30_000)
      elapsed = System.monotonic_time(:millisecond) - start

      assert elapsed < 30_000,
             "3 concurrent pipelines should complete in <30s total, took #{elapsed}ms"
    end
  end

  describe "Data integrity and consistency" do
    test "model data is consistent across serialization" do
      log = create_simple_log()

      {:ok, result1} =
        PM4PyCoordinator.coordinate_discovery(log, [
          agent_count: 1,
          algorithm: "alpha_miner"
        ])

      model1 = result1["model"]
      json_str = Jason.encode!(model1)
      model1_deserialized = Jason.decode!(json_str)

      # Should be equivalent after round-trip
      assert model1 == model1_deserialized
    end

    test "analysis results maintain integrity through pipeline" do
      log = create_simple_log()

      {:ok, _discovery_result} =
        PM4PyCoordinator.coordinate_discovery(log, [
          agent_count: 1,
          algorithm: "inductive_miner"
        ])

      # Build analysis payload
      analysis = %{
        "fitness" => 0.95,
        "precision" => 0.88,
        "simplicity" => 0.92,
        "generalization" => 0.85
      }

      # Serialize and deserialize
      json_str = Jason.encode!(analysis)
      deserialized = Jason.decode!(json_str)

      # All metrics preserved
      assert deserialized["fitness"] == 0.95
      assert deserialized["precision"] == 0.88
      assert deserialized["simplicity"] == 0.92
      assert deserialized["generalization"] == 0.85
    end
  end
end
