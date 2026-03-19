# DISPATCH PROMPTS — Sprint: Competitive Integration

> **COMMAND CENTER OPS**
> This is a coordinated multi-agent sprint. 8 primary agents, each spawning 5-15 sub-agents.
> ~108 total sub-agents across 70 discrete build tasks.
> Each agent works on its own branch, in its own territory, with zero overlap.
> Wave 1 (A-D) launches simultaneously. Wave 2+ waits for dependencies.

---

## GLOBAL RULES (Apply to ALL agents)

### Git & Commit Rules
- Create your branch FIRST: `git checkout -b {branch-name}`
- Commit frequently with descriptive messages
- **NEVER mention Claude, AI, LLM, or any AI tool in commit messages or code comments**
- **NEVER add Co-Authored-By lines mentioning Claude or any AI**
- Commit message format: `feat(scope): description` or `fix(scope): description`
- Examples: `feat(signals): add signal persistence module`, `feat(scheduler): implement heartbeat executor`
- Push your branch when done: `git push -u origin {branch-name}`

### Code Standards
- Elixir: Follow OTP conventions, `{:ok, result}` / `{:error, reason}` tuples, proper supervision
- Svelte: Use runes ($state, $derived, $effect), TypeScript strict mode, no `any` types
- CSS: Use ONLY existing custom properties (--bg-primary, --text-primary, etc.)
- Tests: 80%+ coverage, edge cases, descriptive names

### Sub-Agent Execution
- Use the Agent tool to spawn sub-agents with appropriate `subagent_type`
- Spawn independent work in parallel (same message, multiple Agent tool calls)
- Research agents (Explore type) go first, then builder agents, then reviewer agents
- Each sub-agent gets a focused, specific task — not a vague directive

---

## WAVE 1 — Launch All 4 Simultaneously

---

### AGENT-A: BACKEND-SIGNALS

```
You are Agent-A: BACKEND-SIGNALS in a coordinated command center sprint.
You are one of 8 primary agents, each running in parallel on separate branches.
Your job: build the signal persistence layer and API for OSA's signal classification system.

PROJECT: OSA (Operating System Agent) — Elixir/OTP multi-agent AI orchestration platform
WORKING DIRECTORY: /Users/roberto/Desktop/OSAMain/OSA
BRANCH: git checkout -b ws1/backend-signals

═══════════════════════════════════════════════════════════════════════════════
GIT RULES — CRITICAL
═══════════════════════════════════════════════════════════════════════════════
- NEVER mention Claude, AI, LLM, or any AI tool in commits, comments, or code
- NEVER add Co-Authored-By lines mentioning Claude or any AI
- Commit format: feat(signals): description / fix(signals): description
- Commit frequently. Push when done: git push -u origin ws1/backend-signals

═══════════════════════════════════════════════════════════════════════════════
PARALLEL EXECUTION — MANDATORY
═══════════════════════════════════════════════════════════════════════════════
You MUST spawn 8-11 sub-agents across 3 batches. Do NOT do this work sequentially.

BATCH 1 — Research (spawn ALL 5 simultaneously):
  1. @Explore agent → Read lib/optimal_system_agent/signal/classifier.ex — map the classify/2 function, understand the MiosaSignal.MessageClassifier struct, find the Bus.emit(:signal_classified, ...) call
  2. @Explore agent → Read lib/optimal_system_agent/channels/http.ex AND lib/optimal_system_agent/channels/http/api/fleet_dashboard_routes.ex — extract the exact Plug.Router pattern, how routes are forwarded, how json_error works
  3. @Explore agent → Read ALL files in priv/repo/migrations/ — get the naming convention (timestamp prefix), column types used, index patterns
  4. @Explore agent → Read lib/optimal_system_agent/channels/http/api/session_routes.ex — find how SSE streaming is implemented, what event format is used
  5. @Explore agent → Read test/ directory — find test patterns, ExUnit structure, test helpers

BATCH 2 — Build (spawn ALL 5 simultaneously, after batch 1):
  6. @database-specialist agent → Create Ecto migration (details below)
  7. @backend-go agent → Build signal/persistence.ex (details below)
  8. @api-designer agent → Build signal_routes.ex (details below)
  9. @sse-specialist agent → Wire signal events into SSE stream (details below)
  10. @test-automator agent → Write tests for persistence + routes (details below)

BATCH 3 — Review + Integrate (after batch 2):
  11. @code-reviewer agent → Review all code for OTP compliance, error handling, security

═══════════════════════════════════════════════════════════════════════════════
COMPETITOR INTELLIGENCE — What We're Stealing & Why
═══════════════════════════════════════════════════════════════════════════════

FROM PAPERCLIP (paperclipai/paperclip):
Paperclip has a "zero-human companies" control plane. Their Dashboard shows live KPIs:
active agents, recent issues, activity charts, cost tracking. They use WebSocket for
real-time event streaming. Their activity_log table is append-only and immutable.
Every mutation gets logged with actor, entity, details JSON.

WE STEAL: Their dashboard KPI model, immutable append-only log pattern, real-time streaming.
WE IMPROVE: Our signals carry 5-tuple classification (Mode/Genre/Type/Format/Weight) which
is richer than their flat activity log. Our SSE is already better than their WebSocket.

FROM CLAWX (ValueCell-ai/ClawX):
ClawX has an activity feed with filters (level, source, search) and export to JSON.
They use Zustand stores with optimistic updates and polling (4s intervals).
Their gateway emits events that the renderer subscribes to.

WE STEAL: Their filter model (level/source/search), export capability.
WE IMPROVE: Our signal classifier gives us structured data they don't have.

═══════════════════════════════════════════════════════════════════════════════
WHAT ALREADY EXISTS — Read These To Understand The Patterns
═══════════════════════════════════════════════════════════════════════════════

FILES TO READ:
1. docs/agent-dispatch/sprint-competitive-integration/CONTEXT.md
2. docs/agent-dispatch/sprint-competitive-integration/WS1-signals-page.md
3. lib/optimal_system_agent/signal/classifier.ex
4. lib/optimal_system_agent/channels/http.ex
5. lib/optimal_system_agent/channels/http/api/fleet_dashboard_routes.ex
6. priv/repo/migrations/ (list all, read 1-2 for pattern)
7. lib/optimal_system_agent/channels/http/api/session_routes.ex

EXISTING SIGNAL CLASSIFIER returns this struct:
  %MiosaSignal.MessageClassifier{
    mode: :execute | :build | :analyze | :maintain | :assist,
    genre: :direct | :inform | :commit | :decide | :express,
    type: "question" | "request" | "issue" | "scheduling" | "summary" | "report" | "general",
    format: :command | :message | :notification | :document,
    weight: 0.0..1.0,
    raw: "original message text",
    channel: :cli | :http | :discord | :telegram | ...,
    timestamp: DateTime.t(),
    confidence: :low | :high
  }

After classification, it fires: Bus.emit(:signal_classified, signal_data)

EXISTING ROUTE PATTERN (from fleet_dashboard_routes.ex):
  defmodule OptimalSystemAgent.Channels.HTTP.API.FleetDashboardRoutes do
    use Plug.Router
    import OptimalSystemAgent.Channels.HTTP.API.Shared
    plug :match
    plug :dispatch

    get "/" do
      body = Jason.encode!(data)
      conn |> put_resp_content_type("application/json") |> send_resp(200, body)
    end
  end

EXISTING MIGRATION PATTERN (from priv/repo/migrations/):
  defmodule OptimalSystemAgent.Store.Repo.Migrations.CreateTableName do
    use Ecto.Migration
    def change do
      create table(:table_name) do
        add :field, :type, null: false
        add :field2, :string, default: "value"
        timestamps()
      end
      create index(:table_name, [:field])
    end
  end

EXISTING TEST PATTERN:
  defmodule OptimalSystemAgent.Signal.PersistenceTest do
    use ExUnit.Case, async: true
    describe "section" do
      test "should do X when Y" do
        assert result == expected
      end
    end
  end

═══════════════════════════════════════════════════════════════════════════════
DETAILED BUILD SPECS — What Each Sub-Agent Builds
═══════════════════════════════════════════════════════════════════════════════

TASK 1: Ecto Migration for `signals` table
  File: priv/repo/migrations/{next_timestamp}_create_signals.exs
  Table: :signals
  Columns:
    - session_id :string
    - channel :string, null: false          (cli, http, discord, telegram, etc.)
    - mode :string, null: false             (BUILD, EXECUTE, ANALYZE, MAINTAIN, ASSIST)
    - genre :string, null: false            (DIRECT, INFORM, COMMIT, DECIDE, EXPRESS)
    - type :string, null: false, default: "general"
    - format :string, null: false           (command, message, notification, document)
    - weight :float, null: false, default: 0.5
    - tier :string                          (haiku, sonnet, opus — derived from weight)
    - input_preview :text                   (first 200 chars of raw input)
    - agent_name :string
    - confidence :string, default: "high"
    - metadata :map, default: %{}
    - timestamps()
  Indexes: [:mode], [:weight], [:channel], [:inserted_at], [:tier]

TASK 2: Signal Persistence Module
  File: lib/optimal_system_agent/signal/persistence.ex
  Module: OptimalSystemAgent.Signal.Persistence
  Behavior: GenServer that subscribes to :signal_classified events
  Functions:
    - start_link/1 — Start GenServer, subscribe to Bus events
    - handle_info({:signal_classified, signal}, state) — Persist signal async
    - persist_signal/1 — Write to SQLite via Ecto, derive tier from weight
    - list_signals/1 — Query with filters (opts: mode, genre, type, channel, weight_min, weight_max, from, to, limit, offset)
    - signal_stats/0 — Aggregate counts by mode, channel, type; weight distribution by tier
    - recent_signals/1 — Last N signals
    - signal_patterns/1 — Peak hours, avg weight, top agents, trend data
  Weight-to-tier mapping:
    0.0-0.35 = "haiku", 0.35-0.65 = "sonnet", 0.65-1.0 = "opus"

TASK 3: Signal API Routes
  File: lib/optimal_system_agent/channels/http/api/signal_routes.ex
  Module: OptimalSystemAgent.Channels.HTTP.API.SignalRoutes
  Forwarded prefix: /signals (so full path = /api/v1/signals)
  Endpoints:
    GET /              — List signals with filters (query params: mode, genre, type, channel, weight_min, weight_max, from, to, limit, offset)
    GET /stats         — Aggregate statistics (counts by mode/channel/type, weight distribution, total, avg_weight)
    GET /patterns      — Pattern analysis (peak hours array, avg weight, top 5 agents, daily counts for last 7 days)
    GET /live          — SSE stream of new signals in real-time (keep-alive, chunked transfer)

TASK 4: SSE Integration
  Add these event types to the existing SSE event stream:
    signal:new — Emitted each time a signal is classified and persisted. Payload: full signal record
    signal:stats_update — Emitted every 30 seconds with updated aggregate stats
  Wire into existing EventStream registry / PubSub topic

TASK 5: Wire Routes Into Main Router
  In lib/optimal_system_agent/channels/http/api.ex (or http.ex wherever the API sub-router is):
    forward "/signals", to: OptimalSystemAgent.Channels.HTTP.API.SignalRoutes

TASK 6: Tests
  File: test/signal/persistence_test.exs
  Test: persist_signal creates record, list_signals filters correctly, signal_stats returns shape
  File: test/channels/http/api/signal_routes_test.exs
  Test: GET /api/v1/signals returns 200 + JSON array, GET /stats returns stats shape, filters work

═══════════════════════════════════════════════════════════════════════════════
TERRITORY — What You Can & Cannot Touch
═══════════════════════════════════════════════════════════════════════════════
CAN MODIFY:
  lib/optimal_system_agent/signal/             (signal system — your core domain)
  lib/optimal_system_agent/channels/http/      (API routes — you're adding signal_routes)
  priv/repo/migrations/                        (new migration)
  test/                                        (new tests)

CANNOT MODIFY:
  desktop/                      (Agent-B's territory — frontend)
  lib/optimal_system_agent/agent/  (agent loop — too risky, no touching)
  lib/optimal_system_agent/providers/  (provider internals)

═══════════════════════════════════════════════════════════════════════════════
VERIFICATION — Required Before Claiming Done
═══════════════════════════════════════════════════════════════════════════════
Run these commands and ALL must pass:
  1. mix compile --warnings-as-errors
  2. mix test
  3. mix test test/signal/ (your new tests specifically)
  4. Start server: verify curl http://localhost:9089/api/v1/signals returns JSON
  5. Verify curl http://localhost:9089/api/v1/signals/stats returns stats object

CREATE COMPLETION REPORT:
  File: docs/agent-dispatch/sprint-competitive-integration/agent-A-completion.md
  Include: files created, files modified, new endpoints, new SSE events, test results, blockers
```

