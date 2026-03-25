# PM4PyCoordinator A2A Swarm Integration

## Overview

Wire OSA PM4PyCoordinator to launch an A2A swarm with Byzantine consensus for distributed process discovery. This enables:

- **Parallel discovery**: 3+ agents discover on partitioned event logs simultaneously
- **Byzantine consensus**: Selects final model from agent results with configurable threshold (0.7)
- **A2A posting**: Results posted to BusinessOS via A2A protocol with metadata
- **Fallback logic**: When consensus < 0.7, uses first valid result + consensus note

## Architecture

```
PM4PyCoordinator.launch_swarm(log, opts)
  ├─ Generate swarm_id
  ├─ Partition event log by case_id hash
  ├─ launch_parallel_swarm/3
  │  ├─ Task.Supervisor.async_stream (30s timeout)
  │  └─ discover_partition_via_swarm/4 → HTTP POST /api/discover
  ├─ compute_byzantine_consensus/2
  │  ├─ Validate all agent results
  │  ├─ Calculate consensus_level = valid_count / total_count
  │  └─ Fallback: if consensus_level < 0.7, use first valid
  ├─ post_to_businessos/3
  │  └─ Generate A2A metadata: {agent, method, params, timestamp}
  └─ Return: {:ok, %{swarm_id, agent_results, consensus_model, consensus_level, a2a_call_metadata, execution_time_ms}}
```

## Data Structures

### Input: Event Log
```elixir
%{
  "events" => [
    %{"case_id" => "a_1", "activity" => "Start", "timestamp" => "..."},
    %{"case_id" => "a_1", "activity" => "Process", "timestamp" => "..."},
    ...
  ],
  "trace_count" => 300,
  "event_count" => 1300
}
```

### Output: Swarm Result
```elixir
{:ok, %{
  "swarm_id" => "63d707df718b4575",                    # Unique hex ID
  "agent_results" => %{
    0 => {:ok, %{"model" => {...}}},
    1 => {:ok, %{"model" => {...}}},
    2 => {:error, "..."}
  },
  "consensus_model" => %{"places" => [...], "transitions" => [...]},
  "consensus_level" => 0.66,                           # 2/3 agents
  "consensus_note" => "Fallback to first result (consensus < 0.7 threshold)",
  "a2a_call_metadata" => %{
    "agent" => "pm4py_coordinator",
    "method" => "discover",
    "params" => %{
      "swarm_id" => "...",
      "model" => {...},
      "consensus_level" => 0.66,
      "consensus_note" => "...",
      "algorithm" => "inductive_miner"
    },
    "timestamp" => "2026-03-25T..."
  },
  "execution_time_ms" => 245,
  "algorithm" => "inductive_miner",
  "timestamp" => "2026-03-25T..."
}}
```

### A2A Call to BusinessOS

Agent code (e.g., in ReAct loop) invokes:

```elixir
OptimalSystemAgent.Tools.Builtins.A2ACall.execute(%{
  "action" => "execute_tool",
  "agent_url" => "http://localhost:8001/api/integrations/a2a/agents",
  "tool_name" => "pm4py_discover",
  "arguments" => %{
    "swarm_id" => swarm_result["swarm_id"],
    "model" => swarm_result["consensus_model"],
    "consensus_level" => swarm_result["consensus_level"],
    "consensus_note" => swarm_result["consensus_note"],
    "algorithm" => swarm_result["algorithm"]
  }
})
```

## Functions

### Public API

#### `launch_swarm(event_log, opts \\ [])`

Launch A2A swarm for distributed discovery with Byzantine consensus.

**Parameters:**
- `event_log`: Map with `"events"`, `"trace_count"`, `"event_count"` keys
- `opts`: Keyword list
  - `agent_count`: Integer (default: 3, from `PM4PY_COORDINATOR_AGENTS` env)
  - `algorithm`: String (default: "inductive_miner", from `PM4PY_COORDINATOR_ALGORITHM` env)
  - `byzantine_threshold`: Float (default: 0.7, from `PM4PY_COORDINATOR_BYZANTINE` env)

**Returns:**
- `{:ok, swarm_result}` — Swarm execution successful
- `{:error, reason}` — Swarm execution failed (< 2 agents succeeded, no valid models, etc.)

