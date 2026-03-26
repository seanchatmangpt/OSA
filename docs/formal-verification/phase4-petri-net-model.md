# Phase 4: Petri Net Model Scaffold

**Formal Verification via Petri Nets** — This document defines a Petri net model of the OSA agent loop and ProcessMining.Client interaction. The model captures process states, transitions, and guards to verify **WvdA soundness** (deadlock-freedom, liveness, boundedness) before implementation.

---

## Purpose

Petri nets provide a mathematical foundation for verifying system properties:

- **Deadlock Freedom** — Can the system reach a deadlock state? (unreachable)
- **Liveness** — Can every action eventually complete? (non-dead transitions)
- **Boundedness** — Is the state space finite? (bounded token count)

This scaffold defines the net structure. **Verification via UPPAAL or TLA+ is future work.**

---

## System Overview

The OSA ProcessMining integration involves:

1. **Agent Loop** (in `OSA/lib/optimal_system_agent/agent/loop.ex`)
   - Calls LLM → processes response → executes tools → updates state

2. **Tool Executor** (in `OSA/lib/optimal_system_agent/tools/executor.ex`)
   - Validates tool args → calls ProcessMining.Client → returns result

3. **ProcessMining.Client** (in `OSA/lib/optimal_system_agent/process/client.ex`)
   - GenServer that makes HTTP calls to pm4py-rust
   - All calls have 10-second timeout
   - Returns `{:ok, result}` or `{:error, reason}`

4. **Circuit Breaker** (future: `OSA/lib/optimal_system_agent/process/circuit_breaker.ex`)
   - Prevents cascading timeouts when pm4py-rust is unavailable
   - States: CLOSED (healthy) → OPEN (failed) → HALF_OPEN (recovery)

---

## Petri Net: Agent Loop + Tool Executor + ProcessMining.Client

### Places (P_i)

Places represent states where tokens can reside:

#### Agent Loop States

- **P_agent_idle** — Agent waiting for next tool call or LLM response
- **P_tool_call_pending** — Agent has called a tool, awaiting response
- **P_tool_response_received** — Tool returned result, agent processing

#### Tool Executor States

- **P_tool_executor_idle** — Tool executor ready for next call
- **P_tool_validating_args** — Tool executor validating JSON schema
- **P_tool_executing** — Tool executor calling ProcessMining.Client
- **P_tool_done** — Tool executor returning result to agent

#### ProcessMining.Client States

- **P_client_idle** — Client GenServer ready for call
- **P_client_http_in_flight** — HTTP request to pm4py-rust in flight
- **P_client_timeout_waiting** — Client waiting for timeout (10s)
- **P_client_result_ready** — Result returned from pm4py-rust, ready to return
- **P_client_error_timeout** — Timeout occurred, error being returned

#### Circuit Breaker States

- **P_circuit_closed** — Circuit healthy, calls proceed
- **P_circuit_open** — Circuit broken, calls fail fast
- **P_circuit_half_open** — Circuit probing for recovery

#### Resource States

- **P_http_connection_available** — HTTP connection pool has slots
- **P_timeout_timer_running** — Timeout timer ticking
- **P_pm4py_responding** — pm4py-rust service is responsive

---

### Transitions (T_i)

Transitions represent state changes and actions:

#### Agent → Tool Flow

- **T_agent_request_tool** — Agent calls discover_process_models/1
  - Consumes: P_agent_idle
  - Produces: P_tool_call_pending, P_tool_executor_idle
  - Guard: `agent_ready == true`

- **T_tool_return_success** — Tool returns {:ok, result}
  - Consumes: P_tool_done, P_tool_call_pending
  - Produces: P_agent_idle, P_tool_executor_idle
  - Guard: `result != nil`

- **T_tool_return_error** — Tool returns {:error, reason}
  - Consumes: P_tool_done, P_tool_call_pending
  - Produces: P_agent_idle, P_tool_executor_idle
  - Guard: `reason in [:timeout, :error, :noproc]`

#### Tool Executor → Client Flow

