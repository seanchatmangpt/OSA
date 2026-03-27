# OSA — Agent Definitions

> **Multi-agent orchestration with Signal Theory and intelligent routing.**
>
> AGI-level connections: Signal Theory provider routing, YAWL orchestration patterns.

---

## ═══════════════════════════════════════════════════════════════════════════════
# 🤖 OSA AGENT ECOSYSTEM
# ═══════════════════════════════════════════════════════════════════════════════

**Agent Knowledge Base**: All agents have access to:
- **Signal Theory** S=(M,G,T,F,W) for provider routing
- **YAWL 43 patterns** for orchestration
- **7-Layer Architecture** (layers 2-7)
- **18 LLM providers** with capability mapping
- **12 chat channels** with format requirements

---

## TIER 1: ORCHESTRATION AGENTS

### @osa-architect

**Purpose**: OSA system design and architecture

**Signal Encoding**: `S=(linguistic, spec, commit, markdown, adr-template)`

**Use When**:
- OSA architecture decisions
- Provider routing design
- Multi-agent orchestration patterns
- Integration with Canopy/BusinessOS

**Knowledge**:
- **OSA architecture**: Elixir/OTP + Rust TUI + Tauri/SvelteKit desktop
- **Signal routing**: S=(M,G,T,F,W) classification for provider selection
- **Agent loop**: ReAct pattern (think → act → observe → repeat)
- **Provider capabilities**: 18 LLM providers with model mappings
- **Orchestration patterns**: Fleet, delegation, swarm mode

**Outputs**:
- ADRs for architectural decisions
- Provider routing specifications
- Orchestration pattern documentation

---

### @osa-orchestrator

**Purpose**: Multi-agent coordination in OSA

**Signal Encoding**: `S=(linguistic, plan, direct, markdown, orchestration-plan)`

**Use When**:
- Multi-agent fleet coordination
- Provider selection and fallback
- Complex task decomposition
- Swarm mode activation

**Knowledge**:
- **Agent roster**: All available agents
- **Provider routing**: Signal-based provider selection
- **Fallback chains**: Primary → secondary → tertiary providers
- **Fleet coordination**: Parallel agent execution
- **Delegation patterns**: Task decomposition and assignment

**Orchestration Pattern**:
```
1. Receive user message
2. Classify signal S=(M,G,T,F,W)
3. Select providers based on signal
4. Decompose task if complex
5. Dispatch agents (parallel or sequential)
6. Synthesize results
7. Apply quality gates
```

---

## TIER 2: PROVIDER AGENTS

### @osa-provider-anthropic

**Purpose**: Anthropic Claude provider integration

**Signal Encoding**: `S=(linguistic, chat, direct, markdown, conversation)`

**Use When**:
- Using Claude models (Opus, Sonnet, Haiku)
- Anthropic API integration
- Claude-specific features

**Knowledge**:
- **Models**: Claude Opus 4.6 (planning), Sonnet 4.6 (execution), Haiku (utility)
- **API**: Anthropic API, streaming, tool use
- **Pricing**: Token costs, optimal selection
- **Capabilities**: Vision, long context, tool use

**Signal-based Selection**:
```
S=(linguistic, spec, commit, markdown, adr-template)
  → Use Opus (complex reasoning)

S=(linguistic, chat, direct, markdown, conversation)
  → Use Sonnet (balanced)

S=(linguistic, inform, markdown, markdown, summary)
  → Use Haiku (fast, cheap)
```

---

### @osa-provider-openai

**Purpose**: OpenAI GPT provider integration

**Signal Encoding**: `S=(linguistic, chat, direct, json, openai-format)`

**Use When**:
- Using GPT models
- OpenAI API integration
- GPT-specific features

**Knowledge**:
- **Models**: GPT-4, GPT-4 Turbo, GPT-3.5
- **API**: OpenAI API, function calling
- **Pricing**: Token costs
- **Capabilities**: Function calling, vision, plugins

---

### @osa-provider-groq

**Purpose**: Groq provider integration (fast inference)

**Signal Encoding**: `S=(linguistic, chat, direct, markdown, conversation)`

**Use When**:
- Fast inference needed
- Cost-sensitive operations
- Groq API integration

**Knowledge**:
- **Models**: Llama, Mixtral on Groq
- **Speed**: Ultra-fast inference
- **Pricing**: Very low cost
- **Use case**: Quick responses, simple tasks

---

### @osa-provider-ollama

**Purpose**: Ollama local LLM provider

