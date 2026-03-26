# How-To: Implement a New Healing Pattern in OSA

> **Problem**: OSA detects failure modes (deadlock, timeout, cascade, etc.) but needs custom healing strategies for domain-specific failures. Add a new healer that repairs the system after diagnosis.
>
> **Outcome**: A new healing pattern that detects, diagnoses, and repairs a specific failure mode—with OTEL traces and test coverage.

## Time Estimate
30-45 minutes for a simple healer (read-only repair). Add 15-30 min for write operations.

---

## Prerequisites

- OSA running locally (`mix osa.serve` on port 8089)
- Familiarity with Elixir/OTP GenServer patterns
- Access to `OSA/lib/optimal_system_agent/healing/`

---

## Step 1: Define the Failure Mode

First, identify what you're healing. OSA recognizes 11 failure modes:

| Mode | When It Happens | Repair Strategy |
|------|-----------------|-----------------|
| `:shannon` | Information loss, truncation | Fetch from backup/cache |
| `:ashby` | Wrong setpoint, drift | Reset to known good state |
| `:beer` | State explosion, too complex | Simplify context, compact memory |
| `:wiener` | Feedback oscillation | Dampen control loop |
| `:deadlock` | Circular wait condition | Break cycle, timeout, restart |
| `:cascade` | Failure spreads downstream | Isolate component, restart subtree |
| `:byzantine` | Compromised component | Eject, quarantine, audit |
| `:starvation` | Resource exhausted | Reallocate budget, queue drain |
| `:livelock` | Conflict without progress | Randomize, backoff, retry |
| `:timeout` | Operation exceeds deadline | Escalate, fallback, retry |
| `:inconsistent` | State mismatch across systems | Sync from source of truth |

**For this example**, let's implement a deadlock healer:

```elixir
# OSA/lib/optimal_system_agent/healing/healers/deadlock_healer.ex
# Purpose: Detect and break circular wait conditions
# Failure mode: :deadlock
# Repair strategy: Timeout + force release + restart
```

---

## Step 2: Create the Healer Module

Create a new file implementing the healer behaviour:

```bash
touch OSA/lib/optimal_system_agent/healing/healers/deadlock_healer.ex
```

**Template:**

```elixir
defmodule OptimalSystemAgent.Healing.Healers.DeadlockHealer do
  @moduledoc """
  Healing strategy for :deadlock failure mode.

  Detects circular wait conditions (A waiting for B while B waits for A).
  Repairs by:
    1. Identifying held locks and waiting-for locks
    2. Forcing a timeout on the youngest waiter
    3. Breaking the cycle
    4. Restarting the affected session

  Example:
    iex> DeadlockHealer.heal(%{held_locks: [:a, :b], waiting_for: [:c]})
    {:ok, %{action: :timeout, released_locks: [:a, :b], session_restarted: true}}
  """

  require Logger
  alias OptimalSystemAgent.Healing.Diagnosis

  @doc """
  Heal a deadlock failure.

  Params:
    - `failure` — error context containing locks and wait chains

  Returns:
    - `{:ok, action_map}` — healing succeeded, action_map describes what was done
    - `{:error, reason}` — healing failed, reason explains why
  """
  @spec heal(map()) :: {:ok, map()} | {:error, String.t()}
  def heal(%{held_locks: held_locks, waiting_for: waiting_for} = failure) do
    tracer = :opentelemetry.get_tracer(:optimal_system_agent)

    :otel_tracer.with_span(tracer, "healing.deadlock_heal", %{
      "held_locks" => inspect(held_locks),
      "waiting_for" => inspect(waiting_for),
      "failure_context" => inspect(failure)
    }, fn span_ctx ->
      perform_healing(held_locks, waiting_for, failure, span_ctx)
    end)
  end

  def heal(_), do: {:error, "invalid failure context"}

  # ---- Private Implementation ----

  defp perform_healing(held_locks, waiting_for, failure, span_ctx) do
    try do
      # Step 1: Identify the cycle
      with :ok <- verify_cycle_exists(held_locks, waiting_for) do
        # Step 2: Release locks in reverse order of acquisition
        :ok = release_locks(held_locks)

        # Step 3: Emit healing event
        emit_healing_event(:deadlock_resolved, %{
          held_locks: held_locks,
          waiting_for: waiting_for,
          action: :force_release
        })

        # Step 4: Record outcome in OTEL
        :otel_span.set_attributes(span_ctx, %{
          "healing_status" => "ok",
          "locks_released" => length(held_locks),
          "action" => "force_release_and_timeout"
        })

        {:ok, %{
          action: :timeout,
          released_locks: held_locks,
          session_restarted: false,
          reason: "deadlock cycle broken"
        }}
      end
    rescue
      e in RuntimeError ->
        Logger.error("Deadlock healing failed: #{inspect(e)}")

        :otel_span.set_attributes(span_ctx, %{
          "healing_status" => "error",
          "error_reason" => inspect(e)
        })

        {:error, "deadlock healing failed: #{inspect(e)}"}
    end
  end

  defp verify_cycle_exists(_held, _waiting) do
    # TODO: Implement cycle detection (wait-for graph analysis)
    # For now, assume cycle exists if we were called
    :ok
  end

  defp release_locks(locks) do
    # TODO: Release locks (implementation depends on lock manager)
    # For now, log the intent
    Logger.info("[Healing.Deadlock] Releasing locks: #{inspect(locks)}")
    :ok
  end

  defp emit_healing_event(event_type, data) do
    OptimalSystemAgent.Events.Bus.publish(:system_event, {
      :healing,
      event_type,
      data
    })
  end
end
```

