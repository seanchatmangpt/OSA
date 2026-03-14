# Sprint: Competitive Integration — Master Context

> **Sprint Goal:** Reverse-engineer ClawX + Paperclip, translate their best patterns into OSA's Elixir/OTP + SvelteKit stack, and ship 8 workstreams that close every feature gap.

---

## Intelligence Sources

### ClawX (ValueCell-ai/ClawX)
- **What:** Desktop GUI for OpenClaw AI agents (Electron + React 19 + Zustand)
- **Stack:** TypeScript, Radix UI + Tailwind, Electron IPC, Gateway WebSocket RPC
- **Key Patterns Stolen:**
  - Multi-transport API client (IPC → WS → HTTP fallback with retry + backoff)
  - Cron scheduling UI with 8 presets + custom expression + human-readable preview
  - Session isolation per agent (`agent:{id}:session-type` keying)
  - Debounced gateway restarts (8s coalescing window)
  - Skill marketplace (ClawHub) with install/uninstall/enable/disable
  - Graceful degradation (app works without gateway)
  - Chronological session grouping (Today, Yesterday, Last Week)
  - Hover-activated action buttons (reduce visual clutter)

### Paperclip (paperclipai/paperclip)
- **What:** Control plane for zero-human companies (Express + React 19 + PostgreSQL)
- **Stack:** TypeScript, TanStack Query, Radix UI + Tailwind 4, Drizzle ORM, Better Auth
- **Key Patterns Stolen:**
  - Company-scoped data isolation (every query includes company access check)
  - Heartbeat execution model (schedule → wake → execute → capture → persist)
  - Atomic task checkout (409 Conflict prevents double-assignment)
  - Per-agent + company budget enforcement with auto-pause
  - Config revision tracking with rollback capability
  - Approval gates (hiring, strategy, budget changes need board approval)
  - `reportsTo` org tree with drag-drop restructuring
  - Kanban board with drag-drop status transitions
  - Immutable activity audit trail
  - Persistent agent state across heartbeats (session codec)
  - Cost tracking per agent per task with utilization percentage
  - Live event streaming via WebSocket (heartbeat events, task changes)
  - Workspace isolation (git worktree strategy for parallel agent work)

---

## OSA Foundation (What We Already Have)

### Backend (Elixir/OTP)
| Module | Location | Lines | What It Does |
|--------|----------|-------|-------------|
| Agent Loop | `lib/optimal_system_agent/agent/loop.ex` | 51,956 | ReAct loop (think → act → observe) |
| Orchestrator | `lib/optimal_system_agent/agent/orchestrator.ex` | 31,772 | Multi-agent decomposition |
| Signal Classifier | `lib/optimal_system_agent/signal/classifier.ex` | 9,067 | 5-tuple classification (Mode/Genre/Type/Format/Weight) |
| Scheduler | `lib/optimal_system_agent/agent/scheduler.ex` | + cron_engine, heartbeat, job_executor, persistence, sqlite_store | Cron + HEARTBEAT.md + TRIGGERS.json |
| Treasury | `lib/optimal_system_agent/agent/treasury.ex` | — | Budget enforcement ($250/day, $2500/month) |
| Tasks | `lib/optimal_system_agent/agent/tasks/` | workflow.ex (20.6KB), tracker.ex (13.8KB), queue.ex (13KB) | Task decomposition + tracking + persistent queue |
| Tools Registry | `lib/optimal_system_agent/tools/registry.ex` | 38,555 | Tool discovery, validation, execution |
| 32 Agents | `lib/optimal_system_agent/agents/` | — | Elite + specialist + utility tiers |
| Swarm | `lib/optimal_system_agent/swarm/` | 8 modules | PACT framework, patterns, coordination |
| Fleet | `lib/optimal_system_agent/fleet/` | — | Distributed agent management |
| Vault | `lib/optimal_system_agent/vault/` | 12 modules | Memory, fact store, session lifecycle |
| Intelligence | `lib/optimal_system_agent/intelligence/` | 5 modules | Proactive monitor, contact detector |

### Frontend (Tauri + SvelteKit)
| Page | Location | Status |
|------|----------|--------|
| Dashboard | `desktop/src/routes/app/+page.svelte` | EXISTS |
| Activity | `desktop/src/routes/app/activity/+page.svelte` | EXISTS |
| Agents | `desktop/src/routes/app/agents/+page.svelte` | EXISTS |
| Tasks | `desktop/src/routes/app/tasks/+page.svelte` | EXISTS (14.5KB) |
| Memory | `desktop/src/routes/app/memory/+page.svelte` | EXISTS |
| Models | `desktop/src/routes/app/models/+page.svelte` | EXISTS |
| Usage | `desktop/src/routes/app/usage/+page.svelte` | EXISTS |
| Settings | `desktop/src/routes/app/settings/+page.svelte` | EXISTS |
| Terminal | `desktop/src/routes/app/terminal/+page.svelte` | EXISTS |
| Connectors | `desktop/src/routes/app/connectors/+page.svelte` | EXISTS |
| Chat | `desktop/src/routes/chat/+page.svelte` | EXISTS |
| **Signals** | — | **MISSING — WS1** |
| **Approvals** | — | **MISSING — WS6** |