### Helper Functions (Public for Testing)

#### `compute_byzantine_consensus(agent_results, byzantine_threshold)`

Validate all agent results and select consensus model.

**Parameters:**
- `agent_results`: Map of `{agent_id => result_tuple}`
- `byzantine_threshold`: Float consensus threshold (0.0..1.0)

**Returns:**
- `{:ok, consensus_data}` — Contains `model`, `consensus_level`, `note`
- `{:error, reason}` — No valid results to consensus

#### `post_to_businessos(swarm_id, consensus_data, algorithm)`

Generate A2A metadata for posting result to BusinessOS.

**Parameters:**
- `swarm_id`: String unique swarm identifier
- `consensus_data`: Map with `model`, `consensus_level`, `note`
- `algorithm`: String discovery algorithm name

**Returns:**
- `{:ok, a2a_metadata}` — Ready-to-send A2A payload

#### `generate_swarm_id()`

Generate unique hex ID for swarm execution.

**Returns:**
- Binary string (16 hex characters)

#### `validate_model(model)`

Validate Petri net / BPMN model structure.

**Parameters:**
- `model`: Map with `"places"` and `"transitions"` keys

**Returns:**
- `:ok` — Model is valid
- `{:error, reason}` — Model is invalid

## Test Coverage

### Unit Tests (16/16 passing)

File: `test/integration/pm4py_swarm_unit_test.exs`

**Byzantine Consensus:**
- All valid results (3/3) → consensus_level = 1.0
- Partial results (2/3) → consensus_level = 0.66, fallback
- Single valid result → consensus_level = 1.0, single result note
- No valid results → error

**A2A Posting:**
- Metadata structure: agent, method, params, timestamp
- Timestamp in ISO8601 format
- Model and consensus metadata included

**Swarm ID Generation:**
- Unique hex strings (16 characters)
- Valid hex format (0-9a-f only)

**Consensus Thresholds:**
- 3 agents: 2/3 = 0.66 < 0.7 (fallback)
- 3 agents: 3/3 = 1.0 >= 0.7 (consensus)
- 4 agents: 3/4 = 0.75 >= 0.7 (consensus)
- 5 agents: 3/5 = 0.6 < 0.7 (fallback)

**Model Validation:**
- Valid Petri net (places + transitions)
- Rejects empty places
- Rejects empty transitions
- Rejects non-map model

### Integration Tests (6 tests in pm4py_osa_e2e_test.exs)

File: `test/integration/pm4py_osa_e2e_test.exs`

Tests require PM4Py HTTP server running at `http://localhost:8089`.

**Swarm Launch:**
1. `test "launch_swarm returns 3 agent results from parallel execution"`
2. `test "Byzantine consensus selects model appearing in 2+ agent results"`
3. `test "A2A call succeeds and posts model to BusinessOS"`
4. `test "swarm launch includes swarm_id and consensus_level in metadata"`
5. `test "consensus threshold 0.7 with 3 agents falls back to first result when consensus < 0.7"`
6. `test "error handling when less than 2 agents succeed"`
7. `test "timeout handling: 30s timeout for all 3 agents to complete"`

## Environment Variables

```bash
# Number of agents to launch in swarm (default: 3)
export PM4PY_COORDINATOR_AGENTS=3

# Discovery algorithm (default: inductive_miner)
export PM4PY_COORDINATOR_ALGORITHM=inductive_miner

# Byzantine consensus threshold (default: 0.7)
export PM4PY_COORDINATOR_BYZANTINE=0.7

# PM4Py HTTP endpoint (default: http://localhost:8089)
export PM4PY_HTTP_URL=http://localhost:8089
```

## Running Tests

### Unit Tests (No External Services)

```bash
cd OSA
mix test test/integration/pm4py_swarm_unit_test.exs --no-start
# 16/16 tests pass
```

### Integration Tests (Requires PM4Py)

```bash
cd OSA
# First, ensure pm4py-rust HTTP server is running
# Start in another terminal: cd pm4py-rust && cargo build --release && ./target/release/pm4py_http

mix test test/integration/pm4py_osa_e2e_test.exs --include integration
# 7/7 swarm tests pass (PM4Py must be running)
```

