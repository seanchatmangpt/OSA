# WS7: Config Versioning — Build Guide

> **Agent:** CONFIG-RESILIENCE (Agent-H) — combined with WS8
> **Priority:** P3 — Depends on all previous workstreams
> **Scope:** Full-stack

---

## Objective

Implement Paperclip's config revision tracking. Every change to agent configs, system settings, or critical parameters gets versioned. Enable rollback to any previous version.

---

## What Already Exists

### Configuration System
- **Backend:** `config/` directory with Elixir config files
- **Frontend:** `desktop/src/lib/stores/settingsStore.ts`
- Agent configs defined in individual agent modules
- No revision tracking

---

## Build Plan

### Step 1: Config Revisions Schema

```elixir
create table(:config_revisions) do
  add :entity_type, :string, null: false   # "agent", "system", "scheduler", "budget"
  add :entity_id, :string, null: false     # agent name, "global", etc.
  add :revision_number, :integer, null: false
  add :previous_config, :map              # Snapshot of old config
  add :new_config, :map                   # Snapshot of new config
  add :changed_fields, {:array, :string}  # Which fields changed
  add :changed_by, :string               # "user", "system", agent name
  add :change_reason, :text              # Optional reason
  add :metadata, :map, default: %{}
  timestamps()
end

create index(:config_revisions, [:entity_type, :entity_id])
create unique_index(:config_revisions, [:entity_type, :entity_id, :revision_number])
```

### Step 2: Config Revision Service

```
File: lib/optimal_system_agent/governance/config_revisions.ex
```

- `track_change(entity_type, entity_id, old_config, new_config, changed_by, reason)` — Create revision
- `list_revisions(entity_type, entity_id)` — Revision history
- `get_revision(entity_type, entity_id, revision_number)` — Specific version
- `rollback(entity_type, entity_id, revision_number)` — Restore previous config
- `diff(revision_a, revision_b)` — Show what changed between versions

Fields tracked for agents (stolen from Paperclip):
```elixir
@tracked_fields ~w(name tier role system_prompt skills tools
                    budget_daily_cents budget_monthly_cents
                    reports_to org_role title)
```

### Step 3: Config Revision API Routes

- `GET /api/v1/config/revisions/:entity_type/:entity_id` — List revisions
- `GET /api/v1/config/revisions/:entity_type/:entity_id/:number` — Specific revision
- `POST /api/v1/config/revisions/:entity_type/:entity_id/rollback` — Rollback to version
- `GET /api/v1/config/revisions/:entity_type/:entity_id/diff` — Diff between versions

### Step 4: Integration Points

Wire revision tracking into:
- Agent config changes (hierarchy, budget, role updates)
- System settings changes
- Scheduler config changes
- Automatic — wraps existing update functions

### Step 5: Config History UI

Add "History" tab to Settings page and Agent detail views:
- Timeline of changes with diffs
- "Rollback to this version" button per revision
- Who changed what, when
- Expandable diff view (old vs new)

### Territory (Agent-H — shared with WS8)
```
CAN MODIFY:
  lib/optimal_system_agent/governance/           # Governance modules
  lib/optimal_system_agent/channels/http/api/    # New routes
  priv/repo/migrations/                           # New migration
  desktop/src/routes/app/settings/               # Settings page enhancement
  desktop/src/lib/stores/settingsStore.ts        # Settings store enhancement

CANNOT MODIFY:
  lib/optimal_system_agent/agent/loop.ex         # Agent loop
  desktop/src/lib/components/signals/            # WS1 territory
  desktop/src/lib/components/tasks/              # WS2/WS5 territory
```