- **T_executor_validate_args** — Tool executor validates arguments
  - Consumes: P_tool_executor_idle, P_tool_call_pending
  - Produces: P_tool_validating_args
  - Guard: `json_schema_valid(args)`
  - Time: <10ms

- **T_executor_call_client** — Tool executor calls ProcessMining.Client
  - Consumes: P_tool_validating_args
  - Produces: P_tool_executing, P_client_http_in_flight, P_timeout_timer_running
  - Guard: `client_pid exists`
  - Time: <1ms

#### ProcessMining.Client HTTP Flow

- **T_http_request_sent** — HTTP request sent to pm4py-rust
  - Consumes: P_client_idle
  - Produces: P_client_http_in_flight, P_http_connection_available
  - Guard: `pm4py_url != nil`
  - Time: <10ms

- **T_http_response_received** — HTTP response received from pm4py-rust
  - Consumes: P_client_http_in_flight, P_http_connection_available
  - Produces: P_client_result_ready, P_timeout_timer_running (cancel)
  - Guard: `http_status in [200, 400, 500]`
  - Time: <100ms (bounded by pm4py-rust response)

- **T_http_timeout** — 10-second timeout elapsed with no response
  - Consumes: P_client_http_in_flight, P_timeout_timer_running
  - Produces: P_client_error_timeout
  - Guard: `elapsed_time >= 10000ms`
  - Time: exactly 10s

#### Client Result Handling

- **T_client_return_ok** — Client returning success to caller
  - Consumes: P_client_result_ready, P_tool_executing
  - Produces: P_client_idle, P_tool_done
  - Guard: `status == 200`

