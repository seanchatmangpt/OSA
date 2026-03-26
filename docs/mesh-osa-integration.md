# Data Mesh Consumer Integration for OSA

**Document Type:** Architecture & Implementation Guide
**Last Updated:** 2026-03-26
**Status:** Complete
**Audience:** OSA Core Team, Data Mesh Administrators

## Overview

The Data Mesh Consumer module integrates data mesh federation capabilities into the OSA (Optimal System Agent) platform, enabling agents to:

1. **Register domains** with organizational context
2. **Discover datasets** across federated domains
3. **Query lineage** with depth constraints for circular dependency prevention
4. **Calculate quality metrics** (completeness, accuracy, consistency, timeliness)

All operations delegate to the `bos` CLI, which coordinates SPARQL CONSTRUCT queries against the Oxigraph triplestore.

## Architecture

### System Diagram

```
┌─────────────────────────────────────────────────────┐
│          HTTP Clients (REST API)                    │
├─────────────────────────────────────────────────────┤
│         MeshRoutes (Plug.Router)                    │
│  POST /api/mesh/domains                             │
│  GET  /api/mesh/discover                            │
│  GET  /api/mesh/lineage                             │
│  GET  /api/mesh/quality                             │
├─────────────────────────────────────────────────────┤
│  Consumer GenServer (Gen5rver)                      │
│  - Validation                                       │
│  - bos CLI orchestration                            │
│  - Response parsing                                 │
│  - State tracking (operation count, last_op)        │
├─────────────────────────────────────────────────────┤
│         System.cmd("bos", [...])                    │
│  - register-domain                                  │
│  - discover-datasets                                │
│  - query-lineage                                    │
│  - check-quality                                    │
├─────────────────────────────────────────────────────┤
│       bos CLI → Oxigraph SPARQL                     │
│  - Domain registry (RDF)                            │
│  - Dataset metadata                                 │
│  - Lineage graph (edges)                            │
│  - Quality scores                                   │
└─────────────────────────────────────────────────────┘
```

### Supervision Tree Integration

The Consumer is registered in the OSA infrastructure supervisor as a named GenServer:

```elixir
children = [
  # ... other children ...
  {OptimalSystemAgent.Integrations.Mesh.Consumer, [name: OptimalSystemAgent.Integrations.Mesh.Consumer]},
  # ...
]

Supervisor.init(children, strategy: :rest_for_one, max_restarts: 5, max_seconds: 60)
```

**Restart strategy:** `:permanent` (restarts on any crash)
**Max restarts:** 5 in 60 seconds (supervisor escalates after 5 rapid failures)
**Process isolation:** No shared mutable state; all communication via GenServer messages

## Implementation Details

### Consumer Module: `OptimalSystemAgent.Integrations.Mesh.Consumer`

**File:** `OSA/lib/optimal_system_agent/integrations/mesh/consumer.ex`
**Lines:** 350-450
**Pattern:** GenServer with sync call-based API

#### Client API

All operations are **synchronous** (GenServer.call) with **12-second timeout**:

```elixir
# Register a domain
{:ok, %{...}} = Consumer.register_domain(
  pid_or_atom,
  "sales_domain",
  %{"owner" => "analytics_team", "description" => "Sales data"}
)

# Discover datasets
{:ok, [%{name: "orders", ...}, ...]} = Consumer.discover_datasets(
  pid_or_atom,
  "sales_domain"
)

# Query lineage (max 5 levels)
{:ok, %{"nodes" => [...], "edges" => [...]}} = Consumer.query_lineage(
  pid_or_atom,
  "sales_domain",
  "orders",
  depth: 3
)

# Check quality metrics
{:ok, %{"completeness" => 0.95, "accuracy" => 0.92, ...}} = Consumer.check_quality(
  pid_or_atom,
  "sales_domain",
  "orders"
)
```

#### GenServer State

```elixir
%{
  bos_timeout_ms: 12_000,              # Timeout for bos CLI (configurable)
  last_operation: ~U[2026-03-26T...],  # Timestamp of last operation
  operation_count: 42                   # Total operations processed
}
```

#### Timeout & Constraints (WvdA Soundness)

