# WS6: Approval & Governance — Build Guide

> **Agent:** KANBAN-APPROVALS (Agent-G) — combined with WS5
> **Priority:** P2 — Depends on WS1/WS2
> **Scope:** Full-stack

---

## Objective

Implement Paperclip's approval workflow. Certain actions require explicit human approval before executing. Build an Approvals page and integrate approval gates into agent operations.

---

## What Already Exists

### Permission System (Partial)
- **Frontend:** `desktop/src/lib/stores/permissions.svelte.ts`
- **Components:** PermissionDialog.svelte, PermissionOverlay.svelte
- The concept of permission gating exists (for tool execution)

### What's Missing
1. **Approvals table** — No persistent approval workflow
2. **Approval gates** — No actions requiring board approval
3. **Approvals page** — No dedicated UI
4. **Approval resolution** — No approve/reject/request-revision flow

---

## Build Plan

### Step 1: Approvals Schema

```elixir
create table(:approvals) do
  add :type, :string, null: false    # "agent_create", "budget_change", "task_reassign", "strategy_change", "agent_terminate"
  add :status, :string, default: "pending"  # pending, approved, rejected, revision_requested
  add :title, :string, null: false
  add :description, :text
  add :requested_by, :string         # Agent name or "system"
  add :resolved_by, :string          # User who approved/rejected
  add :resolved_at, :utc_datetime
  add :decision_notes, :text
  add :context, :map, default: %{}   # Arbitrary context (what's being approved)
  add :related_entity_type, :string  # "agent", "task", "budget"
  add :related_entity_id, :string
  timestamps()
end

create index(:approvals, [:status])
create index(:approvals, [:type])
```

### Step 2: Approval Service

```
File: lib/optimal_system_agent/governance/approvals.ex
```

- `create_approval(type, title, description, context)` — Create pending approval
- `resolve(approval_id, decision, notes, resolved_by)` — Approve/reject
- `list_pending()` — All pending approvals
- `list_all(filters)` — Filtered approval history
- `requires_approval?(action_type)` — Check if action needs approval

Approval gates (configurable):
- Agent creation → requires approval
- Budget increase > 50% → requires approval
- Agent termination → requires approval
- Task reassignment from active agent → requires approval

### Step 3: Approval API Routes

```
File: lib/optimal_system_agent/channels/http/api/approval_routes.ex
```

- `GET /api/v1/approvals` — List all (filter by status, type)
- `GET /api/v1/approvals/pending` — Pending count + list
- `POST /api/v1/approvals/:id/approve` — Approve with notes
- `POST /api/v1/approvals/:id/reject` — Reject with notes
- `POST /api/v1/approvals/:id/request-revision` — Request changes

### Step 4: Approval Integration Points

Wire approval checks into:
1. **Agent creation** — When programmatically creating agents, check if approval needed
2. **Treasury budget changes** — Large budget increases trigger approval
3. **Agent pause/terminate** — Shutting down an active agent triggers approval
4. **SSE events** — `approval:created`, `approval:resolved`

### Step 5: Approvals Page

```
File: desktop/src/routes/app/approvals/+page.svelte
```

```
┌─────────────────────────────────────────────────┐
│  APPROVALS                     [3 pending] 🔴   │
│                                                  │
│  ┌─────────────────────────────────────────────┐ │
│  │ 🟡 PENDING — Create Agent "security-bot"    │ │
│  │ Requested by: architect | 2 hours ago       │ │
│  │ [Approve] [Reject] [Request Revision]       │ │
│  └─────────────────────────────────────────────┘ │
│  ┌─────────────────────────────────────────────┐ │
│  │ 🟡 PENDING — Increase coder budget to $500  │ │
│  │ Requested by: system | 1 hour ago           │ │
│  │ [Approve] [Reject] [Request Revision]       │ │
│  └─────────────────────────────────────────────┘ │
│  ┌─────────────────────────────────────────────┐ │
│  │ ✅ APPROVED — Terminate idle-worker agent    │ │
│  │ Approved by: operator | Yesterday           │ │
│  │ Notes: "Agent has been idle for 7 days"     │ │
│  └─────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────┘
```

### Step 6: Sidebar Badge

Add pending approval count badge to sidebar nav item (like unread notifications).

### Step 7: Approval Store

```
File: desktop/src/lib/stores/approvals.svelte.ts
```

- `pendingCount` — derived count of pending approvals
- `fetchApprovals(filters)` — load from API
- `approve(id, notes)` / `reject(id, notes)` — resolution actions
- SSE subscription for real-time updates

### Territory (Agent-G — shared with WS5)
```
CAN MODIFY:
  lib/optimal_system_agent/governance/           # New governance module
  lib/optimal_system_agent/channels/http/api/    # New routes
  priv/repo/migrations/                           # New migration
  desktop/src/routes/app/approvals/              # New page
  desktop/src/lib/stores/approvals.svelte.ts     # New store
  desktop/src/lib/components/approvals/          # New components
  desktop/src/lib/components/layout/Sidebar.svelte  # Badge

CANNOT MODIFY:
  lib/optimal_system_agent/agent/loop.ex         # Agent loop
  desktop/src/lib/components/signals/            # WS1 territory
```

---

## Verification

```bash
mix compile --warnings-as-errors && mix test
# Create approval: verify it appears in GET /api/v1/approvals/pending
# Approve it: POST /api/v1/approvals/:id/approve
# Verify resolved
cd desktop && npm run check && npm run build
# Verify /app/approvals page loads
# Verify pending count badge in sidebar
```