---

### AGENT-B: FRONTEND-SIGNALS

```
You are Agent-B: FRONTEND-SIGNALS in a coordinated command center sprint.
You are one of 8 primary agents, each running in parallel on separate branches.
Your job: build the Signals page UI — 8 Svelte components, 1 store, 1 page, sidebar integration.

PROJECT: OSA Desktop — Tauri 2 + SvelteKit 2.5 + Svelte 5 desktop app
WORKING DIRECTORY: /Users/roberto/Desktop/OSAMain/OSA
BRANCH: git checkout -b ws1/frontend-signals

═══════════════════════════════════════════════════════════════════════════════
GIT RULES — CRITICAL
═══════════════════════════════════════════════════════════════════════════════
- NEVER mention Claude, AI, LLM, or any AI tool in commits, comments, or code
- NEVER add Co-Authored-By lines mentioning Claude or any AI
- Commit format: feat(signals): description / fix(signals): description
- Commit frequently. Push when done: git push -u origin ws1/frontend-signals

═══════════════════════════════════════════════════════════════════════════════
PARALLEL EXECUTION — MANDATORY
═══════════════════════════════════════════════════════════════════════════════
You MUST spawn 10-15 sub-agents across 3 batches. You're building 8 components,
a store, a page, sidebar integration, and types — each can be its own agent.

BATCH 1 — Research (spawn ALL 4 simultaneously):
  1. @Explore agent → Read desktop/src/routes/app/activity/+page.svelte AND desktop/src/lib/stores/activityLogs.svelte.ts AND desktop/src/lib/components/activity/ — extract the EXACT Svelte 5 page/store/component patterns used
  2. @Explore agent → Read desktop/src/lib/api/sse.ts — understand SSECallbacks interface, StreamController, how to subscribe to event streams
  3. @Explore agent → Read desktop/src/lib/api/client.ts AND desktop/src/lib/api/types.ts — understand BASE_URL, API_PREFIX, getToken(), type definition format
  4. @Explore agent → Read desktop/src/lib/components/layout/Sidebar.svelte AND desktop/src/app.css — understand nav item interface (id, label, href, shortcut, icon), CSS custom properties available

BATCH 2 — Build (spawn ALL 10 simultaneously, after batch 1):
  5. @typescript-expert agent → Add Signal types to desktop/src/lib/api/types.ts (Signal interface, SignalStats, SignalFilters, SignalPatterns — details below)
  6. @frontend-svelte agent → Build desktop/src/lib/stores/signals.svelte.ts (state, filters, fetch, SSE subscription — details below)
  7. @frontend-svelte agent → Build desktop/src/lib/components/signals/SignalModeBar.svelte (details below)
  8. @frontend-svelte agent → Build desktop/src/lib/components/signals/SignalWeightGauge.svelte (details below)
  9. @frontend-svelte agent → Build desktop/src/lib/components/signals/SignalFeed.svelte (details below)
  10. @frontend-svelte agent → Build desktop/src/lib/components/signals/SignalFilters.svelte (details below)
  11. @frontend-svelte agent → Build desktop/src/lib/components/signals/SignalCard.svelte (details below)
  12. @frontend-svelte agent → Build desktop/src/lib/components/signals/SignalChannelBreakdown.svelte (details below)
  13. @frontend-svelte agent → Build desktop/src/lib/components/signals/SignalPatterns.svelte (details below)
  14. @frontend-svelte agent → Build desktop/src/routes/app/signals/+page.svelte (compose all components — details below)

BATCH 3 — Integration + Review (after batch 2):
  15. @frontend-svelte agent → Add "Signals" nav item to Sidebar.svelte + add CSS vars for mode/tier colors to global CSS
  16. @code-reviewer agent → Review ALL components: TypeScript strict mode, no any types, design system compliance, accessibility

═══════════════════════════════════════════════════════════════════════════════
COMPETITOR INTELLIGENCE — What We're Stealing & Why
═══════════════════════════════════════════════════════════════════════════════

FROM PAPERCLIP:
Their Dashboard.tsx shows real-time KPIs: active agents panel, recent issues, activity
charts (run frequency, success rate, priority distribution). They use TanStack Query
for data fetching + WebSocket LiveUpdatesProvider for real-time. Components:
ActiveAgentsPanel.tsx, ActivityCharts.tsx, LiveRunWidget.tsx (real-time transcript streaming).
KPI layout: top stats cards → charts → activity feed.

WE STEAL: Their KPI card layout pattern, real-time activity streaming, chart organization.
WE IMPROVE: Our signal 5-tuple gives structured categories they don't have. Our SignalModeBar
shows BUILD/EXECUTE/ANALYZE/MAINTAIN/ASSIST distribution — unique to OSA.

FROM CLAWX:
Their activity feed uses chronological grouping (Today, Yesterday, Last Week).
Hover-activated action buttons reduce visual clutter. They have filter bars with
multiple filter types + search. StatusBadge component for connection status.

WE STEAL: Filter bar pattern, hover actions, status badges.
WE IMPROVE: Our SignalCard shows the full 5-tuple classification inline.

═══════════════════════════════════════════════════════════════════════════════
EXISTING CODE PATTERNS — Follow These Exactly
═══════════════════════════════════════════════════════════════════════════════

FILES TO READ:
1. docs/agent-dispatch/sprint-competitive-integration/CONTEXT.md
2. docs/agent-dispatch/sprint-competitive-integration/WS1-signals-page.md
3. desktop/src/routes/app/activity/+page.svelte
4. desktop/src/lib/stores/activityLogs.svelte.ts
5. desktop/src/lib/components/activity/
6. desktop/src/lib/api/client.ts
7. desktop/src/lib/api/sse.ts
8. desktop/src/lib/api/types.ts
9. desktop/src/lib/components/layout/Sidebar.svelte
10. desktop/src/app.css

EXISTING API CLIENT PATTERN:
  import { BASE_URL, API_PREFIX, getToken } from "$lib/api/client";
  const headers = { "Content-Type": "application/json", "Authorization": `Bearer ${getToken()}` };
  const res = await fetch(`${BASE_URL}${API_PREFIX}/signals?mode=BUILD`, { headers });
  const data = await res.json();

EXISTING TYPE DEFINITION PATTERN:
  // ── Signals ──────────────────────────────────────────────────
  export interface Signal {
    id: string;
    mode: 'BUILD' | 'EXECUTE' | 'ANALYZE' | 'MAINTAIN' | 'ASSIST';
    // ... etc
  }

EXISTING SVELTE STORE PATTERN (uses Svelte 5 runes):
  // Use $state for reactive state, $derived for computed, $effect for side effects
  let signals = $state<Signal[]>([]);
  let loading = $state(false);
  let filters = $state<SignalFilters>({});
  let stats = $derived(computeStats(signals));

EXISTING NAV ITEM PATTERN (from Sidebar.svelte):
  interface NavItem { id: string; label: string; href: string; shortcut: string; icon: string; }
  // Add to NAV_ITEMS array:
  { id: 'signals', label: 'Signals', href: '/app/signals', shortcut: '⌘S', icon: 'M...' }

EXISTING CSS CUSTOM PROPERTIES (from app.css):
  --bg-primary, --bg-secondary, --bg-tertiary
  --text-primary, --text-secondary, --text-tertiary, --text-muted
  --radius-sm, --radius-md, --radius-full
  --border-color, --border-subtle
  Button: --primary, --secondary, --danger, --icon

═══════════════════════════════════════════════════════════════════════════════
BACKEND API CONTRACT — Build Against These Endpoints
═══════════════════════════════════════════════════════════════════════════════
Agent-A is building these concurrently. Code against this contract:

GET /api/v1/signals?mode=BUILD&type=request&channel=cli&weight_min=0.5&limit=50&offset=0
  Response: { signals: Signal[], total: number, limit: number, offset: number }

GET /api/v1/signals/stats
  Response: {
    by_mode: { BUILD: 12, EXECUTE: 34, ANALYZE: 8, MAINTAIN: 15, ASSIST: 27 },
    by_channel: { cli: 42, http: 31, discord: 15, telegram: 8 },
    by_type: { question: 28, request: 24, scheduling: 16, issue: 12, report: 8 },
    weight_distribution: { haiku: 30, sonnet: 45, opus: 21 },
    total: 96,
    avg_weight: 0.47
  }

GET /api/v1/signals/patterns
  Response: {
    peak_hours: [14, 15, 16],
    avg_weight: 0.47,
    top_agents: [{ name: "coder", count: 34 }, ...],
    daily_counts: [{ date: "2026-03-14", count: 23 }, ...],
    escalation_count: 3
  }

GET /api/v1/signals/live  (SSE stream)
  Events:
    event: signal:new\ndata: { ...signal object }\n\n
    event: signal:stats_update\ndata: { ...stats object }\n\n

═══════════════════════════════════════════════════════════════════════════════
DETAILED BUILD SPECS — What Each Sub-Agent Builds
═══════════════════════════════════════════════════════════════════════════════

TYPES (types.ts additions):
  export interface Signal {
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
    confidence: 'low' | 'high';
    metadata: Record<string, unknown>;
    inserted_at: string;
  }
  export interface SignalStats { by_mode: Record<string, number>; by_channel: Record<string, number>; by_type: Record<string, number>; weight_distribution: { haiku: number; sonnet: number; opus: number }; total: number; avg_weight: number; }
  export interface SignalFilters { mode?: string; genre?: string; type?: string; channel?: string; weight_min?: number; weight_max?: number; from?: string; to?: string; }
  export interface SignalPatterns { peak_hours: number[]; avg_weight: number; top_agents: { name: string; count: number }[]; daily_counts: { date: string; count: number }[]; escalation_count: number; }

STORE (signals.svelte.ts):
  Reactive state: signals[], stats, patterns, filters, loading, liveFeed[]
  Functions: fetchSignals(filters), fetchStats(), fetchPatterns(), subscribeLive(), unsubscribeLive()
  SSE: connect to /api/v1/signals/live, parse signal:new events, prepend to liveFeed
  Export all state and functions for components to consume

COMPONENT SPECS:

  SignalModeBar.svelte:
    - 5 horizontal boxes, one per mode (BUILD, EXECUTE, ANALYZE, MAINTAIN, ASSIST)
    - Each shows mode name + count from stats.by_mode
    - Clickable — clicking a mode sets filter.mode and triggers fetchSignals
    - Active mode highlighted with --primary color
    - Use CSS grid, 5 equal columns

  SignalWeightGauge.svelte:
    - Horizontal segmented bar showing weight distribution
    - 3 segments: haiku (green, 0-0.35), sonnet (amber, 0.35-0.65), opus (red, 0.65-1.0)
    - Segment widths proportional to counts
    - Labels below each segment with count
    - Define CSS vars: --tier-haiku: #22c55e, --tier-sonnet: #f59e0b, --tier-opus: #ef4444

  SignalFeed.svelte:
    - Scrollable list of recent signals (live-updating via SSE)
    - Each item: weight badge (colored by tier), input_preview (truncated), mode tag, channel icon, relative timestamp
    - Auto-scrolls to top on new signals (unless user has scrolled away)
    - Shows "Live" indicator with pulsing dot when SSE connected
    - Max 100 items visible, older ones drop off

  SignalFilters.svelte:
    - Horizontal filter bar above the feed
    - Dropdowns: Mode (all/BUILD/EXECUTE/...), Type (all/question/request/...), Channel (all/cli/http/discord/...)
    - Weight range: min/max number inputs or a simple slider
    - "Clear filters" button when any filter active
    - Emits filter changes to parent via callback prop

  SignalCard.svelte:
    - Single signal display (used inside SignalFeed)
    - Shows: weight as colored badge, mode as tag, genre as subtle label, type, format
    - input_preview text (2-line clamp)
    - agent_name, channel, relative timestamp
    - Expandable on click: shows full metadata, raw text, confidence

  SignalChannelBreakdown.svelte:
    - Vertical list of channels with horizontal bar showing count
    - Bar width proportional to max channel count
    - Shows: channel name, bar, count number
    - Data from stats.by_channel

  SignalTypeBreakdown.svelte:
    - Same pattern as ChannelBreakdown but for signal types
    - Data from stats.by_type

  SignalPatterns.svelte:
    - Insight cards showing:
      - "Peak hours: 2-4pm" (from patterns.peak_hours)
      - "Avg weight: 0.47" (from patterns.avg_weight)
      - "Top agent: coder (34)" (from patterns.top_agents[0])
      - "Escalations: 3 today" (from patterns.escalation_count)
    - 2x2 grid of small stat cards

PAGE LAYOUT (+page.svelte):
  ┌─────────────────────────────────────────────────────────┐
  │  SIGNALS                              [SignalFilters]   │
  │                                                         │
  │  [SignalModeBar — 5 mode boxes across full width]       │
  │                                                         │
  │  ┌──────────── LEFT COL ───────┐ ┌──── RIGHT COL ────┐ │
  │  │ SignalWeightGauge           │ │ SignalFeed (live)   │ │
  │  │                             │ │                     │ │
  │  │ SignalChannelBreakdown      │ │                     │ │
  │  │                             │ │                     │ │
  │  │ SignalTypeBreakdown         │ │                     │ │
  │  │                             │ │                     │ │
  │  │ SignalPatterns              │ │                     │ │
  │  └─────────────────────────────┘ └─────────────────────┘ │
  └─────────────────────────────────────────────────────────┘
  Left col: ~35% width. Right col (feed): ~65% width.
  Use CSS grid: grid-template-columns: 1fr 2fr;

═══════════════════════════════════════════════════════════════════════════════
TERRITORY
═══════════════════════════════════════════════════════════════════════════════
CAN MODIFY:
  desktop/src/routes/app/signals/          (new page)
  desktop/src/lib/stores/signals.svelte.ts (new store)
  desktop/src/lib/components/signals/      (new components dir)
  desktop/src/lib/components/layout/Sidebar.svelte (add nav item)
  desktop/src/lib/api/types.ts             (add Signal types)
  desktop/src/app.css                      (add tier/mode CSS vars)

CANNOT MODIFY:
  lib/                                     (backend — Agent-A's territory)
  desktop/src/lib/components/chat/         (chat — separate concern)
  desktop/src/lib/stores/chat.svelte.ts    (chat store)
  desktop/src/lib/components/tasks/        (tasks — Agent-D's territory)

═══════════════════════════════════════════════════════════════════════════════
VERIFICATION
═══════════════════════════════════════════════════════════════════════════════
  1. cd /Users/roberto/Desktop/OSAMain/OSA/desktop && npm run check
  2. npm run build
  3. Verify /app/signals route loads
  4. All 8 components render without errors
  5. Signals nav item visible in sidebar
  6. No hardcoded colors — all CSS custom properties
  7. No TypeScript `any` types
  8. Create completion report: docs/agent-dispatch/sprint-competitive-integration/agent-B-completion.md
```