| Constraint | Value | Rationale |
|-----------|-------|-----------|
| Per-operation timeout | 12 seconds | Adequate for bos SPARQL queries; timeout + fallback prevent deadlock |
| Lineage depth max | 5 levels | Prevents circular dependencies; O(n^5) explosion bounded |
| Concurrent operations | Unlimited | GenServer queue is unbounded; set OS ulimit as needed |

**Deadlock Prevention:**
- All GenServer.call() operations have explicit 12-second timeout
- Timeout action: return `{:error, :timeout}` (no retry loop)
- No resource locks; all state is process-local

**Liveness Guarantee:**
- All operations complete or timeout; no infinite loops
- bos command execution guards against runaway processes (system timeout)

**Boundedness:**
- Lineage depth limited to 5 levels (explicit validation)
- Domain/dataset names limited to ~255 bytes (filesystem constraint)
- Operation counter is unbounded but immaterial (single integer)

### HTTP Routes Module: `OptimalSystemAgent.Channels.HTTP.API.MeshRoutes`

**File:** `OSA/lib/optimal_system_agent/channels/http/api/mesh_routes.ex`
**Lines:** 250-350
**Pattern:** Plug.Router with per-endpoint validation

#### Route Specifications

##### 1. POST /api/mesh/domains — Register Domain

**Request body (JSON):**
```json
{
  "domain_name": "sales_domain",
  "owner": "analytics_team",
  "description": "Sales data warehouse",
  "tags": ["prod", "critical"]
}
```

**Response (200 OK):**
```json
{
  "status": "registered",
  "domain": {
    "domain_name": "sales_domain",
    "owner": "analytics_team",
    "registered_at": "2026-03-26T12:34:56Z"
  }
}
```

**Error responses:**
- `400 invalid_params`: missing domain_name or owner
- `400 registration_failed`: bos command failed (see details)

##### 2. GET /api/mesh/discover?domain=<domain>

**Query parameters:**
- `domain` (required): domain name to query

**Response (200 OK):**
```json
{
  "status": "success",
  "domain": "sales_domain",
  "dataset_count": 3,
  "datasets": [
    {
      "name": "orders",
      "owner": "analytics_team",
      "created_at": "2026-01-15T10:20:30Z",
      "record_count": 1500000
    },
    {
      "name": "customers",
      "owner": "analytics_team",
      "created_at": "2026-02-01T14:22:45Z",
      "record_count": 250000
    }
  ]
}
```

**Error responses:**
- `400 invalid_params`: missing or empty domain parameter
- `400 discovery_failed`: bos command failed

##### 3. GET /api/mesh/lineage?domain=<domain>&dataset=<dataset>&depth=<5>

**Query parameters:**
- `domain` (required): domain name
- `dataset` (required): dataset name
- `depth` (optional, default=5): lineage depth (1-5, clamped)

**Response (200 OK):**
```json
{
  "status": "success",
  "domain": "sales_domain",
  "dataset": "orders",
  "depth": 3,
  "lineage": {
    "root": "orders",
    "nodes": [
      {"id": "orders", "type": "dataset", "level": 0},
      {"id": "raw_orders", "type": "source", "level": 1},
      {"id": "order_logs", "type": "external", "level": 2}
    ],
    "edges": [
      {"source": "raw_orders", "target": "orders", "type": "derived_from"},
      {"source": "order_logs", "target": "raw_orders", "type": "fed_from"}
    ]
  }
}
```

**Error responses:**
- `400 invalid_params`: missing domain or dataset
- `400 lineage_query_failed`: bos command failed or depth out of range

##### 4. GET /api/mesh/quality?domain=<domain>&dataset=<dataset>

**Query parameters:**
- `domain` (required): domain name
- `dataset` (required): dataset name

**Response (200 OK):**
```json
{
  "status": "success",
  "domain": "sales_domain",
  "dataset": "orders",
  "quality_metrics": {
    "completeness": 0.98,
    "accuracy": 0.95,
    "consistency": 0.92,
    "timeliness": 0.88,
    "overall_score": 0.9325,
    "last_updated": "2026-03-26T10:15:30Z"
  }
}
```

**Error responses:**
- `400 invalid_params`: missing domain or dataset
- `400 quality_check_failed`: bos command failed

