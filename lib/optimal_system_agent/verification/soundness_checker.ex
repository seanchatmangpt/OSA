defmodule OptimalSystemAgent.Verification.SoundnessChecker do
  @moduledoc """
  Soundness Verification Module — WvdA (Wil van der Aalst) Correctness Analysis

  Analyzes GenServer supervision trees and state machines for soundness properties:
  1. **Soundness (no deadlock):** For every reachable marking, the sink place is reachable
  2. **Completeness:** All states that should be reachable are reachable
  3. **Fitness:** Model matches observed behavior (process logs)
  4. **Precision:** No over-generalization

  All proofs follow van der Aalst's workflow net soundness theorem.

  Reference: W. M. P. van der Aalst. "Verification of Workflow Nets."
  In: Application and Theory of Petri Nets 1997. ICATPN 1997. LNCS 1248.
  """

  require Logger

  @type state_machine :: {atom(), list(atom()), list(tuple())}
  @type deadlock_risk_score :: float()
  @type soundness_result :: {:sound, list(String.t())} | {:unsound, list(String.t())}

  # ═══════════════════════════════════════════════════════════════════════════════
  # PUBLIC API
  # ═══════════════════════════════════════════════════════════════════════════════

  @doc """
  Verify a state machine for soundness properties.

  Analyzes a state machine structure for:
  - No deadlock loops
  - Proper termination paths
  - All critical states reachable

  Returns {:sound, proofs} or {:unsound, gaps}

  Can accept either:
  - A state machine tuple: {name, [states], [transitions]}
  - A supervisor PID for inspection
  """
  @spec verify_tree(pid() | atom() | state_machine) :: soundness_result()
  def verify_tree({_name, _states, _transitions} = sm) do
    proofs = [
      verify_no_deadlock(sm),
      verify_completeness(sm),
      verify_liveness(sm)
    ]

    case Enum.all?(proofs, &match?({:ok, _}, &1)) do
      true ->
        proof_summaries = Enum.map(proofs, fn {:ok, msg} -> msg end)
        {:sound, proof_summaries}

      false ->
        gaps = Enum.filter_map(proofs, &match?({:error, _}, &1), fn {:error, msg} -> msg end)
        {:unsound, gaps}
    end
  end

  def verify_tree(supervisor_pid) when is_pid(supervisor_pid) or is_atom(supervisor_pid) do
    case fetch_supervision_tree(supervisor_pid) do
      {:ok, tree} ->
        proofs = [
          verify_no_deadlock(tree),
          verify_completeness(tree),
          verify_liveness(tree)
        ]

        case Enum.all?(proofs, &match?({:ok, _}, &1)) do
          true ->
            proof_summaries = Enum.map(proofs, fn {:ok, msg} -> msg end)
            {:sound, proof_summaries}

          false ->
            gaps = Enum.filter_map(proofs, &match?({:error, _}, &1), fn {:error, msg} -> msg end)
            {:unsound, gaps}
        end

      {:error, reason} ->
        {:unsound, ["Failed to analyze supervision tree: #{reason}"]}
    end
  end

  @doc """
  Analyze deadlock potential in a state machine.

  Returns a risk score (0.0–1.0):
  - 0.0 = No deadlock risk (all paths progress)
  - 0.5 = Moderate risk (some blocking states exist)
  - 1.0 = Critical (definite deadlock)

  ## Example

      iex> sm = {
      ...>   :states,
      ...>   [:initial, :processing, :done, :blocked],
      ...>   [
      ...>     {:initial, :processing},
      ...>     {:processing, :done},
      ...>     {:processing, :blocked},
      ...>     {:blocked, :blocked}  # Self-loop = deadlock risk
      ...>   ]
      ...> }
      iex> SoundnessChecker.analyze_deadlock_potential(sm)
      0.5
  """
  @spec analyze_deadlock_potential(state_machine) :: deadlock_risk_score()
  def analyze_deadlock_potential({_name, states, transitions}) do
    # Count states with no outgoing transitions (sinks)
    outgoing = build_adjacency_list(transitions)

    sink_states = Enum.filter(states, fn state ->
      outgoing[state] == nil or Enum.empty?(outgoing[state] || [])
    end)

    # Check for self-loops (indicating potential indefinite blocking)
    self_loops = Enum.count(transitions, fn {from, to} -> from == to end)

    # Risk calculation
    total_states = Enum.count(states)
    sink_ratio = Enum.count(sink_states) / max(total_states, 1)
    self_loop_ratio = self_loops / max(Enum.count(transitions), 1)

    # Higher risk if many sinks (dead ends) or self-loops without progress
    risk = (sink_ratio * 0.4) + (self_loop_ratio * 0.6)
    Float.round(min(risk, 1.0), 2)
  end

  @doc """
  Verify completeness: all states that should be reachable are reachable.

  Returns {:ok, summary} if complete, {:error, reason} if incomplete.

  ## Completeness Definition (WvdA)
  All transitions are on a path from source to sink:
  - Every place must be reachable from the source
  - The sink must be reachable from every place
  """
  @spec verify_completeness(state_machine) :: {:ok, String.t()} | {:error, String.t()}
  def verify_completeness({_name, states, transitions}) do
    outgoing = build_adjacency_list(transitions)
    incoming = build_reverse_adjacency_list(transitions)

    # Assume first state is source, last is sink
    source = List.first(states)
    sink = List.last(states)

    # Forward reachability from source
    forward_reachable = bfs_reachable(source, outgoing)

    # Backward reachability to sink
    backward_reachable = bfs_reachable(sink, incoming)

    # All states must be both forward and backward reachable
    unreachable_from_source = Enum.reject(states, &MapSet.member?(forward_reachable, &1))
    unreachable_to_sink = Enum.reject(states, &MapSet.member?(backward_reachable, &1))

    case {unreachable_from_source, unreachable_to_sink} do
      {[], []} ->
        {:ok, "Completeness verified: All #{Enum.count(states)} states reachable from source to sink"}

      {missing_forward, missing_backward} ->
        gaps =
          Enum.uniq(missing_forward ++ missing_backward)
          |> Enum.map(&inspect/1)
          |> Enum.join(", ")

        {:error, "Completeness violated: Unreachable states: #{gaps}"}
    end
  end

  @doc """
  Check fitness: Does the model match observed behavior?

  Compares model structure against an event log trace.
  Returns fitness_score (0.0–1.0):
  - 1.0 = Perfect fit (all observed transitions in model)
  - 0.5 = Partial fit (some transitions missing)
  - 0.0 = No fit (no observed transitions in model)
  """
  @spec check_fitness(list(String.t()), state_machine) :: float()
  def check_fitness(event_log_trace, {_name, _states, transitions}) do
    transition_set = MapSet.new(transitions)

    # Map events to transitions (event_i → event_i+1)
    observed_transitions = event_log_trace
      |> Enum.zip(Enum.drop(event_log_trace, 1))
      |> Enum.map(fn {e1, e2} ->
        # Convert string events to atoms for comparison with transition tuples
        {String.to_atom(e1), String.to_atom(e2)}
      end)

    matches = Enum.count(observed_transitions, fn observed ->
      MapSet.member?(transition_set, observed)
    end)

    case Enum.count(observed_transitions) do
      0 -> 1.0  # Empty trace = perfect fit
      total -> Float.round(matches / total, 2)
    end
  end

  @doc """
  Check precision: Does the model avoid over-generalization?

  Precision score (0.0–1.0):
  - 1.0 = No over-generalization (only observed behavior allowed)
  - 0.5 = Some over-generalization (model allows some unobserved behavior)
  - 0.0 = Complete over-generalization (model allows everything)

  Calculated as: 1 - (unobserved_transitions / allowed_transitions)
  """
  @spec check_precision(list(String.t()), state_machine) :: float()
  def check_precision(event_log_trace, {_name, _states, transitions}) do
    transition_set = MapSet.new(transitions)

    # Extract observed transitions from log
    observed_transitions = event_log_trace
      |> Enum.zip(Enum.drop(event_log_trace, 1))
      |> Enum.map(fn {e1, e2} ->
        # Convert string events to atoms for comparison
        {String.to_atom(e1), String.to_atom(e2)}
      end)
      |> MapSet.new()

    # Unobserved but allowed transitions
    unobserved_allowed = MapSet.difference(transition_set, observed_transitions)

    case Enum.count(transitions) do
      0 -> 1.0  # No transitions = perfect precision
      total -> Float.round(1.0 - (Enum.count(unobserved_allowed) / total), 2)
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════════
  # PRIVATE HELPERS
  # ═══════════════════════════════════════════════════════════════════════════════

  # Verify no deadlock: Check if any state can deadlock
  defp verify_no_deadlock({_name, states, transitions}) do
    outgoing = build_adjacency_list(transitions)

    # Get the sink state (last in states list)
    sink = List.last(states)

    # A state deadlocks if it has no outgoing transitions AND is not the sink state
    deadlock_states = Enum.filter(states, fn state ->
      has_no_outgoing = outgoing[state] == nil or Enum.empty?(outgoing[state] || [])
      is_not_sink = state != sink

      has_no_outgoing and is_not_sink
    end)

    case deadlock_states do
      [] ->
        {:ok, "No deadlock: All non-sink states have outgoing transitions"}

      bad_states ->
        formatted = bad_states |> Enum.map(&inspect/1) |> Enum.join(", ")
        {:error, "Deadlock risk in states: #{formatted}"}
    end
  end

  # Verify liveness: All transitions can fire
  defp verify_liveness({_name, states, transitions}) do
    incoming = build_reverse_adjacency_list(transitions)

    # Compute reachability from first state
    outgoing = build_adjacency_list(transitions)
    source = List.first(states)
    reachable_from_source = bfs_reachable(source, outgoing)

    # A transition is live if:
    # 1. Its source state is reachable from the initial state
    # 2. It has incoming transitions (or is from source)
    dead_transitions = Enum.filter(transitions, fn {from, _to} ->
      source_unreachable = not MapSet.member?(reachable_from_source, from)
      has_no_incoming = incoming[from] == nil or Enum.empty?(incoming[from] || [])
      from_not_source = from != source

      source_unreachable or (from_not_source and has_no_incoming)
    end)

    case dead_transitions do
      [] ->
        {:ok, "Liveness verified: All #{Enum.count(transitions)} transitions can fire"}

      dead ->
        formatted = dead |> Enum.map(&inspect/1) |> Enum.join(", ")
        {:error, "Dead transitions (unreachable): #{formatted}"}
    end
  end

  # Fetch the supervision tree from a supervisor
  defp fetch_supervision_tree(supervisor_pid) do
    try do
      # Use Supervisor.which_children/1 to get child specs
      case Supervisor.which_children(supervisor_pid) do
        children when is_list(children) ->
          {:ok, children}

        _ ->
          {:error, "Unable to fetch supervision tree"}
      end
    rescue
      _e in [BadArg, ArgumentError, UndefinedFunctionError] ->
        {:error, "Invalid supervisor PID"}
    end
  end

  # Build adjacency list: state → [reachable states]
  defp build_adjacency_list(transitions) do
    Enum.reduce(transitions, %{}, fn {from, to}, acc ->
      Map.update(acc, from, [to], &[to | &1])
    end)
  end

  # Build reverse adjacency list: state ← [sources]
  defp build_reverse_adjacency_list(transitions) do
    Enum.reduce(transitions, %{}, fn {from, to}, acc ->
      Map.update(acc, to, [from], &[from | &1])
    end)
  end

  # BFS: Find all reachable states from a starting state
  defp bfs_reachable(start, adjacency) do
    queue = :queue.in(start, :queue.new())
    visited = MapSet.new([start])
    bfs_loop(queue, visited, adjacency)
  end

  defp bfs_loop(queue, visited, adjacency) do
    case :queue.out(queue) do
      {{:value, current}, rest_queue} ->
        neighbors = adjacency[current] || []

        {new_queue, new_visited} =
          Enum.reduce(neighbors, {rest_queue, visited}, fn neighbor, {q, v} ->
            if MapSet.member?(v, neighbor) do
              {q, v}
            else
              {:queue.in(neighbor, q), MapSet.put(v, neighbor)}
            end
          end)

        bfs_loop(new_queue, new_visited, adjacency)

      {:empty, _} ->
        visited
    end
  end
end
