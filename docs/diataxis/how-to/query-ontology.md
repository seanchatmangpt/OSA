# How to: Query and Integrate with Oxigraph Ontology

**Last Updated:** 2026-03-26
**Applies to:** OSA (Optimal System Agent)
**Related:** WvdA Soundness, PROV-O Audit, DQV Quality

---

## Overview

OSA Phase 3 integrates a semantic ontology layer via Oxigraph (RDF store). This guide covers how to use the ontology to:
- Discover agents and their capabilities dynamically
- Query tools available by operational tier
- Detect policy compliance violations
- Emit provenance (audit trail) after actions
- Track signal quality metrics
- Verify workflow soundness before execution

---

## Prerequisites

1. **Oxigraph Running**
   ```bash
   oxigraph serve --location ./oxigraph_data
   ```
   Default: http://localhost:7878

2. **Ontology Loaded**
   Import workspace.ttl containing agent definitions, tools, policies, and processes:
   ```bash
   curl -X POST http://localhost:7878/import \
     -H "Content-Type: application/x-turtle" \
     -d @workspace.ttl
   ```

3. **OSA Modules**
   All ontology operations go through these modules (in `OSA/lib/optimal_system_agent/ontology/`):
   - `OxigraphClient` — HTTP connection pool to Oxigraph
   - `AgentLoader` — Load agents from ontology
   - `ToolCapabilityRegistry` — Tool discovery and access control
   - `ComplianceChecker` — Policy violation detection
   - `ProvenanceEmitter` — Record PROV-O audit trail
   - `QualityRecorder` — Track DQV quality metrics
   - `SoundnessVerifier` — Verify WvdA soundness

---

## Task 1: Load Agents from Ontology

**Goal:** Fetch all active agents and their metadata from the ontology at startup.

**SPARQL Query Used:**
```sparql
PREFIX chatman: <https://ontology.chatmangpt.com/core#>
PREFIX dcterms: <http://purl.org/dc/terms/>

SELECT ?agentId ?label ?role ?tier WHERE {
  ?agent a chatman:AIAgent ;
    dcterms:identifier ?agentId ;
    rdfs:label ?label ;
    chatman:hasRole ?role ;
    chatman:operatesInTier ?tier .
}
ORDER BY ?tier ?agentId
```

**Elixir Code:**
```elixir
alias OptimalSystemAgent.Ontology.AgentLoader

# At application startup:
case AgentLoader.load_agents() do
  {:ok, count} ->
    Logger.info("Loaded #{count} agents from ontology")
    :ok

  {:error, reason} ->
    Logger.error("Failed to load agents: #{inspect(reason)}")
    :error
end

# Check if a specific agent exists:
case AgentLoader.agent_exists?("agent_7") do
  {:ok, agent} -> IO.inspect(agent)
  {:error, :not_found} -> IO.puts("Agent not found")
end

# Get all agents in a specific tier:
case AgentLoader.agents_by_tier("critical") do
  {:ok, agents} -> Enum.each(agents, &IO.inspect/1)
  {:error, reason} -> IO.inspect(reason)
end
```

**Signal Theory:** S=(data, reference, inform, json, array)
- Mode: data (structured agent list)
- Genre: reference (ontology lookup)
- Type: inform (tell OSA what agents exist)
- Format: JSON (SPARQL results)
- Structure: array of agent maps

---

## Task 2: Discover Tools by Tier

**Goal:** Dynamically fetch tools available to an agent based on its operational tier.

**SPARQL Query Used:**
```sparql
PREFIX chatman: <https://ontology.chatmangpt.com/core#>
PREFIX dcterms: <http://purl.org/dc/terms/>

SELECT ?toolId ?label WHERE {
  ?tool a chatman:Tool ;
    dcterms:identifier ?toolId ;
    rdfs:label ?label ;
    chatman:requiredTier ?requiredTier .

  FILTER (?requiredTier IN ("critical", "high", "normal", "low"))
}
ORDER BY ?toolId
```

