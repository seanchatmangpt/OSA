# OSA — Diátaxis Documentation

> **Optimal System Agent — Multi-agent orchestration with Signal Theory.**
>
> Diátaxis documentation for OSA — tutorials, how-to guides, explanations, and reference.

---

## About OSA

OSA (Optimal System Agent) is an Elixir/OTP + Rust multi-agent orchestration system. It uses Signal Theory for intelligent message routing, achieving ~75% cost reduction vs naive routing through the 5-tuple S=(M,G,T,F,W) classification.

**Tech Stack**: Elixir 1.15 + Phoenix 1.8.5 + Rust TUI + Tauri/SvelteKit desktop

**Capabilities**: 18 LLM providers, 12 chat channels, 32 built-in tools, 1,108 tests

---

## Diátaxis Documentation

### [Tutorials](../../docs/diataxis/tutorials/) — Learn by Doing

| Tutorial | What You'll Learn | Time |
|----------|-------------------|------|
| [OSA Agent Integration](../../docs/diataxis/tutorials/osa-agent-integration.md) | Custom agents in OSA runtime | 50 min |
| [Signal Theory in Practice](../../docs/diataxis/tutorials/signal-theory-practice.md) | Quality-gated agent outputs | 45 min |
| [Your First AI Operation](../../docs/diataxis/tutorials/first-operation.md) | Build Canopy workspace (OSA runs it) | 30 min |

### [How-to Guides](../../docs/diataxis/how-to/) — Solve Problems

| Guide | Solves | Complexity |
|-------|--------|------------|
| [Add S/N Quality Gates](../../docs/diataxis/how-to/add-quality-gates.md) | Reject low-quality agent output | Intermediate |
| [Debug Signal Classification](../../docs/diataxis/how-to/debug-signal-classification.md) | Fix S=(M,G,T,F,W) errors | Intermediate |
| [Integrate Data Operating Standard](../../docs/diataxis/how-to/data-operating-standard.md) | SDK-backed data operations | Advanced |

### [Explanation](../../docs/diataxis/explanation/) — Understand the System

| Explanation | Topic | Why It Matters |
|-------------|-------|----------------|
| [The 7-Layer Architecture in OSA](./explanation/seven-layer-architecture-osa.md) | Signal → Composition → Interface → Data → Feedback → Governance | How OSA organizes complexity into 6 layers that prevent failure |
| [Signal Theory and Quality Gates](./explanation/signal-theory-quality-gates.md) | S=(M,G,T,F,W) as quality mechanism | Why ~75% of agent outputs pass quality gates on first try |
| [Deadlock-Free Design (WvdA Soundness)](./explanation/deadlock-free-design-wvda.md) | Timeouts, supervision, bounded queues | How OSA guarantees the system never freezes |
| [The Chatman Equation](../../docs/diataxis/explanation/chatman-equation.md) | A=μ(O) mathematical foundation | OSA applies this to orchestration |
| [Signal Theory Complete](../../docs/diataxis/explanation/signal-theory-complete.md) | 5-tuple encoding + 4 constraints | OSA's core routing mechanism |
| [The 7-Layer Architecture](../../docs/diataxis/explanation/seven-layer-architecture.md) | Optimal Systems design | OSA implements layers 2-7 |

### [Reference](../../docs/diataxis/reference/) — Look Up Details

| Reference | Covers | Format |
|-----------|--------|--------|
| [Signal Format](../../docs/diataxis/reference/signal-format.md) | S=(M,G,T,F,W) specification | BNF grammar |
| [API Endpoints](../../docs/diataxis/reference/api-endpoints.md) | All REST/WebSocket APIs | OpenAPI specs |
| [CLI Commands](../../docs/diataxis/reference/cli-commands.md) | All `osa` commands | Man pages |
| [Genre Catalog](../../docs/diataxis/reference/genre-catalog.md) | All Signal Theory genres | Usage guide |

---

## OSA-Specific Documentation

### Core Architecture

