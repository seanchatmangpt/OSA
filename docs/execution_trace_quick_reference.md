# Execution Trace Store — Quick Reference

**Location:** `OSA/lib/optimal_system_agent/tracing/execution_trace.ex`

---

## Schema

```elixir
defmodule OptimalSystemAgent.Tracing.ExecutionTrace do
  schema "execution_traces" do
    field :id,              :string    # Primary key (required)
    field :trace_id,        :string    # OTEL trace ID (required)
    field :span_id,         :string    # OTEL span ID (required)
    field :parent_span_id,  :string    # Parent span (optional, for tree)
    field :agent_id,        :string    # Which agent (required)
    field :tool_id,         :string    # Which tool (optional)
    field :status,          :string    # "ok" or "error" (required)
    field :duration_ms,     :integer   # Time spent (optional)
    field :timestamp_us,    :integer   # Microsecond timestamp (required)
    field :error_reason,    :string    # Error message (optional)
    timestamps()
  end
end
```

---

## Quick API Reference

### Record a Span

```elixir
ExecutionTrace.record_span(%{
  id: "span_#{System.unique_integer()}",
  trace_id: trace_id,
  span_id: span_id,
  parent_span_id: parent_span_id,
  agent_id: agent_id,
  tool_id: tool_name,
  status: "ok",                              # or "error"
  duration_ms: duration,
  timestamp_us: System.os_time(:microsecond),
  error_reason: error_msg
})
```

### Get Full Trace Tree

```elixir
{:ok, spans} = ExecutionTrace.get_trace(trace_id)
# Returns: [%ExecutionTrace{}, ...] sorted by timestamp_us
```

### Query Agent Traces

```elixir
start_us = 1_645_123_456_000_000
end_us = 1_645_123_457_000_000

{:ok, traces} = ExecutionTrace.traces_for_agent("agent_id", {start_us, end_us})
# Returns: [%ExecutionTrace{}, ...] within time range
```

### Detect Deadlocks

```elixir
{:ok, cycles} = ExecutionTrace.find_circular_calls(start_us, end_us)
# Returns: [["agent_a", "agent_b"], ...] or []
# Empty = deadlock-free ✓
```

### Cleanup Old Traces

```elixir
{:ok, deleted_count} = ExecutionTrace.cleanup_old_traces(30)
# Deletes traces > 30 days old (for boundedness guarantee)
```

### Monitor Table Size

```elixir
{:ok, count} = ExecutionTrace.table_size()
# Warn if count > 1_000_000
```

---

## WvdA Soundness Verification

| Property | Check | Command |
|----------|-------|---------|
| **Deadlock-Free** | No circular calls | `find_circular_calls/2` → `[]` |
| **Liveness** | All ops complete | `traces_for_agent/2` → all have status |
| **Bounded** | Storage limit | `table_size/0` < 1M, cleanup daily |

---

## Integration in Agent Executor

```elixir
def execute_with_tracing(agent, input) do
  trace_id = generate_trace_id()
  start_us = System.os_time(:microsecond)

  # Execute agent
  result = run_agent(agent, input, trace_id)

  # Record span
  duration_ms = div(System.os_time(:microsecond) - start_us, 1000)

  ExecutionTrace.record_span(%{
    id: "span_#{System.unique_integer()}",
    trace_id: trace_id,
    span_id: generate_span_id(),
    parent_span_id: nil,
    agent_id: agent.id,
    tool_id: agent.current_tool,
    status: if(result[:error], do: "error", else: "ok"),
    duration_ms: duration_ms,
    timestamp_us: start_us,
    error_reason: result[:error]
  })

  result
end
```

---

## Testing

### Unit Tests (No DB)
```bash
mix test test/optimal_system_agent/tracing/execution_trace_test.exs --no-start
# 32 tests, changeset validation only
```

### Integration Tests (With DB)
```bash
mix test test/optimal_system_agent/tracing/execution_trace_integration_test.exs --include integration
# 23 tests, full Repo operations
```

---

## Example: Daily WvdA Verification Task

```elixir
defmodule TraceAnalyzer do
  def daily_check do
    now_us = System.os_time(:microsecond)
    day_ago_us = now_us - 24 * 60 * 60 * 1_000_000

    # 1. Check deadlock-free
    {:ok, cycles} = ExecutionTrace.find_circular_calls(day_ago_us, now_us)
    deadlock_free = if cycles == [], do: "✓", else: "✗ #{length(cycles)} cycles"

    # 2. Check liveness
    {:ok, size} = ExecutionTrace.table_size()
    {:ok, errors} = ExecutionTrace.traces_for_agent("*", {day_ago_us, now_us})
    error_count = Enum.count(errors, &(&1.status == "error"))
    liveness = if error_count == 0, do: "✓", else: "✗ #{error_count} errors"

    # 3. Check bounded
    bounded = if size < 1_000_000, do: "✓", else: "✗ #{size} rows"

    # 4. Cleanup old traces
    {:ok, cleaned} = ExecutionTrace.cleanup_old_traces(30)

    report = """
    WvdA Soundness Daily Report
    ===========================
    Deadlock-Free: #{deadlock_free}
    Liveness:      #{liveness}
    Bounded:       #{bounded}
    Cleaned:       #{cleaned} old traces
    Table Size:    #{size} rows
    """

    Logger.info(report)
    report
  end
end
```

---

## Timestamps in Microseconds

```elixir
# Get current timestamp (microseconds)
now_us = System.os_time(:microsecond)

# Convert to/from common formats
start_of_day_us = 1_645_123_200_000_000  # Example

# Calculate range for last 1 hour
end_us = System.os_time(:microsecond)
start_us = end_us - 60 * 60 * 1_000_000

ExecutionTrace.traces_for_agent("agent_1", {start_us, end_us})
```

---

## Files

| File | Lines | Purpose |
|------|-------|---------|
| `lib/optimal_system_agent/tracing/execution_trace.ex` | 256 | Schema + API |
| `priv/repo/migrations/20260326000001_create_execution_traces.exs` | 25 | DB migration |
| `test/optimal_system_agent/tracing/execution_trace_test.exs` | 450+ | Unit tests (32) |
| `test/optimal_system_agent/tracing/execution_trace_integration_test.exs` | 450+ | Integration tests (23) |

---

## Status Values

```
"ok"    → Operation succeeded
"error" → Operation failed (check error_reason)
```

---

## Performance

| Operation | Time | DB Hits |
|-----------|------|---------|
| `record_span/1` | ~1ms | 1 INSERT |
| `get_trace/1` | ~5ms | 1 SELECT (indexed) |
| `traces_for_agent/2` | ~10ms | 1 SELECT (indexed range) |
| `find_circular_calls/2` | ~50ms | 1 SELECT + DFS |
| `cleanup_old_traces/1` | ~100ms | 1 DELETE (batch) |
| `table_size/0` | ~1ms | 1 COUNT |

