# DISPATCH — Sprint: Competitive Integration

> **Sprint:** Competitive Integration (ClawX + Paperclip → OSA)
> **Agents:** 8 (A through H)
> **Waves:** 4
> **Working Directory:** `/Users/roberto/Desktop/OSAMain/OSA`

---

## Wave Structure

```
WAVE 1 — Foundation (parallel, no dependencies)
  Agent-A: BACKEND-SIGNALS     → WS1 backend
  Agent-B: FRONTEND-SIGNALS    → WS1 frontend
  Agent-C: BACKEND-SCHEDULER   → WS2 backend
  Agent-D: FRONTEND-SCHEDULER  → WS2 frontend

WAVE 2 — Budget + Hierarchy (depends on Wave 1 patterns)
  Agent-E: BUDGET-SYSTEM       → WS3 full-stack
  Agent-F: AGENT-HIERARCHY     → WS4 full-stack

WAVE 3 — Advanced UI (depends on Wave 1+2)
  Agent-G: KANBAN-APPROVALS    → WS5 + WS6 full-stack

WAVE 4 — Resilience (depends on all above)
  Agent-H: CONFIG-RESILIENCE   → WS7 + WS8 full-stack
```

---

## Merge Order

1. Agent-A (BACKEND-SIGNALS) — schema + routes first
2. Agent-C (BACKEND-SCHEDULER) — scheduler enhancements
3. Agent-B (FRONTEND-SIGNALS) — needs Agent-A's API
4. Agent-D (FRONTEND-SCHEDULER) — needs Agent-C's API
5. Agent-E (BUDGET-SYSTEM) — full-stack, references WS1/WS2 patterns
6. Agent-F (AGENT-HIERARCHY) — full-stack, references agent system
7. Agent-G (KANBAN-APPROVALS) — full-stack, references all previous
8. Agent-H (CONFIG-RESILIENCE) — full-stack, final integration layer

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

# Full
cd /Users/roberto/Desktop/OSAMain/OSA && mix compile --warnings-as-errors && mix test && cd desktop && npm run check && npm run build
```

---

## Agent Status Tracking

| Agent | Workstream | Wave | Status | Branch |
|-------|-----------|------|--------|--------|
| A | WS1-backend-signals | 1 | 🔴 NOT STARTED | `ws1/backend-signals` |
| B | WS1-frontend-signals | 1 | 🔴 NOT STARTED | `ws1/frontend-signals` |
| C | WS2-backend-scheduler | 1 | 🔴 NOT STARTED | `ws2/backend-scheduler` |
| D | WS2-frontend-scheduler | 1 | 🔴 NOT STARTED | `ws2/frontend-scheduler` |
| E | WS3-budget-system | 2 | 🔴 NOT STARTED | `ws3/budget-system` |
| F | WS4-agent-hierarchy | 2 | 🔴 NOT STARTED | `ws4/agent-hierarchy` |
| G | WS5-WS6-kanban-approvals | 3 | 🔴 NOT STARTED | `ws5-6/kanban-approvals` |
| H | WS7-WS8-config-resilience | 4 | 🔴 NOT STARTED | `ws7-8/config-resilience` |