**Elixir Code:**
```elixir
alias OptimalSystemAgent.Ontology.ToolCapabilityRegistry

# Discover all tools in the ontology:
case ToolCapabilityRegistry.discover_tools() do
  {:ok, count} ->
    Logger.info("Discovered #{count} tools")
    :ok

  {:error, reason} ->
    Logger.error("Tool discovery failed: #{inspect(reason)}")
end

# Get tools available to a specific agent tier:
case ToolCapabilityRegistry.tools_for_tier(:critical) do
  {:ok, tool_ids} ->
    IO.inspect(tool_ids)
    # ["web_fetch", "file_read", "shell_execute", "git", ...]

  {:error, reason} ->
    IO.inspect(reason)
end

# Get full spec for a specific tool:
case ToolCapabilityRegistry.get_tool_capability("web_fetch") do
  {:ok, spec} ->
    spec = %{
      tool_id: "web_fetch",
      label: "Fetch Web Page",
      input_schema: "...",
      output_schema: "...",
      required_tier: "normal"
    }
    IO.inspect(spec)

  {:error, :not_found} ->
    IO.puts("Tool not found")
end

# Check if agent can access a tool:
case ToolCapabilityRegistry.can_access_tool?(:normal, "web_fetch") do
  {:ok, true} -> IO.puts("Agent can access this tool")
  {:ok, false} -> IO.puts("Agent tier too low for this tool")
  {:error, reason} -> IO.inspect(reason)
end
```

**Tier Hierarchy:**
- **critical**: Can access all tools (no restrictions)
- **high**: Can access high-tier and below
- **normal**: Can access normal-tier and low-tier tools
- **low**: Can only access low-tier tools

**Signal Theory:** S=(data, reference, decide, json, schema)
- Mode: data (tool specifications)
- Genre: reference (lookup capabilities)
- Type: decide (agent checks what tools it can use)
- Format: JSON (schema descriptors)
- Structure: tool capability map

---

## Task 3: Check Compliance Violations

**Goal:** Query active policy violations and emit healing actions to fix them.

**SPARQL Query Used:**
```sparql
PREFIX chatman: <https://ontology.chatmangpt.com/core#>

SELECT ?violation ?resource ?policy ?severity ?remediation WHERE {
  ?violation a chatman:ComplianceViolation ;
    chatman:affectsResource ?resource ;
    chatman:breachesPolicy ?policy ;
    chatman:severity ?severity ;
    chatman:suggestedRemediation ?remediation .
}
ORDER BY DESC(?severity)
```

**Elixir Code:**
```elixir
alias OptimalSystemAgent.Ontology.ComplianceChecker

# Check for all violations:
case ComplianceChecker.check_violations() do
  {:ok, violations} ->
    Enum.each(violations, fn v ->
      IO.puts("Violation: #{v.violation_id}")
      IO.puts("  Resource: #{v.resource}")
      IO.puts("  Policy: #{v.policy}")
      IO.puts("  Severity: #{v.severity}")
      IO.puts("  Remediation: #{v.remediation}")
    end)

  {:error, reason} ->
    Logger.error("Violation check failed: #{inspect(reason)}")
end

# Check violations for a specific resource:
case ComplianceChecker.check_resource_violations("agent_7") do
  {:ok, violations} ->
    Enum.each(violations, &IO.inspect/1)

  {:error, reason} ->
    IO.inspect(reason)
end

# Check AND auto-remediate violations:
case ComplianceChecker.check_and_remediate() do
  {:ok, %{violations: violations, remediated: count}} ->
    Logger.info("Found #{length(violations)} violations, remediated #{count}")

  {:error, reason} ->
    Logger.error("Auto-remediation failed: #{inspect(reason)}")
end
```

**Severity Levels:**
- **critical**: Immediate remediation required (blocks operation)
- **high**: Remediation within 1 hour
- **medium**: Remediation within 24 hours
- **low**: Monitor and remediate next maintenance window

**Healing Actions:**
When a violation is detected, `ComplianceChecker` emits an action to `OptimalSystemAgent.Healing.ReflexArcs`, which triggers auto-remediation based on the suggested remediation in the ontology.

**Signal Theory:** S=(data, audit, inform, json, violation)
- Mode: data (violation records)
- Genre: audit (compliance tracking)
- Type: inform (OSA of violations)
- Format: JSON (violation details)
- Structure: list of compliance violations

---

## Task 4: Emit Provenance (Audit Trail)

**Goal:** Record what happened, when, who did it, and why (PROV-O triples).