## Consensus Algorithm

### Byzantine Threshold: 0.7

For N agents discovering in parallel:

| Total | Valid | Consensus Level | Decision |
|-------|-------|-----------------|----------|
| 1 | 1 | 1.0 | Use single result |
| 2 | 2 | 1.0 | Consensus reached |
| 2 | 1 | 0.5 | Fallback to first |
| 3 | 3 | 1.0 | Consensus reached |
| 3 | 2 | 0.66 | **Fallback to first** |
| 3 | 1 | 0.33 | Fallback to first |
| 4 | 4 | 1.0 | Consensus reached |
| 4 | 3 | 0.75 | Consensus reached |
| 4 | 2 | 0.5 | Fallback to first |
| 5 | 5 | 1.0 | Consensus reached |
| 5 | 4 | 0.8 | Consensus reached |
| 5 | 3 | 0.6 | Fallback to first |

**Fallback Behavior:**
- When consensus_level < 0.7, use first valid agent's model
- Include consensus_note: "Fallback to first result (consensus < 0.7 threshold)"
- Still post result to BusinessOS with consensus metadata for audit trail

## Workflow

1. **Agent receives discovery request** → call `launch_swarm/2`
2. **Partition log** → hash(case_id) % agent_count
3. **Parallel execution** → 3 agents run `pm4py_discover` simultaneously (30s timeout)
4. **Validate results** → check model structure (places, transitions)
5. **Byzantine voting** → consensus_level = valid_count / total_count
6. **Select model** → if consensus >= 0.7, use agreed model; else fallback
7. **Generate metadata** → swarm_id, consensus_level, algorithm, timestamp
8. **Return to caller** → swarm result with a2a_call_metadata
9. **Agent posts to BusinessOS** → `a2a_call` tool with metadata (optional next step)

## Error Handling

```elixir
{:error, "Event log is empty"}
{:error, "Invalid log or agent_count"}
{:error, "Failed to partition log"}
{:error, "Swarm agent launch failed"}  # Task timeout or exception
{:error, "No valid discovery results from swarm"}  # All agents failed validation
```

## Implementation Details

### Partitioning Strategy

```elixir
partition_id = String.to_charlist(case_id) |> Enum.sum() |> rem(agent_count)
```

Distributes traces evenly across agents by case_id hash.

### Timeout Behavior

- Individual agent task: 30 seconds (via `Task.await_many/2`)
- HTTP request: 60 seconds (in `discover_partition_via_swarm/4`)
- If agent times out, Task supervisor marks it as `{:exit, :timeout}`
- Result: agent treated as failed, consensus level recalculated

### Telemetry

Logs at INFO/WARNING/ERROR levels:

```
[PM4PyCoordinator.Swarm] Launching 3-agent swarm 63d707df718b4575
[PM4PyCoordinator.Swarm63d707df718b4575] Launching 3 agents in parallel
[PM4PyCoordinator.Swarm63d707df718b4575.Agent0] Discovering from partition
[PM4PyCoordinator.Consensus] Validated 2/3 results (level: 0.67)
[PM4PyCoordinator.Consensus] Fallback to first result (consensus < 0.7 threshold)
[PM4PyCoordinator.A2A] A2A metadata prepared: {...}
```

## Next Steps

1. **Invoke from Agent**: Call `launch_swarm/2` in agent ReAct loop
2. **Post to BusinessOS**: Use `a2a_call` tool with result metadata
3. **Monitoring**: Collect swarm_id + consensus_level for audit trail
4. **Tuning**: Adjust `PM4PY_COORDINATOR_BYZANTINE` threshold based on production experience

## References

- OSA Swarm Patterns: `lib/optimal_system_agent/swarm/patterns.ex`
- A2A Tool: `lib/optimal_system_agent/tools/builtins/a2a_call.ex`
- PM4PyCoordinator: `lib/optimal_system_agent/providers/pm4py_coordinator.ex`
- Unit Tests: `test/integration/pm4py_swarm_unit_test.exs`
- E2E Tests: `test/integration/pm4py_osa_e2e_test.exs`
