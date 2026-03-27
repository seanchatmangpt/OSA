---
title: "ProcessMining.Client API Reference"
type: reference
tags: [osa, process-mining, pm4py, genserver, wvda, soundness]
---

# ProcessMining.Client API Reference

Module: `OptimalSystemAgent.ProcessMining.Client`
Source: `OSA/lib/optimal_system_agent/process_mining/client.ex`

GenServer HTTP client for the pm4py-rust process mining API. Provides process discovery, WvdA soundness verification, and reachability analysis.

---

## Supervision

The client is started in `OptimalSystemAgent.Supervisors.AgentServices` under the `:one_for_one` strategy:

```elixir
# OSA/lib/optimal_system_agent/supervisors/agent_services.ex
OptimalSystemAgent.Process.Mining.Client,
```

The restart strategy defaults to `:permanent` (always restarted on crash).

The process registers under the atom name `:process_mining_client`:

```elixir
GenServer.start_link(__MODULE__, opts, name: :process_mining_client)
```

A companion `OptimalSystemAgent.Resilience.CircuitBreaker` is started in the `Infrastructure` supervisor. It wraps calls to `ProcessMining.Client` and trips to OPEN after 5 failures in a 60-second window, waiting 30 seconds before testing recovery (HALF_OPEN state). Use `CircuitBreaker.call/1` in production code to prevent cascading failures.

---

## Configuration

```elixir
# config/config.exs (or runtime.exs)
config :optimal_system_agent, pm4py_url: "http://localhost:8090"
```

| Key | Default | Description |
|-----|---------|-------------|
| `:pm4py_url` | `"http://localhost:8090"` | Base URL of the pm4py-rust HTTP API |

The URL is resolved at compile time via `Application.compile_env/3`. Override for staging or production via `config/runtime.exs`.

---

## Function Reference

All functions are synchronous `GenServer.call/3` wrappers with an explicit 10-second timeout. None raise exceptions; all errors are returned as `{:error, reason}` tuples.

| Function | Args | Returns | Timeout | HTTP Method | Endpoint |
|----------|------|---------|---------|-------------|----------|
| `discover_process_models/1` | `resource_type :: String.t()` | `{:ok, map} \| {:error, reason}` | 10 s | `GET` | `/process/discover/:resource_type` |
| `check_deadlock_free/1` | `process_id :: String.t()` | `{:ok, map} \| {:error, reason}` | 10 s | `POST` | `/process/soundness/:process_id` |
| `get_reachability_graph/1` | `process_id :: String.t()` | `{:ok, map} \| {:error, reason}` | 10 s | `GET` | `/process/reachability/:process_id` |
| `analyze_boundedness/1` | `process_id :: String.t()` | `{:ok, map} \| {:error, reason}` | 10 s | `POST` | `/process/soundness/:process_id` |

---

## Function Details

### discover_process_models/1

```elixir
@spec discover_process_models(resource_type :: String.t()) :: {:ok, map()} | {:error, reason}
```

Discovers process models for the given resource type by querying pm4py-rust. Returns all process models associated with that resource class.

**Internal dispatch:** `GET /process/discover/:resource_type` (`resource_type` is URI-encoded).

```elixir
# Example
{:ok, models} = OptimalSystemAgent.ProcessMining.Client.discover_process_models("order")
# models is the decoded JSON body from pm4py-rust
```

---

### check_deadlock_free/1

```elixir
@spec check_deadlock_free(process_id :: String.t()) :: {:ok, map()} | {:error, reason}
```

Performs a WvdA deadlock-freedom check on the identified process. The response body contains a boolean `deadlock_free` field and confidence metrics from pm4py-rust.

**Internal dispatch:** `POST /process/soundness/:process_id` with body `%{check: "deadlock_free"}`.

```elixir
{:ok, result} = OptimalSystemAgent.ProcessMining.Client.check_deadlock_free("order-fulfillment-v2")
# result["deadlock_free"] => true | false
# result["confidence"] => float
```

With circuit breaker (recommended in production):

```elixir
alias OptimalSystemAgent.Resilience.CircuitBreaker

{:ok, result} = CircuitBreaker.call(fn ->
  OptimalSystemAgent.ProcessMining.Client.check_deadlock_free(process_id)
end)
```

---

### get_reachability_graph/1

```elixir
@spec get_reachability_graph(process_id :: String.t()) :: {:ok, map()} | {:error, reason}
```

Returns the reachability graph for the identified process. The graph contains nodes (states) and edges (transitions) showing all states reachable from the initial marking. Used by WvdA Phase 4 agents to verify soundness properties statically.