**Signal Encoding**: `S=(linguistic, chat, direct, markdown, conversation)`

**Use When**:
- Using local models
- Privacy-sensitive operations
- Ollama integration

**Knowledge**:
- **Models**: Qwen, Llama, Mistral (local)
- **API**: Ollama local server
- **Privacy**: No data leaves local machine
- **Cost**: Free (compute costs only)

---

## TIER 2: CHANNEL AGENTS

### @osa-channel-cli

**Purpose**: CLI channel implementation

**Signal Encoding**: `S=(linguistic, message, direct, terminal, cli-format)`

**Use When**:
- Terminal interaction
- CLI command execution
- TUI integration

**Knowledge**:
- **Format**: Terminal output, ANSI codes
- **Interaction**: Command line interface
- **TUI**: Rust TUI integration

---

### @osa-channel-http

**Purpose**: HTTP/WebSocket channel

**Signal Encoding**: `S=(linguistic, message, direct, json, http-format)`

**Use When**:
- HTTP API endpoints
- WebSocket connections
- Web integration

**Knowledge**:
- **API**: REST endpoints, WebSocket
- **Format**: JSON messages
- **Streaming**: SSE for real-time

---

### @osa-channel-telegram

**Purpose**: Telegram bot integration

**Signal Encoding**: `S=(linguistic, message, direct, telegram, telegram-format)`

**Use When**:
- Telegram bot commands
- Telegram message handling
- Bot API integration

**Knowledge**:
- **Telegram Bot API**: Message format, commands
- **Formatting**: Markdown, HTML support
- **Interactions**: Buttons, inline keyboards

---

## TIER 2: TOOL AGENTS

### @osa-tool-file

**Purpose**: File system operations

**Signal Encoding**: `S=(code, implementation, direct, elixir, file-operation)`

**Use When**:
- File reading/writing
- Directory operations
- File system management

**Knowledge**:
- **Operations**: read, write, list, delete
- **Sandboxing**: Permission checks
- **Error handling**: File not found, permission denied

---

### @osa-tool-shell

**Purpose**: Shell command execution

**Signal Encoding**: `S=(code, execution, direct, elixir, shell-command)`

**Use When**:
- Running shell commands
- System operations
- Command output capture

**Knowledge**:
- **Commands**: Bash, sh, PowerShell
- **Sandboxing**: Docker containers
- **Output**: stdout, stderr, exit codes

---

### @osa-tool-git

**Purpose**: Git operations

**Signal Encoding**: `S=(code, implementation, direct, elixir, git-operation)`

**Use When**:
- Git commands
- Repository operations
- Version control

**Knowledge**:
- **Commands**: clone, pull, push, status, commit
- **Branching**: create, switch, merge
- **Status**: working tree, commits

---

### @osa-tool-web

**Purpose**: Web requests and scraping

**Signal Encoding**: `S=(data, result, inform, json, web-response)`

**Use When**:
- HTTP requests
- Web scraping
- API calls

**Knowledge**:
- **HTTP**: GET, POST, PUT, DELETE
- **Headers**: User agents, authentication
- **Parsing**: HTML, JSON extraction

---

### @osa-tool-memory

**Purpose**: Memory operations

**Signal Encoding**: `S=(linguistic, inform, commit, markdown, memory-record)`

**Use When**:
- Storing information
- Retrieving memories
- Knowledge base operations

**Knowledge**:
- **Memory layers**: 5-layer memory system
- **Storage**: Persistent memory
- **Retrieval**: Search, recall

---

## TIER 3: SPECIALIZED AGENTS

### @osa-signal-router

**Purpose**: Signal Theory-based routing

**Signal Encoding**: `S=(linguistic, classification, decide, json, routing-decision)`

**Use When**:
- Classifying signals S=(M,G,T,F,W)
- Provider selection
- Model selection

**Knowledge**:
- **Signal Theory**: Complete S=(M,G,T,F,W) classification
- **Provider capabilities**: Which providers support which signals
- **Cost optimization**: Use cheapest provider that meets requirements
- **Quality gates**: S/N thresholds

**Routing Logic**:
```
Input: User message
  ↓
Classify: S=(M,G,T,F,W)
  ↓
Select provider:
  - Mode: visual → Use vision-capable provider
  - Genre: spec → Use reasoning model (Opus)
  - Type: direct → Use fast model (Haiku/Groq)
  - Format: code → Use code-capable provider
  - Structure: specific → Use provider with template support
  ↓
Fallback chain: Primary → Secondary → Tertiary
```

---

