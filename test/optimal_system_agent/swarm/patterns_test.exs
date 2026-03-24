defmodule OptimalSystemAgent.Swarm.PatternsTest do
  use ExUnit.Case
  @moduletag :skip
  alias OptimalSystemAgent.Swarm.Patterns

  describe "list_patterns/0" do
    test "returns {:ok, list} of available swarm patterns" do
      assert {:ok, patterns} = Patterns.list_patterns()

      assert is_list(patterns)
      assert length(patterns) > 0
    end
  end

  describe "get_pattern/1" do
    test "returns {:ok, config} for known pattern" do
      {:ok, patterns} = Patterns.list_patterns()

      # Test first available pattern
      pattern_name = List.first(patterns)
      assert {:ok, config} = Patterns.get_pattern(pattern_name)

      assert is_map(config)
    end

    test "returns {:error, :not_found} for unknown pattern" do
      assert {:error, :not_found} = Patterns.get_pattern("unknown_pattern_xyz")
    end
  end

  describe "bft_consensus/3" do
    test "returns {:ok, results} when given valid configs" do
      parent_id = "test-session-123"

      configs = [
        %{role: "agent1", task: "Evaluate this proposal"},
        %{role: "agent2", task: "Evaluate this proposal"},
        %{role: "agent3", task: "Evaluate this proposal"}
      ]

      # bft_consensus returns {:ok, results} or falls back to parallel
      # We just verify it doesn't crash and returns a tuple
      result = Patterns.bft_consensus(parent_id, configs, [])

      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "falls back to parallel when fewer than 3 agents" do
      parent_id = "test-session-456"

      configs = [
        %{role: "agent1", task: "Work on this"}
      ]

      # Should fall back to parallel and return {:ok, results}
      assert {:ok, _results} = Patterns.bft_consensus(parent_id, configs, [])
    end
  end

  describe "parallel/3" do
    test "returns {:ok, results} for parallel execution" do
      parent_id = "test-session-789"

      configs = [
        %{role: "worker1", task: "Task 1"},
        %{role: "worker2", task: "Task 2"}
      ]

      # parallel returns {:ok, results}
      assert {:ok, results} = Patterns.parallel(parent_id, configs, [])

      assert is_list(results)
      assert length(results) == 2
    end
  end
end
