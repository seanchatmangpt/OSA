# OSA — the Optimal System Agent

> One AI agent that lives in your OS. Local-first. Open source.

[![License: Apache 2.0](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)
[![Elixir](https://img.shields.io/badge/Elixir-1.17+-purple.svg)](https://elixir-lang.org)
[![OTP](https://img.shields.io/badge/OTP-27+-green.svg)](https://www.erlang.org)
[![Tests](https://img.shields.io/badge/Tests-1730-brightgreen.svg)](#)
[![Version](https://img.shields.io/badge/Version-0.3.0-orange.svg)](#)

---

## Why OSA Exists

Every agent framework processes every message the same way. "Build me a REST API with auth" gets the same pipeline as "What time is it?" Same model, same context window, same latency, same cost.

We built OSA to fix this. It's the AI layer of [MIOSA](https://miosa.ai) — an operating system for running your entire business. The foundation is Signal Theory: every input is classified by intent, domain, and complexity *before* it touches the reasoning engine. The right model gets the right task. Multi-step problems get decomposed into parallel sub-agents. The agent remembers what worked and what didn't across sessions.

---

## What Makes OSA Different

### 1. Signal Classification

Before the agent reasons about anything, it understands what you're asking. Every input is classified into a 5-tuple:

```
S = (Mode, Genre, Type, Format, Weight)

Mode:   What to do     — BUILD, EXECUTE, ANALYZE, MAINTAIN, ASSIST
Genre:  Speech act     — DIRECT, INFORM, COMMIT, DECIDE, EXPRESS
Type:   Domain         — question, request, issue, scheduling, summary
Format: Container      — message, command, document, notification
Weight: Complexity     — 0.0 (trivial) → 1.0 (critical, multi-step)
```

The classifier is LLM-primary with a deterministic fallback. Results are cached in ETS (SHA256 key, 10-minute TTL).

### 2. Multi-Provider LLM Routing

7 providers wired and tested, with intelligent tier routing:

```
Weight 0.0–0.35  →  Utility tier (fast, cheap)
Weight 0.35–0.65 →  Specialist tier (balanced)
Weight 0.65–1.0  →  Elite tier (full reasoning)
```

| Provider | Status |
|----------|--------|
| **Ollama Local** | Runs on your machine — free, private |
| **Ollama Cloud** | Fast cloud inference, no GPU needed |
| **Anthropic** | Claude models (Opus, Sonnet, Haiku) |
| **OpenAI** | GPT models |
| **OpenRouter** | 200+ models, one key |
| **MIOSA** | Fully managed Optimal agent |
| **Custom** | Any OpenAI-compatible endpoint |

### 3. Autonomous Task Orchestration

Complex tasks get decomposed into parallel sub-agents:

```
User: "Build me a REST API with auth, tests, and docs"

OSA Orchestrator:
  ├── Research agent — analyzing codebase
  ├── Builder agent  — writing implementation
  ├── Tester agent   — writing tests
  └── Writer agent   — writing documentation
```

### 4. Multi-Agent Swarm Patterns

```elixir
:parallel     # All agents work simultaneously
:pipeline     # Agent output feeds into next agent
:debate       # Agents argue, consensus emerges
:review_loop  # Build → review → fix → re-review
```

ETS-backed team coordination with shared task lists, mailbox messaging, scratchpads, and iteration budgets.

### 5. 25 Built-in Tools

| Category | Tools |
|----------|-------|
| **File** | `file_read`, `file_write`, `file_edit`, `file_glob`, `file_grep`, `dir_list`, `multi_file_edit` |
| **System** | `shell_execute`, `git`, `download` |
| **Web** | `web_search`, `web_fetch` |
| **Memory** | `memory_save`, `memory_recall`, `session_search` |
| **Agent** | `delegate`, `message_agent`, `list_agents`, `team_tasks` |
| **Skills** | `create_skill`, `list_skills` |
| **Code** | `code_symbols`, `computer_use` |
| **Other** | `task_write`, `ask_user` |

### 6. Identity & Memory

**Soul system:** `IDENTITY.md`, `USER.md`, `SOUL.md` loaded at boot and interpolated into every LLM call. The setup wizard collects your name and agent name — the agent knows who you are from conversation one.

**Memory:**
- **Long-term** — SQLite + ETS with relevance scoring (keyword match + signal weight + recency)
- **Episodic** — Per-session event tracking, capped at 1000 events
- **Skills** — Patterns with occurrence >= 5 auto-generate skill files

### 7. Context & Compression

**Token-budgeted context assembly:**
```
CRITICAL (unlimited): System identity, active tools
HIGH     (40%):       Recent conversation turns, current task state
MEDIUM   (30%):       Relevant memories (keyword-searched)
LOW      (remaining): Workflow context, environmental info
```

**Three-zone compression:** HOT (last 10 msgs, full fidelity) → WARM (progressive compression) → COLD (key facts only).

---

## Channels

| Channel | Status | Notes |
|---------|--------|-------|
| **CLI** | Active | Built-in terminal |
| **Rust TUI** | Active | Full UI — onboarding, model picker, sessions, command palette |
| **HTTP/REST** | Active | API on port 8089, SSE streaming, JWT auth |
| **Telegram** | Active | Long-polling, typing indicators, markdown conversion |
| **Discord** | Active | Webhook mode, token validation |
| **Slack** | Active | Webhook + HMAC-SHA256 verification |

---

## Install

### From Source

```bash
git clone https://github.com/Miosa-osa/OSA.git
cd OSA
mix deps.get
mix ecto.setup
mix osa.serve
```

**TUI (separate terminal):**

```bash
cd priv/rust/tui
cargo run
```

Requires Elixir 1.17+, Erlang/OTP 27+, Rust/Cargo (for TUI).

### Docker

```bash
docker compose up -d
```

---

## Quick Start

| Command | What it does |
|---------|-------------|
| `mix osa.serve` | Start the backend API server |
| `mix osa.chat` | Backend + built-in CLI (no TUI) |
| `cd priv/rust/tui && cargo run` | Rust TUI (connects to running backend) |
| `cd desktop && npm run tauri:dev` | Desktop GUI (experimental) |

**First time?** The TUI launches a 7-step setup wizard — pick your provider, enter keys, name yourself and your agent. Config saves to `~/.osa/.env` and never asks again.

---

## Configuration

All config lives in `~/.osa/.env`, generated by the setup wizard.

```bash
# Example ~/.osa/.env
OSA_DEFAULT_PROVIDER=ollama
OLLAMA_URL=http://localhost:11434
OLLAMA_MODEL=nemotron-3-super
OSA_USER_NAME=Roberto
OSA_AGENT_NAME=OSA
```

**Workspace directory:** `~/.osa/`

```
~/.osa/
├── .env            # Provider config (generated by wizard)
├── IDENTITY.md     # Agent personality
├── USER.md         # User profile
├── SOUL.md         # Agent soul/values
├── HEARTBEAT.md    # Scheduled checklist
├── BOOTSTRAP.md    # First-conversation script (auto-deleted)
├── skills/         # Custom skill definitions
├── CRONS.json      # Cron jobs
└── TRIGGERS.json   # Event-driven triggers
```

---

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                     Channels                         │
│  CLI │ TUI │ HTTP │ Telegram │ Discord │ Slack       │
└──────────────────────┬──────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────┐
│          Signal Classifier (LLM-primary)             │
│    S = (Mode, Genre, Type, Format, Weight)           │
│    ETS cache │ Deterministic fallback                │
└──────────────────────┬──────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────┐
│         Two-Tier Noise Filter                        │
│    Tier 1: <1ms regex │ Tier 2: weight thresholds    │
└──────────────────────┬──────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────┐
│       Events.Bus (goldrush-compiled bytecode)        │
│       PubSub fan-out │ DLQ │ Circuit breakers        │
└──┬──────────┬─────────┬─────────┬───────────────────┘
   │          │         │         │
┌──▼───┐ ┌───▼────┐ ┌──▼────┐ ┌──▼──────────┐
│Agent │ │Orchest-│ │ Swarm │ │  Scheduler  │
│Loop  │ │rator  │ │       │ │  Cron +     │
│      │ │       │ │4 modes│ │  Heartbeat  │
│ReAct │ │Sub-   │ │       │ │             │
│cycle │ │agents │ │Teams  │ │             │
└──┬───┘ └───┬───┘ └──┬───┘ └─────────────┘
   │         │        │
 ┌─▼─────────▼────────▼──────────────────────────────┐
 │           Shared Infrastructure                     │
 │  Context Builder (token-budgeted, 4-tier priority) │
 │  Compactor (3-zone sliding window)                  │
 │  Memory (SQLite + ETS + episodic)                   │
 │  Skills Registry (hot-reload)                       │
 │  Budget Tracker (per-provider costs)                │
 │  Soul (IDENTITY + USER + SOUL interpolation)        │
 └────────────────────────────────────────────────────┘
      │          │          │          │
 ┌────▼────┐ ┌──▼─────┐ ┌──▼────┐ ┌──▼──────┐
 │7 LLM   │ │25 Tools│ │Memory │ │  OS     │
 │Providers│ │        │ │SQLite │ │Templates│
 └─────────┘ └────────┘ └───────┘ └─────────┘
```

---

## Project Structure

```
lib/optimal_system_agent/
  agent/            # ReAct loop, context, memory, strategies, guardrails
  channels/         # CLI, HTTP API, Telegram, Discord, Slack
  events/           # Bus, PubSub bridge, DLQ, failure modes
  providers/        # Ollama, Anthropic, OpenAI-compat, router
  tools/            # 25 built-in tools, registry, schema validation
  memory/           # Store (SQLite + ETS), SICA patterns, skill generator
  swarm/            # Parallel, pipeline, debate, review loop
  budget/           # Per-provider token cost tracking
  signal/           # Signal classification, noise filter
  store/            # Ecto repo, schemas, migrations
  supervisors/      # OTP supervision trees

priv/
  rust/tui/         # Rust TUI (ratatui + crossterm)
  prompts/          # System prompt templates
  agents/           # Agent role definitions
  skills/           # Built-in skills
  swarms/           # Swarm pattern presets

desktop/            # Tauri 2 + SvelteKit 5 (experimental)
```

---

## Adding Custom Skills

Drop a markdown file in `~/.osa/skills/your-skill/SKILL.md`:

```markdown
---
name: data-analyzer
description: Analyze datasets and produce insights
tools:
  - file_read
  - shell_execute
---

## Instructions

When asked to analyze data:
1. Read the file to understand its structure
2. Use shell commands to run analysis
3. Produce a summary with key findings
```

Available immediately — no restart, no rebuild.

---

## What's In Progress

| Area | Status | Notes |
|------|--------|-------|
| Events/Signal tests | Aligning | Core rewritten, tests being updated |
| Agent strategy tests | Evaluating | Mixed test failures under review |
| Swarm HTTP routing | Partial | Works via agent `delegate` tool, HTTP endpoint needs wiring |
| Permission system | Wiring | TUI UI done, backend endpoint pending |
| Sandbox isolation | Not started | Docker/Wasm backends planned |
| Additional channels | Planned | WhatsApp, Signal, Matrix, Email |
| Vault (structured memory) | Planned | 8-category typed memory with fact extraction |

---

## Tests

```bash
mix test                    # Full suite (1730 tests)
mix test test/tools/        # Tool tests only
mix test test/providers/    # Provider tests only
```

---

## Theoretical Foundation

OSA is grounded in four principles from communication and systems theory:

1. **Shannon (Channel Capacity):** Match compute to complexity — don't burn your best model on trivial tasks.
2. **Ashby (Requisite Variety):** The system must match the variety of its inputs.
3. **Beer (Viable System Model):** Five operational modes mirror the five subsystems every viable organization needs.
4. **Wiener (Feedback Loops):** Every action produces feedback. The agent learns across sessions.

**Research:** [Signal Theory: The Architecture of Optimal Intent Encoding](https://zenodo.org/records/18774174) (Luna, 2026)

---

## MIOSA Ecosystem

OSA is the intelligence layer of the MIOSA platform:

| Setup | What You Get |
|-------|-------------|
| **OSA standalone** | Full AI agent in your terminal |
| **OSA + BusinessOS** | Proactive business assistant with CRM, scheduling, revenue alerts |
| **OSA + Custom Template** | Build your own OS template. OSA handles the intelligence. |
| **MIOSA Cloud** | Managed instances with enterprise governance |

[miosa.ai](https://miosa.ai)

---

## Team

Built by [Roberto H. Luna](https://github.com/robertohluna) and the [MIOSA](https://miosa.ai) team.

## Contributing

We prefer **skills over code changes.** Write a SKILL.md, share it with the community. See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

Apache 2.0 — See [LICENSE](LICENSE).

---

Built by [MIOSA](https://miosa.ai). Grounded in [Signal Theory](https://zenodo.org/records/18774174). Powered by the BEAM.
