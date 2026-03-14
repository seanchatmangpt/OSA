# WS2: Task Scheduling + Agent Execution — Build Guide

> **Agent:** BACKEND-SCHEDULER (Agent-C) + FRONTEND-SCHEDULER (Agent-D)
> **Priority:** P0

---

## Objective

Enhance the existing scheduler to support ClawX-style cron presets + Paperclip-style heartbeat execution model. When a scheduled task fires, it should trigger an actual agent loop, capture the output, and stream results to the UI.

---

## What Already Exists

### Scheduler Backend (Partially Built)
- **File:** `lib/optimal_system_agent/agent/scheduler.ex`
- **Sub-modules:** `cron_engine.ex`, `heartbeat.ex`, `job_executor.ex`, `persistence.ex`, `sqlite_store.ex`
- Features: HEARTBEAT.md monitoring, CRONS.json parsing, TRIGGERS.json event-driven automation
- Circuit breaker: 3 consecutive failures = auto-disable
- 1-minute cron tick resolution

### Tasks Backend (Built)
- **Location:** `lib/optimal_system_agent/agent/tasks/`
- `workflow.ex` (20.6KB) — LLM-decomposed multi-step workflows
- `tracker.ex` (13.8KB) — Per-session checklist with dependencies
- `queue.ex` (13KB) — Persistent job queue with SQLite backing
- `persistence.ex` — State persistence

### Tasks Frontend (Built)
- **Page:** `desktop/src/routes/app/tasks/+page.svelte` (14.5KB)
- **Store:** `desktop/src/lib/stores/tasks.svelte.ts`
- **Scheduled Tasks Store:** `desktop/src/lib/stores/scheduledTasks.svelte.ts`
- **Components:** TaskCard.svelte (13.1KB), ScheduledTaskCard.svelte (12KB), ScheduledTaskForm.svelte (12.9KB), TaskCheckbox.svelte

### What's Missing
1. **Cron preset UI** — ClawX has 8 presets with human-readable preview; we need this
2. **Heartbeat execution model** — Paperclip's wake → execute → capture → persist pattern
3. **Execution output capture** — Run results aren't persisted or streamed back
4. **Run history** — No way to see past execution results per scheduled task
5. **Agent-bound scheduling** — Tasks should specify which agent handles them
6. **Test harness** — Automated test execution with result dashboard

---

## Agent-C: BACKEND-SCHEDULER — Build Plan

### Step 1: Execution Run Schema

```elixir
# priv/repo/migrations/XXXXXX_create_scheduled_runs.exs
create table(:scheduled_runs) do
  add :scheduled_task_id, :string, null: false
  add :agent_name, :string
  add :status, :string, default: "pending"  # pending, running, succeeded, failed, timed_out, cancelled
  add :trigger_type, :string               # schedule, manual, event, assignment
  add :started_at, :utc_datetime
  add :completed_at, :utc_datetime
  add :exit_code, :integer
  add :stdout, :text                       # Captured output (compressed if large)
  add :stderr, :text
  add :token_usage, :map, default: %{}     # {input: N, output: N, cost_cents: N}
  add :session_state, :map, default: %{}   # For persistent agent state across runs
  add :error_message, :text
  add :metadata, :map, default: %{}
  timestamps()
end

create index(:scheduled_runs, [:scheduled_task_id])
create index(:scheduled_runs, [:status])
create index(:scheduled_runs, [:inserted_at])
```

### Step 2: Heartbeat Execution Module

```
File: lib/optimal_system_agent/agent/scheduler/heartbeat_executor.ex
```

Paperclip's heartbeat protocol adapted for Elixir:

```elixir
defmodule OptimalSystemAgent.Agent.Scheduler.HeartbeatExecutor do
  @moduledoc """
  Executes scheduled tasks by waking an agent, running a loop iteration,
  capturing output, and persisting results. Adapted from Paperclip's
  heartbeat model.
  """

  # Flow:
  # 1. Create run record (status: "running")
  # 2. Acquire agent startup lock (prevent concurrent runs on same agent)
  # 3. Check budget (Treasury) — abort if exceeded
  # 4. Build agent context with task prompt + session state from last run
  # 5. Execute agent loop (single iteration or multi-step)
  # 6. Capture stdout, token usage, session state
  # 7. Update run record (status: "succeeded" | "failed")
  # 8. Persist session state for next heartbeat
  # 9. Emit SSE event: task:run_complete
  # 10. Check budget post-run — auto-pause if exceeded
end
```

