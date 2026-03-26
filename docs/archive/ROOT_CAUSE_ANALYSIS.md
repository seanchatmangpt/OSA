# Root Cause Analysis — 13 OSA Test Failures

## Phase 1: Root Cause Investigation (COMPLETE)

Investigation date: 2026-03-24
Total failures: 13
Test files affected: 5
Methodology: Read error messages, reproduce in code, trace data flow

---

## Failure Categories & Root Causes

### P0: System Crashes (Implementation Missing) — 4 Failures

#### Failure 1 & 2: ProcessMining Functions Undefined
- **Tests:** vision2030_crash_test.exs:285, 295
- **Error:** `UndefinedFunctionError`
  - `classify_risk/1` is called but not implemented
  - `compute_health_score/2` is called but not implemented
- **Root Cause:** Vision 2030 crash tests reference functions that were planned but not implemented in `ProcessMining` module
- **Evidence:**
  - ProcessMining module exists with `record_snapshot/2`, `process_velocity/1`, `predict_state/2`, etc.
  - Functions `classify_risk/1` and `compute_health_score/2` are NOT in module — verified by grep and source read
  - Tests expect these functions to exist and handle edge cases (nil input, massive data)
- **Fix Priority:** P0 (blocking test execution)
- **Fix Type:** Implement missing functions OR remove tests that reference non-existent API

---

#### Failure 3 & 4: AutonomousPI.new() Returns Wrong Type
- **Tests:** temporal_adapter_test.exs:133, 143, 163 (3 tests total)
- **Error:** `BadMapError` — expecting map, got empty list `[]`
- **Root Cause:** `AutonomousPI.new()` is being called in tests but function is returning `[]` instead of `%AutonomousPI{}` struct
- **Evidence:**
  - Source read shows AutonomousPI.new/2 at line 38-50 DOES return `%__MODULE__{}` struct with proper fields
  - Tests call function and match on return value
  - Tests expect fields like `:workflow_id`, `:current_stage`, etc.
  - **DISCREPANCY:** Code shows correct return type, but test error shows `[]` being returned
  - **Hypothesis:** Either test is calling wrong function OR there's a newer version of code not matching files
  - **Next step:** Need to verify actual function being called at runtime
- **Fix Priority:** P0 (blocking test execution)
- **Fix Type:** Trace actual function call OR ensure tests use correct module path

---

### P1: Wrong Behavior (Test Expectation Mismatch) — 2 Failures

#### Failure 5 & 6: StructuralAnalyzer Case Clause Mismatch
- **Tests:** vision2030_crash_test.exs:205, 215 (analyzing empty and massive workflows)
- **Error:** `CaseClauseError` — no case clause matching returned structure
- **Root Cause:** Tests expect return value with fields `{deadlock: _, livelock: _}` but analyzer returns `{deadlock_free: _, livelock_free: _, ...}`
- **Evidence:**
  - Verified StructuralAnalyzer.analyze_workflow/2 returns:
    ```elixir
    %{
      deadlock_free: boolean(),
      livelock_free: boolean(),
      sound: boolean(),
      proper_completion: boolean(),
      no_orphan_tasks: boolean(),
      no_unreachable_tasks: boolean(),
      overall_score: float(),
      issues: [...]
    }
    ```
  - Test case at line 210 expects: `%{deadlock: _, livelock: _}`
  - Field names are DIFFERENT (missing `_free` suffix in test expectation)
- **Fix Priority:** P1 (wrong behavior)
- **Fix Type:** Fix test case clause to match actual field names

---

### P1: Data Corruption (Test Contamination) — 1 Failure

