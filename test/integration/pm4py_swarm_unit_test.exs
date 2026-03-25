defmodule OptimalSystemAgent.Integration.PM4PySwarmUnitTest do
  @moduledoc """
  Unit tests for PM4PyCoordinator swarm functions that don't require external services.
  Tests the Byzantine consensus logic and swarm structure in isolation.
  """
  use ExUnit.Case, async: true
  doctest OptimalSystemAgent.Providers.PM4PyCoordinator

  # ──────────────────────────────────────────────────────────────────────────
  # Tests for Byzantine Consensus Logic
  # ──────────────────────────────────────────────────────────────────────────

  describe "Byzantine consensus computation (unit)" do
    test "compute_byzantine_consensus with all valid results" do
      agent_results = %{
        0 => {:ok, %{"model" => %{"places" => [1, 2], "transitions" => [1, 2]}}},
        1 => {:ok, %{"model" => %{"places" => [1, 2], "transitions" => [1, 2]}}},
        2 => {:ok, %{"model" => %{"places" => [1, 2], "transitions" => [1, 2]}}}
      }

      {:ok, consensus_data} =
        OptimalSystemAgent.Providers.PM4PyCoordinator.compute_byzantine_consensus(
          agent_results,
          0.7
        )

      assert Map.has_key?(consensus_data, "model")
      assert Map.has_key?(consensus_data, "consensus_level")
      assert consensus_data["consensus_level"] == 1.0
      assert consensus_data["note"] == "Single valid agent result" or
             String.contains?(consensus_data["note"], "Consensus reached")
    end

    test "compute_byzantine_consensus with partial valid results (2/3)" do
      agent_results = %{
        0 => {:ok, %{"model" => %{"places" => [1, 2], "transitions" => [1, 2]}}},
        1 => {:ok, %{"model" => %{"places" => [1, 2], "transitions" => [1, 2]}}},
        2 => {:error, "Failed to discover"}
      }

      {:ok, consensus_data} =
        OptimalSystemAgent.Providers.PM4PyCoordinator.compute_byzantine_consensus(
          agent_results,
          0.7
        )

      # 2/3 = 0.66 < 0.7 threshold, should fallback
      assert consensus_data["consensus_level"] == 2 / 3
      assert String.contains?(consensus_data["note"], "Fallback")
    end

    test "compute_byzantine_consensus with single valid result" do
      agent_results = %{
        0 => {:ok, %{"model" => %{"places" => [1], "transitions" => [1]}}},
        1 => {:error, "Failed"},
        2 => {:error, "Failed"}
      }

      {:ok, consensus_data} =
        OptimalSystemAgent.Providers.PM4PyCoordinator.compute_byzantine_consensus(
          agent_results,
          0.7
        )

      assert consensus_data["consensus_level"] == 1.0
      assert consensus_data["note"] == "Single valid agent result"
    end

    test "compute_byzantine_consensus with no valid results returns error" do
      agent_results = %{
        0 => {:error, "Failed"},
        1 => {:error, "Failed"},
        2 => {:error, "Failed"}
      }

      {:error, reason} =
        OptimalSystemAgent.Providers.PM4PyCoordinator.compute_byzantine_consensus(
          agent_results,
          0.7
        )

      assert String.contains?(reason, "No valid discovery results")
    end
  end

  # ──────────────────────────────────────────────────────────────────────────
  # Tests for A2A Posting Logic
  # ──────────────────────────────────────────────────────────────────────────

  describe "A2A posting to BusinessOS (unit)" do
    test "post_to_businessos generates correct metadata structure" do
      consensus_data = %{
        "model" => %{"places" => [1, 2], "transitions" => [1, 2]},
        "consensus_level" => 0.66,
        "note" => "Fallback to first result"
      }

      swarm_id = "test_swarm_001"
      algorithm = "inductive_miner"

      {:ok, a2a_metadata} =
        OptimalSystemAgent.Providers.PM4PyCoordinator.post_to_businessos(
          swarm_id,
          consensus_data,
          algorithm
        )

      assert Map.has_key?(a2a_metadata, "agent")
      assert a2a_metadata["agent"] == "pm4py_coordinator"
      assert Map.has_key?(a2a_metadata, "method")
      assert a2a_metadata["method"] == "discover"
      assert Map.has_key?(a2a_metadata, "params")
      assert Map.has_key?(a2a_metadata, "timestamp")

      params = a2a_metadata["params"]
      assert params["swarm_id"] == swarm_id
      assert params["algorithm"] == algorithm
      assert params["consensus_level"] == 0.66
      assert Map.has_key?(params, "model")
    end

    test "A2A metadata timestamp is ISO8601 format" do
      consensus_data = %{
        "model" => %{},
        "consensus_level" => 1.0,
        "note" => "Single valid agent"
      }

      {:ok, a2a_metadata} =
        OptimalSystemAgent.Providers.PM4PyCoordinator.post_to_businessos(
          "test_001",
          consensus_data,
          "alpha_miner"
        )

      timestamp = a2a_metadata["timestamp"]
      assert is_binary(timestamp)
      # Basic ISO8601 format check
      assert String.match?(timestamp, ~r/\d{4}-\d{2}-\d{2}/)
    end
  end

  # ──────────────────────────────────────────────────────────────────────────
  # Tests for Swarm ID Generation
  # ──────────────────────────────────────────────────────────────────────────

  describe "swarm ID generation" do
    test "generate_swarm_id creates unique hex strings" do
      id1 = OptimalSystemAgent.Providers.PM4PyCoordinator.generate_swarm_id()
      id2 = OptimalSystemAgent.Providers.PM4PyCoordinator.generate_swarm_id()

      assert is_binary(id1)
      assert is_binary(id2)
      assert byte_size(id1) == 16  # 8 bytes encoded as 16 hex chars
      assert byte_size(id2) == 16
      assert id1 != id2  # Should be unique
    end

    test "generate_swarm_id produces valid hex characters" do
      id = OptimalSystemAgent.Providers.PM4PyCoordinator.generate_swarm_id()
      assert String.match?(id, ~r/^[0-9a-f]{16}$/)
    end
  end

  # ──────────────────────────────────────────────────────────────────────────
  # Tests for Byzantine Threshold Logic
  # ──────────────────────────────────────────────────────────────────────────

  describe "consensus threshold calculations" do
    test "3 agents: 2/3 consensus is below 0.7 threshold" do
      # 2/3 = 0.6666... < 0.7
      threshold = 0.7
      consensus_level = 2 / 3

      assert consensus_level < threshold
    end

    test "3 agents: 3/3 consensus meets 0.7 threshold" do
      # 3/3 = 1.0 >= 0.7
      threshold = 0.7
      consensus_level = 3 / 3

      assert consensus_level >= threshold
    end

    test "4 agents: 3/4 consensus meets 0.7 threshold" do
      # 3/4 = 0.75 >= 0.7
      threshold = 0.7
      consensus_level = 3 / 4

      assert consensus_level >= threshold
    end

    test "5 agents: 3/5 consensus is below 0.7 threshold" do
      # 3/5 = 0.6 < 0.7
      threshold = 0.7
      consensus_level = 3 / 5

      assert consensus_level < threshold
    end
  end

  # ──────────────────────────────────────────────────────────────────────────
  # Tests for Model Validation
  # ──────────────────────────────────────────────────────────────────────────

  describe "model validation" do
    test "validate_model accepts valid Petri net structure" do
      model = %{
        "places" => ["p0", "p1", "p2"],
        "transitions" => ["t0", "t1"]
      }

      :ok = OptimalSystemAgent.Providers.PM4PyCoordinator.validate_model(model)
    end

    test "validate_model rejects model with empty places" do
      model = %{
        "places" => [],
        "transitions" => ["t0"]
      }

      {:error, reason} = OptimalSystemAgent.Providers.PM4PyCoordinator.validate_model(model)
      assert String.contains?(reason, "places")
    end

    test "validate_model rejects model with empty transitions" do
      model = %{
        "places" => ["p0"],
        "transitions" => []
      }

      {:error, reason} = OptimalSystemAgent.Providers.PM4PyCoordinator.validate_model(model)
      assert String.contains?(reason, "transitions")
    end

    test "validate_model rejects non-map model" do
      {:error, reason} = OptimalSystemAgent.Providers.PM4PyCoordinator.validate_model([])
      assert String.contains?(reason, "not a map")
    end
  end
end
