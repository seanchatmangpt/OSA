---
title: The 7-Layer Architecture in OSA
type: explanation
signal: S=(linguistic, explanation, inform, markdown, architecture-reference)
relates_to: [agent-loop, channels, memory, healing, supervision]
---

# The 7-Layer Architecture in OSA

> **Why does OSA have 7 layers? What does each one do? How do they work together?**
>
> This explanation walks you through the Optimal System design, layer by layer, showing how OSA implements each one and why that structure prevents complexity from collapsing the system.

---

## The Core Insight: Why 7 Layers?

Complex systems fail when you try to optimize everything at once. Instead, **successful systems separate concerns** — each layer handles one job, communicates cleanly with neighbors, and ignores the rest.

The 7-Layer Architecture is a proven structure for building systems that:
- **Don't deadlock** (clear responsibility boundaries)
- **Can evolve** (changes in one layer don't cascade)
- **Scale to production** (each layer has its own failure modes)

OSA implements **layers 2 through 7**. (Layer 1 is organizational structure, which is outside the system itself.)

---

## Layer 2: Signal — Encoded Intent

### What This Layer Does

**Signal** is the "language" that travels through the system. Every message, request, and response encodes **what is being asked and what form the answer should take**.

Signal Theory gives you the **S=(M,G,T,F,W)** framework:
- **Mode (M)**: Is this text, code, data, or visual?
- **Genre (G)**: Is this a spec, brief, report, or email?
- **Type (T)**: Is this a request (direct), information (inform), or decision (commit)?
- **Format (F)**: Is it markdown, JSON, code, or HTML?
- **Structure (W)**: Does it follow a pattern (ADR template, checklist, anatomy)?

### Why This Layer Matters

Without Signal clarity, **requests get misrouted**. An agent might:
- Interpret a "brief" (which needs one paragraph) as a "spec" (which needs detailed requirements)
- Output code when the receiver expected plain English
- Give a decision when they wanted information

This causes **rework loops** — the receiver has to ask again in a different way.

### OSA Implementation

In OSA, every agent input and output goes through **Signal classification**:

```elixir
# Signal classifier in lib/optimal_system_agent/signal/classifier.ex

def classify_input(user_message) do
  %Signal{
    mode: classify_mode(user_message),          # "linguistic" or "code" or ...
    genre: classify_genre(user_message),        # "brief" or "spec" or ...
    type: classify_type(user_message),          # "direct" or "inform" or ...
    format: infer_format(user_message),         # "markdown" or "json" or ...
    structure: detect_structure(user_message)   # "adr-template" or ...
  }
end
```

Before an agent produces output, OSA checks:

```elixir
def validate_signal(output_signal, request_signal) do
  case {output_signal.genre, request_signal.genre} do
    {"brief", "spec"} ->
      {:error, "Asked for spec, got brief"}
    {"json", "code"} ->
      {:error, "Asked for code, got JSON"}
    {g, g} ->
      {:ok, output_signal}  # Match — proceed
    {out, req} ->
      {:error, "Genre mismatch: wanted #{req}, got #{out}"}
  end
end
```

**Why this works**: Signal clarity prevents **90% of agent-to-agent rework**. Each party knows exactly what they're getting.

---

## Layer 3: Composition — Agent Internal Structure

### What This Layer Does

**Composition** is the **internal anatomy** of an agent — how it thinks, acts, and learns.

Every agent in OSA follows this loop:

```
┌─────────────────────────────────────┐
│      1. OBSERVE                     │
│  ├─ Read user input                │
│  ├─ Check memory                   │
│  └─ Gather context                 │
├─────────────────────────────────────┤
│      2. THINK                       │
│  ├─ Reason about the input         │
│  ├─ Choose approach                │
│  └─ Plan actions                   │
├─────────────────────────────────────┤
│      3. ACT                         │
│  ├─ Execute chosen action(s)       │
│  ├─ Call tools or spawn sub-agents │
│  └─ Record what happened           │
├─────────────────────────────────────┤
│      4. LEARN                       │
│  ├─ Update memory                  │
│  ├─ Record outcome                 │
│  └─ Loop back to OBSERVE (repeat)  │
└─────────────────────────────────────┘
```

This is the **ReAct pattern** (Reason + Act), proven to work better than pure "thinking" or pure "action."

### Why This Layer Matters

Without clear composition, agents become **unpredictable**:
- Some agents think before acting, others act before thinking
- Some agents update memory, others don't
- Some agents loop forever, others quit too early

By enforcing a standard loop, OSA makes agents **predictable and composable** — you can chain them together without surprises.

### OSA Implementation

In OSA, every agent runs this loop in `lib/optimal_system_agent/agent/loop.ex`:

```elixir
def run(agent_id, context) do
  1. observe(context)
  2. think(agent, context)
  3. act(agent, context)
  4. learn(agent, context)
end
```

Each step is a GenServer call:

```elixir
# Step 1: OBSERVE
def observe(context) do
  user_input = context.request
  memory = MemoryLayer.load(context.agent_id)
  {user_input, memory}
end

# Step 2: THINK
def think(agent, context) do
  {:ok, plan} = Agent.ask_llm(
    agent.provider,
    context.user_input,
    context.memory,
    agent.tools
  )
  plan
end

# Step 3: ACT
def act(agent, {plan, context}) do
  Enum.each(plan.actions, fn action ->
    case action.type do
      :tool_call -> ToolExecutor.execute(action, agent)
      :spawn_agent -> spawn_child_agent(action)
      :output -> send_to_channel(action)
    end
  end)
end

# Step 4: LEARN
def learn(agent, context) do
  MemoryLayer.update(agent.agent_id, context.outcome)
  Hooks.publish(:agent_step_complete, agent.agent_id)
end
```

**Why this works**: By standardizing the loop, OSA can:
- **Monitor** each step (timeouts, crashes)
- **Inject** hooks at each step (logging, auditing, healing)
- **Coordinate** multiple agents running in parallel

---

## Layer 4: Interface — How Agents Expose Capabilities

### What This Layer Does

**Interface** is how the outside world **talks to agents**. It's the channel adapters: HTTP, WebSocket, chat platforms, CLI, etc.

An agent doesn't "know" whether it's being called from:
- A REST API endpoint
- A Slack message
- A webhook from another system
- A desktop UI

The Interface layer **translates** between external protocols and the agent's internal message format.

### Why This Layer Matters

Without a clean interface layer, agents become **tightly coupled** to specific channels. If you want to add Telegram support, you'd have to rewrite agent logic. If you want to switch from HTTP to gRPC, same problem.

By decoupling the interface, you can:
- Add new channels without touching agent code
- Run the same agent on multiple channels simultaneously
- Swap implementations (e.g., HTTP → WebSocket) without affecting agents

### OSA Implementation

In OSA, every channel is a **Plug router** in `lib/optimal_system_agent/channels/`:

```
channels/
  ├─ http/              # REST API
  │  └─ api.ex         # Plug routes
  ├─ websocket/        # Real-time channel
  ├─ slack/            # Slack integration
  ├─ discord/          # Discord integration
  └─ cli/              # Command-line interface
```

Each channel translates incoming requests to an internal message format:

```elixir
# channels/http/api.ex
defmodule OSA.Channels.HTTP.API do
  def handle_post(conn, %{"agent_id" => agent_id, "message" => message}) do
    # Translate HTTP request to internal message
    internal_msg = %Message{
      agent_id: agent_id,
      source: :http,
      content: message,
      channel: :http,
      request_id: UUID.generate()
    }

    # Dispatch to agent (same code for all channels)
    {:ok, response} = Agent.dispatch(internal_msg)

    # Translate response back to HTTP format
    json(conn, %{"response" => response.content})
  end
end
```

The agent **never sees** HTTP — it only sees `%Message{}`. This means:

```elixir
# Same agent, 3 different channels
Agent.dispatch(message)  # Works on HTTP
Agent.dispatch(message)  # Works on Slack
Agent.dispatch(message)  # Works on WebSocket

# No code changes needed
```

---

## Layer 5: Data — Where State Lives

### What This Layer Does

**Data** is where everything **persists** — memories, decisions, audit trails, knowledge graphs.

OSA uses a **3-tier data strategy**:

| Tier | Tech | Purpose | Speed | Persistence |
|------|------|---------|-------|-------------|
| **Hot** | ETS (in-memory) | Current conversation context | Microseconds | Crash-safe (not durable) |
| **Warm** | SQLite (local) | Agent memories, decisions, sessions | Milliseconds | Durable locally |
| **Cold** | PostgreSQL (platform) | Audit trail, knowledge, marketplace | Seconds | Multi-tenant, backups |

### Why This Layer Matters

Without clear data architecture, systems either:
- **Lose everything on crash** (all in-memory, no persistence)
- **Get too slow** (all queries hit the database)
- **Can't scale** (single-node limitation)

By splitting into tiers, OSA achieves:
- **Speed** (recent data in memory)
- **Safety** (durable backup in local SQLite)
- **Scale** (cold storage in PostgreSQL for multi-tenant)

### OSA Implementation

In OSA, data flows through three layers:

```elixir
# Layer 5a: HOT — ETS (in-memory, current context)
# lib/optimal_system_agent/memory/ets_cache.ex

def store_context(agent_id, context) do
  :ets.insert(:agent_contexts, {agent_id, context})
end

def get_context(agent_id) do
  case :ets.lookup(:agent_contexts, agent_id) do
    [{^agent_id, context}] -> {:ok, context}
    [] -> {:error, :not_found}
  end
end
```

```elixir
# Layer 5b: WARM — SQLite (local, durable)
# lib/optimal_system_agent/memory/storage.ex

def save_memory(agent_id, memory) do
  Repo.insert!(%AgentMemory{
    agent_id: agent_id,
    content: Jason.encode!(memory),
    updated_at: DateTime.utc_now()
  })
end

def load_memory(agent_id) do
  case Repo.get_by(AgentMemory, agent_id: agent_id) do
    nil -> {:error, :not_found}
    record -> {:ok, Jason.decode!(record.content)}
  end
end
```

```elixir
# Layer 5c: COLD — PostgreSQL (platform multi-tenant)
# lib/optimal_system_agent/platform/audit.ex

def log_decision(agent_id, decision) do
  {:ok, _} = PlatformRepo.insert(%AuditLog{
    agent_id: agent_id,
    decision: Jason.encode!(decision),
    timestamp: DateTime.utc_now()
  })
end
```

**Why this works**: Each tier is optimized for its use case. You check ETS first (fast), fall back to SQLite (durable), and archive to PostgreSQL (scalable).

---

## Layer 6: Feedback — Self-Correction

### What This Layer Does

**Feedback** is how the system **detects and fixes** its own mistakes. This is where learning happens.

Every agent has **three feedback loops**:

| Loop | Detects | Fixes |
|------|---------|-------|
| **Reflexive** | Immediate error (e.g., tool fails) | Retry, fallback, re-plan |
| **Healing** | Deadlock, timeout, resource exhaustion | Diagnosis, repair action, escalation |
| **Long-term** | Pattern of failures (e.g., always fails on X) | Update skills, retrain, reorganize |

### Why This Layer Matters

Without feedback, failures are **silent and cascading**:
- An agent makes a mistake, doesn't notice, propagates the error
- Multiple agents pile on the same mistake
- The system degrades gracefully into an unusable state

With feedback, failures are **fast and contained**:
- Mistakes detected immediately (reflexive)
- Damage contained (healing)
- Patterns learned and prevented (long-term)

### OSA Implementation

In OSA, feedback is implemented through **Hooks** in `lib/optimal_system_agent/agent/hooks.ex`:

```elixir
# Reflexive feedback: hook on every tool call
Hooks.register(:on_tool_call, fn {tool, result} ->
  case result do
    {:ok, output} ->
      Logger.info("Tool #{tool} succeeded")
    {:error, reason} ->
      Logger.warn("Tool #{tool} failed: #{reason}")
      # Trigger retry or fallback
      Agent.retry_with_fallback(tool)
  end
end)
```

```elixir
# Healing feedback: detect and fix deadlocks
Hooks.register(:on_timeout, fn {agent_id, timeout_ms} ->
  Logger.error("Agent #{agent_id} timed out after #{timeout_ms}ms")

  # Diagnosis phase
  {:ok, diagnosis} = Healing.diagnose(agent_id)

  # Repair phase
  case diagnosis do
    :deadlock -> Healing.break_deadlock(agent_id)
    :starvation -> Healing.increase_budget(agent_id)
    :crash_loop -> Healing.escalate_to_supervisor(agent_id)
  end
end)
```

```elixir
# Long-term feedback: learn from patterns
Hooks.register(:on_hourly_analysis, fn _tick ->
  failures = Repo.recent_failures(1, :hour)
  patterns = Patterns.identify_failures(failures)

  Enum.each(patterns, fn pattern ->
    Logger.warn("Pattern detected: #{pattern.name}")
    Skills.update_with_prevention(pattern)
  end)
end)
```

**Why this works**: By layering feedback (reflexive → healing → learning), the system can recover from mistakes **without human intervention**.

---

## Layer 7: Governance — Policy and Limits

### What This Layer Does

**Governance** is how the organization **enforces policy** on the system. It answers:
- Who can do what? (permissions)
- How much can they spend? (budgets)
- What rules must be followed? (compliance)

This layer sits **outside the agent loop** but intercepts every decision.

### Why This Layer Matters

Without governance, agents become **unpredictable** in production:
- One agent might spend $1,000 on API calls, another $100 on the same task
- One agent might violate compliance rules without knowing
- One agent might have permissions to delete data, another doesn't

By enforcing policy at this layer, you can:
- **Control costs** (per-agent budgets)
- **Enforce compliance** (e.g., GDPR rules)
- **Manage permissions** (who can access what)

### OSA Implementation

In OSA, governance is enforced in `lib/optimal_system_agent/governance/`:

```elixir
# Governance: Check permissions before action
def check_permission(agent_id, action) do
  agent = Repo.get!(Agent, agent_id)

  case action do
    {:delete, resource} ->
      if agent.permissions |> Enum.any?(&(&1 == :delete)) do
        {:ok, :allowed}
      else
        {:error, :permission_denied}
      end
    {:spend, amount} ->
      if agent.budget.remaining >= amount do
        {:ok, :allowed}
      else
        {:error, :budget_exceeded}
      end
  end
end
```

```elixir
# Governance: Enforce budget limits
def charge_operation(agent_id, cost_usd) do
  agent = Repo.get!(Agent, agent_id)

  if agent.budget.remaining >= cost_usd do
    # Deduct from budget
    Repo.update_budget(agent_id, agent.budget.remaining - cost_usd)
    {:ok, :charged}
  else
    {:error, :budget_exceeded}
  end
end
```

```elixir
# Governance: Log all decisions for audit
def audit_decision(agent_id, decision) do
  {:ok, _} = Repo.insert(%AuditLog{
    agent_id: agent_id,
    decision_type: decision.type,
    outcome: decision.outcome,
    timestamp: DateTime.utc_now()
  })
end
```

**Why this works**: Governance is a **policy layer** that doesn't interfere with the agent loop. An agent never needs to ask "am I allowed to do this?" — the layer checks before execution.

---

## How the 7 Layers Work Together

Here's a real example of a complete agent flow through all 7 layers:

```
User asks: "Draft a cold email to prospects"

Layer 2: SIGNAL
  ├─ Classify input: (linguistic, brief, direct, markdown, cold-email-anatomy)
  └─ Agent knows: "User wants 1 paragraph, action-driven, email format"

Layer 3: COMPOSITION
  ├─ Agent loop: Observe (load prospect list) → Think (plan email)
  │            → Act (draft) → Learn (save draft)
  └─ Planning happens inside GenServer, structured

Layer 4: INTERFACE
  ├─ Request came via HTTP POST
  └─ Response returned as JSON to HTTP client

Layer 5: DATA
  ├─ ETS: Load recent prospect context (fast)
  ├─ SQLite: Load agent's past emails (durable)
  └─ PostgreSQL: Log this operation to audit trail (persistent)

Layer 6: FEEDBACK
  ├─ Draft completed successfully
  ├─ Hooks fired: on_success → log stats
  └─ No errors, no healing needed

Layer 7: GOVERNANCE
  ├─ Agent has permission to access prospect list? Yes ✓
  ├─ Agent budget allows for this operation? Yes ✓
  └─ Audit logged: Agent 5, Action: draft_email, Time: 2026-03-25T14:22Z
```

---

## Summary: Why 7 Layers Matter

| Layer | Solves | Benefit |
|-------|--------|---------|
| **2: Signal** | Routing errors | Correct provider/model chosen |
| **3: Composition** | Agent unpredictability | Consistent think-act loop |
| **4: Interface** | Channel coupling | Same agent, multiple channels |
| **5: Data** | Speed vs safety tradeoff | Fast + durable + scalable |
| **6: Feedback** | Silent failures | Fast detection + automatic repair |
| **7: Governance** | Runaway agents | Budgets, permissions, compliance |

**Together**, they create a system that:

✅ Routes messages intelligently (Signal)
✅ Reasons before acting (Composition)
✅ Works on any channel (Interface)
✅ Persists safely at scale (Data)
✅ Fixes its own mistakes (Feedback)
✅ Obeys organizational rules (Governance)

This is what "Optimal System" means: **a system that works reliably without human micromanagement**.

---

## Next Steps

- **See it in action**: [Agent Loop Documentation](../../../backend/agent-loop/)
- **Implement a channel**: [Channel Adapters](../../../backend/channels/)
- **Debug a layer**: [Debugging Guide](../../../operations/debugging.md)