| Topic | Diátaxis Docs | OSA Docs |
|-------|---------------|----------|
| **Agent Loop** | [The Chatman Equation](../../docs/diataxis/explanation/chatman-equation.md) | [Agent Loop](../backend/agent-loop/) |
| **Signal Theory** | [Signal Theory Complete](../../docs/diataxis/explanation/signal-theory-complete.md) | [Signal Theory](../backend/signal-theory.md) |
| **LLM Providers** | [Explanation: Signal Routing](../../docs/diataxis/explanation/signal-theory-complete.md) | [Providers](../backend/providers/) |
| **Tools** | [How-to: Add Quality Gates](../../docs/diataxis/how-to/add-quality-gates.md) | [Tools](../backend/tools/) |
| **Channels** | [Signal Format Reference](../../docs/diataxis/reference/signal-format.md) | [Channels](../backend/channels/) |
| **Memory** | [Progressive Disclosure Theory](../../docs/diataxis/explanation/progressive-disclosure.md) | [Memory](../backend/memory/) |
| **Orchestration** | [43 YAWL Patterns](../../docs/diataxis/reference/yawl-43-patterns.md) | [Orchestration](../backend/orchestration/) |

### Features

| Topic | Diátaxis Docs | OSA Docs |
|-------|---------------|----------|
| **Skills** | [Tutorial: OSA Agent Integration](../../docs/diataxis/tutorials/osa-agent-integration.md) | [Skills](../features/skills.md) |
| **Hooks** | [Explanation: Feedback Loops](../../docs/diataxis/explanation/seven-layer-architecture.md) | [Hooks](../features/hooks.md) |
| **Proactive Mode** | [YAWL Patterns](../../docs/diataxis/reference/yawl-43-patterns.md) | [Proactive Mode](../features/proactive-mode.md) |
| **Tasks** | [How-to: Agent Handoffs](../../docs/diataxis/how-to/agent-handoffs.md) | [Tasks](../features/tasks.md) |

### Desktop Application

| Topic | Diátaxis Docs | OSA Docs |
|-------|---------------|----------|
| **Overview** | [Tutorial: OSA Agent Integration](../../docs/diataxis/tutorials/osa-agent-integration.md) | [Desktop Overview](../desktop/README.md) |
| **Architecture** | [7-Layer Architecture](../../docs/diataxis/explanation/seven-layer-architecture.md) | [Desktop Architecture](../desktop/architecture.md) |
| **Stores** | [Progressive Disclosure Theory](../../docs/diataxis/explanation/progressive-disclosure.md) | [Stores](../desktop/stores.md) |
| **Development** | [Tutorial: Signal Theory Practice](../../docs/diataxis/tutorials/signal-theory-practice.md) | [Desktop Development](../desktop/development.md) |

---

## AGI-Level Connections

### Signal Theory in OSA

OSA uses Signal Theory for **intelligent routing**:

```
┌─────────────────────────────────────────────────────────────┐
│                  SIGNAL ROUTING LAYER                       │
│              S=(M,G,T,F,W) — Universal Encoding             │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  User Message ──→ Classify S=(M,G,T,F,W)                    │
│       │                                                       │
│       ├──→ Mode: linguistic → Use text model                │
│       ├──→ Genre: email → Email generation capability      │
│       ├──→ Type: direct → Action required                  │
│       ├──→ Format: markdown → Text output                  │
│       └──→ Structure: cold-email-anatomy → Email template  │
│                                                               │
│  Result: Right provider + right model + right capabilities  │
│          ~75% cost reduction vs naive routing               │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

### The 7 Layers in OSA

OSA implements layers 2-7 of the Optimal System architecture:

| Layer | What | OSA Implementation |
|-------|------|-------------------|
| **L2: Signal** | Encoded intent | S=(M,G,T,F,W) classification |
| **L3: Composition** | Internal structure | Agent loop, skills, tools |
| **L4: Interface** | How info surfaces | Channel adapters, desktop UI |
| **L5: Data** | Where it's stored | Memory layers, sessions, knowledge graph |
| **L6: Feedback** | Self-correction | Hooks, telemetry, learning loop |
| **L7: Governance** | Organizational purpose | Configuration, permissions, budgets |

### YAWL Patterns in OSA

OSA's orchestration uses YAWL patterns:

| Pattern | OSA Implementation |
|---------|-------------------|
| **Sequence** | Agent loop: think → act → observe |
| **Parallel Split** | Multi-agent execution |
| **Synchronization** | Fleet coordination |
| **Exclusive Choice** | Provider selection |
| **Deferred Choice** | Fallback chains |

---

## Quick Start Paths

### For New Users

1. **Install OSA**: [Installation Guide](../getting-started/README.md)
2. **Learn Signal Theory**: [Tutorial](../../docs/diataxis/tutorials/signal-theory-practice.md)
3. **Integrate agents**: [OSA Agent Integration](../../docs/diataxis/tutorials/osa-agent-integration.md)

### For Developers

1. **Agent Loop**: [Agent Loop Documentation](../backend/agent-loop/)
2. **Providers**: [Provider Integration](../backend/providers/)
3. **Tools**: [Tool Development](../backend/tools/)

### For Operators

1. **Deployment**: [Deployment Guide](../operations/deployment.md)
2. **Configuration**: [Configuration Reference](../../docs/diataxis/reference/configuration.md)
3. **Debugging**: [Debugging Guide](../operations/debugging.md)

---

## Cross-Project Links

- **Root Diátaxis**: [Main Documentation](../../docs/diataxis/README.md)
- **BusinessOS**: [BusinessOS Diátaxis](../../BusinessOS/docs/diataxis/README.md)
- **Canopy**: [Canopy Diátaxis](../../canopy/docs/diataxis/README.md)
- **OSA README**: [Main OSA Documentation](../README.md)

---

*OSA Diátaxis Documentation — Part of the ChatmanGPT Knowledge System*

---

## Latest Additions — Vision 2030 Documentation

### How-To Guides (March 2026)

**[How-To: Implement a New Healing Pattern](./how-to/implement-healing-pattern.md)** (462 lines)
- Add custom healers for 11 failure modes (deadlock, timeout, cascade, etc.)
- Follow 6-step process: define → create → register → test → config → E2E
- Includes deadlock healer example, Armstrong principles, OTEL instrumentation
- Best practices: idempotency, observability, timeouts, supervision

**[How-To: Add an Agent Tool to OSA](./how-to/add-agent-tool.md)** (519 lines)
- Build new tools from scratch (e.g., `@tool process_document`)
- Tools.Behaviour contract, JSON Schema validation, permission enforcement
- Copy-paste ready: document parser example (markdown, JSON, YAML, text)
- Registration, testing, integration checklist

### Reference Guides (March 2026)

**[Reference: Agent API Reference](./reference/agent-api-reference.md)** (568 lines)
- All agent callbacks (init, handle_call, handle_cast, handle_info, terminate)
- Agent config sources and lifecycle
- 32+ built-in tools with safety tiers
- Signals (S=(M,G,T,F,W)), events, modes, permissions
- Memory layers, budget system, common patterns, debugging

**[Reference: OSA Configuration Glossary](./reference/osa-configuration-glossary.md)** (462 lines)
- 40+ environment variables grouped by purpose
- ETS tables (10+ with TTLs, key patterns, usage examples)
- GenServer processes & registries (named singletons, dynamic agents)
- Supervision tree structure & restart strategies
- Database schema, hot reload, health checks, troubleshooting

---

**Cross-Document Navigation:**
- Need healing? → `implement-healing-pattern.md` → `agent-api-reference.md` (Agent callbacks) → `osa-configuration-glossary.md` (Healing config)
- Need tools? → `add-agent-tool.md` → `agent-api-reference.md` (Tool safety tiers) → `osa-configuration-glossary.md` (Tool config)
- Need config? → `osa-configuration-glossary.md` (lookup) → `agent-api-reference.md` (patterns) → how-tos (examples)

**All 4 documents follow:**
- 80/20 principle (specific + copy-paste ready)
- Chicago TDD discipline (tests, Red-Green-Refactor)
- Armstrong principles (supervision, let-it-crash, no shared state)
- OTEL instrumentation (observability)
- WvdA soundness (timeouts, deadlock-free, liveness)

