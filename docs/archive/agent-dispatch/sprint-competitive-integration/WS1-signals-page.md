# WS1: Signals Page — Build Guide

> **Agent:** BACKEND-SIGNALS (Agent-A) + FRONTEND-SIGNALS (Agent-B)
> **Priority:** P0 — This is the crown jewel

---

## Objective

Build a Signals page that surfaces OSA's signal classification engine to the UI. Every signal processed by the system (across all channels) becomes visible, filterable, and queryable. This is OSA's competitive advantage — neither ClawX nor Paperclip has anything like this.

---

## What Already Exists

### Signal Classifier (Backend — DONE)
- **File:** `lib/optimal_system_agent/signal/classifier.ex`
- Produces 5-tuple: `(Mode, Genre, Type, Format, Weight)`
- Modes: `BUILD | EXECUTE | ANALYZE | MAINTAIN | ASSIST`
- Genres: `DIRECT | INFORM | COMMIT | DECIDE | EXPRESS`
- Types: `question | request | issue | scheduling | summary | report | general`
- Formats: `command | message | notification | document`
- Weight: `0.0` (trivial) → `1.0` (critical)
- LLM-based classification with deterministic fallback
- ETS cache with 10-minute TTL (SHA256 key)
- Fires `:signal_classified` event via Bus (goldrush)

### What's Missing
1. **Signal persistence** — classified signals live in memory only, not persisted to DB
2. **Signal history API** — no HTTP routes to query signal history
3. **Signals page** — no frontend page exists
4. **Signal components** — no Svelte components for signal visualization
5. **Signal store** — no Svelte store for signal state

---

## Agent-A: BACKEND-SIGNALS — Build Plan

### Step 1: Signal Persistence Schema

Create Ecto migration for `signals` table:

```elixir
# priv/repo/migrations/XXXXXX_create_signals.exs
create table(:signals) do
  add :session_id, :string
  add :channel, :string          # "cli", "http", "discord", "telegram", etc.
  add :mode, :string             # BUILD, EXECUTE, ANALYZE, MAINTAIN, ASSIST
  add :genre, :string            # DIRECT, INFORM, COMMIT, DECIDE, EXPRESS
  add :type, :string             # question, request, issue, etc.
  add :format, :string           # command, message, notification, document
  add :weight, :float            # 0.0 - 1.0
  add :tier, :string             # haiku, sonnet, opus (derived from weight)
  add :input_preview, :text      # First 200 chars of input (for display)
  add :agent_name, :string       # Which agent handled it
  add :metadata, :map, default: %{}  # Extensible JSON
  timestamps()
end

create index(:signals, [:mode])
create index(:signals, [:weight])
create index(:signals, [:channel])
create index(:signals, [:inserted_at])
```

### Step 2: Signal Persistence Module

```
File: lib/optimal_system_agent/signal/persistence.ex
```

- Subscribe to `:signal_classified` events via Bus
- Write each classified signal to SQLite
- Keep it async (Task.start) so it doesn't block the classifier
- Implement query functions:
  - `list_signals(opts)` — paginated, filterable by mode/genre/type/channel/weight range/date range
  - `signal_stats()` — counts by mode, weight distribution, channel breakdown
  - `recent_signals(limit)` — last N signals
  - `signal_patterns(timeframe)` — aggregate patterns (peak hours, avg weight, top agents)

### Step 3: Signal API Routes

```
File: lib/optimal_system_agent/channels/http/api/signal_routes.ex
```

Endpoints:
- `GET /api/v1/signals` — Paginated signal list with filters
  - Query params: `mode`, `genre`, `type`, `channel`, `weight_min`, `weight_max`, `from`, `to`, `limit`, `offset`
- `GET /api/v1/signals/stats` — Aggregate statistics
- `GET /api/v1/signals/live` — SSE stream of new signals in real-time
- `GET /api/v1/signals/patterns` — Pattern analysis (peak times, trends)

### Step 4: SSE Integration

Add signal events to the existing SSE stream:
- Event type: `signal:new` — emitted on each new classified signal
- Event type: `signal:stats_update` — periodic stats refresh (every 30s)
- Wire into existing `EventStream` registry

### Step 5: Wire Into Router

Add `signal_routes.ex` to the main router in `http.ex`.

### Territory (Agent-A)
```
CAN MODIFY:
  lib/optimal_system_agent/signal/           # Signal system
  lib/optimal_system_agent/channels/http/    # API routes
  lib/optimal_system_agent/channels/http.ex  # Router
  priv/repo/migrations/                       # New migration

CANNOT MODIFY:
  desktop/                                    # Frontend (Agent-B's territory)
  lib/optimal_system_agent/agent/            # Agent loop (too risky)
```

---

## Agent-B: FRONTEND-SIGNALS — Build Plan

### Step 1: Signal Store

```
File: desktop/src/lib/stores/signals.svelte.ts
```

```typescript
// State shape
interface Signal {
  id: string;
  session_id: string;
  channel: string;
  mode: 'BUILD' | 'EXECUTE' | 'ANALYZE' | 'MAINTAIN' | 'ASSIST';
  genre: 'DIRECT' | 'INFORM' | 'COMMIT' | 'DECIDE' | 'EXPRESS';
  type: 'question' | 'request' | 'issue' | 'scheduling' | 'summary' | 'report' | 'general';
  format: 'command' | 'message' | 'notification' | 'document';
  weight: number;
  tier: 'haiku' | 'sonnet' | 'opus';
  input_preview: string;
  agent_name: string;
  metadata: Record<string, unknown>;
  inserted_at: string;
}

interface SignalStats {
  by_mode: Record<string, number>;
  by_channel: Record<string, number>;
  by_type: Record<string, number>;
  weight_distribution: { haiku: number; sonnet: number; opus: number };
  total: number;
  avg_weight: number;
}

interface SignalFilters {
  mode?: string;
  genre?: string;
  type?: string;
  channel?: string;
  weight_min?: number;
  weight_max?: number;
  from?: string;
  to?: string;
}
```

