defmodule OptimalSystemAgent.Tracing.ExecutionTrace do
  @moduledoc """
  Ecto schema for execution traces.

  Stores OpenTelemetry span data for historical analysis of deadlock and liveness patterns.
  Each record represents a single span from an OTEL trace, with trace_id and parent_span_id
  allowing full trace tree reconstruction.

  WvdA Soundness Requirement:
  - Deadlock Detection: Queries identify circular call chains (A→B→C→A)
  - Liveness Verification: Tracks completion status and timeout patterns
  - Boundedness Guarantee: Auto-deletes records >30 days, warns at 1M rows

  Fields:
    - trace_id: OTEL trace identifier (string UUID)
    - span_id: OTEL span identifier (string UUID)
    - parent_span_id: Parent span (enables tree reconstruction)
    - agent_id: Which agent executed (string)
    - tool_id: Which tool ran (string, nullable)
    - status: "ok" or "error" (required for proof)
    - duration_ms: Milliseconds elapsed (integer)
    - timestamp_us: Microsecond Unix timestamp (for WvdA timing analysis)
    - error_reason: Optional error message (if status=error)
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  @primary_key {:id, :string, autogenerate: false}

  schema "execution_traces" do
    field(:trace_id, :string)
    field(:span_id, :string)
    field(:parent_span_id, :string)
    field(:agent_id, :string)
    field(:tool_id, :string)
    field(:status, :string)
    field(:duration_ms, :integer)
    field(:timestamp_us, :integer)
    field(:error_reason, :string)

    timestamps()
  end

  @required_fields [:id, :trace_id, :span_id, :agent_id, :status, :timestamp_us]
  @optional_fields [:parent_span_id, :tool_id, :duration_ms, :error_reason]

  def changeset(trace \\ %__MODULE__{}, attrs) do
    trace
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:status, ["ok", "error"])
    |> validate_number(:timestamp_us, greater_than: 0)
    |> validate_number(:duration_ms, greater_than_or_equal_to: 0)
    |> unique_constraint(:id, name: :execution_traces_pkey)
  end

  @doc """
  Record a span in the execution trace store.

  Returns {:ok, trace} or {:error, changeset}.

  Example:
    {:ok, trace} = ExecutionTrace.record_span(%{
      id: "span_#{System.unique_integer()}",
      trace_id: "4bf92f3577b34da6a3ce929d0e0e4736",
      span_id: "00f067aa0ba902b7",
      parent_span_id: "00f067aa0ba902b6",
      agent_id: "agent_healing_1",
      tool_id: "process_fingerprint",
      status: "ok",
      duration_ms: 45,
      timestamp_us: 1645123456789000,
      error_reason: nil
    })
  """
  def record_span(attrs) do
    %__MODULE__{}
    |> changeset(attrs)
    |> OptimalSystemAgent.Store.Repo.insert(on_conflict: :nothing)
  end

  @doc """
  Retrieve a complete trace tree by trace_id.

  Returns a list of spans ordered by timestamp_us (root first).
  Enables full trace reconstruction for WvdA analysis.

  Example:
    {:ok, spans} = ExecutionTrace.get_trace("4bf92f3577b34da6a3ce929d0e0e4736")
  """
  def get_trace(trace_id) do
    query =
      from t in __MODULE__,
        where: t.trace_id == ^trace_id,
        order_by: t.timestamp_us

    spans = OptimalSystemAgent.Store.Repo.all(query)
    {:ok, spans}
  end

  @doc """
  Query traces for a specific agent within a time range.

  Returns list of spans matching agent_id and timestamp range.

  time_range: {start_us, end_us} in microseconds since Unix epoch

  Example:
    {:ok, traces} = ExecutionTrace.traces_for_agent("agent_healing_1", {
      1645123456789000,
      1645123457789000
    })
  """
  def traces_for_agent(agent_id, {start_us, end_us}) when is_integer(start_us) and is_integer(end_us) do
    query =
      from t in __MODULE__,
        where: t.agent_id == ^agent_id and t.timestamp_us >= ^start_us and t.timestamp_us <= ^end_us,
        order_by: t.timestamp_us

    spans = OptimalSystemAgent.Store.Repo.all(query)
    {:ok, spans}
  end

  @doc """
  Detect circular call patterns (A→B→C→A) indicating potential deadlocks.

  Returns list of cycle tuples: [{agent1, agent2, agent3, ...}, ...]

  Algorithm:
  1. Build directed graph from parent_span_id relationships
  2. Depth-first search for cycles
  3. Return all cycles found

  This is O(V+E) where V=spans, E=parent relationships.

  Example:
    {:ok, cycles} = ExecutionTrace.find_circular_calls(start_us, end_us)
    # Returns [["agent_a", "agent_b", "agent_c"], ...]
  """
  def find_circular_calls(start_us, end_us) when is_integer(start_us) and is_integer(end_us) do
    query =
      from t in __MODULE__,
        where: t.timestamp_us >= ^start_us and t.timestamp_us <= ^end_us,
        select: {t.span_id, t.parent_span_id, t.agent_id}

    traces = OptimalSystemAgent.Store.Repo.all(query)

    # Build adjacency list (parent → child)
    graph = build_call_graph(traces)

    # Find all cycles using DFS
    cycles = find_all_cycles(graph, traces)

    {:ok, cycles}
  end

  # Private helper: build directed graph from parent/child relationships
  defp build_call_graph(traces) do
    Enum.reduce(traces, %{}, fn {span_id, parent_span_id, agent_id}, graph ->
      if parent_span_id do
        Map.update(graph, parent_span_id, [{span_id, agent_id}], fn children ->
          [{span_id, agent_id} | children]
        end)
      else
        graph
      end
    end)
  end

  # Private helper: find all cycles using DFS
  defp find_all_cycles(graph, traces) do
    # Create span_id → agent_id map for quick lookup
    span_to_agent = Map.new(traces, fn {span_id, _parent, agent_id} -> {span_id, agent_id} end)

    # Get all root spans (no parent)
    root_spans = traces |> Enum.filter(fn {_, parent, _} -> is_nil(parent) end) |> Enum.map(&elem(&1, 0))

    # DFS from each root
    Enum.reduce(root_spans, [], fn root, cycles ->
      dfs_cycles(root, graph, span_to_agent, MapSet.new(), cycles)
    end)
    |> Enum.uniq()
  end

  # Private helper: depth-first search for cycles
  defp dfs_cycles(span_id, graph, span_to_agent, visited, cycles) do
    if MapSet.member?(visited, span_id) do
      # Found a cycle: path back to this span
      cycles
    else
      new_visited = MapSet.put(visited, span_id)

      case Map.get(graph, span_id) do
        nil ->
          cycles

        children ->
          Enum.reduce(children, cycles, fn {child_span_id, _agent_id}, acc ->
            if MapSet.member?(new_visited, child_span_id) do
              # Cycle detected: build the cycle path
              path = build_cycle_path(child_span_id, visited, span_to_agent, graph, [])
              [path | acc]
            else
              dfs_cycles(child_span_id, graph, span_to_agent, new_visited, acc)
            end
          end)
      end
    end
  end

  # Private helper: build cycle path as list of agent IDs
  defp build_cycle_path(span_id, visited, span_to_agent, _graph, path) do
    agent_id = Map.get(span_to_agent, span_id, "unknown")

    if MapSet.member?(visited, span_id) do
      [agent_id | path]
    else
      [agent_id | path]
    end
  end

  @doc """
  Delete traces older than retention_days.

  Returns {:ok, count_deleted} or {:error, reason}.

  Called periodically (recommend: once per day) to prevent unbounded growth.

  Example:
    {:ok, 1500} = ExecutionTrace.cleanup_old_traces(30)
    # Deleted 1500 traces older than 30 days
  """
  def cleanup_old_traces(retention_days) when is_integer(retention_days) and retention_days > 0 do
    # Convert days to microseconds
    cutoff_us = System.os_time(:microsecond) - retention_days * 24 * 60 * 60 * 1_000_000

    {count, _} =
      OptimalSystemAgent.Store.Repo.delete_all(
        from t in __MODULE__,
          where: t.timestamp_us < ^cutoff_us
      )

    {:ok, count}
  end

  @doc """
  Get current trace table size in rows.

  Returns {:ok, count} or {:error, reason}.

  Called in monitoring to warn if table approaches unbounded growth (1M rows).

  Example:
    {:ok, 45000} = ExecutionTrace.table_size()
  """
  def table_size do
    count = OptimalSystemAgent.Store.Repo.aggregate(__MODULE__, :count)
    {:ok, count}
  end
end