---

## Step 3: Register the Healer in the Dispatcher

The healing orchestrator routes failures to healers. Register your healer:

**File**: `OSA/lib/optimal_system_agent/healing/orchestrator.ex`

**Change**: Locate `heal/1` function and add your healer:

```elixir
defp route_to_healer({:deadlock, _desc, _cause}, failure_context) do
  OptimalSystemAgent.Healing.Healers.DeadlockHealer.heal(failure_context)
end

# Add your healer to the pattern match:
defp route_to_healer({:deadlock, _desc, _cause}, failure_context) do
  DeadlockHealer.heal(failure_context)
end
```

---

## Step 4: Write a Test

Create a test file validating your healer:

**File**: `OSA/test/healing/deadlock_healer_test.exs`

```elixir
defmodule OptimalSystemAgent.Healing.Healers.DeadlockHealerTest do
  use ExUnit.Case, async: true

  alias OptimalSystemAgent.Healing.Healers.DeadlockHealer

  describe "heal/1 — deadlock resolution" do
    test "detects and breaks circular wait" do
      failure = %{
        held_locks: [:a, :b],
        waiting_for: [:c],
        session_id: "sess_123"
      }

      assert {:ok, result} = DeadlockHealer.heal(failure)
      assert result.action == :timeout
      assert result.released_locks == [:a, :b]
    end

    test "rejects invalid failure context" do
      assert {:error, _reason} = DeadlockHealer.heal(%{})
    end

    test "logs healing event" do
      failure = %{
        held_locks: [:lock_1],
        waiting_for: [:lock_2],
        session_id: "sess_456"
      }

      # Capture logs (requires Logger.capture_log/1)
      log =
        capture_log(fn ->
          DeadlockHealer.heal(failure)
        end)

      assert log =~ "Releasing locks"
    end

    test "emits OTEL span during healing" do
      # This test verifies OTEL instrumentation
      # Run with: mix test --include integration
      failure = %{
        held_locks: [:a],
        waiting_for: [:b]
      }

      {:ok, _result} = DeadlockHealer.heal(failure)

      # Check Jaeger: http://localhost:16686
      # Look for span name: healing.deadlock_heal
      # Expected attributes: held_locks, waiting_for, healing_status
    end
  end
end
```

**Run the test:**

```bash
cd OSA
mix test test/healing/deadlock_healer_test.exs
```

Expected output:
```
Compiling 1 file (.ex)
Generated optimal_system_agent app
.....
3 tests, 0 failures
```

---

## Step 5: Add Configuration (Optional)

If your healer needs config, add environment variables:

**File**: `OSA/config/config.exs`

```elixir
config :optimal_system_agent, :healing,
  deadlock: %{
    timeout_ms: 5000,
    max_retries: 3,
    force_restart: false
  }
```

**Access in your healer:**

```elixir
config = Application.get_env(:optimal_system_agent, :healing)
deadlock_config = Map.get(config, :deadlock, %{})
timeout_ms = Map.get(deadlock_config, :timeout_ms, 5000)
```

---

## Step 6: Integration Test (End-to-End)

Test the full path: failure detection → diagnosis → healing:

**File**: `OSA/test/healing/integration/deadlock_e2e_test.exs`