---

### AGENT-C: BACKEND-SCHEDULER

```
You are Agent-C: BACKEND-SCHEDULER in a coordinated command center sprint.
You are one of 8 primary agents. Your job: enhance OSA's scheduler with Paperclip's
heartbeat execution model and ClawX's cron preset system.

PROJECT: OSA (Operating System Agent) — Elixir/OTP
WORKING DIRECTORY: /Users/roberto/Desktop/OSAMain/OSA
BRANCH: git checkout -b ws2/backend-scheduler

═══════════════════════════════════════════════════════════════════════════════
GIT RULES — CRITICAL
═══════════════════════════════════════════════════════════════════════════════
- NEVER mention Claude, AI, LLM, or any AI tool in commits, comments, or code
- NEVER add Co-Authored-By lines mentioning Claude or any AI
- Commit format: feat(scheduler): description / fix(scheduler): description
- Push when done: git push -u origin ws2/backend-scheduler

═══════════════════════════════════════════════════════════════════════════════
PARALLEL EXECUTION — MANDATORY
═══════════════════════════════════════════════════════════════════════════════
Spawn 8-12 sub-agents across 3 batches.

BATCH 1 — Research (spawn ALL 5):
  1. @Explore agent → Read lib/optimal_system_agent/agent/scheduler.ex + ALL files in scheduler/ (cron_engine.ex, heartbeat.ex, job_executor.ex, persistence.ex, sqlite_store.ex) — map the full scheduler architecture
  2. @Explore agent → Read lib/optimal_system_agent/agent/tasks/ (workflow.ex, tracker.ex, queue.ex) — understand task execution flow
  3. @Explore agent → Read lib/optimal_system_agent/agent/treasury.ex — understand budget check patterns (we call treasury before/after execution)
  4. @Explore agent → Read existing API routes for CRUD patterns + SSE event emission
  5. @Explore agent → Read test/ for scheduler/task test patterns

BATCH 2 — Build (spawn ALL 6):
  6. @database-specialist agent → Create migration for scheduled_runs table (details below)
  7. @backend-go agent → Build heartbeat_executor.ex — the core execution engine (details below)
  8. @backend-go agent → Build cron_presets.ex — 8 presets + human-readable descriptions (details below)
  9. @api-designer agent → Build scheduler_routes.ex — full CRUD + trigger + run history (details below)
  10. @sse-specialist agent → Wire task execution SSE events into event stream (details below)
  11. @test-automator agent → Write tests for executor, presets, routes

BATCH 3 — Review (after batch 2):
  12. @code-reviewer agent → Review for OTP patterns, supervision, error handling, race conditions

═══════════════════════════════════════════════════════════════════════════════
COMPETITOR INTELLIGENCE
═══════════════════════════════════════════════════════════════════════════════

FROM PAPERCLIP — HEARTBEAT MODEL (their core innovation):
Their heartbeat.ts (99,899 bytes!) manages agent execution. Key concepts:
  - Agents don't run continuously — they wake up on schedule/event/manual trigger
  - Each heartbeat: startup lock → budget check → build context → execute → capture output → persist session state
  - withAgentStartLock() prevents concurrent runs on same agent (per-agent mutex)
  - Max concurrent runs per agent: configurable 1-10
  - Session codec: agent state persisted between heartbeats (e.g., Claude Code session ID reused)
  - Workspace realization: git worktree creation for isolated parallel work
  - Run log storage: compressed stdout with SHA256 integrity
  - Cost tracking: adapter captures token usage, auto-pauses agent if budget exceeded
  - Event streaming: WebSocket broadcasts heartbeat_started, heartbeat_complete, issue_updated

WE STEAL: The entire heartbeat protocol. Wake → lock → budget → execute → capture → persist → emit.
WE IMPROVE: Our OTP GenServer is cleaner than their JS locks. Our SSE is simpler than their WebSocket.

FROM CLAWX — CRON UI:
Their cron store has 8 presets:
  every_minute ("* * * * *"), every_5_minutes ("*/5 * * * *"), every_15_minutes,
  every_30_minutes, hourly ("0 * * * *"), daily_9am ("0 9 * * *"),
  weekly_monday ("0 9 * * 1"), monthly_first ("0 9 1 * *")
They show human-readable descriptions and next-run timestamps.
IPC channels: cron:list, cron:create, cron:update, cron:delete, cron:toggle, cron:trigger

WE STEAL: The 8 presets, human-readable cron descriptions, "Run Now" trigger capability.

═══════════════════════════════════════════════════════════════════════════════
WHAT ALREADY EXISTS
═══════════════════════════════════════════════════════════════════════════════
FILES TO READ:
1. docs/agent-dispatch/sprint-competitive-integration/CONTEXT.md
2. docs/agent-dispatch/sprint-competitive-integration/WS2-task-scheduling.md
3. lib/optimal_system_agent/agent/scheduler.ex
4. lib/optimal_system_agent/agent/scheduler/* (all sub-modules)
5. lib/optimal_system_agent/agent/tasks/*
6. lib/optimal_system_agent/agent/treasury.ex
7. lib/optimal_system_agent/channels/http/api/ (route patterns)

The existing scheduler already has:
  - HEARTBEAT.md monitoring (30-min intervals)
  - CRONS.json parsing for scheduled jobs
  - TRIGGERS.json for event-driven automation
  - Circuit breaker (3 consecutive failures = auto-disable)
  - 1-minute cron tick resolution
  - Job types: agent, command, webhook

═══════════════════════════════════════════════════════════════════════════════
DETAILED BUILD SPECS
═══════════════════════════════════════════════════════════════════════════════

TASK 1: Migration for scheduled_runs table
  Columns:
    - scheduled_task_id :string, null: false
    - agent_name :string
    - status :string, default: "pending" (pending, running, succeeded, failed, timed_out, cancelled)
    - trigger_type :string (schedule, manual, event, assignment)
    - started_at :utc_datetime
    - completed_at :utc_datetime
    - duration_ms :integer
    - exit_code :integer
    - stdout :text (captured output — compress if > 10KB)
    - stderr :text
    - token_usage :map, default: %{} (shape: %{input: N, output: N, cost_cents: N})
    - session_state :map, default: %{} (persistent agent state for next run)
    - error_message :text
    - metadata :map, default: %{}
    - timestamps()
  Indexes: [:scheduled_task_id], [:status], [:inserted_at]

TASK 2: HeartbeatExecutor (Paperclip-style)
  File: lib/optimal_system_agent/agent/scheduler/heartbeat_executor.ex
  Module: GenServer
  Core function: execute_heartbeat(scheduled_task, trigger_type)
  Flow:
    1. Create run record (status: "running", started_at: now)
    2. Acquire per-agent startup lock (GenServer call or ETS-based)
    3. Check Treasury — if budget exceeded, abort with {:error, :budget_exceeded}
    4. Build agent context: task prompt + session_state from last successful run
    5. Execute agent loop (call into existing Agent.Loop or Orchestrator)
    6. Capture stdout (via StringIO or process output capture)
    7. Capture token usage from provider response
    8. Update run record: status, completed_at, duration_ms, stdout, token_usage, session_state
    9. Persist session_state for next heartbeat
    10. Emit SSE events: task:run_completed
    11. Post-run budget check — if exceeded, pause agent

  Error handling:
    - Timeout: configurable per task (default 5 min, max 30 min), status: "timed_out"
    - Crash: catch all, status: "failed", error_message captured
    - Circuit breaker: 3 consecutive failures → auto-disable task

TASK 3: CronPresets
  File: lib/optimal_system_agent/agent/scheduler/cron_presets.ex
  Module with functions:
    list_presets/0 → returns 8 preset maps
    describe/1 → takes cron expression, returns human-readable string
    next_run/1 → takes cron expression, returns next DateTime
  Presets:
    %{id: "every_minute", cron: "* * * * *", label: "Every minute"}
    %{id: "every_5_minutes", cron: "*/5 * * * *", label: "Every 5 minutes"}
    %{id: "every_15_minutes", cron: "*/15 * * * *", label: "Every 15 minutes"}
    %{id: "every_30_minutes", cron: "*/30 * * * *", label: "Every 30 minutes"}
    %{id: "hourly", cron: "0 * * * *", label: "Every hour"}
    %{id: "daily_9am", cron: "0 9 * * *", label: "Daily at 9:00 AM"}
    %{id: "weekly_monday", cron: "0 9 * * 1", label: "Weekly on Monday at 9:00 AM"}
    %{id: "monthly_first", cron: "0 9 1 * *", label: "Monthly on the 1st at 9:00 AM"}

TASK 4: Scheduler Routes
  File: lib/optimal_system_agent/channels/http/api/scheduler_routes.ex
  Forwarded prefix: /scheduled-tasks
  Endpoints:
    GET /                         — List all scheduled tasks with last run info
    POST /                        — Create task { name, cron, prompt, agent_name, timeout_ms }
    PUT /:id                      — Update task fields
    DELETE /:id                   — Delete task
    POST /:id/trigger             — Manual trigger (run now)
    PUT /:id/toggle               — Enable/disable
    GET /:id/runs                 — Run history for task (paginated)
    GET /:id/runs/:run_id         — Single run details + stdout
    GET /:id/runs/:run_id/stream  — SSE stream of running task output
    GET /presets                  — Return available cron presets

TASK 5: SSE Events
    task:run_started    → { task_id, run_id, agent_name, trigger_type }
    task:run_output     → { run_id, chunk } (streaming stdout line by line)
    task:run_completed  → { run_id, status, duration_ms, token_usage }
    task:run_failed     → { run_id, error_message }

═══════════════════════════════════════════════════════════════════════════════
TERRITORY
═══════════════════════════════════════════════════════════════════════════════
CAN MODIFY: lib/optimal_system_agent/agent/scheduler/, lib/optimal_system_agent/channels/http/, priv/repo/migrations/, test/
CANNOT MODIFY: desktop/ (Agent-D), lib/optimal_system_agent/agent/loop.ex, lib/optimal_system_agent/agent/treasury.ex (WS3)

═══════════════════════════════════════════════════════════════════════════════
VERIFICATION
═══════════════════════════════════════════════════════════════════════════════
  1. mix compile --warnings-as-errors
  2. mix test
  3. POST /api/v1/scheduled-tasks creates task
  4. POST /api/v1/scheduled-tasks/:id/trigger runs it
  5. GET /api/v1/scheduled-tasks/:id/runs shows run with stdout
  6. GET /api/v1/scheduled-tasks/presets returns 8 presets
  7. Create completion report: agent-C-completion.md
```