**Internal dispatch:** `GET /process/reachability/:process_id` (`process_id` is URI-encoded).

```elixir
{:ok, graph} = OptimalSystemAgent.ProcessMining.Client.get_reachability_graph("invoice-process-v1")
# graph["nodes"] => [%{"id" => ..., "marking" => ...}, ...]
# graph["edges"] => [%{"from" => ..., "to" => ..., "label" => ...}, ...]
```

---

### analyze_boundedness/1

```elixir
@spec analyze_boundedness(process_id :: String.t()) :: {:ok, map()} | {:error, reason}
```

Analyzes the boundedness properties of the identified process. The response contains a boolean `bounded` field and the discovered resource limits (maximum token counts per place in the Petri net model).

**Internal dispatch:** `POST /process/soundness/:process_id` with body `%{check: "bounded"}`.

```elixir
{:ok, result} = OptimalSystemAgent.ProcessMining.Client.analyze_boundedness("payment-process-v3")
# result["bounded"] => true | false
# result["max_tokens_per_place"] => %{"place_id" => integer, ...}
```

---

## Error Handling

All errors are returned as `{:error, reason}` — the client never raises.

| Error | Cause |
|-------|-------|
| `{:error, :timeout}` | GenServer call exceeded 10-second timeout; caught via `catch :exit, {:timeout, _}` |
| `{:error, {:http, status, body}}` | pm4py-rust returned a non-200 HTTP status; `status` is the integer code, `body` is the decoded response |
| `{:error, reason}` | `Req` HTTP client error (connection refused, network failure, etc.); `reason` is the underlying `Req` error term. Logged at `Logger.error/1` |

Timeout errors are caught at the public API layer:

```elixir
def discover_process_models(resource_type) do
  GenServer.call(:process_mining_client, {:discover, resource_type}, @timeout_ms)
catch
  :exit, {:timeout, _} -> {:error, :timeout}
end
```

---

## pm4py-rust API Endpoints

| Function | Method | Path | Request Body |
|----------|--------|------|--------------|
| `discover_process_models/1` | `GET` | `/process/discover/:resource_type` | none |
| `check_deadlock_free/1` | `POST` | `/process/soundness/:process_id` | `{"check": "deadlock_free"}` |
| `get_reachability_graph/1` | `GET` | `/process/reachability/:process_id` | none |
| `analyze_boundedness/1` | `POST` | `/process/soundness/:process_id` | `{"check": "bounded"}` |

All path parameters are URI-encoded via `URI.encode/1` before injection.

pm4py-rust default base URL: `http://localhost:8090`

---

## Downstream Consumers

`ProcessMining.Client` is the primary integration point between OSA and pm4py-rust. It is used by the WvdA Phase 4 verification agents:

| Consumer | Module | Function Called |
|----------|--------|----------------|
| Deadlock agent | `OptimalSystemAgent.Process.Client` (wrapper) | `check_deadlock_free/1` via `CircuitBreaker.call/1` |
| Liveness agent | WvdA Phase 4 | `get_reachability_graph/1` |
| Boundedness agent | WvdA Phase 4 | `analyze_boundedness/1` |
| Settlement agent | WvdA Phase 4 | `discover_process_models/1` |
| Optimizer agent | WvdA Phase 4 | `discover_process_models/1` + `check_deadlock_free/1` |
| Health monitor | `OptimalSystemAgent.Health.Pm4pyMonitor` | `discover_process_models/1` (ping) |

---

## WvdA Compliance Notes

This client was designed to satisfy van der Aalst soundness requirements:

- **Deadlock Freedom:** Every `GenServer.call/3` carries an explicit `@timeout_ms` (10 000 ms). Timeouts return `{:error, :timeout}` rather than blocking indefinitely.
- **Liveness:** No unbounded loops. The HTTP request either succeeds, returns an error, or times out. The GenServer is restarted by its supervisor after any crash.
- **Boundedness:** HTTP calls use `receive_timeout: @timeout_ms` on the `Req` client, bounding both connection and read time.

---

## Related Reference

- `OSA/docs/diataxis/reference/agent-api-reference.md` — OSA agent API overview
- `docs/diataxis/reference/port-map-service-locations.md` — Port 8090 (pm4py-rust)
- `docs/WAVE_8_GAP_ANALYSIS_MASTER_SUMMARY.md` — WvdA Phase 4 agent design
- `.claude/rules/wvda-soundness.md` — WvdA soundness standard applied throughout OSA