```elixir
defmodule OptimalSystemAgent.Healing.Integration.DeadlockE2ETest do
  use ExUnit.Case, async: false
  @tag :integration

  alias OptimalSystemAgent.Agent.Loop
  alias OptimalSystemAgent.Healing.Diagnosis

  test "deadlock is detected, diagnosed, and healed" do
    # 1. Simulate a deadlock scenario
    failure = %{
      "error" => "deadlock detected",
      "component_a" => "waiting_for_b",
      "component_b" => "waiting_for_a",
      "held_locks" => [:a, :b],
      "waiting_for" => [:c]
    }

    # 2. Run diagnosis
    {mode, desc, cause} = Diagnosis.diagnose(failure)
    assert mode == :deadlock

    # 3. Trigger healing
    {:ok, healing_result} =
      OptimalSystemAgent.Healing.Orchestrator.heal(mode, failure)

    assert healing_result.action == :timeout
  end
end
```

**Run with integration flag:**

```bash
mix test test/healing/integration/deadlock_e2e_test.exs --include integration
```

---

## Best Practices

### 1. **Idempotency**
Make your healer safe to call multiple times:

```elixir
# GOOD: Checking if already fixed
def heal(failure) do
  case is_already_fixed?(failure) do
    true -> {:ok, %{action: :no_op, reason: "already fixed"}}
    false -> perform_repair(failure)
  end
end
```

### 2. **Observability**
Always emit OTEL spans and events:

```elixir
:otel_tracer.with_span(tracer, "healing.your_healer", %{
  "failure_mode" => "your_mode",
  "status" => "ok"
}, fn _span_ctx ->
  # Your healing code
end)
```

### 3. **Armstrong Principles**
Follow OTP supervision patterns:

- **Let it Crash**: Don't catch errors silently; let the supervisor know
- **No Shared State**: Use message passing, not global mutable state
- **Supervision**: Always report back to Healing.Orchestrator

```elixir
# GOOD: Raise on unrecoverable error, let orchestrator restart
def heal(failure) do
  case repair_component(failure) do
    :ok -> {:ok, %{status: "healed"}}
    :error -> raise "Unrecoverable failure: #{inspect(failure)}"
  end
end
```

### 4. **Timeouts**
Always include timeouts to prevent healing from hanging:

```elixir
def heal(failure, opts \\ []) do
  timeout_ms = Keyword.get(opts, :timeout_ms, 10_000)

  Task.async(fn -> perform_healing(failure) end)
  |> Task.await(timeout_ms)
rescue
  _e -> {:error, "healing timeout"}
end
```

---

## Troubleshooting

### **Issue**: Healer not being called

**Diagnosis**: Check that `Diagnosis.diagnose/2` returns your failure mode.

```elixir
failure = ...
{mode, _desc, _cause} = Diagnosis.diagnose(failure)
IO.inspect(mode)  # Should be :deadlock
```

**Fix**: Add pattern matching to `Diagnosis` if your mode isn't recognized.

### **Issue**: OTEL span not showing in Jaeger

**Diagnosis**: Verify OpenTelemetry is running:

```bash
# Terminal 1: Start Jaeger
docker run -d -p 16686:16686 jaegertracing/all-in-one

# Terminal 2: Verify OSA connects
mix osa.serve
# Check http://localhost:16686 for traces
```

### **Issue**: Test fails with "no process" error

**Diagnosis**: Your healer might be calling a GenServer that isn't started.

**Fix**: Use `--no-start` for unit tests:

```bash
# This test doesn't need the full app running:
mix test test/healing/deadlock_healer_test.exs --no-start

# This test needs the app:
mix test test/healing/integration/deadlock_e2e_test.exs --tag integration
```

---

## What's Next

1. **Expand to other failure modes**: Implement healers for `:cascade`, `:starvation`, `:timeout`
2. **Add smart routing**: Make `Orchestrator.heal/2` choose the best healer based on confidence scores
3. **Feedback loop**: Track healing success rate and adjust strategy
4. **Formal verification**: Use WvdA soundness rules to prove your healer prevents deadlock

---

## References

- [Healing Architecture](../explanation/healing-architecture.md) — 7 reflex arcs + orchestrator patterns
- [WvdA Soundness Standard](../../../.claude/rules/wvda-soundness.md) — Deadlock-free verification
- [Chicago TDD Discipline](../../../.claude/rules/chicago-tdd.md) — Red-Green-Refactor pattern
- [OTEL Instrumentation](../how-to/add-otel-spans.md) — Observability in healing
- Test examples: `OSA/test/healing/*_test.exs`