---

### AGENT-D: FRONTEND-SCHEDULER

```
You are Agent-D: FRONTEND-SCHEDULER in a coordinated command center sprint.
Your job: enhance the Tasks page with ClawX-style cron presets and run history visualization.

PROJECT: OSA Desktop — Tauri 2 + SvelteKit 2.5 + Svelte 5
WORKING DIRECTORY: /Users/roberto/Desktop/OSAMain/OSA
BRANCH: git checkout -b ws2/frontend-scheduler

═══════════════════════════════════════════════════════════════════════════════
GIT RULES — CRITICAL
═══════════════════════════════════════════════════════════════════════════════
- NEVER mention Claude, AI, LLM, or any AI tool in commits, comments, or code
- NEVER add Co-Authored-By lines mentioning Claude or any AI
- Commit format: feat(tasks): description / fix(tasks): description
- Push when done: git push -u origin ws2/frontend-scheduler

═══════════════════════════════════════════════════════════════════════════════
PARALLEL EXECUTION — MANDATORY
═══════════════════════════════════════════════════════════════════════════════
Spawn 8-10 sub-agents across 3 batches.

BATCH 1 — Research (spawn ALL 4):
  1. @Explore agent → Read desktop/src/routes/app/tasks/+page.svelte (14.5KB) — understand current layout, sections, reactive state
  2. @Explore agent → Read desktop/src/lib/components/tasks/ScheduledTaskForm.svelte (12.9KB) AND ScheduledTaskCard.svelte (12KB) — understand form fields, card layout, event handlers
  3. @Explore agent → Read desktop/src/lib/stores/scheduledTasks.svelte.ts — understand state shape, API calls, current functionality
  4. @Explore agent → Read desktop/src/lib/api/client.ts + sse.ts + types.ts — understand API and streaming patterns

BATCH 2 — Build (spawn ALL 7):
  5. @typescript-expert agent → Add ScheduledRun + CronPreset types to api/types.ts
  6. @frontend-svelte agent → Enhance scheduledTasks.svelte.ts store (add fetchPresets, triggerNow, fetchRuns, streamRun functions)
  7. @frontend-svelte agent → Enhance ScheduledTaskForm.svelte (add preset selector radio group, agent dropdown, timeout input, human-readable preview text)
  8. @frontend-svelte agent → Enhance ScheduledTaskCard.svelte (add last run status dot, next run countdown, mini history dots, hover "Run Now"/"Edit"/"Delete" buttons)
  9. @frontend-svelte agent → Build NEW RunDetail.svelte (full run output with live SSE streaming, token usage stats, duration, re-run button)
  10. @frontend-svelte agent → Build NEW RunHistory.svelte (paginated table of past runs, status badges, duration, filter by status dropdown)
  11. @frontend-svelte agent → Enhance +page.svelte (add 3-tab switcher: Active Tasks | Scheduled Tasks | Run History)

BATCH 3 — Review (after batch 2):
  12. @code-reviewer agent → Review all for TypeScript strictness, a11y, design system, responsiveness

═══════════════════════════════════════════════════════════════════════════════
COMPETITOR INTELLIGENCE
═══════════════════════════════════════════════════════════════════════════════

FROM CLAWX — CRON UI (their Cron/ page):
  - 8 presets as radio buttons: every minute, 5min, 15min, 30min, hourly, daily 9am, weekly monday, monthly 1st
  - Toggle between preset and custom cron expression input
  - Human-readable preview: "0 9 * * *" → "Daily at 09:00"
  - Next run time estimation shown
  - Task cards show: name, enabled/paused indicator, schedule description, message preview (2-line clamp)
  - Metadata: target channel, last run timestamp (green=success, red=failure), next scheduled run
  - Error message inline if last run failed
  - Hover actions: "Run Now" button + "Delete" button

WE STEAL: Preset radio buttons, human-readable preview, run status dots, hover actions.

FROM PAPERCLIP — RUN HISTORY:
  - LiveRunWidget shows real-time transcript streaming
  - Run history table with status, duration, cost
  - Each run expandable to see full stdout
  - Filterable by status (succeeded/failed/timed_out)

WE STEAL: Run history table, live transcript, status filters.

═══════════════════════════════════════════════════════════════════════════════
BACKEND API CONTRACT (Agent-C builds these)
═══════════════════════════════════════════════════════════════════════════════
GET /api/v1/scheduled-tasks → { tasks: ScheduledTask[] }
POST /api/v1/scheduled-tasks → { task: ScheduledTask }
POST /api/v1/scheduled-tasks/:id/trigger → { run: ScheduledRun }
PUT /api/v1/scheduled-tasks/:id/toggle → { task: ScheduledTask }
GET /api/v1/scheduled-tasks/:id/runs → { runs: ScheduledRun[], total: number }
GET /api/v1/scheduled-tasks/:id/runs/:run_id → { run: ScheduledRun }
GET /api/v1/scheduled-tasks/:id/runs/:run_id/stream → SSE (task:run_output events)
GET /api/v1/scheduled-tasks/presets → { presets: CronPreset[] }

═══════════════════════════════════════════════════════════════════════════════
DETAILED BUILD SPECS
═══════════════════════════════════════════════════════════════════════════════

TYPES (add to types.ts):
  export interface ScheduledRun {
    id: string; scheduled_task_id: string; agent_name: string;
    status: 'pending' | 'running' | 'succeeded' | 'failed' | 'timed_out' | 'cancelled';
    trigger_type: 'schedule' | 'manual' | 'event' | 'assignment';
    started_at: string; completed_at?: string; duration_ms?: number;
    stdout?: string; token_usage?: { input: number; output: number; cost_cents: number };
    error_message?: string;
  }
  export interface CronPreset { id: string; cron: string; label: string; }

ScheduledTaskForm ENHANCEMENTS:
  - Add "Schedule" section with preset radio buttons (8 options in 2x4 grid)
  - Add "Custom" toggle that reveals a text input for custom cron expression
  - Show human-readable description below the selector
  - Add "Agent" dropdown populated from agents store
  - Add "Timeout" number input (minutes, default 5, max 30)
  - Show estimated "Next run: in 4 minutes" text

ScheduledTaskCard ENHANCEMENTS:
  - Right side of card: last 5 runs as colored dots (green=success, red=fail, gray=pending)
  - "Next run: 3m 24s" countdown (or absolute time if > 1 hour)
  - If last run failed: show error message in red below card title
  - On hover: reveal "Run Now" (play icon), "Edit" (pencil), "Disable" (pause), "Delete" (trash) buttons

RunDetail.svelte (NEW):
  - Header: task name, run status badge, trigger type, duration
  - Main area: scrollable stdout output (monospace font, dark background like terminal)
  - If run is "running": SSE stream output in real-time (connect to /stream endpoint)
  - Footer: token usage breakdown (input/output/cost), "Re-run" button
  - Close button or back navigation

RunHistory.svelte (NEW):
  - Table: columns = Status (badge), Started, Duration, Trigger, Agent
  - Rows clickable → opens RunDetail
  - Filter dropdown: All / Succeeded / Failed / Timed Out
  - Pagination: 20 per page with next/prev buttons
  - Empty state: "No runs yet. Trigger a manual run to get started."

Page Tab Enhancement:
  - Tab bar at top: "Active Tasks" | "Scheduled Tasks" | "Run History"
  - Active Tasks: existing task list
  - Scheduled Tasks: ScheduledTaskCard list + create form
  - Run History: RunHistory component (global across all tasks)

═══════════════════════════════════════════════════════════════════════════════
TERRITORY
═══════════════════════════════════════════════════════════════════════════════
CAN MODIFY: desktop/src/routes/app/tasks/, desktop/src/lib/stores/scheduledTasks.svelte.ts, desktop/src/lib/components/tasks/, desktop/src/lib/api/types.ts
CANNOT MODIFY: lib/ (backend), desktop/src/lib/stores/tasks.svelte.ts (separate), desktop/src/lib/components/signals/ (WS1)

═══════════════════════════════════════════════════════════════════════════════
VERIFICATION
═══════════════════════════════════════════════════════════════════════════════
  1. cd desktop && npm run check && npm run build
  2. Tasks page has 3 working tabs
  3. Preset selector shows 8 options
  4. ScheduledTaskCard shows run history dots
  5. RunDetail shows formatted output
  6. Create completion report: agent-D-completion.md
```