**Elixir Code:**
```elixir
alias OptimalSystemAgent.Ontology.ProvenanceEmitter

# After an agent action, emit provenance:
:ok = ProvenanceEmitter.emit_action(
  "a2a_call_123",     # action_id
  "agent_7",          # agent_id
  "query_execution",  # action_type
  "ontology_agents",  # resource_id
  %{
    input: "SELECT ?agent WHERE...",
    output: "5 rows",
    duration_ms: 245
  }
)

# Get provenance chain for a resource:
case ProvenanceEmitter.get_provenance_chain("ontology_agents") do
  {:ok, actions} ->
    Enum.each(actions, fn action ->
      IO.puts("Action: #{action.action_id}")
      IO.puts("  Agent: #{action.agent_id}")
      IO.puts("  Type: #{action.action_type}")
      IO.puts("  Time: #{action.timestamp}")
    end)

  {:error, reason} ->
    IO.inspect(reason)
end

# Query actions by time range:
start_time = "2026-03-26T00:00:00Z"
end_time = "2026-03-26T23:59:59Z"

case ProvenanceEmitter.query_provenance_by_time(start_time, end_time) do
  {:ok, actions} ->
    IO.puts("#{length(actions)} actions in time range")
    Enum.each(actions, &IO.inspect/1)

  {:error, reason} ->
    IO.inspect(reason)
end
```

**PROV-O Triples Stored:**
```turtle
<https://ontology.chatmangpt.com/action/a2a_call_123>
  a prov:Activity ;
  prov:wasAssociatedWith <https://ontology.chatmangpt.com/agent/agent_7> ;
  prov:used <https://ontology.chatmangpt.com/resource/ontology_agents> ;
  chatman:actionType "query_execution" ;
  dcterms:issued "2026-03-26T12:30:45Z"^^xsd:dateTime ;
  chatman:hasInput "SELECT ?agent WHERE..." ;
  chatman:hasOutput "5 rows" ;
  chatman:duration_ms 245 .
```

**Signal Theory:** S=(data, audit, record, ttl, triple)
- Mode: data (action records)
- Genre: audit (immutable trail)
- Type: record (timestamp + who + what + why)
- Format: RDF N-Triples (PROV-O)
- Structure: PROV-O activity + associations

---

## Task 5: Track Signal Quality (DQV)

**Goal:** Record Data Quality Vocabulary metrics after agent actions.

**Elixir Code:**
```elixir
alias OptimalSystemAgent.Ontology.QualityRecorder

# Record a quality measurement after an action:
:ok = QualityRecorder.record_quality(
  "a2a_call_123",
  "signal_to_noise",
  0.95,
  %{agent: "agent_7", tier: "critical"}
)

# Get quality metrics for an action:
case QualityRecorder.get_action_quality("a2a_call_123") do
  {:ok, metrics} ->
    Enum.each(metrics, fn m ->
      IO.puts("#{m.metric_name}: #{m.value}")
    end)

  {:error, reason} ->
    IO.inspect(reason)
end

# Aggregate quality metric over time window:
start_time = "2026-03-26T00:00:00Z"
end_time = "2026-03-26T23:59:59Z"

case QualityRecorder.aggregate_quality_metric("signal_to_noise", start_time, end_time) do
  {:ok, stats} ->
    IO.puts("Average S/N ratio: #{stats.avg}")
    IO.puts("Range: #{stats.min} .. #{stats.max}")
    IO.puts("Samples: #{stats.count}")

  {:error, reason} ->
    IO.inspect(reason)
end
```

**DQV Metrics Tracked:**
- **signal_to_noise**: 0.0 .. 1.0, target >= 0.7
- **accuracy**: 0.0 .. 1.0, target >= 0.9
- **relevance**: 0.0 .. 1.0, target >= 0.85
- **completeness**: 0.0 .. 1.0, target >= 0.95
- **latency_ms**: milliseconds, budget varies by tier

**Signal Theory:** S=(data, metric, inform, json, quality)
- Mode: data (quality measurements)
- Genre: metric (quantified observations)
- Type: inform (OSA of output quality)
- Format: JSON (numeric values + dimensions)
- Structure: DQV measurement + context

---

## Task 6: Verify Workflow Soundness

**Goal:** Check that a workflow is deadlock-free, live, and bounded before executing it.

**WvdA Properties:**
1. **Deadlock Freedom**: No execution gets stuck waiting forever
2. **Liveness**: All actions eventually complete
3. **Boundedness**: Resources don't grow infinitely