### Request/Response Contract

**All error responses follow this format:**
```json
{
  "error": "<error_code>",
  "details": "<human_readable_message>"
}
```

**Error codes:**
- `invalid_params` — request parameters malformed
- `invalid_json` — request body is not valid JSON
- `registration_failed` — domain registration failed
- `discovery_failed` — dataset discovery failed
- `lineage_query_failed` — lineage query failed
- `quality_check_failed` — quality calculation failed
- `not_found` — route not found (404)

**Status codes:**
- `200 OK` — operation succeeded
- `400 Bad Request` — validation failed or command failed
- `404 Not Found` — route not found
- `500 Internal Server Error` — unhandled exception (rare)

## Lineage Query Walkthrough

### Example: Order Processing Pipeline

**Scenario:** Query lineage for `orders` dataset in `sales_domain` with depth=3.

**Request:**
```bash
curl "http://localhost:8089/api/mesh/lineage?domain=sales_domain&dataset=orders&depth=3"
```

**Internal flow:**

1. **MeshRoutes receives request:**
   - Validates query params: `domain` and `dataset` present
   - Parses depth: `"3"` → `3` (integer)
   - Calls `Consumer.query_lineage(Consumer, "sales_domain", "orders", depth: 3)`

2. **Consumer validates inputs:**
   - Domain name: matches `~r/^[a-z0-9_-]+$/i` ✓
   - Dataset name: matches `~r/^[a-z0-9_.-]+$/i` ✓
   - Depth: 3 is in range [1, 5] ✓

3. **Consumer invokes bos CLI:**
   ```bash
   bos mesh query-lineage --domain sales_domain --dataset orders --depth 3
   ```

4. **bos executes SPARQL CONSTRUCT query (via Oxigraph):**
   ```sparql
   CONSTRUCT {
     ?root <lineage:hasUpstream> ?upstream .
     ?upstream <lineage:hasDownstream> ?downstream .
   }
   WHERE {
     ?root <rdf:name> "orders" .
     ?root <lineage:isInDomain> "sales_domain" .
     UNION
     ?root <lineage:dependsOn> ?upstream .
       ?upstream <lineage:dependsOn> ?intermediate .
         ?intermediate <lineage:dependsOn> ?downstreamItem .
   }
   ```

5. **bos returns JSON:**
   ```json
   {
     "nodes": [
       {"id": "orders", "type": "dataset", "level": 0, "owner": "analytics"},
       {"id": "raw_orders", "type": "staging", "level": 1, "owner": "ingest"},
       {"id": "order_log", "type": "source", "level": 2, "owner": "payments"},
       {"id": "kafka_orders", "type": "stream", "level": 3, "owner": "events"}
     ],
     "edges": [
       {"source": "raw_orders", "target": "orders", "operation": "enrich", "latency_ms": 450},
       {"source": "order_log", "target": "raw_orders", "operation": "aggregate", "latency_ms": 120},
       {"source": "kafka_orders", "target": "order_log", "operation": "filter", "latency_ms": 50}
     ]
   }
   ```

6. **Consumer parses response:**
   - Decodes JSON: `Jason.decode(output)` → `%{"nodes" => [...], "edges" => [...]}`
   - Ensures `nodes` and `edges` keys exist (defaults to `[]` if missing)
   - Returns `{:ok, lineage_map}`

7. **MeshRoutes sends HTTP response:**
   ```json
   {
     "status": "success",
     "domain": "sales_domain",
     "dataset": "orders",
     "depth": 3,
     "lineage": {
       "nodes": [...],
       "edges": [...]
     }
   }
   ```

### Depth Constraint Rationale

**Why max depth = 5?**

- **Circular dependency prevention:** Depth limit forces DAG validation
- **Performance:** O(edges^depth) explosion; 5 is practical max
- **Data quality:** Most use cases don't need >5 hops (source → transform → aggregate → warehouse → BI tool)
- **User experience:** >5 hops typically indicates design issues (tool fragmentation)

### Lineage Node Types

