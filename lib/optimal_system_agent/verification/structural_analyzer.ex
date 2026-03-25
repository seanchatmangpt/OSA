defmodule OptimalSystemAgent.Verification.StructuralAnalyzer do
  @moduledoc """
  Structural workflow analyzer for Formal Correctness as a Service.

  Implements six verification checks that catch common workflow issues
  without requiring a full YAWL v6 verification engine:

    1. Deadlock detection      -- circular wait dependencies between parallel branches
    2. Livelock detection      -- loops without exit conditions
    3. Soundness               -- every task reachable from start AND can reach end
    4. Proper completion       -- workflow has a defined end state
    5. Orphan task detection   -- tasks not connected to the main flow
    6. Unreachable task detection -- tasks that can never be executed

  Accepts parsed workflow structures (maps with tasks, transitions, start_node, end_node)
  from YAWL XML, BPMN XML, or markdown parsers.
  """

  require Logger

  @typedoc "A single workflow task node."
  @type task :: %{
    id: String.t(),
    name: String.t(),
    type: :task | :condition | :gateway | :start | :end,
    split_type: nil | :and | :xor | :or,
    join_type: nil | :and | :xor | :or
  }

  @typedoc "A transition edge between two tasks."
  @type transition :: %{
    from: String.t(),
    to: String.t(),
    condition: String.t() | nil
  }

  @typedoc "Parsed workflow structure for analysis."
  @type workflow :: %{
    tasks: %{String.t() => task()},
    transitions: [transition()],
    start_node: String.t() | nil,
    end_node: String.t() | nil,
    metadata: map()
  }

  @typedoc "Result of a single verification check."
  @type check_result :: %{
    passed: boolean(),
    issues: [%{type: String.t(), severity: :error | :warning | :info, description: String.t()}]
  }

  @typedoc "Complete analysis result."
  @type analysis_result :: %{
    deadlock_free: boolean(),
    livelock_free: boolean(),
    sound: boolean(),
    proper_completion: boolean(),
    no_orphan_tasks: boolean(),
    no_unreachable_tasks: boolean(),
    overall_score: float(),
    issues: [map()]
  }

  # ===========================================================================
  # Public API
  # ===========================================================================

  @doc """
  Run all six structural checks on a parsed workflow and return an analysis result.

  ## Parameters
    - workflow: parsed workflow structure (map with tasks, transitions, start_node, end_node)
    - format: source format for logging (:yawl, :bpmn, :markdown)

  ## Returns
    A map with per-check booleans, overall score (0.0-5.0), and issue list.
  """
  @spec analyze_workflow(workflow(), atom()) :: analysis_result()
  def analyze_workflow(workflow, format \\ :unknown)

  def analyze_workflow(nil, _format) do
    {:error, :nil_workflow}
  end

  def analyze_workflow(workflow, format) do
    workflow = normalize_workflow(workflow)

    Logger.info("[StructuralAnalyzer] Analyzing #{format} workflow: #{map_size(workflow.tasks)} tasks, #{length(workflow.transitions)} transitions")

    # Run all checks
    deadlock = check_deadlock(workflow)
    livelock = check_livelock(workflow)
    soundness = check_soundness(workflow)
    completion = check_proper_completion(workflow)
    orphans = check_orphan_tasks(workflow)
    unreachable = check_unreachable_tasks(workflow)

    # Aggregate issues
    all_issues =
      []
      |> Enum.concat(deadlock.issues)
      |> Enum.concat(livelock.issues)
      |> Enum.concat(soundness.issues)
      |> Enum.concat(completion.issues)
      |> Enum.concat(orphans.issues)
      |> Enum.concat(unreachable.issues)

    # Compute overall score: 5.0 is perfect, subtract for each failed check
    checks_passed = Enum.count([deadlock, livelock, soundness, completion, orphans, unreachable], & &1.passed)
    total_checks = 6
    # Score ranges from 0.0 (all failed) to 5.0 (all passed)
    overall_score = (checks_passed / total_checks) * 5.0
    overall_score = Float.round(overall_score, 1)

    %{
      deadlock_free: deadlock.passed,
      livelock_free: livelock.passed,
      sound: soundness.passed,
      proper_completion: completion.passed,
      no_orphan_tasks: orphans.passed,
      no_unreachable_tasks: unreachable.passed,
      overall_score: overall_score,
      issues: all_issues
    }
  end

  # ===========================================================================
  # Check 1: Deadlock Detection
  # ===========================================================================

  @doc """
  Detect potential deadlocks caused by circular wait dependencies
  between parallel (AND-split/join) branches.

  A deadlock occurs when:
  - Two or more AND-split branches exist
  - Tasks in different branches have dependency edges pointing at each other
  - An AND-join waits for all branches, but branch completion depends on the other

  This is a simplified structural check -- it looks for cycles that cross
  parallel branch boundaries (cycles entirely within one branch are allowed
  for loop patterns).
  """
  @spec check_deadlock(workflow()) :: check_result()
  def check_deadlock(%{tasks: tasks, transitions: transitions, start_node: start_node}) do
    _issues = []

    # Build adjacency list
    adj = build_adjacency(transitions)

    # Identify AND-split/join boundaries to find parallel regions
    parallel_regions = find_parallel_regions(tasks, adj)

    if parallel_regions == [] or map_size(tasks) < 2 do
      %{
        passed: true,
        issues: []
      }
    else
      # Check for cycles that cross parallel region boundaries
      deadlock_issues = detect_cross_region_cycles(tasks, adj, parallel_regions, start_node)

      %{
        passed: deadlock_issues == [],
        issues: deadlock_issues
      }
    end
  end

  # ===========================================================================
  # Check 2: Livelock Detection
  # ===========================================================================

  @doc """
  Detect potential livelocks -- cycles in the workflow graph that lack
  exit conditions.

  Unlike deadlocks (where tasks wait forever), livelocks involve tasks
  that keep executing but never make progress toward completion.

  Checks:
  - XOR-loops without an outgoing edge that leaves the loop
  - Self-loops (task transitions to itself without condition exit)
  - Unconditional cycles where every node in the cycle has exactly one outgoing edge
  """
  @spec check_livelock(workflow()) :: check_result()
  def check_livelock(%{tasks: tasks, transitions: transitions}) do
    if map_size(tasks) < 2 do
      %{
        passed: true,
        issues: []
      }
    else
      adj = build_adjacency(transitions)

      # Find all strongly connected components (cycles)
      sccs = tarjan_scc(tasks, adj)

      # For each SCC with more than 1 node (or self-loop), check if there's an exit
      livelock_issues =
        sccs
        |> Enum.filter(fn scc -> length(scc) > 1 end)
        |> Enum.concat(
          # Also check for self-loops
          tasks
          |> Map.keys()
          |> Enum.filter(fn node -> node in Map.get(adj, node, []) end)
          |> Enum.map(fn node -> [node] end)
        )
        |> Enum.filter(fn scc -> cycle_has_no_exit?(scc, adj) end)
        |> Enum.map(fn scc ->
          task_names =
            scc
            |> Enum.map(fn id -> Map.get(tasks, id, %{name: id}) |> Map.get(:name, id) end)
            |> Enum.join(", ")

          %{
            type: "livelock",
            severity: :error,
            description: "Potential livelock: cycle [#{task_names}] has no exit path"
          }
        end)

      %{
        passed: livelock_issues == [],
        issues: livelock_issues
      }
    end
  end

  # ===========================================================================
  # Check 3: Soundness
  # ===========================================================================

  @doc """
  Verify workflow soundness: every task must be reachable from the start node
  AND every task must be able to reach the end node.

  A sound workflow guarantees:
  1. No task is "stranded" (can be reached but never leads to completion)
  2. No task is "useless" (can reach end but is never triggered)
  """
  @spec check_soundness(workflow()) :: check_result()
  def check_soundness(%{tasks: tasks, transitions: transitions, start_node: start_node, end_node: end_node}) do
    _issues = []

    if is_nil(start_node) or is_nil(end_node) do
      issues = [
        %{
          type: "soundness",
          severity: :error,
          description: "Cannot verify soundness: workflow has no #{if is_nil(start_node), do: "start node", else: "end node"}"
        }
      ]

      %{
        passed: false,
        issues: issues
      }
    else
      adj = build_adjacency(transitions)
      reverse_adj = build_reverse_adjacency(transitions)

      # Forward reachability: which tasks can be reached from start?
      reachable_from_start = bfs_reachable(start_node, adj)

      # Backward reachability: which tasks can reach the end?
      can_reach_end = bfs_reachable(end_node, reverse_adj)

      issues =
        tasks
        |> Map.keys()
        |> Enum.reject(fn task_id -> task_id == start_node or task_id == end_node end)
        |> Enum.flat_map(fn task_id ->
          name = Map.get(tasks, task_id, %{name: task_id}) |> Map.get(:name, task_id)
          task_issues = []

          task_issues =
            if task_id not in reachable_from_start do
              [
                %{
                  type: "soundness",
                  severity: :error,
                  description: "Task '#{name}' (#{task_id}) is not reachable from start"
                }
                | task_issues
              ]
            else
              task_issues
            end

          if task_id not in can_reach_end do
            [
              %{
                type: "soundness",
                severity: :error,
                description: "Task '#{name}' (#{task_id}) cannot reach the end node"
              }
              | task_issues
            ]
          else
            task_issues
          end
        end)

      %{
        passed: issues == [],
        issues: issues
      }
    end
  end

  # ===========================================================================
  # Check 4: Proper Completion
  # ===========================================================================

  @doc """
  Verify that the workflow has a defined end state and that all execution
  paths can eventually reach it.

  A workflow without a proper end state is incomplete and may leave
  executions in an indeterminate state.
  """
  @spec check_proper_completion(workflow()) :: check_result()
  def check_proper_completion(%{tasks: tasks, transitions: transitions, end_node: end_node}) do
    issues = []

    # Check 1: Does the workflow have an end node?
    issues =
      if is_nil(end_node) do
        [
          %{
            type: "proper_completion",
            severity: :error,
            description: "Workflow has no end node -- all execution paths must terminate"
          }
          | issues
        ]
      else
        issues
      end

    # Check 2: Are there tasks with no outgoing transitions that are not the end node?
    adj = build_adjacency(transitions)

    sink_nodes =
      tasks
      |> Map.keys()
      |> Enum.filter(fn id ->
        id != end_node and Map.get(adj, id, []) == []
      end)

    issues =
      sink_nodes
      |> Enum.map(fn id ->
        name = Map.get(tasks, id, %{name: id}) |> Map.get(:name, id)

        %{
          type: "proper_completion",
          severity: :warning,
          description: "Task '#{name}' (#{id}) has no outgoing transitions and is not the end node"
        }
      end)
      |> Enum.concat(issues)

    # Check 3: Does the end node have no outgoing transitions?
    issues =
      if not is_nil(end_node) and Map.get(adj, end_node, []) != [] do
        name = Map.get(tasks, end_node, %{name: end_node}) |> Map.get(:name, end_node)

        [
          %{
            type: "proper_completion",
            severity: :warning,
            description: "End node '#{name}' (#{end_node}) has outgoing transitions"
          }
          | issues
        ]
      else
        issues
      end

    %{
      passed: Enum.all?(issues, fn i -> i.severity != :error end),
      issues: issues
    }
  end

  # ===========================================================================
  # Check 5: Orphan Task Detection
  # ===========================================================================

  @doc """
  Find orphan tasks -- tasks that are not connected to any transition
  (no incoming AND no outgoing edges).

  Orphan tasks represent disconnected workflow elements that are
  never part of any execution path.
  """
  @spec check_orphan_tasks(workflow()) :: check_result()
  def check_orphan_tasks(%{tasks: tasks, transitions: transitions}) do
    if transitions == [] and map_size(tasks) > 0 do
      # All tasks are orphans if there are no transitions
      orphan_names =
        tasks
        |> Map.values()
        |> Enum.map(fn t -> t[:name] || t[:id] end)
        |> Enum.join(", ")

      %{
        passed: false,
        issues: [
          %{
            type: "orphan_task",
            severity: :error,
            description: "All tasks are orphans (no transitions defined): #{orphan_names}"
          }
        ]
      }
    else
      # Build sets of nodes that appear in transitions
      connected_nodes =
        transitions
        |> Enum.flat_map(fn t -> [t.from, t.to] end)
        |> MapSet.new()

      orphan_ids =
        tasks
        |> Map.keys()
        |> Enum.reject(fn id -> MapSet.member?(connected_nodes, id) end)

      issues =
        orphan_ids
        |> Enum.map(fn id ->
          name = Map.get(tasks, id, %{name: id}) |> Map.get(:name, id)

          %{
            type: "orphan_task",
            severity: :warning,
            description: "Task '#{name}' (#{id}) is not connected to any transition"
          }
        end)

      %{
        passed: orphan_ids == [],
        issues: issues
      }
    end
  end

  # ===========================================================================
  # Check 6: Unreachable Task Detection
  # ===========================================================================

  @doc """
  Find unreachable tasks -- tasks that exist in the workflow definition
  but can never be executed because no path from the start node leads to them.

  This is a stricter subset of soundness: it only checks forward reachability.
  """
  @spec check_unreachable_tasks(workflow()) :: check_result()
  def check_unreachable_tasks(%{tasks: tasks, transitions: transitions, start_node: start_node}) do
    if is_nil(start_node) do
      %{
        passed: false,
        issues: [
          %{
            type: "unreachable_task",
            severity: :error,
            description: "Cannot determine reachability: workflow has no start node"
          }
        ]
      }
    else
      adj = build_adjacency(transitions)
      reachable = bfs_reachable(start_node, adj)

      unreachable_ids =
        tasks
        |> Map.keys()
        |> Enum.reject(fn id -> MapSet.member?(reachable, id) end)

      issues =
        unreachable_ids
        |> Enum.map(fn id ->
          name = Map.get(tasks, id, %{name: id}) |> Map.get(:name, id)

          %{
            type: "unreachable_task",
            severity: :error,
            description: "Task '#{name}' (#{id}) is unreachable from start node"
          }
        end)

      %{
        passed: unreachable_ids == [],
        issues: issues
      }
    end
  end

  # ===========================================================================
  # Private: Graph Algorithms
  # ===========================================================================

  @spec build_adjacency([transition()]) :: %{String.t() => [String.t()]}
  defp build_adjacency(transitions) do
    Enum.reduce(transitions, %{}, fn t, acc ->
      Map.update(acc, t.from, [t.to], fn existing -> [t.to | existing] end)
    end)
  end

  @spec build_reverse_adjacency([transition()]) :: %{String.t() => [String.t()]}
  defp build_reverse_adjacency(transitions) do
    Enum.reduce(transitions, %{}, fn t, acc ->
      Map.update(acc, t.to, [t.from], fn existing -> [t.from | existing] end)
    end)
  end

  @spec bfs_reachable(String.t(), %{String.t() => [String.t()]}) :: MapSet.t()
  defp bfs_reachable(start, adj) do
    bfs_reachable_loop([start], adj, MapSet.new([start]))
  end

  defp bfs_reachable_loop([], _adj, visited), do: visited

  defp bfs_reachable_loop([current | rest], adj, visited) do
    neighbors = Map.get(adj, current, []) |> Enum.reject(&MapSet.member?(visited, &1))
    new_visited = Enum.reduce(neighbors, visited, &MapSet.put(&2, &1))
    bfs_reachable_loop(rest ++ neighbors, adj, new_visited)
  end

  # ===========================================================================
  # Private: Parallel Region Analysis (for deadlock detection)
  # ===========================================================================

  @spec find_parallel_regions(%{String.t() => task()}, %{String.t() => [String.t()]}) :: [
          MapSet.t()
        ]
  defp find_parallel_regions(tasks, adj) do
    # Find AND-split nodes (gateway/condition tasks with split_type :and)
    and_splits =
      tasks
      |> Map.values()
      |> Enum.filter(fn t -> t[:split_type] == :and end)

    and_splits
    |> Enum.flat_map(fn split ->
      successors = Map.get(adj, split[:id], [])

      # For each AND-split, trace each branch until an AND-join is found
      successors
      |> Enum.map(fn succ ->
        trace_branch(succ, adj, tasks, MapSet.new())
      end)
    end)
    |> Enum.filter(fn region -> MapSet.size(region) > 0 end)
  end

  @spec trace_branch(String.t(), %{String.t() => [String.t()]}, %{String.t() => task()}, MapSet.t()) ::
          MapSet.t()
  defp trace_branch(node, adj, tasks, visited) do
    if MapSet.member?(visited, node) do
      visited
    else
      visited = MapSet.put(visited, node)
      task = Map.get(tasks, node, %{})

      cond do
        # Stop at AND-join (end of parallel region)
        task[:join_type] == :and ->
          visited

        # Stop at end node
        task[:type] == :end ->
          visited

        # Stop at another AND-split (nested parallelism boundary)
        task[:split_type] == :and and node != hd(MapSet.to_list(visited)) ->
          visited

        # Continue tracing single successor
        true ->
          successors = Map.get(adj, node, [])

          case successors do
            [next] -> trace_branch(next, adj, tasks, visited)
            [] -> visited
            _ ->
              # Multiple successors (XOR split) -- trace all branches
              Enum.reduce(successors, visited, fn succ, acc ->
                MapSet.union(acc, trace_branch(succ, adj, tasks, visited))
              end)
          end
      end
    end
  end

  @spec detect_cross_region_cycles(
          %{String.t() => task()},
          %{String.t() => [String.t()]},
          [MapSet.t()],
          String.t() | nil
        ) :: [map()]
  defp detect_cross_region_cycles(tasks, adj, parallel_regions, _start_node) do
    # Check for edges that go FROM one parallel region INTO another
    # This indicates a potential deadlock if both regions need to synchronize
    region_map =
      parallel_regions
      |> Enum.with_index()
      |> Enum.flat_map(fn {region, idx} ->
        MapSet.to_list(region)
        |> Enum.map(fn node -> {node, idx} end)
      end)
      |> Map.new()

    cross_edges =
      adj
      |> Enum.flat_map(fn {from, tos} ->
        from_region = Map.get(region_map, from)

        if is_nil(from_region) do
          []
        else
          tos
          |> Enum.filter(fn to ->
            to_region = Map.get(region_map, to)
            not is_nil(to_region) and to_region != from_region
          end)
          |> Enum.map(fn to -> {from, to, from_region, Map.get(region_map, to)} end)
        end
      end)

    if cross_edges == [] do
      []
    else
      # Check if the cross-edges form a cycle between regions
      region_graph =
        cross_edges
        |> Enum.reduce(%{}, fn {_from, _to, from_r, to_r}, acc ->
          Map.update(acc, from_r, MapSet.new([to_r]), &MapSet.put(&1, to_r))
        end)

      # Detect cycles in the region graph
      region_cycles = find_cycles_in_region_graph(region_graph)

      region_cycles
      |> Enum.map(fn cycle ->
        from_name = Map.get(tasks, elem(cycle, 0), %{name: elem(cycle, 0)}) |> Map.get(:name, elem(cycle, 0))
        to_name = Map.get(tasks, elem(cycle, 1), %{name: elem(cycle, 1)}) |> Map.get(:name, elem(cycle, 1))

        %{
          type: "deadlock",
          severity: :error,
          description:
            "Potential deadlock: cross-region dependency from '#{from_name}' to '#{to_name}' " <>
              "may cause circular wait between parallel branches"
        }
      end)
    end
  end

  @spec find_cycles_in_region_graph(%{integer() => MapSet.t()}) :: [{String.t(), String.t()}]
  defp find_cycles_in_region_graph(region_graph) do
    # Simple cycle detection: if region A -> region B and region B -> region A,
    # there's a potential deadlock
    cross_edges = []

    cross_edges =
      Enum.reduce(region_graph, cross_edges, fn {from, tos}, acc ->
        Enum.reduce(tos, acc, fn to, inner_acc ->
          if Map.get(region_graph, to, MapSet.new()) |> MapSet.member?(from) do
            [{from, to} | inner_acc]
          else
            inner_acc
          end
        end)
      end)

    cross_edges
  end

  # ===========================================================================
  # Private: Tarjan's SCC (for livelock detection)
  # ===========================================================================

  @spec tarjan_scc(%{String.t() => task()}, %{String.t() => [String.t()]}) :: [[String.t()]]
  defp tarjan_scc(tasks, adj) do
    nodes = Map.keys(tasks)

    # Iterative Tarjan's SCC algorithm
    # State: index_map = %{node => index, :next => counter, {node, :lowlink} => lowlink}
    #        stack = [node, ...], on_stack = MapSet.t()
    initial_state = {%{next: 0}, [], MapSet.new(), []}

    {_, _, _, sccs} =
      Enum.reduce(nodes, initial_state, fn node, {index_map, stack, on_stack, sccs} ->
        if Map.has_key?(index_map, node) do
          {index_map, stack, on_stack, sccs}
        else
          tarjan_visit(node, adj, {index_map, stack, on_stack, sccs})
        end
      end)

    sccs
  end

  # Iterative DFS-based Tarjan's SCC visitor.
  # Uses an explicit call stack to avoid recursion depth issues.
  defp tarjan_visit(start, adj, {index_map, stack, on_stack, sccs}) do
    # Call stack frames: {:visit, node} or {:resume, node, neighbors, visited_neighbors}
    call_stack = [{:visit, start}]
    {index_map, stack, on_stack, sccs} = {index_map, stack, on_stack, sccs}

    {index_map, stack, on_stack, sccs} =
      tarjan_loop(call_stack, adj, index_map, stack, on_stack, sccs)

    {index_map, stack, on_stack, sccs}
  end

  defp tarjan_loop([], _adj, index_map, stack, on_stack, sccs) do
    {index_map, stack, on_stack, sccs}
  end

  defp tarjan_loop([{:visit, v} | rest], adj, index_map, stack, on_stack, sccs) do
    v_index = index_map.next
    index_map = index_map |> Map.put(v, v_index) |> Map.put(:next, v_index + 1)
    index_map = Map.put(index_map, {v, :lowlink}, v_index)
    stack = [v | stack]
    on_stack = MapSet.put(on_stack, v)

    neighbors = Map.get(adj, v, [])
    tarjan_loop([{:resume, v, neighbors, []} | rest], adj, index_map, stack, on_stack, sccs)
  end

  defp tarjan_loop([{:resume, v, [w | remaining], visited} | rest], adj, index_map, stack, on_stack, sccs) do
    cond do
      not Map.has_key?(index_map, w) ->
        # Unvisited successor: push w onto call stack, resume v later
        tarjan_loop(
          [{:visit, w}, {:resume, v, remaining, [w | visited]} | rest],
          adj, index_map, stack, on_stack, sccs
        )

      MapSet.member?(on_stack, w) ->
        # Back edge: update lowlink
        w_index = Map.get(index_map, w)
        v_lowlink = Map.get(index_map, {v, :lowlink})
        new_lowlink = min(v_lowlink, w_index)
        index_map = Map.put(index_map, {v, :lowlink}, new_lowlink)

        tarjan_loop([{:resume, v, remaining, [w | visited]} | rest], adj, index_map, stack, on_stack, sccs)

      true ->
        # Cross edge to already-finished component: skip
        tarjan_loop([{:resume, v, remaining, [w | visited]} | rest], adj, index_map, stack, on_stack, sccs)
    end
  end

  defp tarjan_loop([{:resume, v, [], _visited} | rest], adj, index_map, stack, on_stack, sccs) do
    # All neighbors processed -- check if v is a root
    v_lowlink = Map.get(index_map, {v, :lowlink})
    v_index = Map.get(index_map, v)

    if v_lowlink == v_index do
      # Pop SCC from stack
      {component, new_stack} = pop_stack_until(v, stack)

      on_stack =
        Enum.reduce(component, on_stack, fn c, os -> MapSet.delete(os, c) end)

      # Only record SCCs with more than 1 node (cycles)
      new_sccs =
        if length(component) > 1 do
          [component | sccs]
        else
          sccs
        end

      tarjan_loop(rest, adj, index_map, new_stack, on_stack, new_sccs)
    else
      tarjan_loop(rest, adj, index_map, stack, on_stack, sccs)
    end
  end

  defp pop_stack_until(target, stack) do
    pop_stack_until(target, stack, [])
  end

  defp pop_stack_until(target, [target | rest], acc), do: {[target | acc], rest}

  defp pop_stack_until(target, [h | t], acc), do: pop_stack_until(target, t, [h | acc])

  defp pop_stack_until(_, [], acc), do: {acc, []}

  # ===========================================================================
  # Private: Livelock helpers
  # ===========================================================================

  @spec cycle_has_no_exit?([String.t()], %{String.t() => [String.t()]}) :: boolean()
  defp cycle_has_no_exit?(cycle_nodes, adj) do
    cycle_set = MapSet.new(cycle_nodes)

    # Check if ANY node in the cycle has an outgoing edge that LEAVES the cycle
    Enum.all?(cycle_nodes, fn node ->
      neighbors = Map.get(adj, node, [])
      Enum.all?(neighbors, fn neighbor -> MapSet.member?(cycle_set, neighbor) end)
    end)
  end

  # ===========================================================================
  # Private: Workflow normalization
  # ===========================================================================

  @spec normalize_workflow(workflow()) :: workflow()
  defp normalize_workflow(workflow) when is_map(workflow) do
    tasks_raw = Map.get(workflow, :tasks, %{})
    # Convert list of tasks to map format if needed
    tasks = if is_list(tasks_raw), do: Map.new(Enum.map(tasks_raw, &{&1[:id], &1})), else: tasks_raw
    transitions = Map.get(workflow, :transitions, [])
    start_node = Map.get(workflow, :start_node)
    end_node = Map.get(workflow, :end_node)
    metadata = Map.get(workflow, :metadata, %{})

    # Try to auto-detect start/end nodes if not specified
    {start_node, end_node} =
      cond do
        start_node && end_node ->
          {start_node, end_node}

        map_size(tasks) == 0 ->
          {nil, nil}

        true ->
          # Auto-detect: look for tasks with type :start/:end
          auto_start =
            tasks
            |> Map.values()
            |> Enum.find(fn t -> t[:type] == :start end)
            |> then(fn
              nil -> nil
              t -> t[:id]
            end)

          auto_end =
            tasks
            |> Map.values()
            |> Enum.find(fn t -> t[:type] == :end end)
            |> then(fn
              nil -> nil
              t -> t[:id]
            end)

          {start_node || auto_start, end_node || auto_end}
      end

    %{
      tasks: tasks,
      transitions: transitions,
      start_node: start_node,
      end_node: end_node,
      metadata: metadata
    }
  end

  # Handle non-map workflow inputs gracefully
  defp normalize_workflow(_workflow) do
    %{
      tasks: %{},
      transitions: [],
      start_node: nil,
      end_node: nil,
      metadata: %{}
    }
  end

  @doc """
  Analyze a workflow for structural issues.

  Delegates to analyze_workflow/2 for nil and empty input handling.
  """
  def analyze(nil), do: {:error, :nil_workflow}
  def analyze(workflow), do: analyze_workflow(workflow)
end