### @osa-multi-agent-fleet

**Purpose**: Fleet coordination (parallel agents)

**Signal Encoding**: `S=(linguistic, plan, direct, markdown, fleet-plan)`

**Use When**:
- Running multiple agents in parallel
- Coordinating fleet operations
- Synthesizing agent results

**Knowledge**:
- **YAWL patterns**: Parallel split, synchronization
- **Agent dispatch**: Send tasks to multiple agents
- **Result synthesis**: Combine agent outputs
- **Conflict resolution**: Handle disagreements

**Fleet Pattern**:
```
┌─────────────────────────────────────────────────────────────┐
│ FLEET COORDINATOR                                           │
├─────────────────────────────────────────────────────────────┤
│ 1. Receive task                                             │
│ 2. Decompose into subtasks                                  │
│ 3. Dispatch to agents (parallel):                           │
│    ├─ Agent A: Subtask 1                                   │
│    ├─ Agent B: Subtask 2                                   │
│    └─ Agent C: Subtask 3                                   │
│ 4. Wait for all agents (YAWL synchronization)               │
│ 5. Synthesize results                                      │
│ 6. Apply quality gates                                     │
└─────────────────────────────────────────────────────────────┘
```

---

### @osa-delegation-agent

**Purpose**: Task decomposition and delegation

**Signal Encoding**: `S=(linguistic, plan, direct, markdown, delegation-plan)`

**Use When**:
- Complex task decomposition
- Breaking down user requests
- Assigning subtasks to agents

**Knowledge**:
- **Task analysis**: Understand user intent
- **Decomposition**: Break into manageable subtasks
- **Agent selection**: Match subtasks to agent capabilities
- **Dependencies**: Identify sequential vs parallel execution

**Delegation Pattern**:
```
User request: "Build a web scraper for X"
  ↓
Decompose:
  1. Design scraper architecture
  2. Implement scraping logic
  3. Add error handling
  4. Write tests
  5. Deploy
  ↓
Delegate:
  → @architect: Design (1)
  → @backend-go: Implement (2, 3)
  → @test-automator: Tests (4)
  → @devops-engineer: Deploy (5)
```

---

## ═══════════════════════════════════════════════════════════════════════════════
# YAWL INTEGRATION TOOLS
# ═══════════════════════════════════════════════════════════════════════════════

> These four tools expose a live YAWL 6 engine (yawlv6) to OSA agents.
> They chain together: `yawl_spec_library → yawl_workflow → yawl_work_item → yawl_process_mining`

### `yawl_spec_library`

**Purpose**: Browse and load YAWL workflow specifications

**Operations**:
- `list_patterns` — Returns all 43 WCP workflow control patterns with metadata
- `get_pattern` — Fetch a named WCP pattern spec (e.g. `WCP-1-Sequence`, `WCP-17-MI-DAT`)
- `list_specs` — List real-data specs from `~/yawlv6/exampleSpecs/`
- `load_spec` — Read a `.yawl` spec file by name or path

**Config**:
- No network required — reads local `~/yawlv6/exampleSpecs/` directory

**Use When**:
- Selecting a workflow pattern before launching a case
- Inspecting available specs for a given domain
- Loading spec XML to upload via `yawl_workflow`

---

### `yawl_workflow`

**Purpose**: Upload specs, launch cases, and manage running workflows via YAWL Interface A

**Operations**:
- `upload_spec` — POST a `.yawl` spec to the engine (returns spec ID)
- `launch_case` — Start a new case for a loaded spec (returns case ID)
- `cancel_case` — Terminate a running case by case ID
- `list_cases` — List all active cases (optionally filtered by spec ID)
- `get_case` — Fetch current state and data for a running case

**Config**:
- `YAWL_ENGINE_URL` — YAWL engine base URL (default: `http://localhost:8080`)

**Use When**:
- Starting an orchestrated workflow from a YAWL spec
- Monitoring or cancelling running workflow instances
- Chaining: load spec with `yawl_spec_library`, then call `upload_spec` + `launch_case`

---

### `yawl_work_item`

**Purpose**: Checkout and complete YAWL work items via Interface B

**Operations**:
- `list_enabled` — List all enabled (available) work items across active cases
- `checkout` — Check out a work item (moves to executing, returns item data)
- `checkin` — Complete a work item, submitting output data (advances the workflow)
- `get_item` — Fetch details and current data for a specific work item
- `suspend` — Suspend a checked-out item (returns to enabled pool)

**Config**:
- `YAWL_ENGINE_URL` — YAWL engine base URL (default: `http://localhost:8080`)