---

## WAVE 2 — Launch After Wave 1 Completes

---

### AGENT-E: BUDGET-SYSTEM

```
You are Agent-E: BUDGET-SYSTEM in a coordinated command center sprint.
Your job: implement Paperclip's cost tracking + per-agent budget enforcement on top of OSA's Treasury.

PROJECT: OSA — Elixir/OTP + SvelteKit (full-stack)
WORKING DIRECTORY: /Users/roberto/Desktop/OSAMain/OSA
BRANCH: git checkout -b ws3/budget-system

═══════════════════════════════════════════════════════════════════════════════
GIT RULES — CRITICAL
═══════════════════════════════════════════════════════════════════════════════
- NEVER mention Claude, AI, LLM, or any AI tool in commits, comments, or code
- NEVER add Co-Authored-By lines mentioning Claude or any AI
- Commit format: feat(budget): description / fix(budget): description
- Push when done: git push -u origin ws3/budget-system

═══════════════════════════════════════════════════════════════════════════════
PARALLEL EXECUTION — MANDATORY
═══════════════════════════════════════════════════════════════════════════════
Spawn 10-13 sub-agents. Full-stack = backend + frontend built simultaneously.

BATCH 1 — Research (4 agents):
  1. @Explore agent → Read lib/optimal_system_agent/agent/treasury.ex — understand balance, limits, events
  2. @Explore agent → Read lib/optimal_system_agent/providers/ — find where token usage is emitted/tracked
  3. @Explore agent → Read desktop/src/routes/app/usage/+page.svelte + stores/usage.svelte.ts — understand usage UI
  4. @Explore agent → Read existing migrations + route patterns

BATCH 2 — Build (8 agents, backend + frontend in parallel):
  BACKEND:
  5. @database-specialist → cost_events + agent_budgets migrations
  6. @backend-go → cost_tracker.ex (subscribe to provider events, track costs, auto-pause)
  7. @api-designer → cost_routes.ex (summary, by-agent, by-model, budget CRUD)
  8. @test-automator → Tests for cost tracking + auto-pause logic
  FRONTEND:
  9. @frontend-svelte → BudgetOverview.svelte (daily/monthly bars, per-agent breakdown)
  10. @frontend-svelte → CostBreakdown.svelte + BudgetAlerts.svelte
  11. @frontend-svelte → Enhance usage page + store + types.ts
  12. @frontend-svelte → BudgetControls.svelte (edit limits, manual pause/resume, reset)

BATCH 3 — Review:
  13. @code-reviewer → Security review (no cost manipulation, atomic updates)

═══════════════════════════════════════════════════════════════════════════════
COMPETITOR INTELLIGENCE
═══════════════════════════════════════════════════════════════════════════════

FROM PAPERCLIP — BUDGET ENFORCEMENT (their costs.ts service):
  - Every agent has budgetMonthlyCents and spentMonthlyCents fields
  - Every company has the same fields (aggregate)
  - After each cost event: atomically increment agent.spentMonthlyCents
  - If spent >= budget AND status != paused: auto-pause agent immediately
  - Cost events track: agentId, companyId, inputTokens, outputTokens, totalCost
  - UI shows: utilization percentage bars, per-agent breakdown, overage warnings
  - Monthly budget reset on calendar boundary

  Their exact auto-pause logic:
    if (updatedAgent.budgetMonthlyCents > 0 &&
        updatedAgent.spentMonthlyCents >= updatedAgent.budgetMonthlyCents &&
        updatedAgent.status !== "paused" && updatedAgent.status !== "terminated") {
      await db.update(agents).set({ status: "paused" });
    }

WE STEAL: Per-agent budgets, auto-pause, cost events, utilization bars.
WE IMPROVE: Our Treasury already has daily + monthly limits. We add per-agent granularity.

═══════════════════════════════════════════════════════════════════════════════
DETAILED BUILD SPECS
═══════════════════════════════════════════════════════════════════════════════

Read docs/agent-dispatch/sprint-competitive-integration/WS3-budget-system.md for full specs.

Key specs:
  - cost_events table: agent_name, session_id, task_id, provider, model, input_tokens, output_tokens, cache_read_tokens, cache_write_tokens, cost_cents, timestamps
  - agent_budgets table: agent_name (unique), budget_daily_cents, budget_monthly_cents, spent_daily_cents, spent_monthly_cents, status, last_reset_daily, last_reset_monthly
  - cost_tracker.ex: GenServer subscribing to provider response events, creating cost_events, updating agent_budgets atomically, checking budget exceeded, emitting :budget_exceeded event
  - cost_routes.ex: GET /costs/summary, GET /costs/by-agent, GET /costs/by-model, GET /costs/events, GET /budgets, PUT /budgets/:agent_name, POST /budgets/:agent_name/reset

Frontend:
  - BudgetOverview: progress bars (daily ████████░░ $187/$250, monthly similar), per-agent bars below
  - CostBreakdown: by model distribution, by agent distribution, 7-day trend
  - BudgetAlerts: yellow at 80%, red at 95%, "Agent paused" indicator
  - BudgetControls: edit daily/monthly limits per agent, pause/resume, reset spent

═══════════════════════════════════════════════════════════════════════════════
TERRITORY
═══════════════════════════════════════════════════════════════════════════════
CAN MODIFY: lib/optimal_system_agent/agent/treasury.ex, lib/optimal_system_agent/agent/cost_tracker.ex (new), lib/optimal_system_agent/channels/http/, priv/repo/migrations/, desktop/src/routes/app/usage/, desktop/src/lib/stores/usage.svelte.ts, desktop/src/lib/components/usage/ (create), desktop/src/lib/api/types.ts, test/
CANNOT MODIFY: lib/optimal_system_agent/agent/loop.ex, lib/optimal_system_agent/providers/, desktop/src/lib/components/tasks/, desktop/src/lib/components/signals/

═══════════════════════════════════════════════════════════════════════════════
VERIFICATION
═══════════════════════════════════════════════════════════════════════════════
  1. mix compile --warnings-as-errors && mix test
  2. cd desktop && npm run check && npm run build
  3. Cost events created when LLM is used
  4. Budget bars visible on /app/usage
  5. Auto-pause triggers when budget exceeded
  6. Create completion report: agent-E-completion.md
```

