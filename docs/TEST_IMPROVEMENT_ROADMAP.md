# Test Improvement Roadmap: Reducing 449 --no-start Failures

**Goal:** Make `mix test --no-start` more useful for fast feedback loops
**Current State:** 6,095 tests executed, 449 failures, 365 skips
**Target State:** <50 failures in --no-start mode, all legitimate validation tests

---

## The Problem

When running `mix test --no-start`, you get 449 failures because infrastructure isn't available:
- Ecto database (140 failures)
- GenServer processes (100+ failures)
- Phoenix.PubSub (449 failures in one file)
- ETS tables (30+ failures)

**These aren't bugs — they're expected failures.** But they clutter the output.

---

## Top 10 Priority Improvements

### PRIORITY 1: Move EventStream Tests to Integration (BIG WIN)
**Impact:** 449 failures → 0
**Effort:** 1-2 hours
**Risk:** LOW

**Current:** `test/optimal_system_agent/event_stream_test.exs` — 400+ tests with `@moduletag :integration` but some tests run in `--no-start` and fail

**Problem:** EventStream broadcasts to Phoenix.PubSub, which isn't available in --no-start. Tests fail waiting for registry.

**Solution:**
```bash
# Check if already tagged
grep "@moduletag :integration" test/optimal_system_agent/event_stream_test.exs

# If not, add to top of file:
# @moduletag :integration
```

**Verification:**
```bash
mix test --no-start --exclude integration 2>&1 | grep event_stream  # Should be 0
mix test --include integration test/optimal_system_agent/event_stream_test.exs  # Should all pass
```

**Why this is priority #1:** Removes 449 failures in one action.

---

### PRIORITY 2: Tag Ecto-Dependent Tests (~140 failures)
**Impact:** 140 failures → skipped
**Effort:** 2-3 hours
**Risk:** LOW

**Affected files:**
- `test/memory/` suite (~30 tests)
- `test/optimal_system_agent/memory/` suite
- `test/optimal_system_agent/sensors/` suite
- `test/optimal_system_agent/consensus/` suite
- `test/optimal_system_agent/commerce/` suite

**Solution:** Add `@tag :skip` to test function or `@moduletag :skip` to file:

```elixir
# Option A: Skip entire file (if all tests use Ecto)
@moduletag :skip

# Option B: Skip individual tests
@tag :skip
test "stores data in database" do
  # ...
end
```

**How to find:** Search for patterns:
```bash
grep -r "Repo\." test --include="*.exs" | grep "test/" | cut -d: -f1 | sort | uniq
```

**Verification:**
```bash
mix test --no-start 2>&1 | grep -c "RuntimeError.*Repo"  # Should drop from 140 to near-0
```

---

### PRIORITY 3: Tag GenServer-Dependent Tests (~100+ failures)
**Impact:** 100+ failures → skipped
**Effort:** 2-3 hours
**Risk:** LOW

**Affected modules:**
- OptimalSystemAgent.Process.OrgEvolution
- OptimalSystemAgent.Sensors.SensorRegistry
- OptimalSystemAgent.Agent.LoopManager
- OptimalSystemAgent.Process.Healing
- OptimalSystemAgent.Commerce.Marketplace

**How to find:**
```bash
grep -r "GenServer.call\|GenServer.cast" test --include="*.exs" | grep -v "moduletag.*integration" | cut -d: -f1 | sort | uniq
```

**Solution:** Add appropriate skip tags:
```elixir
# Skip entire test file
@moduletag :skip

# Or individual tests
@tag :skip
test "calls genserver process" do
  GenServer.call(SomeModule, :message)
end
```

**Verification:**
```bash
mix test --no-start 2>&1 | grep -c "no process"  # Should drop significantly
```

---

### PRIORITY 4: Create Ecto Test Helpers (~20 tests affected)
**Impact:** 20 failures → useful skips
**Effort:** 2-3 hours
**Risk:** MEDIUM

**Goal:** Provide mock Repo module for unit tests that don't need real database

**Solution:** Create `test/support/ecto_helpers.ex`:

```elixir
defmodule EctoHelpers do
  defmacro skip_without_repo do
    quote do
      setup do
        if not Application.started_applications() |> Enum.any?(fn {app, _} -> app == :ecto end) do
          {:skip, "Ecto not started"}
        else
          :ok
        end
      end
    end
  end
end
```

**Apply in test files:**
```elixir
defmodule MyTest do
  use ExUnit.Case
  skip_without_repo()

  # tests here
end
```

**Benefit:** Tests skip gracefully with message instead of failing

---

### PRIORITY 5: Extract PubSub Pure Logic (~30 tests potential)
**Impact:** 30 failures → testable logic
**Effort:** 4-6 hours
**Risk:** MEDIUM

**Pattern:**
```elixir
# BEFORE: Tightly coupled to PubSub
defmodule EventStream do
  def broadcast(event_type, data) do
    Phoenix.PubSub.broadcast(OptimalSystemAgent.PubSub, topic, {event_type, data})
  end
end

# AFTER: Separated concerns
defmodule EventStream do
  # Pure logic — can be tested without PubSub
  def prepare_event(event_type, data) do
    {event_type, serialize_data(data)}
  end

  # Integration point — only called at runtime
  def broadcast(event_type, data) do
    event = prepare_event(event_type, data)
    Phoenix.PubSub.broadcast(OptimalSystemAgent.PubSub, topic, event)
  end
end
```

**Benefits:**
- Unit tests can test `prepare_event/2` without PubSub
- Integration tests verify PubSub broadcast

---

### PRIORITY 6: Add Setup Guards for Registry (~25 tests)
**Impact:** 25 failures → graceful skip
**Effort:** 1-2 hours
**Risk:** LOW

**Problem:** Tests that use Registry fail when it's not started

**Solution:** Add conditional setup:

```elixir
setup do
  if not Application.started_applications() |> Enum.any?(fn {app, _} -> app == :osa end) do
    {:skip, "Application not started"}
  else
    :ok
  end
end
```

**Or use tag-based exclusion:**
```elixir
# In test_helper.exs, add after line 1:
ExUnit.start(exclude: [:integration, :requires_genserver])

# In test files:
@moduletag :requires_genserver
defmodule SomeTest do
  # ...
end
```

---

### PRIORITY 7: Create Mock GenServer Adapter (~40 tests potential)
**Impact:** 40 failures → useful tests
**Effort:** 6-8 hours
**Risk:** MEDIUM

**Goal:** Provide in-memory mock for GenServer calls during --no-start

**Example:**
```elixir
defmodule MockRegistry do
  def lookup(key) do
    # Check if app is started
    if Application.started_applications() |> Enum.any?(fn {app, _} -> app == :osa end) do
      Registry.lookup(__MODULE__, key)  # Real
    else
      :not_found  # Mock
    end
  end
end
```

**Inject in tests:**
```elixir
setup do
  # If app not started, use mock
  if not Application.started_applications() |> Enum.any?(fn {app, _} -> app == :osa end) do
    {:ok, registry: MockRegistry}
  else
    {:ok, registry: Registry}
  end
end
```

---

### PRIORITY 8: Audit Trail Tests Organization (~20 failures)
**Impact:** 20 failures → integration or skip
**Effort:** 1-2 hours
**Risk:** LOW

**Problem:** Some hook/audit trail tests might not need app startup

