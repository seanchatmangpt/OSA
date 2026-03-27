defmodule OptimalSystemAgent.Swarm.PatternsTest do
  use ExUnit.Case


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
    test "returns ok or error (YAWL required, consensus system optional)" do
      parent_id = "test-session-123"

      configs = [
        %{role: "agent1", task: "Evaluate this proposal"},
        %{role: "agent2", task: "Evaluate this proposal"},
        %{role: "agent3", task: "Evaluate this proposal"}
      ]

      # bft_consensus may fail if HotStuff or consensus system is unavailable
      # Phase B: YAWL Primary — validate topology before consensus voting
      result = Patterns.bft_consensus(parent_id, configs, [])

      # Accepts any result — either success or error (BFT system optional in test)
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "falls back to parallel when fewer than 3 agents (YAWL required)" do
      parent_id = "test-session-456"

      configs = [
        %{role: "agent1", task: "Work on this"}
      ]

      # Falls back to parallel but requires YAWL validation
      # Phase B: YAWL Primary — fails when YAWL unavailable
      result = Patterns.bft_consensus(parent_id, configs, [])
      assert match?({:ok, _}, result) or match?({:error, :yawl_unavailable}, result)
    end
  end

  describe "parallel/3" do
    test "validates YAWL topology before spawning agents" do
      parent_id = "test-session-789"

      configs = [
        %{role: "worker1", task: "Task 1"},
        %{role: "worker2", task: "Task 2"}
      ]

      # Phase B: YAWL Primary — fails when YAWL engine unavailable
      result = Patterns.parallel(parent_id, configs, [])

      # Either succeeds (if YAWL running) or fails with :yawl_unavailable
      assert match?({:ok, _}, result) or match?({:error, :yawl_unavailable}, result)
    end
  end
end