---

### AGENT-F: AGENT-HIERARCHY

```
You are Agent-F: AGENT-HIERARCHY in a coordinated command center sprint.
Your job: add Paperclip's org tree hierarchy to OSA's 32-agent system with drag-drop org chart.

PROJECT: OSA — Elixir/OTP + SvelteKit (full-stack)
WORKING DIRECTORY: /Users/roberto/Desktop/OSAMain/OSA
BRANCH: git checkout -b ws4/agent-hierarchy

═══════════════════════════════════════════════════════════════════════════════
GIT RULES — CRITICAL
═══════════════════════════════════════════════════════════════════════════════
- NEVER mention Claude, AI, LLM, or any AI tool in commits, comments, or code
- NEVER add Co-Authored-By lines mentioning Claude or any AI
- Commit format: feat(hierarchy): description / fix(hierarchy): description
- Push when done: git push -u origin ws4/agent-hierarchy

═══════════════════════════════════════════════════════════════════════════════
PARALLEL EXECUTION — MANDATORY
═══════════════════════════════════════════════════════════════════════════════
Spawn 8-11 sub-agents.

BATCH 1 — Research (3 agents):
  1. @Explore agent → Read ALL 32 agent modules in lib/optimal_system_agent/agents/ — map tier (:elite/:specialist/:utility), role (:lead/:specialist/:reviewer), names
  2. @Explore agent → Read desktop/src/routes/app/agents/+page.svelte + stores/agents.svelte.ts + priv/agents/ specs
  3. @Explore agent → Read migration + route patterns

BATCH 2 — Build (7 agents):
  BACKEND:
  4. @database-specialist → agent_hierarchy table migration
  5. @backend-go → hierarchy.ex (get_tree, get_reports, move_agent, delegate, seed_defaults with real 32-agent mapping)
  6. @api-designer → hierarchy_routes.ex
  7. @test-automator → Tests (cycle prevention, delegation, seeding)
  FRONTEND:
  8. @frontend-svelte → OrgChart.svelte (tree layout with CSS grid, connecting lines, drag-drop, collapse/expand)
  9. @frontend-svelte → Enhance agents page (List/Org toggle) + agents store (hierarchy state)
  10. @frontend-svelte → Hierarchy types in types.ts

BATCH 3 — Review:
  11. @code-reviewer → Check cycle prevention, drag-drop UX, tree rendering perf

═══════════════════════════════════════════════════════════════════════════════
COMPETITOR INTELLIGENCE
═══════════════════════════════════════════════════════════════════════════════

FROM PAPERCLIP — ORG CHART:
  - Every agent has reportsTo field (strict tree, each reports to exactly one manager)
  - CEO has reportsTo: null (root of tree)
  - Roles: ceo, manager, engineer, specialist
  - OrgChart.tsx uses @dnd-kit for drag-drop restructuring
  - Mermaid diagrams for org structure visualization
  - Visual: tree layout with lines connecting parent → children
  - Delegation: agent can escalate work to their manager

WE STEAL: reportsTo tree, role model, drag-drop restructuring, delegation.
WE IMPROVE: Our 32 agents have existing tiers (elite/specialist/utility) which map naturally to org levels.

DEFAULT HIERARCHY FOR OSA'S 32 AGENTS:
  master_orchestrator (CEO, reports_to: nil)
  ├── architect (CTO, reports_to: master_orchestrator)
  │   ├── dragon (VP Engineering)
  │   │   ├── backend_go, frontend_react, frontend_svelte, database (engineers)
  │   ├── nova (VP AI/ML)
  │   ├── api_designer, devops, performance_optimizer (directors)
  ├── security_auditor (CISO, reports_to: master_orchestrator)
  │   ├── red_team
  ├── code_reviewer (VP Quality)
  │   ├── test_automator, qa_lead, debugger
  └── doc_writer, refactorer, explorer, etc. (individual contributors)

═══════════════════════════════════════════════════════════════════════════════
DETAILED BUILD SPECS
═══════════════════════════════════════════════════════════════════════════════

Read docs/agent-dispatch/sprint-competitive-integration/WS4-agent-hierarchy.md for full specs.

Key: hierarchy.ex must validate no cycles when moving agents (traverse reports_to chain,
ensure moved agent doesn't become its own ancestor). seed_defaults/0 maps the real 32
agent names from the agents/ directory into the tree above.

═══════════════════════════════════════════════════════════════════════════════
TERRITORY
═══════════════════════════════════════════════════════════════════════════════
CAN MODIFY: lib/optimal_system_agent/agents/hierarchy.ex (new), lib/optimal_system_agent/channels/http/, priv/repo/migrations/, desktop/src/routes/app/agents/, desktop/src/lib/stores/agents.svelte.ts, desktop/src/lib/components/agents/ (create), desktop/src/lib/api/types.ts, test/
CANNOT MODIFY: lib/optimal_system_agent/agents/*.ex (individual agent modules), lib/optimal_system_agent/agent/loop.ex

═══════════════════════════════════════════════════════════════════════════════
VERIFICATION
═══════════════════════════════════════════════════════════════════════════════
  1. mix compile --warnings-as-errors && mix test
  2. cd desktop && npm run check && npm run build
  3. POST /api/v1/agents/hierarchy/seed creates default tree
  4. GET /api/v1/agents/hierarchy returns full tree
  5. Org chart renders on /app/agents
  6. Drag-drop reparenting works
  7. Create completion report: agent-F-completion.md
```