**Solution:**
1. Review `test/optimal_system_agent/hooks/` suite
2. Move heavy integration tests to `@moduletag :integration`
3. Keep pure logic tests (hooks that don't call processes) as unit tests

**Verification:**
```bash
mix test --no-start test/optimal_system_agent/hooks/ 2>&1 | tail -3
```

---

### PRIORITY 9: Documentation of Skip Reasons (~30 min)
**Impact:** Easier troubleshooting
**Effort:** 0.5 hours
**Risk:** NONE

**Action:** Add comments to skip tags:
```elixir
# @moduletag :skip
# Reason: Requires OptimalSystemAgent.Agent.Progress GenServer
# To test: run `mix test` (with app startup)
# Issue: https://github.com/...

test "progress tracks nested operations" do
  # ...
end
```

**Benefits:**
- New developers understand why tests are skipped
- Helps prioritize refactoring effort
- Tracks known issues

---

### PRIORITY 10: CI Configuration Update (~1 hour)
**Impact:** Better test reporting
**Effort:** 1 hour
**Risk:** LOW

**Goal:** Make CI/CD pipeline report both --no-start and full test results

**Current `Makefile` or `.github/workflows/test.yml`:**
```bash
# Add both runs:
test-no-start:
	mix test --no-start --exclude integration

test-full:
	mix test --include integration

test-all: test-no-start test-full
```

**Benefits:**
- Developers see which tests are fast (--no-start)
- CI confirms integration tests also work
- Clear separation of concerns

---

## Implementation Order (Recommended)

| Phase | Task | Priority | Time | Impact |
|-------|------|----------|------|--------|
| **Quick Wins** | Priority 1: Move EventStream to integration | P0 | 1h | -449 failures |
| | Priority 9: Documentation | P5 | 0.5h | -0 failures, better DX |
| **Medium** | Priority 2: Tag Ecto tests | P1 | 2h | -140 failures |
| | Priority 3: Tag GenServer tests | P2 | 2h | -100 failures |
| | Priority 6: Setup guards | P3 | 1h | -25 failures |
| **Advanced** | Priority 4: Ecto helpers | P4 | 2h | Better error messages |
| | Priority 5: Extract PubSub logic | P4 | 4h | -30 testable cases |
| | Priority 7: Mock GenServer | P5 | 6h | -40 testable cases |
| | Priority 8: Audit trail review | P6 | 1h | -20 failures |
| **Ops** | Priority 10: CI config | P7 | 1h | Better reporting |

**Total Quick Win:** 1.5 hours → 449 fewer failures
**Total Phase 1:** 7.5 hours → 449 + 140 + 100 + 25 = 714 fewer failures
**Total Full Roadmap:** 20 hours → <50 failures in --no-start mode

---

## Success Metrics

### Current State
```
mix test --no-start
  Finished in 45.3 seconds (31.2s async, 14.1s sync)
  2 doctests, 6095 tests, 449 failures, 58 invalid, 365 skipped
```

### After Quick Win (1.5 hours)
```
mix test --no-start
  Finished in 30 seconds (20s async, 10s sync)
  2 doctests, 6095 tests, 0 failures, 58 invalid, 365 skipped
  [EventStream tests moved to integration]
```

### After Phase 1 (7.5 hours)
```
mix test --no-start
  Finished in 25 seconds (15s async, 10s sync)
  2 doctests, 5300 tests, 15 failures, 58 invalid, 600+ skipped
  [All app-dependent tests properly tagged]
```

### Final State (20 hours, optional)
```
mix test --no-start
  Finished in 20 seconds (12s async, 8s sync)
  2 doctests, 5500 tests, 5 failures, 0 invalid, 500 skipped
  [Pure logic extracted, better error messages]
```

---

## How to Contribute

Each priority has a clear action. Pick one:

1. **Fork/branch:** `git checkout -b fix/test-improvements`
2. **Choose priority:** Pick from list above
3. **Make changes:** Add skip tags, move tests, or refactor
4. **Test:** Run `mix test --no-start` to verify
5. **Commit:** `git commit -m "test: [priority-N] fix description"`
6. **PR:** Submit for review

---

## Questions?

**Q: Will removing these failures break anything?**
A: No. Failures are expected when infrastructure isn't available. Skipping them is the correct behavior.

**Q: Should I skip or move to integration?**
A: **Skip** if test depends on app startup forever (process lifecycle). **Move to integration** if test needs external services (Ollama, OpenAI, etc.).

**Q: How do I know if my changes work?**
A: Run both:
```bash
mix test --no-start                  # Should have fewer failures
mix test --include integration       # Should still pass
```

**Q: Can I do this incrementally?**
A: Yes! Each priority is independent. Do Priority 1 first (biggest impact per hour).

