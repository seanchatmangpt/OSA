# Execution Trace Store — WvdA Historical Analysis

**Date:** 2026-03-26
**Purpose:** Historical deadlock and liveness analysis for Wil van der Aalst (WvdA) soundness verification
**Location:** `OSA/lib/optimal_system_agent/tracing/`

---

## Overview

The Execution Trace Store persists OpenTelemetry span data for analysis of deadlock, liveness, and boundedness patterns. Every span recorded during agent execution creates an immutable record that can be queried to:

1. **Detect deadlocks**: Identify circular call chains (A→B→C→A)
2. **Verify liveness**: Confirm all operations complete (no infinite loops)
3. **Guarantee boundedness**: Monitor resource limits and auto-cleanup

This is a **WvdA Soundness Requirement** — systems must prove they are deadlock-free, liveness-guaranteed, and bounded.

---

## Schema

**Table:** `execution_traces`

```elixir
schema "execution_traces" do
  field :id,              :string    # Primary key (span-unique)
  field :trace_id,        :string    # OTEL trace identifier
  field :span_id,         :string    # OTEL span identifier
  field :parent_span_id,  :string    # Parent span (enables tree reconstruction)
  field :agent_id,        :string    # Which agent executed
  field :tool_id,         :string    # Which tool ran
  field :status,          :string    # "ok" or "error"
  field :duration_ms,     :integer   # Execution time (WvdA timing analysis)
  field :timestamp_us,    :integer   # Microsecond Unix timestamp
  field :error_reason,    :string    # Optional error message

  timestamps()  # inserted_at, updated_at
end
```

### Indexes

| Index | Purpose |
|-------|---------|
| `(trace_id)` | Retrieve full trace tree by trace_id |
| `(agent_id, timestamp_us)` | Query traces for agent within time range |
| `(status)` | Find all error spans |
| `(agent_id, timestamp_us, status)` | Complex range + status queries |

---

## API

### record_span(attrs) → {:ok, trace} \| {:error, changeset}

Record a single span in the execution trace store.

**Example:**
```elixir
{:ok, trace} = ExecutionTrace.record_span(%{
  id: "span_abc123",
  trace_id: "4bf92f3577b34da6a3ce929d0e0e4736",
  span_id: "00f067aa0ba902b7",
  parent_span_id: "00f067aa0ba902b6",
  agent_id: "agent_healing_1",
  tool_id: "process_fingerprint",
  status: "ok",
  duration_ms: 45,
  timestamp_us: 1_645_123_456_789_000,
  error_reason: nil
})
```

**Duplicate handling:** `on_conflict: :nothing` — duplicate IDs are silently ignored (idempotent).

---

### get_trace(trace_id) → {:ok, [spans]}

Retrieve a complete trace tree (all spans for a given trace_id).

**Returns:** Ordered by `timestamp_us` (root first).

**Example:**
```elixir
{:ok, spans} = ExecutionTrace.get_trace("4bf92f3577b34da6a3ce929d0e0e4736")
# Returns: [
#   %ExecutionTrace{span_id: "span_1", timestamp_us: 1000},
#   %ExecutionTrace{span_id: "span_2", timestamp_us: 2000},
#   %ExecutionTrace{span_id: "span_3", timestamp_us: 3000}
# ]
```

---

### traces_for_agent(agent_id, {start_us, end_us}) → {:ok, [spans]}

Query traces for a specific agent within a time range.

**Parameters:**
- `agent_id`: String identifier (e.g., "agent_healing_1")
- `{start_us, end_us}`: Microsecond Unix timestamps (inclusive boundaries)

**Example:**
```elixir
start_us = 1_645_123_456_000_000
end_us = 1_645_123_457_000_000

{:ok, traces} = ExecutionTrace.traces_for_agent("agent_healing_1", {start_us, end_us})
# Returns all spans for agent_healing_1 within the time range
```

---

### find_circular_calls(start_us, end_us) → {:ok, [[agent_ids]]}

Detect circular call patterns (deadlock signatures) within a time range.

**Algorithm:** Depth-first search on call graph (parent_span_id → span_id mapping).

**Returns:** List of cycles, each cycle is a list of agent IDs.

**Example:**
```elixir
{:ok, cycles} = ExecutionTrace.find_circular_calls(start_us, end_us)
# If A→B→A found: [["agent_a", "agent_b"], ...]
# If no cycles: []
```

**WvdA Interpretation:**
- Empty result = deadlock-free for the time period
- Non-empty result = potential deadlock detected (requires investigation)

---