Features:
- Fetch signals with filters (paginated)
- Fetch stats
- Subscribe to SSE for live signal feed
- Derived state for active filters count

### Step 2: Signal Components

```
Directory: desktop/src/lib/components/signals/
```

Components to build:

1. **SignalModeBar.svelte** — Horizontal bar showing mode distribution (BUILD/EXECUTE/ANALYZE/MAINTAIN/ASSIST) with counts. Clicking a mode filters the list.

2. **SignalWeightGauge.svelte** — Three-segment bar showing weight distribution across tiers (Haiku/Sonnet/Opus). Visual indicator of workload complexity.

3. **SignalFeed.svelte** — Live-updating feed of recent signals. Each item shows: weight badge (colored by tier), input preview, mode tag, channel icon, timestamp. Auto-scrolls. SSE-driven.

4. **SignalFilters.svelte** — Filter panel: mode select, type select, channel select, weight range slider, date range picker. Emits filter changes to parent.

5. **SignalCard.svelte** — Individual signal display. Shows all 5-tuple fields, agent name, timestamp, expandable metadata.

6. **SignalChannelBreakdown.svelte** — Bar chart or list showing signals by source channel (CLI, HTTP, Discord, etc.).

7. **SignalPatterns.svelte** — Pattern insights: peak hours, average weight, top agent, escalation count, budget utilization.

8. **SignalTypeBreakdown.svelte** — Distribution of signal types (question, request, issue, etc.).

### Step 3: Signals Page

```
File: desktop/src/routes/app/signals/+page.svelte
```

Layout (reference the wireframe in CONTEXT.md):
```
┌─────────────────────────────────────────────────────────┐
│  SIGNALS                                    [filters ▼] │
│                                                         │
│  [SignalModeBar — 5 mode boxes with counts]             │
│                                                         │
│  ┌──────────────────────┐ ┌────────────────────────────┐│
│  │ [SignalWeightGauge]   │ │ [SignalFeed — live stream] ││
│  │                       │ │                            ││
│  │ [SignalChannelBreak]  │ │                            ││
│  │                       │ │                            ││
│  │ [SignalTypeBreak]     │ │                            ││
│  │                       │ │                            ││
│  │ [SignalPatterns]      │ │                            ││
│  └──────────────────────┘ └────────────────────────────┘│
└─────────────────────────────────────────────────────────┘
```

### Step 4: Navigation Integration

Add "Signals" to the sidebar in `desktop/src/lib/components/layout/Sidebar.svelte`:
- Icon: activity/pulse icon
- Position: after Dashboard, before Activity
- Active state highlighting

### Step 5: SSE Subscription

Connect to the signal SSE endpoint for real-time updates:
- On page mount: subscribe to `/api/v1/signals/live`
- On each `signal:new` event: prepend to feed, update stats
- On page unmount: close SSE connection

### Step 6: Design System Compliance

Use ONLY existing CSS custom properties:
- `--bg-primary`, `--bg-secondary` for backgrounds
- `--text-primary`, `--text-secondary` for text
- `--radius-sm`, `--radius-md` for borders
- Mode colors: define 5 new CSS variables for mode badges (add to existing theme)
- Weight tier colors: green (haiku), amber (sonnet), red (opus)

### Territory (Agent-B)
```
CAN MODIFY:
  desktop/src/routes/app/signals/            # New signals page
  desktop/src/lib/stores/signals.svelte.ts   # New store
  desktop/src/lib/components/signals/        # New components
  desktop/src/lib/components/layout/Sidebar.svelte  # Add nav item
  desktop/src/lib/api/types.ts               # Add signal types
  desktop/src/app.css or global styles       # Add mode/tier color vars

CANNOT MODIFY:
  lib/                                        # Backend (Agent-A's territory)
  desktop/src/lib/components/chat/           # Chat components
  desktop/src/lib/stores/chat.svelte.ts      # Chat store
```

---

## Verification

```bash
# Backend
cd /Users/roberto/Desktop/OSAMain/OSA
mix compile --warnings-as-errors
mix test
# Verify: curl http://localhost:9089/api/v1/signals returns JSON
# Verify: curl http://localhost:9089/api/v1/signals/stats returns stats

# Frontend
cd /Users/roberto/Desktop/OSAMain/OSA/desktop
npm run check
npm run build
# Verify: /app/signals route loads
# Verify: Signals appear in live feed when sending messages via chat
```

---

## Stolen Patterns Applied

| From | Pattern | How We Apply It |
|------|---------|----------------|
| Paperclip | Dashboard KPIs | SignalModeBar + SignalPatterns show live KPIs |
| Paperclip | Live event streaming | SSE signal feed (we already have SSE infra) |
| ClawX | Activity feed with filters | SignalFilters + SignalFeed pattern |
| ClawX | Hover-activated actions | Signal cards expand on hover/click |
| Paperclip | Immutable audit trail | Signals table is append-only history |