**Use When**:
- An OSA agent needs to perform a task step in a running YAWL workflow
- Implementing human-in-the-loop patterns (agent acts as a resource)
- Chaining: after `yawl_workflow` launches a case, poll `list_enabled` then `checkout`/`checkin`

---

### @osa-process-mining

**Purpose**: YAWL-integrated process mining, discovery, and conformance checking

**Signal Encoding**: `S=(data, result, inform, json, process-mining-report)`

**Use When**:
- Discovering process models from event logs
- Conformance checking against YAWL specs
- Computing case/variant/performance statistics
- Feeding XES event data into pm4py-rust

**Knowledge**:
- **XES extraction**: Pulls event logs directly from running YAWL engine
- **pm4py-rust**: Forwards XES to pm4py-rust service for discovery/conformance/stats
- **Discovery algorithms**: Alpha Miner, Heuristics Miner, Inductive Miner (via pm4py-rust)
- **Conformance**: Token-based replay and alignments against YAWL Petri net semantics
- **WCP patterns**: Knows all 43 patterns; annotates mined models with pattern labels

**Tool**: `yawl_process_mining`

**Operations**:
- `pull_xes` — Extract XES event log from YAWL engine for a given spec or case range
- `discover` — Run process discovery (returns BPMN/Petri net + WCP pattern annotations)
- `conformance` — Replay log against YAWL spec; returns fitness/precision scores
- `stats` — Case frequency, variant distribution, median throughput time

**Config**:
- `YAWL_ENGINE_URL` — YAWL engine base URL (default: `http://localhost:8080`)

**Chain Position**: Used downstream of `yawl_workflow` after cases complete

---

### @osa-quality-gate

**Purpose**: S/N quality enforcement

**Signal Encoding**: `S=(linguistic, decision, decide, markdown, quality-report)`

**Use When**:
- Validating agent outputs
- Enforcing S/N thresholds
- Rejecting low-quality outputs

**Knowledge**:
- **Signal Theory**: Complete S=(M,G,T,F,W) theory
- **S/N scoring**: Python implementation in `docs/superpowers/implementation/signal-theory/sn_scorer.py`
- **Four constraints**: Shannon, Ashby, Beer, Wiener
- **Quality thresholds**: S/N ≥ 0.7 required for all agent outputs

**Quality Gate Logic**:
```
Agent produces output
  ↓
┌─────────────────────┐
│ S/N Scorer          │
│                     │
│ Check:              │
│ 1. All 5 dimensions │ ← Any unresolved? REJECT
│ 2. No filler        │ ← Filler detected? REJECT
│ 3. Genre matches    │ ← Wrong genre? REJECT
│ 4. Shannon check    │ ← Bandwidth overflow? REJECT
│ 5. Structure present│ ← No structure? REJECT
└──────────┬──────────┘
           │
     SCORE ≥ threshold      SCORE < threshold
           │                         │
           ▼                         ▼
     TRANSMIT                  REJECTION NOTICE
     to receiver               returned to agent
```

---

## ═══════════════════════════════════════════════════════════════════════════════
# AGENT DISPATCH RULES
# ═══════════════════════════════════════════════════════════════════════════════

## Auto-Dispatch by Provider

```
"Claude", "Anthropic", "Opus", "Sonnet", "Haiku"
  → @osa-provider-anthropic

"GPT", "OpenAI", "GPT-4"
  → @osa-provider-openai

"Groq", "fast", "cheap"
  → @osa-provider-groq

"Ollama", "local", "privacy"
  → @osa-provider-ollama
```

## Auto-Dispatch by Channel

```
"CLI", "terminal", "command line"
  → @osa-channel-cli

"HTTP", "WebSocket", "web", "API"
  → @osa-channel-http

"Telegram", "bot"
  → @osa-channel-telegram
```

## Auto-Dispatch by Tool

```
"file", "read file", "write file"
  → @osa-tool-file

"shell", "command", "execute"
  → @osa-tool-shell

"git", "commit", "push"
  → @osa-tool-git

"web", "HTTP", "scrape"
  → @osa-tool-web

"memory", "store", "remember"
  → @osa-tool-memory
```

## Auto-Dispatch by Task Type

```
"route", "classify signal", "provider selection"
  → @osa-signal-router

"fleet", "parallel agents", "coordinate"
  → @osa-multi-agent-fleet

"delegate", "break down", "decompose"
  → @osa-delegation-agent

"quality", "S/N", "validate", "check"
  → @osa-quality-gate
```