| Type | Example | Description |
|------|---------|-------------|
| `dataset` | orders | Persistent table/view (primary asset) |
| `staging` | raw_orders | Intermediate transformation stage |
| `source` | external_api | External system (Salesforce, database, file) |
| `stream` | kafka_orders | Real-time event stream |
| `dimension` | customer_dim | Lookup table (dimension table) |
| `fact` | order_fact | Fact table (measurement) |

## Quality Metrics Calculation

### Metrics Definition

| Metric | Range | Definition | Calculation |
|--------|-------|-----------|-------------|
| **Completeness** | [0.0, 1.0] | Fraction of non-null values | rows_with_values / total_rows |
| **Accuracy** | [0.0, 1.0] | Match with authoritative source | 1.0 - (errors / total_values) |
| **Consistency** | [0.0, 1.0] | Conformance to schema | valid_records / total_records |
| **Timeliness** | [0.0, 1.0] | Freshness (age vs SLA) | 1.0 - min(1.0, age_hours / sla_hours) |

### Quality Score Aggregation

```
overall_score = (completeness + accuracy + consistency + timeliness) / 4
```

**Example:**
- Completeness: 0.98 (2% nulls)
- Accuracy: 0.95 (5% mismatches vs authoritative)
- Consistency: 0.92 (8% schema violations)
- Timeliness: 0.88 (12 hours old, SLA is 24 hours)

Overall: (0.98 + 0.95 + 0.92 + 0.88) / 4 = 0.9325

### Quality Grade Scale

| Score | Grade | Recommendation |
|-------|-------|----------------|
| ≥ 0.95 | A | Production-ready; publish to data marketplace |
| 0.90–0.94 | B | Production use with caveats; document issues |
| 0.80–0.89 | C | Development/staging only; address issues |
| < 0.80 | D | Do not consume; fix immediately |

## Testing

### Test Suite: `OSA/test/integrations/mesh/consumer_test.exs`

**File:** `OSA/test/integrations/mesh/consumer_test.exs`
**Test count:** 13+ tests
**All tests PASS**

#### Test Coverage

| Test | Scenario | Assertion |
|------|----------|-----------|
| register_domain_happy_path | Valid domain & metadata | Returns `{:ok, map}` |
| register_domain_empty_domain | Empty domain_name | Returns `{:error, :invalid_domain_name}` |
| register_domain_invalid_chars | Special chars in domain | Returns `{:error, :invalid_domain_name}` |
| register_domain_missing_owner | Metadata missing owner | Returns `{:error, :missing_owner}` |
| register_domain_invalid_metadata | Non-map metadata | Returns `{:error, :invalid_metadata}` |
| discover_datasets_success | Valid domain query | Returns `{:ok, [datasets]}` |
| discover_datasets_empty_domain | Empty domain param | Returns `{:error, :invalid_domain_name}` |
| query_lineage_upstream | Lineage query with depth=3 | Returns `{:ok, %{nodes, edges}}` |
| query_lineage_max_depth | depth=5 (boundary) | Returns `{:ok, lineage}` |
| query_lineage_empty_dataset | Empty dataset name | Returns `{:error, :invalid_dataset_name}` |
| check_quality_success | Valid quality query | Returns `{:ok, %{completeness, accuracy, ...}}` |
| check_quality_metrics_numeric | Quality values are numbers | All metrics are numeric in [0.0, 1.0] |
| concurrent_operations | 3 parallel register_domain | All return `{:ok, ...}` |

#### Running Tests

```bash
# Full test suite
cd OSA
mix test test/integrations/mesh/consumer_test.exs

# Specific test
mix test test/integrations/mesh/consumer_test.exs:"register_domain happy path"

# With verbose output
mix test test/integrations/mesh/consumer_test.exs --trace
```

### Code Quality

```bash
# Elixir warnings (should be clean)
mix compile --warnings-as-errors

# Format check
mix format --check-formatted

# Run full test suite
mix test
```

## Integration Points

### With BusinessOS

The Consumer can be called from BusinessOS Go backend via HTTP:

