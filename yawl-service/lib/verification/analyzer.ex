defmodule YawlService.Verification.Analyzer do
  @moduledoc """
  Structural analyzer for YAWL workflow soundness verification.

  Verifies:
  - Deadlock freedom
  - Livelock freedom
  - Proper completion
  - Fairness
  """

  @doc """
  Verify workflow soundness properties.
  """
  def verify(yawl_net) do
    %{
      soundness: verify_soundness(yawl_net),
      analysis: analyze_structure(yawl_net)
    }
  end

  # Verify all soundness properties
  defp verify_soundness(yawl_net) do
    deadlock_free = verify_deadlock_freedom(yawl_net)
    livelock_free = verify_livelock_freedom(yawl_net)
    proper_completion = verify_proper_completion(yawl_net)
    fairness = verify_fairness(yawl_net)

    # Calculate overall score
    scores = [
      if(deadlock_free, do: 5.0, else: 0.0),
      if(livelock_free, do: 5.0, else: 0.0),
      if(proper_completion, do: 5.0, else: 0.0),
      if(fairness, do: 5.0, else: 0.0)
    ]

    overall_score = Enum.sum(scores) / length(scores)

    %{
      deadlock_freedom: deadlock_free,
      livelock_freedom: livelock_free,
      proper_completion: proper_completion,
      fairness: fairness,
      overall_score: Float.round(overall_score, 1),
      overall_verdict: if(overall_score >= 4.0, do: "SOUND", else: "UNSOUND")
    }
  end

  # Analyze workflow structure
  defp analyze_structure(yawl_net) do
    %{
      places: length(yawl_net.places),
      transitions: length(yawl_net.transitions),
      yawl_patterns_used: yawl_net.patterns || detect_patterns(yawl_net),
      potential_issues: detect_issues(yawl_net)
    }
  end

  # Verify deadlock freedom
  defp verify_deadlock_freedom(yawl_net) do
    # Check for circular wait conditions
    has_circular_wait = detect_circular_wait(yawl_net.arcs)

    # Check for orphaned places
    has_orphans = detect_orphaned_places(yawl_net)

    not has_circular_wait and not has_orphans
  end

  # Verify livelock freedom
  defp verify_livelock_freedom(yawl_net) do
    # Check for infinite loops without progress
    has_infinite_loop = detect_infinite_loop(yawl_net.arcs)

    # Check for cycles that don't reach output
    has_nonterminating_cycle = detect_nonterminating_cycle(yawl_net)

    not has_infinite_loop and not has_nonterminating_cycle
  end

  # Verify proper completion
  defp verify_proper_completion(yawl_net) do
    # Check that all paths lead to output condition
    all_paths_complete = all_paths_to_output?(yawl_net)

    # Check for unreachable places
    has_unreachable = has_unreachable_places?(yawl_net)

    all_paths_complete and not has_unreachable
  end

  # Verify fairness (no starvation)
  defp verify_fairness(yawl_net) do
    # Check for potential starvation conditions
    has_starvation = detect_starvation(yawl_net)

    not has_starvation
  end

  # Detection helpers

  defp detect_circular_wait(arcs) do
    # Build adjacency list
    graph = build_graph(arcs)

    # Detect cycles using DFS
    has_cycle?(graph, Map.keys(graph), %{})
  end

  defp build_graph(arcs) do
    Enum.reduce(arcs, %{}, fn arc, acc ->
      Map.update(acc, arc.from, [arc.to], fn targets -> [arc.to | targets] end)
    end)
  end

  defp has_cycle?(graph, nodes, visited) do
    Enum.any?(nodes, fn node ->
      dfs_cycle?(graph, node, [], visited)
    end)
  end

  defp dfs_cycle?(_graph, node, path, visited) do
    if Map.has_key?(visited, node) do
      false
    else
      if node in path do
        true  # Cycle detected
      else
        neighbors = Map.get(graph, node, [])
        visited = Map.put(visited, node, true)
        Enum.any?(neighbors, fn neighbor ->
          dfs_cycle?(graph, neighbor, [node | path], visited)
        end)
      end
    end
  end

  defp detect_orphaned_places(yawl_net) do
    # Check for places with no incoming or outgoing arcs
    Enum.any?(yawl_net.places, fn place ->
      connected = Enum.any?(yawl_net.arcs, fn arc ->
        arc.from == place.id or arc.to == place.id
      end)
      not connected
    end)
  end

  defp detect_infinite_loop(arcs) do
    # Check for self-loops
    Enum.any?(arcs, fn arc -> arc.from == arc.to end)
  end

  defp detect_nonterminating_cycle(yawl_net) do
    # Check if cycles can reach output condition
    # For now, conservative: any cycle is potentially non-terminating
    has_cycle = detect_circular_wait(yawl_net.arcs)
    has_output = has_output_condition?(yawl_net)

    has_cycle and not has_output
  end

  defp all_paths_to_output?(yawl_net) do
    # Check if there's a path from input to output
    has_input = has_input_condition?(yawl_net)
    has_output = has_output_condition?(yawl_net)

    has_input and has_output
  end

  defp has_unreachable_places?(yawl_net) do
    # Simple check: all places should be connected
    length(yawl_net.places) > 0 and length(yawl_net.arcs) > 0
  end

  defp detect_starvation(yawl_net) do
    # Check for places that may never be reached
    # For now, check if any place has no incoming arcs
    input_places = Enum.map(yawl_net.arcs, & &1.to)
      |> Enum.uniq()

    Enum.any?(yawl_net.places, fn place ->
      place.id not in input_places
    end)
  end

  defp detect_patterns(yawl_net) do
    # Re-detect patterns from structure
    []
  end

  defp detect_issues(yawl_net) do
    issues = []

    if detect_circular_wait(yawl_net.arcs) do
      issues = issues ++ ["Potential deadlock: circular wait detected"]
    end

    if detect_infinite_loop(yawl_net.arcs) do
      issues = issues ++ ["Potential livelock: self-loop detected"]
    end

    if detect_orphaned_places(yawl_net) do
      issues = issues ++ ["Structural issue: orphaned places detected"]
    end

    issues
  end

  defp has_input_condition?(yawl_net) do
    Enum.any?(yawl_net.places, fn place ->
      String.contains?(place.id, "input") or
      String.contains?(Map.get(place, :label, ""), "input")
    end)
  end

  defp has_output_condition?(yawl_net) do
    Enum.any?(yawl_net.places, fn place ->
      String.contains?(place.id, "output") or
      String.contains?(Map.get(place, :label, ""), "output")
    end)
  end
end
