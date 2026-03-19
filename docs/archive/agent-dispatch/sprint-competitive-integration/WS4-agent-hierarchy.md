# WS4: Agent Hierarchy & Org View — Build Guide

> **Agent:** AGENT-HIERARCHY (Agent-F)
> **Priority:** P1 — Depends on WS1/WS2 patterns
> **Scope:** Full-stack

---

## Objective

Add Paperclip's `reportsTo` org tree concept to OSA's agent system. Create a visual org chart on the Agents page with drag-drop restructuring. Enable delegation flows (agent escalates to manager).

---

## What Already Exists

### Agents Backend (Built)
- **Location:** `lib/optimal_system_agent/agents/` — 32 agent modules
- **Specs:** `priv/agents/` — markdown specifications per agent
- Agent tiers: `:elite`, `:specialist`, `:utility`
- Agent roles: `:lead`, `:specialist`, `:reviewer`
- AgentBehaviour: `name/0`, `description/0`, `tier/0`, `role/0`, `system_prompt/0`, `skills/0`

### Agents Frontend (Built)
- **Page:** `desktop/src/routes/app/agents/+page.svelte`
- **Store:** `desktop/src/lib/stores/agents.svelte.ts`
- Shows agent list with status

### What's Missing
1. **`reports_to` field** — No hierarchy relationship between agents
2. **Org chart visualization** — Flat list only
3. **Delegation flow** — Agents can't escalate to a manager
4. **Role assignment** — No CEO/manager/engineer role model
5. **Drag-drop restructuring** — Can't visually rearrange hierarchy

---

## Build Plan

### Step 1: Agent Hierarchy Schema

```elixir
# priv/repo/migrations/XXXXXX_create_agent_hierarchy.exs
create table(:agent_hierarchy) do
  add :agent_name, :string, null: false
  add :reports_to, :string          # null = top-level (CEO equivalent)
  add :org_role, :string, default: "engineer"  # ceo, manager, lead, engineer, specialist
  add :title, :string               # Custom title: "Chief Architect", "Security Lead"
  add :org_order, :integer, default: 0  # Sort order within same level
  add :can_delegate_to, {:array, :string}, default: []  # Agents this one can delegate work to
  add :metadata, :map, default: %{}
  timestamps()
end

create unique_index(:agent_hierarchy, [:agent_name])
create index(:agent_hierarchy, [:reports_to])
```

### Step 2: Hierarchy Service

```
File: lib/optimal_system_agent/agents/hierarchy.ex
```

Functions:
- `get_tree()` — Build full org tree from flat records
- `get_reports(agent_name)` — Direct reports for an agent
- `get_chain(agent_name)` — Management chain up to root
- `move_agent(agent_name, new_reports_to)` — Reparent (validate no cycles)
- `set_role(agent_name, role)` — Update org role
- `delegate(from_agent, to_agent, task)` — Create delegation (validates to_agent is in can_delegate_to or direct report)
- `seed_defaults()` — Seed default hierarchy based on agent tiers:
  - `master_orchestrator` → CEO (reports_to: nil)
  - `architect` → CTO (reports_to: master_orchestrator)
  - Elite agents → Directors (report to architect)
  - Specialist agents → Engineers (report to relevant elite)
  - Utility agents → Support (report to relevant specialist)

### Step 3: Hierarchy API Routes

```
File: lib/optimal_system_agent/channels/http/api/hierarchy_routes.ex
```

- `GET /api/v1/agents/hierarchy` — Full org tree
- `PUT /api/v1/agents/hierarchy/:agent_name` — Update position (reports_to, role, title)
- `POST /api/v1/agents/hierarchy/seed` — Seed default hierarchy
- `POST /api/v1/agents/hierarchy/:agent_name/delegate` — Delegate task to report

### Step 4: Delegation Integration

When an agent encounters a task outside its expertise:
1. Check `can_delegate_to` list
2. Find appropriate agent by skill match
3. Create delegation signal (new signal type: `delegation`)
4. Log in activity feed
5. Track delegation chain for auditability

### Step 5: Org Chart Component

```
File: desktop/src/lib/components/agents/OrgChart.svelte
```

Visual org tree rendering:
- Tree layout with lines connecting managers to reports
- Each node shows: agent icon, name, role badge, status indicator
- Drag-drop to reparent agents (updates via API)
- Click node to view agent details
- Collapsible sub-trees for large org charts

Use CSS grid/flexbox for layout (no external drag-drop library needed for tree — use native drag events or a small library like `svelte-dnd-action`).

### Step 6: Enhanced Agents Page

Enhance `desktop/src/routes/app/agents/+page.svelte`:
- Add view toggle: "List" | "Org Chart"
- List view: existing flat list (enhanced with role/title badges)
- Org Chart view: new OrgChart component
- "Seed Default Hierarchy" button (for first-time setup)

### Territory (Agent-F)
```
CAN MODIFY:
  lib/optimal_system_agent/agents/hierarchy.ex    # New module
  lib/optimal_system_agent/channels/http/api/     # New routes
  priv/repo/migrations/                            # New migration
  desktop/src/routes/app/agents/                   # Agents page
  desktop/src/lib/stores/agents.svelte.ts          # Agents store
  desktop/src/lib/components/agents/               # New components (create dir)
  desktop/src/lib/api/types.ts                     # Add hierarchy types

CANNOT MODIFY:
  lib/optimal_system_agent/agents/*.ex             # Individual agent modules
  lib/optimal_system_agent/agent/loop.ex           # Agent loop
  desktop/src/lib/components/tasks/                # Tasks (WS2 territory)
```

---

## Verification

```bash
mix compile --warnings-as-errors && mix test
# Seed hierarchy: POST /api/v1/agents/hierarchy/seed
# Get tree: GET /api/v1/agents/hierarchy
# Move agent: PUT /api/v1/agents/hierarchy/debugger { "reports_to": "architect" }
cd desktop && npm run check && npm run build
# Verify org chart renders on /app/agents
# Verify drag-drop reparenting works
```

---

## Stolen Patterns Applied

| From | Pattern | How We Apply It |
|------|---------|----------------|
| Paperclip | `reportsTo` strict tree hierarchy | agent_hierarchy table with reports_to |
| Paperclip | Drag-drop org chart | OrgChart.svelte with native drag events |
| Paperclip | Role-based org (ceo, manager, engineer) | org_role field |
| Paperclip | Delegation flows up org chart | delegate() function with chain tracking |
| Paperclip | Agent title customization | title field ("Chief Architect") |
