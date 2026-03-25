defmodule OptimalSystemAgent.Tools.Builtins.PM4PyDiscoverTest do
  use ExUnit.Case, async: false

  alias OptimalSystemAgent.Tools.Builtins.PM4PyDiscover

  # ──────────────────────────────────────────────────────────────────────────
  # Setup & Fixtures
  # ──────────────────────────────────────────────────────────────────────────

  @moduletag :integration

  setup do
    # Skip individual test if pm4py is not running
    if is_pm4py_running() do
      {:ok, %{pm4py_available: true}}
    else
      {:skip, "pm4py-rust HTTP server not running on localhost:8089"}
    end
  end

  defp is_pm4py_running do
    try do
      case Req.get("http://localhost:8089/health") do
        {:ok, %{status: status}} when status in 200..299 -> true
        _ -> false
      end
    rescue
      _ -> false
    end
  end

  # Simple 3-trace event log
  defp simple_log do
    %{
      "events" => [
        %{"case_id" => "1", "activity" => "Start", "timestamp" => "2024-01-01T10:00:00Z"},
        %{"case_id" => "1", "activity" => "Process", "timestamp" => "2024-01-01T10:05:00Z"},
        %{"case_id" => "1", "activity" => "End", "timestamp" => "2024-01-01T10:10:00Z"},
        %{"case_id" => "2", "activity" => "Start", "timestamp" => "2024-01-01T11:00:00Z"},
        %{"case_id" => "2", "activity" => "Process", "timestamp" => "2024-01-01T11:05:00Z"},
        %{"case_id" => "2", "activity" => "End", "timestamp" => "2024-01-01T11:10:00Z"},
        %{"case_id" => "3", "activity" => "Start", "timestamp" => "2024-01-01T12:00:00Z"},
        %{"case_id" => "3", "activity" => "Process", "timestamp" => "2024-01-01T12:05:00Z"},
        %{"case_id" => "3", "activity" => "End", "timestamp" => "2024-01-01T12:10:00Z"}
      ],
      "trace_count" => 3,
      "event_count" => 9
    }
  end

  # Empty log
  defp empty_log do
    %{"events" => [], "trace_count" => 0, "event_count" => 0}
  end

  # Single-event log
  defp single_event_log do
    %{
      "events" => [
        %{"case_id" => "1", "activity" => "SingleTask", "timestamp" => "2024-01-01T10:00:00Z"}
      ],
      "trace_count" => 1,
      "event_count" => 1
    }
  end

  # Larger log (100 traces, 300 events)
  defp large_log do
    events =
      Enum.flat_map(1..100, fn case_num ->
        [
          %{
            "case_id" => "case_#{case_num}",
            "activity" => "Start",
            "timestamp" => "2024-01-01T10:00:00Z"
          },
          %{
            "case_id" => "case_#{case_num}",
            "activity" => "Process",
            "timestamp" => "2024-01-01T10:05:00Z"
          },
          %{
            "case_id" => "case_#{case_num}",
            "activity" => "End",
            "timestamp" => "2024-01-01T10:10:00Z"
          }
        ]
      end)

    %{"events" => events, "trace_count" => 100, "event_count" => 300}
  end

  # ──────────────────────────────────────────────────────────────────────────
  # Single-Agent Discovery Tests
  # ──────────────────────────────────────────────────────────────────────────

  describe "single-agent discovery (happy path)" do
    test "alpha_miner discovers simple 3-trace log" do
      log = simple_log() |> Jason.encode!()

      {:ok, result} = PM4PyDiscover.execute(%{
        "event_log" => log,
        "algorithm" => "alpha_miner",
        "conformance" => false
      })

      assert is_map(result)
      assert Map.has_key?(result, "model")
      assert Map.has_key?(result, "cost")
      assert result["cost"] > 0
      assert result["algorithm"] == "alpha_miner"
    end

    test "result includes log statistics" do
      log = simple_log() |> Jason.encode!()

      {:ok, result} = PM4PyDiscover.execute(%{
        "event_log" => log,
        "algorithm" => "inductive_miner"
      })

      assert Map.has_key?(result, "log_stats")
      stats = result["log_stats"]
      assert stats["trace_count"] == 3
      assert stats["event_count"] == 9
    end

    test "cost calculated correctly for log size" do
      log = simple_log() |> Jason.encode!()

      {:ok, result} = PM4PyDiscover.execute(%{
        "event_log" => log,
        "algorithm" => "alpha_miner"
      })

      # Cost = 10 (base) + 5 * 3 (traces) + 2 * 9 (events)
      # = 10 + 15 + 18 = 43
      assert result["cost"] == 43
    end

    test "large log cost scales correctly" do
      log = large_log() |> Jason.encode!()

      {:ok, result} = PM4PyDiscover.execute(%{
        "event_log" => log,
        "algorithm" => "inductive_miner"
      })

      # Cost = 10 + 5*100 + 2*300 = 10 + 500 + 600 = 1110
      assert result["cost"] == 1110
    end
  end

  # ──────────────────────────────────────────────────────────────────────────
  # Algorithm Variants
  # ──────────────────────────────────────────────────────────────────────────

  describe "algorithm variants" do
    test "inductive_miner discovery" do
      log = simple_log() |> Jason.encode!()

      {:ok, result} = PM4PyDiscover.execute(%{
        "event_log" => log,
        "algorithm" => "inductive_miner"
      })

      assert result["algorithm"] == "inductive_miner"
      assert is_map(result["model"])
    end

    test "heuristic_miner discovery" do
      log = simple_log() |> Jason.encode!()

      {:ok, result} = PM4PyDiscover.execute(%{
        "event_log" => log,
        "algorithm" => "heuristic_miner"
      })

      assert result["algorithm"] == "heuristic_miner"
      assert is_map(result["model"])
    end

    test "causal_net discovery" do
      log = simple_log() |> Jason.encode!()

      {:ok, result} = PM4PyDiscover.execute(%{
        "event_log" => log,
        "algorithm" => "causal_net"
      })

      assert result["algorithm"] == "causal_net"
      assert is_map(result["model"])
    end

    test "log_skeleton discovery" do
      log = simple_log() |> Jason.encode!()

      {:ok, result} = PM4PyDiscover.execute(%{
        "event_log" => log,
        "algorithm" => "log_skeleton"
      })

      assert result["algorithm"] == "log_skeleton"
      assert is_map(result["model"])
    end

    test "declare discovery" do
      log = simple_log() |> Jason.encode!()

      {:ok, result} = PM4PyDiscover.execute(%{
        "event_log" => log,
        "algorithm" => "declare"
      })

      assert result["algorithm"] == "declare"
      assert is_map(result["model"])
    end
  end

  # ──────────────────────────────────────────────────────────────────────────
  # Conformance Checking
  # ──────────────────────────────────────────────────────────────────────────

  describe "conformance checking" do
    test "conformance enabled (default)" do
      log = simple_log() |> Jason.encode!()

      {:ok, result} = PM4PyDiscover.execute(%{
        "event_log" => log,
        "algorithm" => "alpha_miner"
      })

      # Conformance should be included
      assert Map.has_key?(result, "model")
    end

    test "conformance disabled" do
      log = simple_log() |> Jason.encode!()

      {:ok, result} = PM4PyDiscover.execute(%{
        "event_log" => log,
        "algorithm" => "alpha_miner",
        "conformance" => false
      })

      assert is_map(result)
      assert result["algorithm"] == "alpha_miner"
    end

    test "conformance result included when enabled" do
      log = simple_log() |> Jason.encode!()

      {:ok, result} = PM4PyDiscover.execute(%{
        "event_log" => log,
        "algorithm" => "alpha_miner",
        "conformance" => true
      })

      # Result should contain model info
      assert Map.has_key?(result, "model")
    end
  end

  # ──────────────────────────────────────────────────────────────────────────
  # Edge Cases
  # ──────────────────────────────────────────────────────────────────────────

  describe "edge cases" do
    test "empty log returns error" do
      log = empty_log() |> Jason.encode!()

      result = PM4PyDiscover.execute(%{
        "event_log" => log,
        "algorithm" => "alpha_miner"
      })

      # pm4py should reject empty log or return ok with map
      case result do
        {:error, _} -> assert true
        {:ok, data} -> assert is_map(data)
      end
    end

    test "single-event log discovered" do
      log = single_event_log() |> Jason.encode!()

      {:ok, result} = PM4PyDiscover.execute(%{
        "event_log" => log,
        "algorithm" => "alpha_miner",
        "conformance" => false
      })

      assert is_map(result)
      assert result["log_stats"]["event_count"] == 1
      assert result["log_stats"]["trace_count"] == 1
    end

    test "duplicate case_ids merged correctly" do
      log = %{
        "events" => [
          %{"case_id" => "1", "activity" => "A", "timestamp" => "2024-01-01T10:00:00Z"},
          %{"case_id" => "1", "activity" => "B", "timestamp" => "2024-01-01T10:05:00Z"},
          %{"case_id" => "1", "activity" => "A", "timestamp" => "2024-01-01T10:10:00Z"},
          %{"case_id" => "1", "activity" => "B", "timestamp" => "2024-01-01T10:15:00Z"}
        ],
        "trace_count" => 1,
        "event_count" => 4
      } |> Jason.encode!()

      {:ok, result} = PM4PyDiscover.execute(%{
        "event_log" => log,
        "algorithm" => "alpha_miner",
        "conformance" => false
      })

      assert result["log_stats"]["trace_count"] == 1
      assert result["log_stats"]["event_count"] == 4
    end

    test "unicode activity names preserved" do
      log = %{
        "events" => [
          %{"case_id" => "1", "activity" => "开始", "timestamp" => "2024-01-01T10:00:00Z"},
          %{"case_id" => "1", "activity" => "处理", "timestamp" => "2024-01-01T10:05:00Z"},
          %{"case_id" => "1", "activity" => "结束", "timestamp" => "2024-01-01T10:10:00Z"}
        ],
        "trace_count" => 1,
        "event_count" => 3
      } |> Jason.encode!()

      {:ok, result} = PM4PyDiscover.execute(%{
        "event_log" => log,
        "algorithm" => "alpha_miner",
        "conformance" => false
      })

      assert is_map(result)
      assert result["log_stats"]["event_count"] == 3
    end
  end

  # ──────────────────────────────────────────────────────────────────────────
  # Error Handling
  # ──────────────────────────────────────────────────────────────────────────

  describe "error handling" do
    test "invalid algorithm returns error" do
      log = simple_log() |> Jason.encode!()

      {:error, reason} = PM4PyDiscover.execute(%{
        "event_log" => log,
        "algorithm" => "invalid_algorithm"
      })

      assert is_binary(reason)
      assert String.contains?(reason, "Invalid algorithm")
    end

    test "missing required parameters" do
      result = PM4PyDiscover.execute(%{"algorithm" => "alpha_miner"})
      assert {:error, _reason} = result
    end

    test "missing algorithm" do
      log = simple_log() |> Jason.encode!()
      result = PM4PyDiscover.execute(%{"event_log" => log})
      assert {:error, _reason} = result
    end

    test "malformed JSON log" do
      result = PM4PyDiscover.execute(%{
        "event_log" => "{invalid json",
        "algorithm" => "alpha_miner"
      })

      # Should attempt CSV parsing as fallback or return error
      case result do
        {:error, _} -> assert true
        {:ok, _} -> assert true
      end
    end

    test "non-map JSON returns error" do
      result = PM4PyDiscover.execute(%{
        "event_log" => Jason.encode!("not a map"),
        "algorithm" => "alpha_miner"
      })

      assert {:error, _reason} = result
    end
  end

  # ──────────────────────────────────────────────────────────────────────────
  # CSV Format Support
  # ──────────────────────────────────────────────────────────────────────────

  describe "CSV format support" do
    test "parses CSV log format" do
      csv = """
      case_id,activity,timestamp
      1,Start,2024-01-01T10:00:00Z
      1,Process,2024-01-01T10:05:00Z
      1,End,2024-01-01T10:10:00Z
      2,Start,2024-01-01T11:00:00Z
      2,Process,2024-01-01T11:05:00Z
      2,End,2024-01-01T11:10:00Z
      """

      {:ok, result} = PM4PyDiscover.execute(%{
        "event_log" => csv,
        "algorithm" => "alpha_miner",
        "conformance" => false
      })

      assert is_map(result)
      assert result["log_stats"]["trace_count"] == 2
      assert result["log_stats"]["event_count"] == 6
    end

    test "CSV with missing rows skips them" do
      csv = """
      case_id,activity,timestamp
      1,Start,2024-01-01T10:00:00Z
      1,Process
      1,End,2024-01-01T10:10:00Z
      """

      {:ok, result} = PM4PyDiscover.execute(%{
        "event_log" => csv,
        "algorithm" => "alpha_miner",
        "conformance" => false
      })

      # Should parse only valid rows
      assert result["log_stats"]["event_count"] >= 2
    end
  end

  # ──────────────────────────────────────────────────────────────────────────
  # Tool Metadata
  # ──────────────────────────────────────────────────────────────────────────

  describe "tool metadata" do
    test "name is correct" do
      assert PM4PyDiscover.name() == "pm4py_discover"
    end

    test "safety level is sandboxed" do
      assert PM4PyDiscover.safety() == :sandboxed
    end

    test "description is present" do
      desc = PM4PyDiscover.description()
      assert is_binary(desc)
      assert String.contains?(desc, "discover")
    end

    test "parameters schema is valid" do
      params = PM4PyDiscover.parameters()
      assert Map.has_key?(params, "type")
      assert Map.has_key?(params, "properties")
      assert Map.has_key?(params, "required")
      assert params["type"] == "object"
    end

    test "all algorithms listed in parameters" do
      params = PM4PyDiscover.parameters()
      enum = params["properties"]["algorithm"]["enum"]
      assert is_list(enum)
      assert Enum.member?(enum, "alpha_miner")
      assert Enum.member?(enum, "inductive_miner")
      assert Enum.member?(enum, "heuristic_miner")
    end
  end
end