## Auto-Dispatch by YAWL Tool

```
"YAWL spec", "WCP pattern", "workflow spec", "example spec"
  → yawl_spec_library

"launch case", "upload spec", "cancel case", "list cases"
  → yawl_workflow

"work item", "checkout", "checkin", "enabled items"
  → yawl_work_item

"process mining", "XES", "discover process", "conformance"
  → yawl_process_mining
```

**YAWL Tool Chain** (typical end-to-end flow):
```
1. yawl_spec_library.list_patterns     → choose WCP pattern
2. yawl_spec_library.load_spec         → get spec XML
3. yawl_workflow.upload_spec           → register with engine → spec_id
4. yawl_workflow.launch_case           → start instance → case_id
5. yawl_work_item.list_enabled         → find available work items
6. yawl_work_item.checkout / checkin   → agent performs work steps
7. yawl_process_mining.pull_xes        → extract completed event log
8. yawl_process_mining.discover        → mine process model + WCP annotations
9. yawl_process_mining.conformance     → fitness/precision vs. original spec
```

---

## ═══════════════════════════════════════════════════════════════════════════════
# CROSS-PROJECT KNOWLEDGE
# ═══════════════════════════════════════════════════════════════════════════════

## Shared with Canopy

- **Signal Theory**: Same S=(M,G,T,F,W) encoding
- **YAWL patterns**: Orchestration coordination
- **Quality gates**: S/N scoring
- **Elixir/OTP**: Backend patterns

## Shared with BusinessOS

- **Multi-agent coordination**: Fleet patterns
- **Provider routing**: Signal-based selection
- **Desktop integration**: Terminal, UI components

## Unique to OSA

- **18 LLM providers**: Complete provider coverage
- **12 chat channels**: All major platforms
- **Signal routing**: S=(M,G,T,F,W) for provider selection
- **Agent loop**: ReAct pattern implementation
- **SORX engine**: Skill execution

---

## ═══════════════════════════════════════════════════════════════════════════════
# QUICK REFERENCE
# ═══════════════════════════════════════════════════════════════════════════════

```
╔══════════════════════════════════════════════════════════════════════════╗
║ OSA AGENT QUICK REFERENCE                                               ║
╠══════════════════════════════════════════════════════════════════════════╣
║                                                                          ║
║ ORCHESTRATION:                                                           ║
║   @osa-architect           → System architecture                         ║
║   @osa-orchestrator        → Multi-agent coordination                    ║
║                                                                          ║
║ PROVIDERS:                                                               ║
║   @osa-provider-anthropic  → Claude (Opus, Sonnet, Haiku)              ║
║   @osa-provider-openai     → GPT-4, GPT-4 Turbo                        ║
║   @osa-provider-groq       → Fast inference (Llama, Mixtral)           ║
║   @osa-provider-ollama     → Local models (Qwen, Llama, Mistral)        ║
║                                                                          ║
║ CHANNELS:                                                                ║
║   @osa-channel-cli         → Terminal/CLI                                ║
║   @osa-channel-http        → HTTP/WebSocket                             ║
║   @osa-channel-telegram    → Telegram bot                               ║
║                                                                          ║
║ TOOLS:                                                                   ║
║   @osa-tool-file           → File operations                            ║
║   @osa-tool-shell          → Shell commands                             ║
║   @osa-tool-git            → Git operations                             ║
║   @osa-tool-web            → Web requests/scraping                      ║
║   @osa-tool-memory         → Memory operations                          ║
║                                                                          ║
║ SPECIALIZED:                                                             ║
║   @osa-signal-router       → Signal-based provider routing              ║
║   @osa-multi-agent-fleet   → Parallel agent coordination                ║
║   @osa-delegation-agent    → Task decomposition                         ║
║   @osa-quality-gate        → S/N quality enforcement                     ║
║                                                                          ║
║ YAWL INTEGRATION TOOLS:                                                  ║
║   yawl_spec_library        → Browse 43 WCP patterns + exampleSpecs      ║
║   yawl_workflow            → Upload specs, launch/cancel/list cases      ║
║   yawl_work_item           → Checkout/checkin work items (Interface B)   ║
║   yawl_process_mining      → XES extraction, discovery, conformance      ║
║                                                                          ║
╚══════════════════════════════════════════════════════════════════════════╝
```

---

*OSA AGENTS.md — Part of the ChatmanGPT Agent Ecosystem*
*Version: 2.0.0 — AGI-Level Cross-Project Integration*
