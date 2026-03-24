# Fortune 5 Quickstart Guide

**Signal Theory:** S=(linguistic,tutorial,direct,markdown,quickstart)

---

## What is Fortune 5?

Fortune 5 is a 7-layer architecture for **running a Fortune 500 company from desktop in 45 minutes/week** through autonomous process coordination.

### The 7 Layers

1. **Signal Collection** - SPR Sensors scan codebase
2. **Signal Synchronization** - Pre-commit quality gates
3. **Data Recording** - RDF/Turtle generation (workspace.ttl)
4. **Correlation** - SPARQL CONSTRUCT queries (ggen/)
5. **Reconstruction** - Process model generation
6. **Verification** - Formal correctness proofs
7. **Event Horizon** - 45-minute week board process

---

## Quick Start (5 Minutes)

### Step 1: Scan Your Codebase

```elixir
# Scan lib/ directory and generate SPR data
{:ok, result} = OptimalSystemAgent.Sensors.SensorRegistry.scan_sensor_suite(
  codebase_path: "lib",
  output_dir: "priv/sensors"
)

IO.puts("Found #{result.total_modules} modules")
```

**Output:** `priv/sensors/modules.json`, `deps.json`, `patterns.json`

### Step 2: Generate RDF

```elixir
# Convert SPR to RDF/Turtle
{:ok, metadata} = OptimalSystemAgent.Sensors.RDFGenerator.generate_rdf()

IO.puts("Generated #{metadata.triple_count} RDF triples")
```

**Output:** `priv/sensors/workspace.ttl`

### Step 3: Run Tests

```bash
# Verify all Fortune 5 layers work
mix test test/optimal_system_agent/fortune_5/
```

**Expected:** 77 tests, 53+ passing

---

## Signal Theory Encoding

Every output in Fortune 5 uses **Signal Theory S=(M,G,T,F,W)**:

```elixir
%{
  "mode" => "data",        # linguistic, code, data, visual, mixed
  "genre" => "spec",       # spec, brief, report, analysis
  "type" => "inform",      # direct, inform, commit, decide
  "format" => "json",      # markdown, code, json, yaml
  "structure" => "list"    # adr-template, module-pattern, etc.
}
```

### Quality Gate Threshold

**S/N Score ≥ 0.8** required for all outputs.

Calculated as:
- Individual files: All 5 dimensions present = 1.0
- Combined SPR: (modules × 0.5 + deps × 0.25 + patterns × 0.25)

---

## Pre-commit Quality Gate

The pre-commit hook automatically blocks low-quality commits:

```bash
# Hook location: .git/modules/OSA/hooks/pre-commit
git commit -m "feat: add new feature"
# 🔍 Running Fortune 5 Quality Gate...
# Combined S/N Score: 0.9500
# ✅ QUALITY GATE PASSED
```

If S/N < 0.8:
```bash
# ❌ QUALITY GATE FAILED
# S/N score 0.7500 < 0.8
# Commit blocked.
```

---

## Fortune 5 Board Process (45 Minutes)

### Weekly Agenda

```
┌─────────────────────────────────────┐
│  FORTUNE 5 BOARD AGENDA             │
│  Duration: 45 minutes               │
└─────────────────────────────────────┘

📊 CALL TO ORDER (5 min)
   ├─ Review metrics
   ├─ Validate quality gates
   └─ Confirm operations status

🤖 AGENT PERFORMANCE (15 min)
   ├─ Top 5 agents
   ├─ Bottom 3 agents
   └─ Reflex arcs triggered

📈 PROCESS MINING (10 min)
   ├─ Bottlenecks
   ├─ Compliance violations
   └─ Efficiency improvements

🎯 STRATEGIC DECISIONS (10 min)
   ├─ Swarm authorizations
   ├─ Policy adjustments
   └─ Resource allocation

📋 ACTION ITEMS (5 min)
   ├─ Executive actions
   ├─ Agent tasks authorized
   └─ Next week priorities
```

See `docs/FORTUNE_5_BOARD_PROCESS_45_MINUTE_WEEK.md` for full specification.

---

## Common Workflows

### Daily Development

```bash
# 1. Make changes
vim lib/my_module.ex

# 2. Quality gate runs automatically
git add .
git commit -m "feat: add feature"
# ✅ QUALITY GATE PASSED

# 3. Run tests
mix test
```

### Weekly Board Review

```bash
# 1. Run Fortune 5 scan
mix run -e "OptimalSystemAgent.Sensors.SensorRegistry.scan_sensor_suite()"

# 2. Generate board report
mix run -e "Fortune5.Board.report()"

# 3. Review in 45-minute meeting
open docs/minutes/board-week-$(date +%Y-%V).md
```

---

## File Structure

```
OSA/
├── lib/optimal_system_agent/sensors/
│   ├── sensor_registry.ex       # Layer 1: SPR Sensors
│   └── rdf_generator.ex         # Layer 3: RDF Generation
├── priv/sensors/
│   ├── modules.json             # SPR: Module catalog
│   ├── deps.json                # SPR: Dependencies
│   ├── patterns.json            # SPR: YAWL patterns
│   └── workspace.ttl            # RDF: Workspace graph
├── ggen/sparql/
│   ├── construct_modules.rq     # SPARQL: Modules → SPR
│   ├── construct_deps.rq        # SPARQL: Dependencies → SPR
│   └── construct_patterns.rq    # SPARQL: Patterns → SPR
├── .git/modules/OSA/hooks/
│   └── pre-commit               # Layer 2: Quality gate
├── docs/
│   ├── FORTUNE_5_BOARD_PROCESS_45_MINUTE_WEEK.md
│   ├── fortune5_quickstart.md   # This file
│   ├── fortune5_usage_examples.md
│   └── fortune5_troubleshooting.md
└── test/optimal_system_agent/fortune_5/
    ├── fortune_5_gaps_test.exs           # Layer tests
    ├── signal_theory_quality_gates_test.exs  # S/N tests
    └── comprehensive_gaps_test.exs       # Integration tests
```

---

## Next Steps

1. **Read the full docs:** `docs/FORTUNE_5_BOARD_PROCESS_45_MINUTE_WEEK.md`
2. **Run the tests:** `mix test test/optimal_system_agent/fortune_5/`
3. **Check examples:** `docs/fortune5_usage_examples.md`
4. **Review board agenda:** `docs/FORTUNE_5_BOARD_AGENDA_TEMPLATE.md`

---

## Key Concepts

| Concept | Description |
|---------|-------------|
| **SPR** | Signal Processing Record - JSON sensor output |
| **S/N Score** | Signal-to-Noise ratio - quality metric (0.0 to 1.0) |
| **Quality Gate** | Pre-commit hook enforcing S/N ≥ 0.8 |
| **workspace.ttl** | RDF/Turtle representation of entire codebase |
| **SPARQL** | Query language for RDF graphs |
| **ggen/** | SPARQL CONSTRUCT queries for SPR generation |

---

**Last Updated:** 2026-03-23
**Fortune 5 Version:** 1.0