### cleanup_old_traces(retention_days) → {:ok, deleted_count}

Delete traces older than `retention_days` (for boundedness guarantee).

**Called periodically** (recommend: daily) to prevent unbounded table growth.

**Example:**
```elixir
# Delete traces older than 30 days
{:ok, 1500} = ExecutionTrace.cleanup_old_traces(30)
# Deleted 1500 rows
```

**Monitoring:** Warn if table grows above 1M rows.

---

### table_size() → {:ok, count}

Get current number of rows in execution_traces table.

**Used for:** Boundedness monitoring (verify resource limits enforced).

**Example:**
```elixir
{:ok, 45000} = ExecutionTrace.table_size()
```

---

## Testing

### Unit Tests (Pure Schema Validation)

**File:** `test/optimal_system_agent/tracing/execution_trace_test.exs`
**Count:** 32 tests
**Async:** true
**Requires DB:** No

Tests changeset validation, required fields, constraints, and edge cases:
- Status enum validation ("ok" or "error")
- Timestamp and duration bounds checking
- Optional field handling
- Unicode and large value edge cases

**Run:**
```bash
mix test test/optimal_system_agent/tracing/execution_trace_test.exs --no-start
```

### Integration Tests (Repo Operations)

**File:** `test/optimal_system_agent/tracing/execution_trace_integration_test.exs`
**Count:** 23 tests
**Async:** false
**Requires DB:** Yes (marked with `@moduletag :integration`)

Tests database operations:
- `record_span/1` — inserting traces
- `get_trace/1` — retrieving full trace trees
- `traces_for_agent/2` — agent-specific queries
- `find_circular_calls/2` — deadlock detection
- `cleanup_old_traces/1` — data retention
- `table_size/0` — boundedness monitoring

**Run with full app:**
```bash
mix test test/optimal_system_agent/tracing/execution_trace_integration_test.exs --include integration
```

---

## Database Setup

### Migration

**File:** `priv/repo/migrations/20260326000001_create_execution_traces.exs`

Creates `execution_traces` table with proper indexes for deadlock/liveness analysis.

**Run:**
```bash
mix ecto.migrate
```

---

## WvdA Soundness Mapping

### 1. Deadlock Freedom (Safety)

The `timestamp_us` and `duration_ms` fields enable timeout detection:

```elixir
# Query: Find spans with excessive duration (timeout indicator)
from t in ExecutionTrace,
  where: t.duration_ms > 30_000,  # > 30 seconds = likely timeout
  select: t
```

The `find_circular_calls/2` function detects circular dependencies:

```elixir
# Query: Find A→B→C→A patterns (deadlock signature)
{:ok, cycles} = ExecutionTrace.find_circular_calls(start_us, end_us)
if cycles == [], do: "Deadlock-free ✓"
```

### 2. Liveness (Progress Guarantee)

The `status` field ("ok" or "error") proves completion:

```elixir
# Query: Find spans that errored (liveness violation)
from t in ExecutionTrace,
  where: t.status == "error",
  group_by: t.agent_id,
  select: {t.agent_id, count(t.id)}
```

All spans must eventually have a status (ok or error) — no infinite loops.

### 3. Boundedness (Resource Guarantee)

The `cleanup_old_traces/1` function enforces size limits:

```elixir
# Daily: Delete traces >30 days old
{:ok, deleted} = ExecutionTrace.cleanup_old_traces(30)
Logger.info("Cleaned #{deleted} old traces")

# Monitor: Warn if table > 1M rows
{:ok, size} = ExecutionTrace.table_size()
if size > 1_000_000, do: alert("Trace store unbounded!")
```

---

## Integration Points

### OSA Agent Execution

When an agent runs, the executor should emit spans:

```elixir
# In agent executor:
def execute(agent, input) do
  start_us = System.os_time(:microsecond)
  result = run_agent(agent, input)
  duration_ms = div(System.os_time(:microsecond) - start_us, 1000)

  :ok = ExecutionTrace.record_span(%{
    id: "span_#{System.unique_integer()}",
    trace_id: trace_id,  # From context
    span_id: generate_span_id(),
    parent_span_id: parent_span_id,  # From context
    agent_id: agent.id,
    tool_id: agent.current_tool,
    status: if(result.error, do: "error", else: "ok"),
    duration_ms: duration_ms,
    timestamp_us: start_us,
    error_reason: result.error
  })

  result
end
```

### Monitoring & Alerts

Create a daily background task:

```elixir
# In supervisor:
{Task.Supervisor, name: TraceCleanup.Supervisor},

# Scheduled task:
def cleanup_traces do
  {:ok, deleted} = ExecutionTrace.cleanup_old_traces(30)
  {:ok, size} = ExecutionTrace.table_size()

  case {deleted, size} do
    {_, size} when size > 1_000_000 ->
      Logger.warn("Execution trace table unbounded: #{size} rows")
    {deleted, _} when deleted > 0 ->
      Logger.info("Cleaned #{deleted} old execution traces")
    _ -> :ok
  end
end
```

---

## Example Workflow: WvdA Verification

```elixir
# 1. Agent runs, emits spans (50 spans over 1 hour)
# 2. Analyst queries for deadlock patterns:
{:ok, cycles} = ExecutionTrace.find_circular_calls(start_us, end_us)

case cycles do
  [] ->
    # DEADLOCK-FREE ✓
    "No circular dependencies detected"

  cycles ->
    # POTENTIAL DEADLOCK ✗
    "Found cycles: #{inspect(cycles)}"
    # Recommendation: Investigate agent #{hd(hd(cycles))}
end

# 3. Check liveness (all operations completed):
{:ok, errors} = ExecutionTrace.traces_for_agent("agent_1", {start_us, end_us})
error_count = Enum.count(errors, &(&1.status == "error"))

case error_count do
  0 ->
    # LIVENESS ✓
    "All operations completed (0 errors)"

  n ->
    # LIVENESS VIOLATION ✗
    "#{n} operations failed — investigate error_reason"
end

# 4. Verify boundedness (storage limits):
{:ok, size} = ExecutionTrace.table_size()

case size do
  size when size < 1_000_000 ->
    # BOUNDED ✓
    "Trace store within bounds: #{size} rows"

  size ->
    # UNBOUNDED ✗
    "Trace store exceeds limit: #{size} rows"
    # Action: Increase retention_days in cleanup_old_traces/1
end
```

---

## Performance Characteristics

| Operation | Complexity | Notes |
|-----------|-----------|-------|
| `record_span/1` | O(1) | Single insert, on_conflict handling |
| `get_trace/1` | O(n) | n = spans in trace (typically < 100) |
| `traces_for_agent/2` | O(log n) + O(k) | Index on (agent_id, timestamp_us), k = results |
| `find_circular_calls/2` | O(V + E) | V = spans, E = parent relationships (DFS) |
| `cleanup_old_traces/1` | O(k) | k = rows to delete (typically < 1% of table) |
| `table_size/0` | O(1) | Aggregate query (can use DB cache) |

---

## Future Enhancements

1. **OTEL Integration:** Accept spans directly from OTEL collector
2. **Alert Engine:** Auto-detect circular calls and trigger escalation
3. **Analytics Dashboard:** Visualize deadlock/liveness metrics over time
4. **Formal Verification:** Export to UPPAAL or TLA+ for mathematical proof
5. **Budget Enforcement:** Link to budget tier to enforce per-agent limits

---

## Files Created

| File | Purpose |
|------|---------|
| `lib/optimal_system_agent/tracing/execution_trace.ex` | Schema + API |
| `priv/repo/migrations/20260326000001_create_execution_traces.exs` | Database migration |
| `test/optimal_system_agent/tracing/execution_trace_test.exs` | Unit tests (32 tests, pure schema) |
| `test/optimal_system_agent/tracing/execution_trace_integration_test.exs` | Integration tests (23 tests, requires DB) |

---

## Test Results

```
Unit Tests (--no-start):
  32 tests passed ✓
  0 failures
  Execution time: 0.1s (async, no DB)

Integration Tests (with --include integration):
  23 tests (pending full app startup)
  Tests: record_span, get_trace, traces_for_agent, find_circular_calls,
         cleanup_old_traces, table_size, full lifecycle
```

---

## Status

- [x] Schema design (deadlock/liveness/boundedness fields)
- [x] Migration file created
- [x] API functions implemented (record, query, cleanup, monitor)
- [x] Unit tests (32 passing, no DB required)
- [x] Integration tests (23 tests, marked for full app)
- [x] Documentation (this file)
- [ ] OTEL instrumentation (future: add to agent executor)
- [ ] Alert engine (future: auto-detection)
- [ ] Analytics dashboard (future: metrics visualization)

---

## References

- **WvdA Process Verification:** `docs/.claude/rules/wvda-soundness.md`
- **Petri Net Deadlock Detection:** van der Aalst, *Process Mining* (2016), Ch. 2
- **OpenTelemetry Spans:** https://opentelemetry.io/docs/concepts/signals/traces/