- **T_client_return_error** — Client returning error to caller
  - Consumes: P_client_error_timeout, P_tool_executing
  - Produces: P_client_idle, P_tool_done
  - Guard: `true` (error type doesn't matter for net structure)

#### Circuit Breaker Transitions

- **T_circuit_detect_fault** — Detect timeout, increment failure count
  - Consumes: P_circuit_closed, P_client_error_timeout
  - Produces: P_circuit_closed (if failures < 3), P_circuit_open (if failures >= 3)
  - Guard: `timeout_count >= 3`

- **T_circuit_enter_recovery** — After 30s, allow probe attempt
  - Consumes: P_circuit_open
  - Produces: P_circuit_half_open
  - Guard: `time_since_open >= 30000ms`
  - Time: exactly 30s

- **T_circuit_probe_success** — Probe call succeeds during half-open
  - Consumes: P_circuit_half_open
  - Produces: P_circuit_closed (if 3 probes succeed)
  - Guard: `probes_succeeded >= 3`

- **T_circuit_probe_fail** — Probe call fails, re-open circuit
  - Consumes: P_circuit_half_open
  - Produces: P_circuit_open
  - Guard: `probe_failed == true`

---

### Marking (Initial State)

Initial marking represents the system at rest:

```
M0 = {
  P_agent_idle: 1              # 1 agent token
  P_tool_executor_idle: 1      # 1 executor token
  P_client_idle: 1             # 1 client token
  P_circuit_closed: 1          # 1 circuit token (healthy)
  P_http_connection_available: 1  # 1 connection slot
  P_pm4py_responding: 1        # 1 service availability token

  all other places: 0          # no tokens elsewhere
}
```

Total tokens in initial marking: **6**

---

## Reachability Analysis

### Deadlock State (Unreachable)

A deadlock state would have:
```
M_deadlock = {
  P_tool_call_pending: 1           # Agent waiting for tool response
  P_client_http_in_flight: 1       # Client waiting for HTTP response
  P_timeout_timer_running: 1       # Timeout still running
  P_pm4py_responding: 0            # pm4py-rust not responding

  # All other places: 0
  # No enabled transitions!
}
```

**Is M_deadlock reachable?** **NO** ✅

**Why?** Because:
1. Even if pm4py-rust is unresponsive (P_pm4py_responding = 0), T_http_timeout will eventually fire
2. T_http_timeout (10-second absolute timeout) will transition P_client_http_in_flight → P_client_error_timeout
3. P_client_error_timeout enables T_client_return_error
4. T_client_return_error transitions to P_tool_done, enabling T_tool_return_error
5. T_tool_return_error transitions to P_agent_idle, unblocking the agent

**Proof:** The timeout transition is **time-enabled** (always fires after 10 seconds), so no state with P_client_http_in_flight and no other enabled transitions can persist.

---

### Liveness: All Actions Complete

**Claim:** Every action eventually completes (no infinite loops in reachability graph).

**Proof:**
1. Agent calls tool (T_agent_request_tool) → blocked in P_tool_call_pending
2. Tool executor validates and calls client (T_executor_validate_args, T_executor_call_client)
3. Client either:
   - Gets response within 10s (T_http_response_received) → T_client_return_ok → done
   - Times out after 10s (T_http_timeout) → T_client_return_error → done
4. Tool executor returns (T_tool_return_success or T_tool_return_error)
5. Agent unblocked (T_tool_return_success or T_tool_return_error)
6. Agent can now proceed to next action

**Worst-case latency:** 10 seconds (if pm4py-rust always times out)

**No infinite loops:** Each transition consumes tokens and enables other transitions in sequence. No cycle exists in the transition graph that produces the same marking.

---

### Boundedness: Finite State Space

**Claim:** The system can only reach a finite number of states (bounded tokens).

**Proof:**

Token count per place:

| Place | Min | Max | Bounded? |
|-------|-----|-----|----------|
| P_agent_idle | 0 | 1 | Yes (1 agent) |
| P_tool_call_pending | 0 | 1 | Yes (1 tool call per agent) |
| P_tool_executor_idle | 0 | 1 | Yes (1 executor) |
| P_client_idle | 0 | 1 | Yes (1 client) |
| P_client_http_in_flight | 0 | 1 | Yes (1 HTTP request per client) |
| P_circuit_closed | 0 | 1 | Yes (1 circuit state) |
| P_circuit_open | 0 | 1 | Yes (1 circuit state) |
| P_circuit_half_open | 0 | 1 | Yes (1 circuit state) |
| P_http_connection_available | 0 | 1 | Yes (1 connection slot) |
| P_pm4py_responding | 0 | 1 | Yes (1 service health token) |

**Total states:** At most 2^10 = 1024 distinct markings

**Important constraint:** Transitions enforce mutual exclusion (e.g., circuit cannot be CLOSED and OPEN simultaneously).

**Bounded:** ✅ Yes, finite state space

---

## Guards & Timing Constraints

### Timeout Guard (WvdA Safety)

Every blocking operation has an explicit timeout:

```
T_executor_call_client:
  Guard: `client_pid != nil`
  Produces: P_timeout_timer_running (starts 10s timer)

T_http_timeout:
  Guard: `elapsed_time >= 10000ms` (exactly 10 seconds)
  Enables: Unblocking any transition waiting for HTTP response
```

**Guarantee:** No operation can wait indefinitely. After 10 seconds, T_http_timeout **must** fire.

### Circuit Breaker Guard (Failure Handling)

```
T_circuit_detect_fault:
  Guard: `(failures == 3) AND (P_circuit_closed == 1)`
  Effect: Move circuit token from P_circuit_closed to P_circuit_open

T_circuit_enter_recovery:
  Guard: `(time_since_open >= 30000ms) AND (P_circuit_open == 1)`
  Effect: Move circuit token to P_circuit_half_open
```

**Guarantee:** Circuit remains open for at least 30 seconds before retry, preventing immediate retry storms.

### Resource Availability Guard

```
T_http_request_sent:
  Guard: `P_http_connection_available == 1`
  Consumes: P_http_connection_available (connection acquired)
  Produces: P_client_http_in_flight

T_http_response_received:
  Produces: P_http_connection_available (connection released)
```

**Guarantee:** Connections are properly acquired and released, preventing connection pool exhaustion.

---

## State Space Visualization (Simplified)

```
M0 (Initial)
├─ Agent idle, Client idle, Circuit closed
│
├─ T_agent_request_tool
│  └─ Agent tool_call_pending, Tool executing
│     ├─ T_executor_call_client
│     │  └─ Client http_in_flight, Timeout timer running
│     │     ├─ T_http_response_received (pm4py-rust responds)
│     │     │  └─ Client result_ready
│     │     │     └─ T_client_return_ok
│     │     │        └─ Agent idle, Tool done
│     │     │           └─ T_tool_return_success
│     │     │              └─ M0 (cycle complete, back to idle)
│     │     │
│     │     └─ T_http_timeout (10s elapsed, no response)
│     │        └─ Client error_timeout
│     │           └─ T_client_return_error
│     │              └─ Agent idle, Tool done
│     │                 └─ T_tool_return_error
│     │                    ├─ M0 (success, circuit_closed)
│     │                    │
│     │                    └─ [If 3+ timeouts]
│     │                       ├─ T_circuit_detect_fault
│     │                       │  └─ Circuit open
│     │                       │     ├─ [Wait 30s]
│     │                       │     └─ T_circuit_enter_recovery
│     │                       │        └─ Circuit half_open
│     │                       │           ├─ [Probe succeeds 3x]
│     │                       │           └─ T_circuit_probe_success
│     │                       │              └─ Circuit closed
│     │                       │                 └─ M0
```

---

## Guards Preventing Deadlock

**Scenario:** Could Agent be blocked forever?

```
M = {P_tool_call_pending: 1, P_client_http_in_flight: 1, ...}

Can this transition to safe state?
```

**Answer:** YES, via T_http_timeout:

1. T_http_timeout **does not require** pm4py-rust to respond
2. T_http_timeout **only requires** 10 seconds to elapse
3. Time always elapses (monotonic), so T_http_timeout will eventually fire
4. After T_http_timeout fires → P_client_error_timeout is produced
5. T_client_return_error becomes enabled
6. Eventually returns to safe state (P_agent_idle)

**No deadlock possible.** ✅

---

## Key Invariants

Invariants that must hold in every reachable state:

### Inv_1: Single Agent Token
```
In every reachable marking M:
  sum(P_agent_idle + P_tool_call_pending + P_tool_response_received) == 1

Proof: Transitions preserve this (consume exactly 1 agent token, produce exactly 1)
```

### Inv_2: Single Client Token
```
In every reachable marking M:
  sum(P_client_idle + P_client_http_in_flight + P_client_result_ready + P_client_error_timeout) <= 1

Proof: Client GenServer is a single process; at most 1 state at a time
```

### Inv_3: Single Circuit Token
```
In every reachable marking M:
  sum(P_circuit_closed + P_circuit_open + P_circuit_half_open) == 1

Proof: Circuit breaker has exactly 1 state at any time
```

### Inv_4: No Deadlock (Safety)
```
In every reachable marking M:
  if (P_tool_call_pending > 0) then (T_http_timeout enabled after 10s)

Proof: Timeout is time-enabled, not dependent on other transitions
```

### Inv_5: Bounded Tokens (Resource)
```
In every reachable marking M:
  sum(all places) <= 6

Proof: No transition produces more tokens than it consumes
(This is a semi-live Petri net where source places never exceed initial tokens)
```

---

## Integration with Formal Tools

### UPPAAL Verification

This model can be translated to UPPAAL (real-time model checker):

```uppaal
system Agent, Executor, Client, CircuitBreaker;

process Agent {
  state idle, tool_call_pending, tool_response_received;
  init idle;
  // transitions...
}

process Client {
  state idle, http_in_flight, result_ready, error_timeout;
  clock timer;
  init idle;
  // transitions with timing constraints...
}

// Verify:
// deadlock => false (no deadlock reachable)
// A[] (timer <= 10000 && http_in_flight => eventually result_ready || error_timeout)
```

### TLA+ Specification

Alternatively, describe in TLA+ (temporal logic):

```tla+
CONSTANT AGENTS, CLIENTS, TIMEOUT_MS

vars == <<agent_state, client_state, circuit_state, timer>>

Init ==
  /\ agent_state = "idle"
  /\ client_state = "idle"
  /\ circuit_state = "closed"
  /\ timer = 0

Next ==
  \/ AgentRequestTool
  \/ ClientHttpRequest
  \/ HttpTimeoutFire     (* Always enabled after 10s *)
  \/ CircuitDetectFault
  \/ ...

(* Safety: No deadlock *)
Deadlock_Free == <>[](agent_state /= "blocked")

(* Liveness: All actions complete *)
Liveness == A[] (tool_call_pending => <> agent_idle)

(* Bounded: Finite state space *)
Bounded == FINITE CardinallValue(agent_state ∪ client_state ∪ circuit_state)
```

### Petri Net Tool (ePNK, CPN Tools)

Export to Petri net XML format for analysis:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<pnml xmlns="http://www.pnml.org/version-2009/grammar/pnml">
  <net id="OSA-ProcessMining">
    <name>OSA Agent Loop + ProcessMining.Client</name>

    <place id="P_agent_idle">
      <name>Agent Idle</name>
      <initialMarking><text>1</text></initialMarking>
    </place>

    <transition id="T_agent_request_tool">
      <name>Agent Request Tool</name>
      <guard><text>agent_ready == true</text></guard>
    </transition>

    <!-- ... more places/transitions ... -->

  </net>
</pnml>
```

---

## Testing Against Model

### Unit Test: Verify Timeout Always Fires

```elixir
# test/formal_verification/timeout_always_fires_test.exs
test "timeout fires within 11 seconds even if pm4py never responds" do
  start_test_pm4py_server(delay: 30_000)  # 30s response time

  start_time = System.monotonic_time(:millisecond)
  result = ProcessMining.Client.discover_process_models("order")
  end_time = System.monotonic_time(:millisecond)
  elapsed = end_time - start_time

  assert {:error, :timeout} = result
  assert elapsed >= 10_000   # At least 10s (timeout)
  assert elapsed <= 11_000   # But not more than 11s
end
```

### Chaos Test: Verify Deadlock Never Occurs

```elixir
# test/formal_verification/chaos_deadlock_test.exs
test "100 concurrent agents never deadlock even with all pm4py calls timing out" do
  Task.Supervisor.start_link(name: TestTaskSupervisor, max_children: 200)

  tasks = 1..100 |> Enum.map(fn agent_id ->
    Task.Supervisor.async(TestTaskSupervisor, fn ->
      run_agent_loop(agent_id, iterations: 10)
    end)
  end)

  results = Task.await_many(tasks, 180_000)  # 3 minute timeout

  # If we get here without hanging, no deadlock occurred
  assert Enum.all?(results, &(&1 == :ok))
end
```

---

## WvdA Soundness Claims

Based on the Petri net model:

| Property | Claim | Evidence |
|----------|-------|----------|
| **Deadlock-Free** | No reachable marking enables no transitions | T_http_timeout always fires after 10s |
| **Liveness** | Every action eventually completes | Timeout transition guarantees unblock |
| **Boundedness** | State space is finite | Max 6 tokens per state, ≤1024 total states |

---

## Future Enhancements

1. **Multi-Agent Model** — Extend to N concurrent agents competing for HTTP connections
2. **Cascading Failure** — Model supervisor restart chain (ProcessMining crash → dependent crashes)
3. **Backpressure** — Add queue length limits to prevent unbounded agent spawn
4. **Consensus** — Model HotStuff BFT consensus for distributed decisions

---

## References

- **Wil van der Aalst, "Process Mining: Data Science in Action"** (2016), Chapter 2: Soundness
- **Kurt Jensen, "Coloured Petri Nets"** (2nd Edition, 2009)
- **UPPAAL Model Checker**: http://www.uppaal.org/
- **TLA+**: https://lamport.azurewebsites.net/tla/tla.html
- **ePNK (Eclipse Petri Net Kernel)**: https://www.pnk.pn/

---

## Version History

| Date | Version | Change |
|------|---------|--------|
| 2026-03-26 | 1.0 | Initial Petri net model scaffold for Phase 4 |

---

**Next Steps:**
1. Implement circuit breaker in ProcessMining.Client based on this model
2. Translate model to UPPAAL and run deadlock-freedom verification
3. Run chaos tests to validate model assumptions
4. Document any deviations between Petri net and actual implementation