Key features:
- **Startup lock:** Per-agent mutex prevents concurrent heartbeats (GenServer-based)
- **Max concurrent runs:** Configurable per agent (default 1, max 10)
- **Session persistence:** Store agent session state between runs (like Paperclip's sessionCodec)
- **Budget enforcement:** Check Treasury before and after execution
- **Timeout:** Configurable per task (default 5 minutes, max 30 minutes)
- **Circuit breaker:** Already exists — 3 consecutive failures = auto-disable

### Step 3: Enhanced Cron Presets

```
File: lib/optimal_system_agent/agent/scheduler/cron_presets.ex
```

Stolen from ClawX — 8 standard presets:

```elixir
@presets [
  %{id: "every_minute",    cron: "* * * * *",     label: "Every minute"},
  %{id: "every_5_minutes", cron: "*/5 * * * *",   label: "Every 5 minutes"},
  %{id: "every_15_minutes",cron: "*/15 * * * *",  label: "Every 15 minutes"},
  %{id: "every_30_minutes",cron: "*/30 * * * *",  label: "Every 30 minutes"},
  %{id: "hourly",          cron: "0 * * * *",     label: "Every hour"},
  %{id: "daily_9am",       cron: "0 9 * * *",     label: "Daily at 9:00 AM"},
  %{id: "weekly_monday",   cron: "0 9 * * 1",     label: "Weekly on Monday at 9:00 AM"},
  %{id: "monthly_first",   cron: "0 9 1 * *",     label: "Monthly on the 1st at 9:00 AM"}
]

# Human-readable cron description
def describe("*/5 * * * *"), do: "Every 5 minutes"
def describe("0 9 * * 1-5"), do: "Weekdays at 9:00 AM"
# ... pattern match common expressions, fallback to generic parser
```

### Step 4: Scheduled Task API Routes

```
File: lib/optimal_system_agent/channels/http/api/scheduler_routes.ex
```

New/enhanced endpoints:
- `GET /api/v1/scheduled-tasks` — List all scheduled tasks with last run info
- `POST /api/v1/scheduled-tasks` — Create scheduled task (with agent assignment)
- `PUT /api/v1/scheduled-tasks/:id` — Update task (cron, agent, prompt)
- `DELETE /api/v1/scheduled-tasks/:id` — Delete task
- `POST /api/v1/scheduled-tasks/:id/trigger` — Manual trigger (run now)
- `PUT /api/v1/scheduled-tasks/:id/toggle` — Enable/disable
- `GET /api/v1/scheduled-tasks/:id/runs` — Run history for a task
- `GET /api/v1/scheduled-tasks/:id/runs/:run_id` — Single run details + output
- `GET /api/v1/scheduled-tasks/:id/runs/:run_id/stream` — SSE stream of running task output
- `GET /api/v1/cron-presets` — Return available presets

### Step 5: SSE Events for Task Execution

Add to existing event stream:
- `task:run_started` — { task_id, run_id, agent_name, trigger_type }
- `task:run_output` — { run_id, chunk } (streaming stdout)
- `task:run_completed` — { run_id, status, duration_ms, token_usage }
- `task:run_failed` — { run_id, error_message }

### Territory (Agent-C)
```
CAN MODIFY:
  lib/optimal_system_agent/agent/scheduler/   # Scheduler modules
  lib/optimal_system_agent/agent/scheduler.ex # Main scheduler
  lib/optimal_system_agent/channels/http/api/ # New routes
  lib/optimal_system_agent/channels/http.ex   # Router
  priv/repo/migrations/                        # New migration

CANNOT MODIFY:
  desktop/                                     # Frontend (Agent-D's territory)
  lib/optimal_system_agent/agent/loop.ex      # Agent loop (too risky)
  lib/optimal_system_agent/agent/treasury.ex  # Treasury (WS3's territory)
```

---

## Agent-D: FRONTEND-SCHEDULER — Build Plan

### Step 1: Enhanced Scheduled Tasks Store

```
File: desktop/src/lib/stores/scheduledTasks.svelte.ts (enhance existing)
```

Add:
- `fetchPresets()` — load cron presets from API
- `triggerNow(taskId)` — manual trigger
- `fetchRuns(taskId)` — load run history
- `streamRun(runId)` — SSE subscription for live output
- Run state: `runs: Record<string, ScheduledRun[]>`

```typescript
interface ScheduledRun {
  id: string;
  scheduled_task_id: string;
  agent_name: string;
  status: 'pending' | 'running' | 'succeeded' | 'failed' | 'timed_out' | 'cancelled';
  trigger_type: 'schedule' | 'manual' | 'event' | 'assignment';
  started_at: string;
  completed_at?: string;
  duration_ms?: number;
  stdout?: string;
  token_usage?: { input: number; output: number; cost_cents: number };
  error_message?: string;
}
```

### Step 2: Enhanced ScheduledTaskForm

Enhance existing `desktop/src/lib/components/tasks/ScheduledTaskForm.svelte`:

Add stolen from ClawX:
- **Preset selector:** 8 radio buttons for common schedules
- **Custom toggle:** Switch between preset / custom cron expression
- **Human-readable preview:** Show next run time + schedule description
- **Agent selector:** Dropdown to pick which agent handles the task
- **Timeout setting:** How long the task can run before killing
- **Max retries:** How many times to retry on failure

### Step 3: Enhanced ScheduledTaskCard

Enhance existing `desktop/src/lib/components/tasks/ScheduledTaskCard.svelte`:

Add stolen from ClawX:
- **Last run indicator:** Green checkmark or red X with timestamp
- **Next run time:** Countdown or absolute time
- **Run history mini-view:** Last 5 runs as colored dots (green=success, red=fail)
- **Hover actions:** "Run Now" + "Edit" + "Disable" + "Delete"
- **Error message display:** If last run failed, show error inline

### Step 4: Run Detail Panel

```
New file: desktop/src/lib/components/tasks/RunDetail.svelte
```

- Shows full output of a specific run
- Live streaming view when run is in progress
- Token usage breakdown
- Duration, trigger type, agent info
- Error details if failed
- "Re-run" button

### Step 5: Run History View

```
New file: desktop/src/lib/components/tasks/RunHistory.svelte
```

- Paginated list of past runs for a scheduled task
- Status badge, duration, trigger type, timestamp
- Click to expand → RunDetail
- Filter by status (succeeded/failed)

### Step 6: Tasks Page Enhancement

Enhance `desktop/src/routes/app/tasks/+page.svelte`:
- Add tabs or toggle: "Active Tasks" | "Scheduled Tasks" | "Run History"
- Scheduled Tasks tab shows enhanced cards with run history
- Run History tab shows all runs across all tasks (global view)

### Territory (Agent-D)
```
CAN MODIFY:
  desktop/src/routes/app/tasks/              # Tasks page
  desktop/src/lib/stores/scheduledTasks.svelte.ts  # Scheduled tasks store
  desktop/src/lib/components/tasks/          # Task components
  desktop/src/lib/api/types.ts               # Add run types

CANNOT MODIFY:
  lib/                                        # Backend (Agent-C's territory)
  desktop/src/lib/stores/tasks.svelte.ts     # Active tasks store (separate concern)
```

---

## Verification

```bash
# Backend
mix compile --warnings-as-errors
mix test
# Create a scheduled task: POST /api/v1/scheduled-tasks with cron "*/1 * * * *"
# Wait 1 minute, verify: GET /api/v1/scheduled-tasks/:id/runs shows a run
# Manual trigger: POST /api/v1/scheduled-tasks/:id/trigger
# Verify run output: GET /api/v1/scheduled-tasks/:id/runs/:run_id

# Frontend
cd desktop && npm run check && npm run build
# Verify: Tasks page has Scheduled Tasks tab
# Verify: Can create scheduled task with preset
# Verify: Can see run history
# Verify: Manual "Run Now" works and shows live output
```

---

## Stolen Patterns Applied

| From | Pattern | How We Apply It |
|------|---------|----------------|
| ClawX | 8 cron presets + custom toggle | Preset selector in ScheduledTaskForm |
| ClawX | Human-readable schedule preview | Next run time + description text |
| ClawX | Hover-activated "Run Now" + "Delete" | On ScheduledTaskCard hover |
| Paperclip | Heartbeat execution model | HeartbeatExecutor with wake → execute → capture |
| Paperclip | Persistent agent state across runs | session_state in scheduled_runs table |
| Paperclip | Atomic execution (startup lock) | Per-agent GenServer lock |
| Paperclip | Budget enforcement at heartbeat time | Treasury check before/after run |
| Paperclip | Run result capture (stdout, usage, cost) | Full capture in scheduled_runs |
