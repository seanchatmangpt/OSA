# WS5: Kanban Task Board — Build Guide

> **Agent:** KANBAN-APPROVALS (Agent-G) — combined with WS6
> **Priority:** P2 — Depends on WS1/WS2 frontend patterns
> **Scope:** Full-stack

---

## Objective

Add a Kanban board view to the Tasks page with drag-drop status transitions. Implement Paperclip's atomic task checkout to prevent double-assignment.

---

## What Already Exists

### Tasks System (Built)
- **Backend:** `lib/optimal_system_agent/agent/tasks/` — workflow.ex, tracker.ex, queue.ex
- **Frontend Page:** `desktop/src/routes/app/tasks/+page.svelte` (14.5KB)
- **Store:** `desktop/src/lib/stores/tasks.svelte.ts`
- Task statuses: `pending`, `active`, `completed`, `failed`

### What's Missing
1. **Kanban visualization** — List view only
2. **Drag-drop status transitions** — No visual drag between columns
3. **Atomic checkout** — No prevention of double-assignment
4. **Extended status model** — Need `backlog`, `todo`, `in_progress`, `in_review`, `done`, `blocked`, `cancelled`
5. **Task assignment** — No explicit agent assignment on tasks
6. **Priority field** — No low/medium/high priority

---

## Build Plan

### Step 1: Extended Task Status Model

Update the task schema to support richer statuses:

```elixir
# Enhance existing tasks table or create migration
@valid_statuses ~w(backlog todo in_progress in_review done blocked cancelled)
@valid_priorities ~w(low medium high critical)
```

Add fields:
- `status` — Extended from 4 to 7 statuses
- `priority` — low, medium, high, critical
- `assignee_agent` — Which agent owns this task
- `checkout_lock` — Timestamp when task was checked out (for atomic checkout)

### Step 2: Atomic Checkout

Stolen from Paperclip — prevent concurrent work on same task:

```elixir
def checkout_task(task_id, agent_name) do
  # Atomic update: only checkout if status is "todo" and no lock
  case Repo.update_all(
    from(t in Task,
      where: t.id == ^task_id,
      where: t.status == "todo",
      where: is_nil(t.checkout_lock)
    ),
    set: [
      assignee_agent: agent_name,
      status: "in_progress",
      checkout_lock: DateTime.utc_now()
    ]
  ) do
    {1, _} -> {:ok, :checked_out}
    {0, _} -> {:error, :already_assigned}  # 409 Conflict
  end
end
```

### Step 3: Task API Enhancements

Add to existing task routes:
- `POST /api/v1/tasks/:id/checkout` — Atomic checkout (returns 409 if taken)
- `POST /api/v1/tasks/:id/release` — Release checkout lock
- `PUT /api/v1/tasks/:id/status` — Status transition with validation
- `PUT /api/v1/tasks/:id/priority` — Update priority
- `PUT /api/v1/tasks/:id/assign` — Assign to agent

### Step 4: Kanban Board Component

```
File: desktop/src/lib/components/tasks/KanbanBoard.svelte
```

```
┌──────────┬──────────┬──────────┬──────────┬──────────┐
│ BACKLOG  │   TODO   │IN PROGRESS│IN REVIEW │   DONE   │
│ (3)      │ (5)      │ (2)      │ (1)      │ (12)     │
├──────────┼──────────┼──────────┼──────────┼──────────┤
│┌────────┐│┌────────┐│┌────────┐│┌────────┐│┌────────┐│
││ Task A ││ │ Task D ││ │ Task G ││ │ Task I ││ │ Task J ││
││ 🟡 med ││ │ 🔴 high││ │ 🔴 high││ │ 🟡 med ││ │ 🟢 low ││
││ @coder ││ │ @debug ││ │ @arch  ││ │ @review││ │ @coder ││
│└────────┘│└────────┘│└────────┘│└────────┘│└────────┘│
│┌────────┐│┌────────┐│┌────────┐│          │┌────────┐│
││ Task B ││ │ Task E ││ │ Task H ││          ││ Task K ││
│└────────┘│└────────┘│└────────┘│          │└────────┘│
└──────────┴──────────┴──────────┴──────────┴──────────┘
```

Features:
- 5 columns (backlog, todo, in_progress, in_review, done)
- Blocked/cancelled shown separately or as badges
- Drag-drop between columns triggers status update API call
- Cards show: title (truncated), priority badge, assignee agent
- Click card → expand to full task detail
- Column counts
- Filter bar: by priority, by agent, search

Use `svelte-dnd-action` (already may be available) or native HTML5 drag-and-drop.

### Step 5: Task Card (Kanban Version)

```
File: desktop/src/lib/components/tasks/KanbanCard.svelte
```

Compact card for Kanban:
- Title (2-line clamp)
- Priority badge (colored dot: green/yellow/orange/red)
- Assignee avatar/icon
- Created date
- Drag handle
- Click to expand

### Step 6: Enhanced Tasks Page

Update `desktop/src/routes/app/tasks/+page.svelte`:
- Add view toggle: "List" | "Kanban" | "Scheduled"
- Kanban view shows KanbanBoard component
- List view shows existing task list (enhanced with priority/assignee)
- Persist view preference in settings store

### Territory (Agent-G)
```
CAN MODIFY:
  lib/optimal_system_agent/agent/tasks/          # Task modules
  lib/optimal_system_agent/channels/http/api/    # Task route enhancements
  priv/repo/migrations/                           # Schema changes
  desktop/src/routes/app/tasks/                   # Tasks page
  desktop/src/lib/stores/tasks.svelte.ts          # Tasks store
  desktop/src/lib/components/tasks/               # Task components
  desktop/src/lib/api/types.ts                    # Task type updates

Also handles WS6 (Approvals) — see WS6-approvals.md
```

---

## Verification

```bash
mix compile --warnings-as-errors && mix test
# Create task, checkout: POST /api/v1/tasks/:id/checkout
# Try checkout again → expect 409
# Drag card in Kanban → verify status change
cd desktop && npm run check && npm run build
# Verify Kanban view renders on /app/tasks
# Verify drag-drop works
# Verify atomic checkout prevents double-assign
```