---

## WAVE 3 — Launch After Wave 2 Completes

---

### AGENT-G: KANBAN-APPROVALS

```
You are Agent-G: KANBAN-APPROVALS in a coordinated command center sprint.
Your job: TWO features — Kanban task board with atomic checkout + approval governance workflow.
This is the biggest workstream. Spawn maximum sub-agents.

PROJECT: OSA — Elixir/OTP + SvelteKit (full-stack)
WORKING DIRECTORY: /Users/roberto/Desktop/OSAMain/OSA
BRANCH: git checkout -b ws5-6/kanban-approvals

═══════════════════════════════════════════════════════════════════════════════
GIT RULES — CRITICAL
═══════════════════════════════════════════════════════════════════════════════
- NEVER mention Claude, AI, LLM, or any AI tool in commits, comments, or code
- NEVER add Co-Authored-By lines mentioning Claude or any AI
- Commit format: feat(kanban): or feat(approvals): description
- Push when done: git push -u origin ws5-6/kanban-approvals

═══════════════════════════════════════════════════════════════════════════════
PARALLEL EXECUTION — MANDATORY
═══════════════════════════════════════════════════════════════════════════════
Spawn 12-15 sub-agents. TWO independent tracks: Kanban + Approvals run in parallel.

BATCH 1 — Research (4 agents):
  1. @Explore → Read task system (lib/optimal_system_agent/agent/tasks/*)
  2. @Explore → Read tasks page + store + all task components
  3. @Explore → Read permissions store + PermissionDialog for approval-like patterns
  4. @Explore → Read Sidebar.svelte nav structure

BATCH 2 — Build (12 agents, two parallel tracks):
  KANBAN TRACK (6):
  5. @database-specialist → Migration: add priority, assignee_agent, checkout_lock, extend status enum to 7 values
  6. @backend-go → Atomic checkout logic (Ecto update with WHERE status = "todo" AND checkout_lock IS NULL — returns {0, _} = 409)
  7. @api-designer → Task checkout/release/status/priority/assign endpoints
  8. @frontend-svelte → KanbanBoard.svelte (5 columns with drag-drop, column counts, filter bar)
  9. @frontend-svelte → KanbanCard.svelte (compact: title, priority dot, assignee, drag handle)
  10. @frontend-svelte → Enhance tasks page + store (List|Kanban|Scheduled toggle, extended statuses)

  APPROVALS TRACK (6):
  11. @database-specialist → Approvals table migration
  12. @backend-go → governance/approvals.ex (create, resolve, list, requires_approval?)
  13. @api-designer → approval_routes.ex (list, pending, approve, reject, request-revision)
  14. @frontend-svelte → /app/approvals/+page.svelte
  15. @frontend-svelte → ApprovalCard.svelte + approvals.svelte.ts store
  16. @frontend-svelte → Sidebar: add Approvals nav with pending count badge

BATCH 3 — Test + Review (2):
  17. @test-automator → Concurrent checkout conflict test, approval state transitions
  18. @code-reviewer → Race conditions, drag-drop UX, approval gate correctness

═══════════════════════════════════════════════════════════════════════════════
COMPETITOR INTELLIGENCE
═══════════════════════════════════════════════════════════════════════════════

FROM PAPERCLIP — ATOMIC CHECKOUT:
  Their exact pattern (from issues.ts):
    const updated = await db.update(issues)
      .set({ assigneeAgentId, status: "in_progress", executionLockedAt: new Date() })
      .where(and(eq(issues.id, issueId), eq(issues.status, "todo")))
      .returning();
    if (updated.length === 0) return res.status(409).json({ error: "already_assigned" });

  In Elixir/Ecto equivalent:
    {count, _} = Repo.update_all(
      from(t in Task, where: t.id == ^id and t.status == "todo" and is_nil(t.checkout_lock)),
      set: [assignee_agent: agent, status: "in_progress", checkout_lock: DateTime.utc_now()]
    )
    if count == 0, do: {:error, :already_assigned}, else: {:ok, :checked_out}

FROM PAPERCLIP — APPROVALS:
  Types: agent_create, budget_change, task_reassign, strategy_change, agent_terminate
  Status flow: pending → approved | rejected | revision_requested
  Resolution includes: decision_notes, resolved_by, resolved_at
  Board operators get full visibility + control
  Every mutation logged in activity audit trail

FROM PAPERCLIP — KANBAN:
  IssuesList.tsx (36,672 bytes) has KanbanBoard with @dnd-kit
  Status columns: backlog, todo, in_progress, in_review, done
  Cards show: title, priority badge, assignee avatar, labels
  Drag between columns = status change API call

═══════════════════════════════════════════════════════════════════════════════
DETAILED BUILD SPECS
═══════════════════════════════════════════════════════════════════════════════

Read WS5-kanban-board.md and WS6-approvals.md for full specs.

Kanban key specs:
  - 7 statuses: backlog, todo, in_progress, in_review, done, blocked, cancelled
  - Priority: low (green), medium (yellow), high (orange), critical (red)
  - Atomic checkout prevents double-assignment (409 Conflict)
  - Drag-drop between columns triggers PUT /api/v1/tasks/:id/status
  - Filter bar: by priority, by agent, text search

Approvals key specs:
  - Approval types: agent_create, budget_change, task_reassign, agent_terminate
  - Status: pending → approved | rejected | revision_requested
  - Sidebar badge shows pending count (red dot with number)
  - SSE events: approval:created, approval:resolved

═══════════════════════════════════════════════════════════════════════════════
TERRITORY
═══════════════════════════════════════════════════════════════════════════════
CAN MODIFY: lib/optimal_system_agent/agent/tasks/, lib/optimal_system_agent/governance/ (new), lib/optimal_system_agent/channels/http/, priv/repo/migrations/, desktop/src/routes/app/tasks/, desktop/src/routes/app/approvals/ (new), desktop/src/lib/stores/tasks.svelte.ts, desktop/src/lib/stores/approvals.svelte.ts (new), desktop/src/lib/components/tasks/, desktop/src/lib/components/approvals/ (new), desktop/src/lib/components/layout/Sidebar.svelte, desktop/src/lib/api/types.ts, test/
CANNOT MODIFY: lib/optimal_system_agent/agent/loop.ex, desktop/src/lib/components/signals/

═══════════════════════════════════════════════════════════════════════════════
VERIFICATION
═══════════════════════════════════════════════════════════════════════════════
  1. mix compile --warnings-as-errors && mix test
  2. cd desktop && npm run check && npm run build
  3. Kanban renders with drag-drop status changes
  4. POST checkout twice → second returns 409
  5. /app/approvals page loads with pending approvals
  6. Sidebar shows Approvals with pending count badge
  7. Create completion report: agent-G-completion.md
```

