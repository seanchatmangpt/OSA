# Agent-C: Backend Scheduler — Completion Report

## Branch: ws2/backend-scheduler

## Deliverables

### 1. Migration: `scheduled_runs` table
**File:** `priv/repo/migrations/20260314000004_create_scheduled_runs.exs`

Columns: scheduled_task_id, agent_name, status, trigger_type, started_at, completed_at, duration_ms, exit_code, stdout, stderr, token_usage (map), session_state (map), error_message, metadata (map), timestamps.
Indexes: scheduled_task_id, status, inserted_at.

### 2. HeartbeatExecutor
**File:** `lib/optimal_system_agent/agent/scheduler/heartbeat_executor.ex`

GenServer with:
- Per-agent mutex lock (prevents concurrent runs)
- Circuit breaker (3 consecutive failures → auto-disable, reset_failures/1 to re-enable)
- Budget check via Treasury.get_balance/0 (graceful fallback if unavailable)
- Execution via Task.async + Task.yield/shutdown (proper OTP supervision)
- Output capture with gzip compression for > 10KB
- Run persistence to scheduled_runs table
- SSE events: task_run_started, task_run_completed, task_run_failed

### 3. CronPresets
**File:** `lib/optimal_system_agent/agent/scheduler/cron_presets.ex`

8 presets with describe/1 (human-readable) and next_run/1 (DateTime calculation).

### 4. Scheduler Routes
**File:** `lib/optimal_system_agent/channels/http/api/scheduler_routes.ex`
**Prefix:** `/api/v1/scheduled-tasks`

| Method | Path                     | Description                    |
|--------|--------------------------|--------------------------------|
| GET    | /                        | List tasks with next_run       |
| POST   | /                        | Create task                    |
| PUT    | /:id                     | Update task                    |
| DELETE | /:id                     | Delete task                    |
| POST   | /:id/trigger             | Run now via HeartbeatExecutor  |
| PUT    | /:id/toggle              | Enable/disable                 |
| GET    | /:id/runs                | Paginated run history          |
| GET    | /:id/runs/:run_id        | Single run with stdout         |
| GET    | /:id/runs/:run_id/stream | SSE stream of running output   |
| GET    | /presets                 | 8 cron presets with next_run   |

### 5. SSE Events
- task_run_started → { task_id, run_id, agent_name, trigger_type }
- task_run_completed → { run_id, status, duration_ms, token_usage }
- task_run_failed → { run_id, error_message }

### 6. Tests
- cron_presets_test.exs — 8 tests (presets, describe, next_run)
- heartbeat_executor_test.exs — 15 tests (init, locks, circuit breaker, failure tracking, API)
- scheduler_routes_test.exs — 10 tests (presets, CRUD, runs, 404s)