#### Failure 7: Unicode Corruption in IntentBroadcaster
- **Test:** intent_broadcaster_test.exs:176 ("sorts intents by timestamp")
- **Error:** Assertion failure — expected `"agent_1"`, got `"代理_1"` (Chinese characters)
- **Root Cause:** ETS table `:osa_file_intents` contains stale data from previous test or another test suite
- **Evidence:**
  - Test inserts: `IntentBroadcaster.broadcast_intent("agent_1", "/tmp/test.txt", "first")`
  - Expected return: `intent.agent_id == "agent_1"`
  - Actual return: `intent.agent_id == "代理_1"` (Chinese translation of "agent")
  - **Pattern:** Data structure is correct (has agent_id), but value is wrong
  - **Cause:** ETS table `init_tables()` at setup doesn't clear existing data, OR async test pollution from parallel test run
- **Fix Priority:** P1 (wrong data returned)
- **Fix Type:** Ensure ETS tables are cleared between tests OR mark as `async: false` if not already

---

### P2: Test Infrastructure (External Dependency) — 3 Failures

#### Failure 8 & 9: TemporalAdapter Connection Error Format
- **Tests:** temporal_adapter_test.exs:27, 58, 71 (3 tests total, but grouped as P2)
- **Error:** Assertion failure — expected `{:error, {:connection_failed, _}}` or `{:error, {:http_error, _}}`, got something else
- **Root Cause:** TemporalAdapter returns error in different format than test expects
  - Possible actual returns: `{:error, "Missing required parameters: ..."}` (string reason)
  - Possible actual returns: `{:error, "Invalid Temporal configuration: ..."}` (string reason)
  - Possible actual returns: `{:error, :timeout}` (atom reason)
- **Evidence:**
  - TemporalAdapter catches errors and wraps them in logging but doesn't normalize error format
  - Tests expect tuple format `{:error, {:connection_failed, _}}` but code returns `{:error, reason_string}`
- **Fix Priority:** P2 (external dependency — Temporal server not available)
- **Fix Type:** Either normalize error format OR update test expectations to match actual error format

---

#### Failure 10: Missing Test Fixtures (Signal Quality Gates)
- **Tests:** fortune_5/signal_theory_quality_gates_test.exs:61, 125 (2 tests total)
- **Error:** `{:error, :enoent}` when trying to read `modules.json`
- **Root Cause:** Test assumes `modules.json` file exists but it hasn't been generated
- **Evidence:**
  - Test path: `modules_path = "...modules.json"`
  - File.read(modules_path) returns `{:error, :enoent}` (file not found)
  - **Dependency:** Test likely needs a setup step to generate this file OR file should be committed to repo
  - **Possible causes:**
    1. Test is part of a larger suite where earlier step generates the file (missing dependency)
    2. File should be in test fixtures but isn't
    3. Generation script hasn't been run
- **Fix Priority:** P2 (test infrastructure)
- **Fix Type:** Add fixture file OR add test setup step to generate it

---

## Summary by Fix Type

| Fix Type | Count | Priority | Effort |
|----------|-------|----------|--------|
| Implement missing functions | 2 | P0 | Medium |
| Fix test case clauses | 2 | P1 | Low |
| Fix test data contamination | 1 | P1 | Low |
| Normalize error format | 3 | P2 | Medium |
| Add missing fixtures | 2 | P2 | Low |

---

## Chicago TDD Fix Order

1. **P0 Phase — Make it not crash:**
   - Implement `classify_risk/1` and `compute_health_score/2` (or remove tests)
   - Verify AutonomousPI.new() returns correct type (may already be fixed, need trace)

2. **P1 Phase — Fix wrong behavior:**
   - Fix StructuralAnalyzer test case clauses (field name mismatch)
   - Clear ETS tables between tests in IntentBroadcaster setup

3. **P2 Phase — Handle edge cases:**
   - Normalize TemporalAdapter error format OR update test expectations
   - Create/commit missing modules.json fixture OR add generation step

---

## Next Phase: Phase 2 (Pattern Analysis)

Need to determine:
1. Are `classify_risk/1` and `compute_health_score/2` supposed to exist? → Check Vision 2030 spec
2. Is AutonomousPI.new() return type actually correct in runtime? → Need to trace execution
3. Should IntentBroadcaster tests clear ETS or use async: true? → Check test design pattern in codebase
4. What error format should TemporalAdapter use? → Check existing similar error handling in codebase