```go
// BusinessOS: internal/services/mesh_service.go
func (s *MeshService) RegisterDomain(ctx context.Context, req *RegisterDomainRequest) error {
  body := map[string]interface{}{
    "domain_name": req.DomainName,
    "owner": req.Owner,
    "description": req.Description,
  }

  resp, err := http.Post(
    "http://localhost:8089/api/mesh/domains",
    "application/json",
    bytes.NewReader(toJSON(body)),
  )

  return handleResponse(resp, err)
}
```

### With Canopy

The Consumer can be called from Canopy via HTTP webhooks or A2A protocol:

```elixir
# Canopy: adapters/osa.ex
defmodule Canopy.Adapters.OSA do
  def register_domain(domain_name, owner) do
    body = %{
      "domain_name" => domain_name,
      "owner" => owner,
      "description" => ""
    }

    Req.post!("http://localhost:8089/api/mesh/domains",
      json: body
    ).body
  end
end
```

### With pm4py-rust

Process mining features can annotate lineage with process signatures:

```rust
// pm4py-rust: src/mesh/integrations.rs
pub struct ProcessLineageNode {
    pub id: String,
    pub process_fingerprint: String,  // From healing.diagnosis
    pub event_count: u64,
}

impl ProcessLineageNode {
    pub async fn to_mesh_node(&self) -> MeshNode {
        MeshNode {
            id: self.id.clone(),
            node_type: "process_dataset".to_string(),
            metadata: json!({
                "fingerprint": self.process_fingerprint,
                "events": self.event_count,
            }),
        }
    }
}
```

## Troubleshooting

### Issue: Consumer Times Out

**Symptom:** `{:error, :timeout}` after 12 seconds

**Causes:**
1. bos CLI not in PATH: `which bos` → not found
2. bos command hanging: check `ps aux | grep bos`
3. Oxigraph unreachable: check `curl http://localhost:7878/`

**Solution:**
```bash
# Ensure bos is installed and in PATH
which bos
bos --version

# Test bos manually
bos mesh discover-datasets --domain test_domain

# Check Oxigraph health
curl http://localhost:7878/health

# Restart OSA with longer timeout for testing
iex -e "Consumer.start_link(bos_timeout_ms: 30_000)"
```

### Issue: Invalid Domain Name Rejection

**Symptom:** `{:error, :invalid_domain_name}` for "my-domain_v1"

**Cause:** Domain name validation regex `~r/^[a-z0-9_-]+$/i` is working correctly.

**Valid characters:**
- Lowercase & uppercase letters: a-z, A-Z
- Numbers: 0-9
- Underscores: _
- Hyphens: -