### Design System
- CSS custom properties (NOT Tailwind — keep ours)
- Dark mode default with semantic tokens
- Variables: `--bg-primary`, `--bg-secondary`, `--text-primary`, `--text-secondary`, `--text-tertiary`, `--text-muted`
- Radii: `--radius-sm`, `--radius-md`, `--radius-full`
- Button variants: `--primary`, `--secondary`, `--danger`, `--icon`

### API
- Base: `http://localhost:9089/api/v1`
- Auth: JWT HS256 Bearer token
- Streaming: SSE via `/api/v1/stream/:session_id`
- Client: `desktop/src/lib/api/client.ts`

---

## Architecture Translation Rules

When translating from ClawX/Paperclip patterns:

| They Use | We Use | Notes |
|----------|--------|-------|
| React 19 | Svelte 5 | Runes ($state, $derived, $effect) |
| Zustand / TanStack Query | Svelte stores (.svelte.ts) | Reactive by default |
| Radix UI + Tailwind | CSS custom properties | Keep our design system |
| Electron IPC | Tauri Commands/Events | Already have this |
| Express.js routes | Plug routes | Already have this |
| Drizzle ORM + PostgreSQL | Ecto + SQLite/PostgreSQL | Already have both |
| WebSocket live events | Phoenix.PubSub + SSE | Already better |
| Better Auth | JWT HS256 | Already have this |

---

## File Path Quick Reference

```
Backend Core:     OSA/lib/optimal_system_agent/
Frontend Core:    OSA/desktop/src/
Routes:           OSA/desktop/src/routes/app/
Stores:           OSA/desktop/src/lib/stores/
Components:       OSA/desktop/src/lib/components/
API Client:       OSA/desktop/src/lib/api/
API Routes:       OSA/lib/optimal_system_agent/channels/http/api/
Agents:           OSA/lib/optimal_system_agent/agents/
Signal:           OSA/lib/optimal_system_agent/signal/
Scheduler:        OSA/lib/optimal_system_agent/agent/scheduler.ex
Treasury:         OSA/lib/optimal_system_agent/agent/treasury.ex
Tasks:            OSA/lib/optimal_system_agent/agent/tasks/
Config:           OSA/config/
Mix:              OSA/mix.exs
Package:          OSA/desktop/package.json
```

---

## Sprint Wave Structure

```
WAVE 1 (Foundation — parallel, no deps):
  Agent-A: BACKEND-SIGNALS    → WS1 backend (signal persistence + API routes)
  Agent-B: FRONTEND-SIGNALS   → WS1 frontend (Signals page + components)
  Agent-C: BACKEND-SCHEDULER  → WS2 backend (enhanced scheduler + heartbeat execution)
  Agent-D: FRONTEND-SCHEDULER → WS2 frontend (cron UI + execution output)

WAVE 2 (Budget + Hierarchy — depends on WS1/WS2 patterns):
  Agent-E: BUDGET-SYSTEM      → WS3 (cost tracking + budget enforcement)
  Agent-F: AGENT-HIERARCHY    → WS4 (org tree + reportsTo + delegation)

WAVE 3 (Advanced UI — depends on WS1/WS2 frontend patterns):
  Agent-G: KANBAN-APPROVALS   → WS5 + WS6 (kanban board + approval workflow)

WAVE 4 (Resilience — depends on all above):
  Agent-H: CONFIG-RESILIENCE  → WS7 + WS8 (config versioning + multi-transport)
```

---

## Build & Verify Commands

```bash
# Backend
cd /Users/roberto/Desktop/OSAMain/OSA
mix compile --warnings-as-errors
mix test

# Frontend
cd /Users/roberto/Desktop/OSAMain/OSA/desktop
npm run check
npm run build

# Full verification
mix compile --warnings-as-errors && mix test && cd desktop && npm run check && npm run build
```

---

## Quality Gates (Every Workstream)

1. Code compiles with zero warnings
2. All existing tests pass
3. New tests written for new modules (80%+ coverage target)
4. No regressions in existing functionality
5. SSE integration verified (signals flow from backend → frontend)
6. Design system tokens used (no hardcoded colors/spacing)
7. TypeScript strict mode passes
8. No `any` types introduced
