# WS3: Cost/Budget Dashboard — Build Guide

> **Agent:** BUDGET-SYSTEM (Agent-E)
> **Priority:** P1 — Depends on WS1/WS2 patterns being established
> **Scope:** Full-stack (backend + frontend)

---

## Objective

Implement Paperclip's budget enforcement model on top of OSA's existing Treasury module. Add per-agent budget caps with auto-pause, cost event tracking per task, and a budget dashboard in the Usage page.

---

## What Already Exists

### Treasury Module (Backend — Built)
- **File:** `lib/optimal_system_agent/agent/treasury.ex`
- Central balance with deposit/withdrawal/reservation/release
- Daily limit: $250, Monthly limit: $2,500
- Max single transaction: $50
- Min reserve: $10
- Events: `:treasury_deposit`, `:treasury_withdrawal`, `:treasury_reserve`, `:treasury_release`, `:treasury_limit_exceeded`

### Usage Page (Frontend — Built)
- **Page:** `desktop/src/routes/app/usage/+page.svelte`
- **Store:** `desktop/src/lib/stores/usage.svelte.ts`
- **Components:** StatCard.svelte, UsageChart.svelte
- Shows token usage metrics

### What's Missing
1. **Per-agent budgets** — Treasury is global, not per-agent
2. **Cost events table** — No persistent cost tracking per request/task
3. **Auto-pause on budget exceeded** — Treasury emits event but doesn't pause agents
4. **Budget UI** — No budget bars, alerts, or projections in Usage page
5. **Cost attribution** — Can't see which agent/task consumed what

---

## Build Plan

### Step 1: Cost Events Schema

```elixir
# priv/repo/migrations/XXXXXX_create_cost_events.exs
create table(:cost_events) do
  add :agent_name, :string, null: false
  add :session_id, :string
  add :task_id, :string
  add :provider, :string         # "anthropic", "openai", "ollama", etc.
  add :model, :string            # "claude-opus-4-6", "gpt-4o", etc.
  add :input_tokens, :integer, default: 0
  add :output_tokens, :integer, default: 0
  add :cache_read_tokens, :integer, default: 0
  add :cache_write_tokens, :integer, default: 0
  add :cost_cents, :integer, default: 0   # Cost in cents (integer for precision)
  add :metadata, :map, default: %{}
  timestamps()
end

create index(:cost_events, [:agent_name])
create index(:cost_events, [:inserted_at])
```

### Step 2: Agent Budget Extension

Add per-agent budget fields to agent configs or a new table:

```elixir
# priv/repo/migrations/XXXXXX_create_agent_budgets.exs
create table(:agent_budgets) do
  add :agent_name, :string, null: false
  add :budget_daily_cents, :integer, default: 25000    # $250 default
  add :budget_monthly_cents, :integer, default: 250000  # $2500 default
  add :spent_daily_cents, :integer, default: 0
  add :spent_monthly_cents, :integer, default: 0
  add :status, :string, default: "active"  # active, paused_budget, paused_manual
  add :last_reset_daily, :date
  add :last_reset_monthly, :date
  timestamps()
end

create unique_index(:agent_budgets, [:agent_name])
```

### Step 3: Cost Tracking Service

```
File: lib/optimal_system_agent/agent/cost_tracker.ex
```

- Subscribe to provider response events (after each LLM call)
- Create cost_event record with token counts and calculated cost
- Update agent_budgets spent counters (atomic increment)
- Check if budget exceeded → emit `:budget_exceeded` event
- Auto-pause agent if `spent >= budget` (like Paperclip)
- Daily/monthly reset logic (check on each cost event, reset if date changed)

Cost calculation:
```elixir
def calculate_cost(provider, model, input_tokens, output_tokens, cache_read, cache_write) do
  # Use provider pricing table
  # Anthropic: opus input=$15/MTok, output=$75/MTok
  # Anthropic: sonnet input=$3/MTok, output=$15/MTok
  # etc.
end
```

### Step 4: Cost API Routes

```
File: lib/optimal_system_agent/channels/http/api/cost_routes.ex
```

- `GET /api/v1/costs/summary` — Global cost summary (today, this week, this month)
- `GET /api/v1/costs/by-agent` — Per-agent cost breakdown
- `GET /api/v1/costs/by-model` — Per-model cost breakdown
- `GET /api/v1/costs/events` — Paginated cost event history
- `GET /api/v1/budgets` — All agent budgets with utilization
- `PUT /api/v1/budgets/:agent_name` — Update agent budget limits
- `POST /api/v1/budgets/:agent_name/reset` — Reset spent counters

### Step 5: Budget Dashboard UI

Enhance `desktop/src/routes/app/usage/+page.svelte`:

Add new sections:

**Budget Overview Panel:**
```
┌─────────────────────────────────────────┐
│  BUDGET STATUS                          │
│                                         │
│  Daily:   ████████░░ $187 / $250 (75%)  │
│  Monthly: ██████░░░░ $1,247 / $2,500    │
│                                         │
│  Per Agent:                             │
│  coder     ██████████ $89 / $100  ⚠️    │
│  debugger  ████░░░░░░ $42 / $100        │
│  reviewer  ██░░░░░░░░ $23 / $100        │
│  architect ███░░░░░░░ $33 / $100        │
│                                         │
│  [⚠️ = approaching limit]              │
└─────────────────────────────────────────┘
```

**Cost Breakdown:**
- By model (pie chart or bar)
- By agent (bar chart)
- Trend over time (line chart — last 7 days / 30 days)

**Budget Alerts:**
- Yellow warning at 80% utilization
- Red alert at 95% utilization
- "Agent paused" indicator when budget exceeded

### Step 6: Budget Controls

New component for budget management:
- Edit per-agent daily/monthly limits
- Manual pause/resume agents
- Reset spent counters
- View cost event history per agent

### Territory (Agent-E)
```
CAN MODIFY:
  lib/optimal_system_agent/agent/treasury.ex       # Enhance treasury
  lib/optimal_system_agent/agent/cost_tracker.ex   # New module
  lib/optimal_system_agent/channels/http/api/      # New routes
  priv/repo/migrations/                             # New migrations
  desktop/src/routes/app/usage/                     # Usage page
  desktop/src/lib/stores/usage.svelte.ts           # Usage store
  desktop/src/lib/components/usage/                 # New components (create dir)
  desktop/src/lib/api/types.ts                     # Add cost/budget types

CANNOT MODIFY:
  lib/optimal_system_agent/agent/loop.ex           # Agent loop
  lib/optimal_system_agent/providers/              # Provider internals
  desktop/src/lib/components/tasks/                # Tasks (WS2 territory)
```

---

## Verification

```bash
mix compile --warnings-as-errors && mix test
# Send a chat message, verify cost_event created
# Check budget: GET /api/v1/budgets
# Verify auto-pause: set budget to $0.01, send message, check agent paused
cd desktop && npm run check && npm run build
# Verify budget bars visible on /app/usage
```

---

## Stolen Patterns Applied

| From | Pattern | How We Apply It |
|------|---------|----------------|
| Paperclip | `budgetMonthlyCents` / `spentMonthlyCents` per agent | agent_budgets table |
| Paperclip | Auto-pause when `spent >= budget` | cost_tracker checks after each event |
| Paperclip | Cost events with token usage | cost_events table |
| Paperclip | Utilization percentage | Budget bars in UI |
| Paperclip | Cost summary by date range | /api/v1/costs/summary endpoint |
