# OSA Diataxis Documentation — March 2026 Additions

**Created**: 2026-03-25  
**Format**: 4 Diataxis documents (2 how-to, 2 reference)  
**Total**: 2,011 lines, ~8,000 words  
**Scope**: Healing patterns + tool development + configuration

---

## Document Summary

### How-To Guides (Problem-Solution Narrative)

#### 1. **Implement a New Healing Pattern** (462 lines, 12 KB)
**File**: `how-to/implement-healing-pattern.md`

**Problem**: OSA detects deadlock but lacks custom healing strategies.

**6-Step Solution**:
1. Define failure mode (11 modes: shannon, ashby, beer, wiener, deadlock, cascade, byzantine, starvation, livelock, timeout, inconsistent)
2. Create healer module implementing `heal/1` callback
3. Register healer in `Healing.Orchestrator.heal/1`
4. Write test using Red-Green-Refactor (failing test first)
5. Add configuration (optional, hot-reloadable)
6. Integration test (end-to-end: failure → diagnosis → healing)

**Key Sections**:
- Failure mode reference table (11 modes + repair strategies)
- Code template (deadlock healer, ready to copy-paste)
- Test patterns (unit + integration)
- Best practices: idempotency, observability, Armstrong principles, timeouts
- Troubleshooting guide (healer not called, OTEL spans not showing, test errors)

**Standards Applied**:
✓ Chicago TDD (Red-Green-Refactor cycle)
✓ Armstrong fault tolerance (let-it-crash, supervision)
✓ OTEL instrumentation (spans with attributes)
✓ WvdA soundness (timeouts, deadlock-free)

---

#### 2. **Add an Agent Tool to OSA** (519 lines, 19 KB)
**File**: `how-to/add-agent-tool.md`

**Problem**: Agent needs new capability (e.g., `@tool process_document`).

**5-Step Solution**:
1. Define tool (name, safety tier, input/output, timeout)
2. Create module implementing `Tools.Behaviour` (6 callbacks)
3. Register tool (auto-discovery in `builtins/` or manual)
4. Write tests (unit + integration)
5. Verify via `/api/tools` endpoint

**Tool Anatomy**:
```elixir
name()         → "process_document"
description()  → "Parse & extract structure from documents"
parameters()   → JSON Schema (type, properties, required)
execute(params)→ {:ok, result} | {:error, reason}
safety()       → :read_only | :write_safe | :write_destructive
available?()   → runtime gate (optional)
```

**Key Sections**:
- Design checklist (name, safety, inputs, outputs, permissions, timeout)
- Complete example: document parser tool (markdown, JSON, YAML, text formats)
- Test file (10 test cases: metadata, parsing, error handling)
- Integration test (agent calls tool end-to-end)
- Best practices: input validation, OTEL tracing, permission checks, timeouts
- Troubleshooting (tool not in API, wrong name, timeout)

**Standards Applied**:
✓ Chicago TDD (failing test first, FIRST principles)
✓ JSON Schema validation
✓ OTEL instrumentation (tool execution spans)
✓ Permission-based access control

---

### Reference Guides (Lookup Tables)

#### 3. **Agent API Reference** (568 lines, 14 KB)
**File**: `reference/agent-api-reference.md`

**Purpose**: Authoritative lookup for agent development.

**Sections** (lookup tables format):

| Section | Content | Audience |
|---------|---------|----------|
| Agent Callbacks | `init`, `handle_call`, `handle_cast`, `handle_info`, `terminate` | GenServer developers |
| Agent Configuration | Config sources (app config, env vars, startup opts) | Operators, developers |
| Agent Lifecycle | Initialization → running → shutdown → cleanup | Architects |
| Built-In Tools | All 32+ tools with safety tiers | Tool developers |
| Signals | S=(M,G,T,F,W) encoding, genres, examples | System designers |
| Events | Bus API, event categories, publish/subscribe | Integration developers |
| Operation Modes | Normal, Plan, Readonly, Subagent | Advanced users |
| Permission Tiers | :full, :workspace, :read_only, :subagent | Security engineers |
| Memory Layers | Scratch, Episodic, Semantic, Procedural | Data architects |
| Budget System | 4 tiers (critical, high, normal, low) | Budget administrators |
| Common Patterns | Sync calls, async tasks, event-driven, healing | Developers |
| Debugging | Status checks, events, OTEL spans, logs | Operators |
| Type Signatures | Elixir type definitions | Type-conscious developers |

**Format**: Lookup tables, NOT narrative. Fast scanning, exact definitions.

---

#### 4. **OSA Configuration Glossary** (462 lines, 15 KB)
**File**: `reference/osa-configuration-glossary.md`

**Purpose**: Complete configuration reference for deployment & operations.

**Major Sections**:

| Section | Entries | Format |
|---------|---------|--------|
| **Environment Variables** | 40+ | Name → Type → Default → Purpose → Where Checked |
| **Application Config** | 3 subsections | `config/config.exs` patterns |
| **ETS Tables** | 10+ tables | Table → Scope → Key → Value → TTL → Purpose |
| **GenServer Processes** | Singletons + dynamic | Module → Registered As → Supervision → Purpose |
| **Supervision Tree** | Full diagram | Root → subsystems → children → restart strategies |
| **Database Schema** | Core tables | Table → Columns → Indexes → Purpose |
| **Hot Reload** | Pattern | Runtime config change without restart |
| **Validation & Health** | Startup + runtime | Health check endpoints, validation rules |
| **Troubleshooting** | 8 scenarios | Problem → Check → Fix |

**Environment Variables Grouped by Purpose**:
- Agent config (budget, permissions, model)
- HTTP server (port, host, timeout, CORS)
- Healing & reflexes (enable, timeout)
- Tool execution (limits, timeouts, paths)
- Provider credentials (API keys, endpoints)
- Storage & persistence (DB URLs, paths)
- Telemetry & observability (OTEL, metrics, logs)
- Advanced features (experimental flags)

**ETS Tables Detail**:
All 10+ tables listed with:
- Key type and pattern
- Value structure
- TTL (if applicable)
- Usage example
- Guard patterns (safe deletion checks)

**GenServer Registry Detail**:
- Named singletons (Tools.Registry, Healing.Orchestrator, etc.)
- Dynamic processes (Agent.Loop via AgentRegistry)
- Lookup patterns with Registry module
- Via tuples for GenServer calls

---

## Integration & Cross-Reference

### Navigation Paths

**Scenario 1: "I need to heal a new failure mode"**
```
implement-healing-pattern.md (steps 1-6)
  ↓ (need agent callbacks)
agent-api-reference.md (Agent callbacks table)
  ↓ (need configuration)
osa-configuration-glossary.md (Healing config section)
```

**Scenario 2: "I need to add a custom tool"**
```
add-agent-tool.md (steps 1-5)
  ↓ (need tool safety info)
agent-api-reference.md (Tool safety tiers table)
  ↓ (need tool registry config)
osa-configuration-glossary.md (Tools config, ETS tables)
```

**Scenario 3: "System is behaving oddly, need to debug"**
```
osa-configuration-glossary.md (Troubleshooting checklist)
  ↓ (need to check ETS table state)
osa-configuration-glossary.md (ETS tables section, with guard patterns)
  ↓ (need to understand what's running)
osa-configuration-glossary.md (Supervision tree, GenServer processes)
  ↓ (need to see events)
agent-api-reference.md (Event types & bus API)
```

---

## Standards & Constraints Applied

All 4 documents follow ChatmanGPT's engineering standards:

### 1. Chicago TDD Discipline
- All code examples include test cases
- Red-Green-Refactor cycle documented
- FIRST principles (Fast, Independent, Repeatable, Self-Checking, Timely)

### 2. Armstrong Fault Tolerance (Erlang/OTP)
- Let-it-crash pattern in healing examples
- Supervision tree structure documented
- No shared mutable state, message-passing emphasized
- Budget constraints explained

### 3. WvdA Soundness (van der Aalst)
- Deadlock-free: all timeouts documented (timeout_ms parameters)
- Liveness: all loops have escape conditions
- Boundedness: all queues, caches have size limits

### 4. Signal Theory (S=(M,G,T,F,W))
- Agent signals section explains 5-tuple encoding
- Genres and modes documented with examples
- Quality gates mentioned in signal reference

### 5. 80/20 Principle
- How-To guides: specific, copy-paste ready, step-by-step
- Reference guides: lookup tables, fast scanning, exact definitions
- No unnecessary narrative; emphasis on actionable content

### 6. OTEL Instrumentation
- All examples include OTEL span patterns
- Attributes, status fields, error handling documented
- Jaeger verification steps included

---

## Quick Stats

| Metric | Value |
|--------|-------|
| Total lines | 2,011 |
| Total size | 61 KB |
| Documents | 4 |
| How-To guides | 2 |
| Reference guides | 2 |
| Code examples | 20+ |
| Tables | 40+ |
| Environment variables | 40+ |
| ETS tables documented | 10+ |
| Built-in tools listed | 32+ |
| Failure modes covered | 11 |

---

## File Locations

```
OSA/docs/diataxis/
├── how-to/
│   ├── implement-healing-pattern.md    (462 lines)
│   ├── add-agent-tool.md              (519 lines)
│   └── mcp-a2a-testing-guide.md       (existing)
├── reference/
│   ├── agent-api-reference.md         (568 lines)
│   ├── osa-configuration-glossary.md  (462 lines)
│   └── (other existing references)
├── explanation/
│   └── (theory documents)
└── README.md                           (updated with links)
```

---

## Usage & Discovery

All documents are:
- ✅ Indexed in `OSA/docs/diataxis/README.md`
- ✅ Cross-linked (how-to → reference)
- ✅ Searchable (grep for keyword or use table of contents)
- ✅ Copy-paste ready (code examples, config snippets)
- ✅ Production ready (tested patterns, real codebase references)

---

**Created by**: Claude Code Agent  
**Date**: 2026-03-25  
**Status**: Complete, ready for production use