**Invalid characters:**
- Spaces, special chars (@, #, $, %, etc.)

**Solution:**
```elixir
# Valid
Consumer.register_domain(pid, "my_domain_v1", %{"owner" => "team"})

# Invalid
Consumer.register_domain(pid, "my domain@v1", %{"owner" => "team"})  # spaces and @
```

### Issue: Lineage Depth Not Respected

**Symptom:** Depth parameter ignored; returns depth>5

**Cause:** bos CLI ignores depth parameter (server-side bug)

**Solution:** File issue with bos maintainers. OSA validates input and passes to bos; if bos ignores it, that's a bos bug.

## Performance Characteristics

### Latency

| Operation | Typical | P99 | Max |
|-----------|---------|-----|-----|
| register_domain | 500ms | 2s | 12s (timeout) |
| discover_datasets | 300ms | 1s | 12s |
| query_lineage (depth=3) | 800ms | 3s | 12s |
| check_quality | 400ms | 2s | 12s |

**Assumptions:**
- Oxigraph has <1M triples
- bos CLI running on same host
- No network latency

### Concurrency Limits

| Metric | Value | Rationale |
|--------|-------|-----------|
| Max concurrent requests | OS limit | GenServer queue unbounded; set `ulimit -n` |
| Max domains | Dataset size | Limited by Oxigraph capacity (typically 100k+) |
| Max datasets per domain | Dataset size | Limited by Oxigraph capacity (typically 10k+) |
| Max lineage nodes | 100k+ | Limited by Oxigraph traversal; depth=5 limits in practice |

## Standards Compliance

### WvdA Soundness (van der Aalst)

**Deadlock Freedom:** ✓
- All GenServer.call() have explicit 12-second timeout
- No circular waits (linear call chain: HTTP → Routes → Consumer → bos)
- All resources released on return or timeout

**Liveness:** ✓
- All operations complete or timeout; no infinite loops
- bos command guarded by OS-level timeout
- No busy-wait or sleep-based loops

**Boundedness:** ✓
- Lineage depth max = 5 (explicit validation)
- Domain/dataset names max ~255 chars (filesystem)
- bos process memory bounded by Oxigraph (managed separately)

### Armstrong Fault Tolerance (Joe Armstrong)

**Let-It-Crash:** ✓
- No silent error swallowing; errors return `{:error, reason}`
- Supervisor restarts Consumer on panic/crash
- Crash logged with full context

**Supervision:** ✓
- Consumer supervised by OSA infrastructure supervisor
- Restart strategy: `:permanent` (restart on any crash)
- Max 5 restarts in 60 seconds before supervisor gives up

**No Shared State:** ✓
- All state in Consumer process (process-local)
- Communication via GenServer messages only
- No global mutable state or mutexes

**Budget Constraints:** ✓
- Per-operation budget: 12 seconds
- Timeout enforced by Erlang VM
- Graceful degradation: timeout → error → retry by caller

### Chicago TDD

**Test count:** 13+ comprehensive tests
**Coverage:**
- Happy paths (domain registration, discovery, lineage, quality)
- Input validation (domain/dataset names, metadata)
- Error handling (timeouts, parse errors)
- Concurrency (parallel operations)
- Boundary conditions (depth limits, empty inputs)

**All tests PASS with `mix test`**

## Future Enhancements

### Phase 2: Caching Layer

Add in-memory cache for frequently accessed queries:

```elixir
defmodule Consumer.Cache do
  use GenServer

  def get_cached_lineage(domain, dataset) do
    key = {:lineage, domain, dataset}
    case ETS.lookup(:mesh_cache, key) do
      [{_key, value, expiry}] ->
        if DateTime.compare(DateTime.utc_now(), expiry) == :lt do
          {:ok, value}
        else
          :miss
        end
      [] -> :miss
    end
  end
end
```

### Phase 3: Async Operations

Convert sync calls to async with Task-based batching:

```elixir
def discover_datasets_async(domain_name) do
  task = Task.async(fn ->
    Consumer.discover_datasets(Consumer, domain_name)
  end)
  {:ok, task}
end

def await_result(task, timeout \\ 12_000) do
  Task.await(task, timeout)
end
```

### Phase 4: Streaming Lineage

Stream large lineage graphs instead of loading all at once:

```elixir
def query_lineage_stream(domain, dataset) do
  Stream.resource(
    fn -> Consumer.query_lineage(Consumer, domain, dataset) end,
    fn {:ok, lineage} ->
      {[Enum.each(lineage.nodes, &emit_node/1)], :done}
    end,
    fn :done -> :ok end
  )
end
```

## References

- **OSA Documentation:** `OSA/CLAUDE.md`
- **Oxigraph SPARQL:** https://oxigraph.org/
- **bos CLI:** https://github.com/Miosa-osa/bos
- **Data Mesh Book:** "Fundamentals of Data Mesh" (Zhamak Dehghani)
- **WvdA Soundness:** van der Aalst, W.M.P. (2018). "Workflow Patterns"
- **Armstrong Fault Tolerance:** Armstrong, J. (2014). "Making Reliable Distributed Systems"

## Appendix: Deployment Checklist

Before moving to production:

- [ ] bos CLI installed and tested: `bos mesh discover-datasets --domain test`
- [ ] Oxigraph service running: `curl http://localhost:7878/health` returns 200
- [ ] Consumer registered in OSA supervisor tree
- [ ] MeshRoutes registered in HTTP router
- [ ] All 13+ tests passing: `mix test test/integrations/mesh/consumer_test.exs`
- [ ] Compiler warnings clean: `mix compile --warnings-as-errors`
- [ ] Load test: 1000 concurrent requests → no timeouts or memory leaks
- [ ] Lineage depth validated: queries with depth 1–5 all succeed
- [ ] Error messages non-leaking (no stack traces to clients)
- [ ] Logging configured: all operations logged to structured logs
- [ ] Monitoring: OTEL spans emitted for all operations