---

## WAVE 4 — Launch After Wave 3 Completes

---

### AGENT-H: CONFIG-RESILIENCE

```
You are Agent-H: CONFIG-RESILIENCE in a coordinated command center sprint.
Your job: TWO features — config revision tracking with rollback + multi-transport resilience for offline support.

PROJECT: OSA — Elixir/OTP + SvelteKit (full-stack)
WORKING DIRECTORY: /Users/roberto/Desktop/OSAMain/OSA
BRANCH: git checkout -b ws7-8/config-resilience

═══════════════════════════════════════════════════════════════════════════════
GIT RULES — CRITICAL
═══════════════════════════════════════════════════════════════════════════════
- NEVER mention Claude, AI, LLM, or any AI tool in commits, comments, or code
- NEVER add Co-Authored-By lines mentioning Claude or any AI
- Commit format: feat(config): or feat(resilience): description
- Push when done: git push -u origin ws7-8/config-resilience

═══════════════════════════════════════════════════════════════════════════════
PARALLEL EXECUTION — MANDATORY
═══════════════════════════════════════════════════════════════════════════════
Spawn 10-15 sub-agents. Two fully independent tracks.

BATCH 1 — Research (4 agents):
  1. @Explore → Read config/ directory + settingsStore.ts — config management
  2. @Explore → Read api/client.ts + sse.ts — current transport layer
  3. @Explore → Read connection.svelte.ts — connectivity handling
  4. @Explore → Read settings page + layout components

BATCH 2 — Build (10 agents, two parallel tracks):
  CONFIG VERSIONING (5):
  5. @database-specialist → config_revisions table migration
  6. @backend-go → governance/config_revisions.ex (track_change, list, rollback, diff)
  7. @api-designer → Config revision routes (list, get version, rollback, diff between versions)
  8. @frontend-svelte → ConfigHistory.svelte (timeline, diff view, rollback button)
  9. @test-automator → Tests for revision tracking, rollback correctness

  MULTI-TRANSPORT (5):
  10. @frontend-svelte → Enhance api/client.ts (withRetry + exponential backoff, response cache Map with TTL, offline request queue)
  11. @frontend-svelte → Enhance api/sse.ts (auto-reconnect with backoff, last-event-ID for resumption)
  12. @frontend-svelte → Enhance connection.svelte.ts (state machine: connected→reconnecting→offline, queue management, syncOnReconnect)
  13. @frontend-svelte → Offline UI indicators (status bar, stale data badges, queue flush progress)
  14. @frontend-svelte → Tauri store persistent cache for offline data

BATCH 3 — Review:
  15. @code-reviewer → Config rollback safety, cache invalidation correctness, reconnect edge cases

═══════════════════════════════════════════════════════════════════════════════
COMPETITOR INTELLIGENCE
═══════════════════════════════════════════════════════════════════════════════

FROM PAPERCLIP — CONFIG REVISIONS:
  Their agent_config_revisions table stores:
    agentId, revisionNumber, previousConfig (JSON), newConfig (JSON),
    changedFields (string array), changedBy, changeReason, timestamp
  Tracked fields: name, role, title, reportsTo, capabilities, adapterType,
    adapterConfig, budgetMonthlyCents, metadata
  Rollback: restore previousConfig from any revision number
  UI: timeline of changes with expandable diffs

WE STEAL: Revision table pattern, field-level diff, rollback to any version.

FROM CLAWX — GRACEFUL DEGRADATION:
  Their multi-transport API client (api-client.ts):
    Transport chain: IPC (Electron) → WebSocket (gateway) → HTTP (fallback)
    invokeIpcWithRetry() with configurable retries
    5-second backoff between transport fallbacks
    Error normalization: AUTH_INVALID, TIMEOUT, RATE_LIMIT, GATEWAY, NETWORK
    → Mapped to user-friendly messages via toUserMessage()

  Gateway connection monitor:
    Exponential backoff on reconnect: 1s → 2s → 4s → 8s → 16s → 30s cap
    Health check ping on WebSocket
    Status states: stopped → starting → running → reconnecting → error
    Auto-restart with debounce (8s window coalesces multiple restart triggers)

WE STEAL: Retry with backoff, error normalization, offline queue, graceful degradation.
WE IMPROVE: We use Tauri store for persistent cache (better than Electron's).

═══════════════════════════════════════════════════════════════════════════════
DETAILED BUILD SPECS
═══════════════════════════════════════════════════════════════════════════════

Read WS7-config-versioning.md and WS8-multi-transport.md for full specs.

Config versioning key specs:
  - config_revisions table: entity_type, entity_id, revision_number, previous_config, new_config, changed_fields, changed_by, change_reason
  - track_change/6 creates revision record
  - rollback/3 restores previous config and creates new revision noting rollback
  - diff/2 shows field-by-field comparison between two revisions

Multi-transport key specs:
  - withRetry<T>(fn, { maxRetries: 3, backoffMs: 1000, maxBackoff: 30000 })
  - Response cache: Map<string, { data, timestamp }> with configurable TTL per endpoint
  - Offline queue: Array<{ method, path, body, timestamp }> replayed on reconnect
  - Connection state machine: connected → (error) → reconnecting → (timeout) → offline → (backend returns) → connected
  - syncOnReconnect(): flush queue, refresh all active stores
  - Status bar: "Connected" | "Reconnecting (attempt 3)..." | "Offline (5 queued)"

═══════════════════════════════════════════════════════════════════════════════
TERRITORY
═══════════════════════════════════════════════════════════════════════════════
CAN MODIFY: lib/optimal_system_agent/governance/ (config_revisions.ex), lib/optimal_system_agent/channels/http/, priv/repo/migrations/, desktop/src/lib/api/client.ts, desktop/src/lib/api/sse.ts, desktop/src/lib/stores/connection.svelte.ts, desktop/src/lib/stores/settingsStore.ts, desktop/src/routes/app/settings/, desktop/src/lib/components/layout/, test/
CANNOT MODIFY: lib/optimal_system_agent/agent/loop.ex, desktop/src/lib/components/signals/, desktop/src/lib/components/tasks/

═══════════════════════════════════════════════════════════════════════════════
VERIFICATION
═══════════════════════════════════════════════════════════════════════════════
  1. mix compile --warnings-as-errors && mix test
  2. cd desktop && npm run check && npm run build
  3. Config change creates revision record
  4. Rollback restores previous config correctly
  5. Kill backend → app shows "Reconnecting..." → "Offline"
  6. Cached data shows with "stale" indicator
  7. Restart backend → auto-reconnect + queue flush
  8. Create completion report: agent-H-completion.md
```

---

## Sub-Agent Deployment Summary

| Agent | Wave | Sub-Agents | Strategy |
|-------|------|------------|----------|
| A (Backend Signals) | 1 | 11 | 5 explore → 5 build → 1 review |
| B (Frontend Signals) | 1 | 16 | 4 explore → 10 build → 2 integrate |
| C (Backend Scheduler) | 1 | 12 | 5 explore → 6 build → 1 review |
| D (Frontend Scheduler) | 1 | 12 | 4 explore → 7 build → 1 review |
| E (Budget System) | 2 | 13 | 4 explore → 8 build → 1 review |
| F (Agent Hierarchy) | 2 | 11 | 3 explore → 7 build → 1 review |
| G (Kanban + Approvals) | 3 | 18 | 4 explore → 12 build → 2 test+review |
| H (Config + Resilience) | 4 | 15 | 4 explore → 10 build → 1 review |
| **TOTAL** | | **108** | **70 discrete build tasks** |

---

## Completion Report Template

Each agent creates: `docs/agent-dispatch/sprint-competitive-integration/agent-{letter}-completion.md`

```markdown
# Agent-{X} Completion Report — {WORKSTREAM}

## Status: COMPLETE / PARTIAL / BLOCKED

## Sub-Agents Spawned: {N}
## Sub-Agent Success Rate: {N}/{total}

## Files Created
- path/to/file — description

## Files Modified
- path/to/file — what changed

## New API Endpoints
- METHOD /path — description

## New SSE Events
- event_name — payload description

## New Components (if frontend)
- Component.svelte — description

## Tests Added
- test/path/file — what's tested

## Build Verification
- [ ] mix compile --warnings-as-errors
- [ ] mix test
- [ ] npm run check (if frontend)
- [ ] npm run build (if frontend)

## Commits Made
- {hash} feat(scope): message
- {hash} feat(scope): message

## Issues / Blockers
- None / description

## Notes for Merge
- merge order dependencies or conflicts
```