**Elixir Code:**
```elixir
alias OptimalSystemAgent.Ontology.SoundnessVerifier

# Verify a process before execution:
case SoundnessVerifier.verify_process("workflow_123") do
  {:ok, result} ->
    IO.puts("Workflow is SOUND")
    IO.puts("  Deadlock-free: #{result.deadlock_free}")
    IO.puts("  Liveness: #{result.liveness}")
    IO.puts("  Bounded: #{result.bounded}")

  {:error, %{failing_properties: failing}} ->
    IO.puts("Workflow is UNSOUND")
    IO.inspect(failing)
end

# Quick deadlock-free check only:
case SoundnessVerifier.check_deadlock_free("workflow_123") do
  {:ok, true} -> IO.puts("Safe to execute (deadlock-free)")
  {:ok, false} -> IO.puts("WARNING: Workflow may deadlock")
  {:error, reason} -> IO.inspect(reason)
end

# Get soundness status of all processes:
case SoundnessVerifier.list_processes_with_soundness() do
  {:ok, processes} ->
    sound = Enum.filter(processes, fn p ->
      p.deadlock_free && p.liveness && p.bounded
    end)
    IO.puts("#{length(sound)}/#{length(processes)} processes are sound")

  {:error, reason} ->
    IO.inspect(reason)
end
```

**Integration with Execution Gate:**
```elixir
defmodule OSA.Workflow.Executor do
  def execute(workflow_id, context) do
    # Gate 1: Verify soundness
    case SoundnessVerifier.verify_process(workflow_id) do
      {:ok, _} ->
        # Gate 2: Check compliance
        case ComplianceChecker.check_violations() do
          {:ok, []} ->
            # Gate 3: Execute
            do_execute(workflow_id, context)

          {:ok, violations} ->
            {:error, {:compliance_violations, violations}}

          {:error, reason} ->
            {:error, reason}
        end

      {:error, unsound} ->
        {:error, {:unsound_workflow, unsound}}
    end
  end

  defp do_execute(workflow_id, context) do
    # Actual workflow execution
    # Emit provenance after key steps
    # Record quality metrics
  end
end
```

**Signal Theory:** S=(data, audit, assess, json, soundness)
- Mode: data (verification results)
- Genre: audit (formal assessment)
- Type: assess (check fitness for execution)
- Format: JSON (boolean properties + proof)
- Structure: WvdA result + failing properties

---

## Troubleshooting

### Oxigraph Connection Fails

```elixir
# Check health:
case OxigraphClient.health_check() do
  {:ok, %{status: "ok"}} ->
    IO.puts("Oxigraph is healthy")

  {:error, reason} ->
    IO.puts("Oxigraph unreachable: #{inspect(reason)}")
    IO.puts("Is Oxigraph running on localhost:7878?")
end

# Check pool stats:
stats = OxigraphClient.stats()
IO.inspect(stats)
```

### Query Returns No Results

1. Check ontology is loaded:
   ```bash
   curl http://localhost:7878/query \
     -H "Content-Type: application/sparql-query" \
     -H "Accept: application/sparql-results+json" \
     -d "SELECT * WHERE { ?s ?p ?o } LIMIT 1"
   ```

2. Verify URI prefixes match:
   - Query: `PREFIX chatman: <https://ontology.chatmangpt.com/core#>`
   - Ontology: Check workspace.ttl uses same URIs

3. Check SPARQL syntax:
   ```bash
   # Oxigraph logs invalid queries
   docker logs oxigraph 2>&1 | grep -i error
   ```

### Healing Action Not Emitted

1. Check ReflexArcs is running:
   ```elixir
   OptimalSystemAgent.Healing.ReflexArcs.status()
   ```

2. Check compliance violation structure:
   ```elixir
   ComplianceChecker.check_violations()
   # Verify :remediation key is present
   ```

---

## Performance Considerations

### Query Timeouts
All queries have explicit timeout_ms with fallback:
```elixir
# Default: 10 seconds
case AgentLoader.load_agents() do
  {:ok, count} -> :ok
  {:error, :timeout} -> use_cached_agents()
  {:error, reason} -> {:error, reason}
end
```

### Caching
For frequently accessed data (tools, agents), consider:
```elixir
# Cache in ETS (lock-free reads)
:ets.insert(:tool_cache, {tool_id, spec})

# Or use Agent for mutable state
Agent.get(:tool_cache, &Map.get(&1, tool_id))
```

### Batch Operations
Query multiple items at once:
```elixir
# Instead of:
agents = Enum.map(agent_ids, &AgentLoader.agent_exists?/1)

# Use:
AgentLoader.agents_by_tier("critical")
# Returns all critical agents in one query
```

---

## References

- **W3C PROV-O:** https://www.w3.org/TR/prov-o/
- **W3C DQV:** https://www.w3.org/TR/vocab-dqv/
- **Oxigraph Documentation:** https://oxigraph.org/
- **WvdA Process Mining:** van der Aalst, W. M. "Process Mining" (2016)

---

**Last Updated:** 2026-03-26 by ChatmanGPT Phase 3 Integration
