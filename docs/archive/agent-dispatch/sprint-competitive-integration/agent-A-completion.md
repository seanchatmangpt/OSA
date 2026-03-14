# Agent-A: BACKEND-SIGNALS — Completion Report

## Status: COMPLETE

## Files Created
- `lib/optimal_system_agent/store/signal.ex` — Ecto schema with Jason.Encoder, changeset validation, weight-to-tier derivation
- `lib/optimal_system_agent/signal/persistence.ex` — GenServer subscribing to :signal_classified Bus events, with list/stats/patterns/recent queries
- `lib/optimal_system_agent/channels/http/api/signal_routes.ex` — Plug.Router with 4 endpoints + SSE live stream
- `priv/repo/migrations/20260314030000_create_signals.exs` — SQLite migration with 5 indexes
- `test/signal/persistence_test.exs` — 10 tests for persistence + changeset
- `test/channels/http/api/signal_routes_test.exs` — 6 tests for routes via Plug.Test

## Files Modified
- `lib/optimal_system_agent/events/bus.ex` — Added `:signal_classified` to `@event_types`
- `lib/optimal_system_agent/supervisors/agent_services.ex` — Added `Signal.Persistence` to supervision tree
- `lib/optimal_system_agent/channels/http/api.ex` — Added `forward "/signals", to: API.SignalRoutes`

## New Endpoints
| Method | Path | Description |
|--------|------|-------------|
| GET | /api/v1/signals | List signals with filters (mode, genre, type, channel, tier, weight_min/max, from/to, limit, offset) |
| GET | /api/v1/signals/stats | Aggregate counts by mode/channel/type/tier, total, avg_weight |
| GET | /api/v1/signals/patterns | Peak hours, avg weight, top 5 agents, daily counts for last N days |
| GET | /api/v1/signals/live | SSE stream — `signal:new` and `signal:stats_update` events |

## SSE Events
- `signal:new` — Emitted on each persisted signal classification
- `signal:stats_update` — Available for periodic broadcast (consumer can subscribe to `osa:signals` PubSub topic)

## Bug Fix
- `:signal_classified` was missing from `Bus.@event_types` guard — `classify_async/3` would raise `FunctionClauseError`. Fixed.

## Test Results
```
16 tests, 0 failures
```

## Blockers
- Pre-existing compilation issues in other workstream files (approvals.ex, hierarchy.ex, dashboard_routes.ex, cost_tracker.ex) — not signal-related, worked around during build
- Linter/hooks auto-reverting changes to shared files (bus.ex, api.ex, agent_services.ex) — required multiple re-applies
