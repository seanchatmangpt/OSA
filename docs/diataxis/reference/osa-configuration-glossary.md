# Reference: OSA Configuration Glossary

> **Purpose**: Authoritative lookup table for all configuration variables, ETS tables, GenServer processes, and supervisor structure in OSA.
>
> **Format**: Name → Type → Description → Where Checked/Used

---

## Environment Variables

All environment variables are **optional** unless marked `(REQUIRED)`.

### Agent Configuration

| Variable | Type | Default | Purpose |
|----------|------|---------|---------|
| `OSA_AGENT_ID` | string | Generated UUID | Unique agent identifier |
| `OSA_PERMISSION_TIER` | atom | `:workspace` | `full` \| `workspace` \| `read_only` |
| `OSA_DEFAULT_PROVIDER` | string | `"anthropic"` | Primary LLM provider |
| `OSA_DEFAULT_MODEL` | string | `"claude-3-5-sonnet"` | Default LLM model |
| `OSA_BUDGET_TIER` | atom | `normal` | `critical` \| `high` \| `normal` \| `low` |
| `OSA_BUDGET_TOKENS_PER_DAY` | integer | `100000` | Daily token limit |
| `OSA_MAX_CONTEXT_TOKENS` | integer | `8000` | Session context window |

**Checked in:**
- `OptimalSystemAgent.Agent.Loop`
- `OptimalSystemAgent.Providers.*`
- `OptimalSystemAgent.Agent.Budget`

### HTTP Server

| Variable | Type | Default | Purpose |
|----------|------|---------|---------|
| `OSA_HTTP_PORT` | integer | `8089` | HTTP listener port |
| `OSA_HTTP_HOST` | string | `"127.0.0.1"` | HTTP bind address |
| `OSA_HTTP_TIMEOUT_MS` | integer | `30000` | Request timeout |
| `OSA_CORS_ORIGINS` | string (comma-sep) | `"*"` | CORS allowed origins |

**Checked in:**
- `OptimalSystemAgent.Channels.HTTP.Server`
- `OptimalSystemAgent.Application.start/2`

### Healing & Reflex Arcs

| Variable | Type | Default | Purpose |
|----------|------|---------|---------|
| `OSA_HEALING_ENABLED` | boolean | `true` | Enable healing orchestrator |
| `OSA_HEALING_TIMEOUT_MS` | integer | `10000` | Max healing operation time |
| `OSA_REFLEX_PROVIDER_FAILOVER` | boolean | `true` | Enable provider failover reflex |
| `OSA_REFLEX_CONTEXT_RELIEF` | boolean | `true` | Enable context compaction reflex |
| `OSA_REFLEX_BUDGET_THROTTLE` | boolean | `true` | Enable budget-based throttling |
| `OSA_REFLEX_DOOM_LOOP_BREAK` | boolean | `true` | Enable doom loop detection |
| `OSA_REFLEX_SESSION_REAPER` | boolean | `true` | Enable idle session cleanup |

**Checked in:**
- `OptimalSystemAgent.Healing.Orchestrator`
- `OptimalSystemAgent.Healing.ReflexArcs`

### Tool Execution

| Variable | Type | Default | Purpose |
|----------|------|---------|---------|
| `OSA_MAX_TOOL_CALLS_PER_TURN` | integer | `10` | Limit tool invocations per agent turn |
| `OSA_TOOL_TIMEOUT_MS` | integer | `30000` | Individual tool execution timeout |
| `OSA_TOOL_PARALLEL_EXECUTION` | boolean | `true` | Allow parallel tool calls |
| `OSA_ALLOWED_TOOLS` | string (comma-sep) | `"all"` | Whitelist tools (or `all`) |
| `OSA_BLOCKED_TOOLS` | string (comma-sep) | `""` | Blacklist tools |
| `OSA_SHELL_TIMEOUT_MS` | integer | `60000` | Shell command timeout |
| `OSA_ALLOWED_READ_PATHS` | string (comma-sep) | `System.user_home!/0` | Allowed file read directories |
| `OSA_ALLOWED_WRITE_PATHS` | string (comma-sep) | `System.user_home!/0` | Allowed file write directories |

**Checked in:**
- `OptimalSystemAgent.Agent.Loop.ToolExecutor`
- `OptimalSystemAgent.Tools.Builtins.*`
- `OptimalSystemAgent.Tools.Registry`

### Provider Configuration

| Variable | Type | Default | Purpose |
|----------|------|---------|---------|
| `ANTHROPIC_API_KEY` | string (REQUIRED) | — | Anthropic API key |
| `OPENAI_API_KEY` | string | — | OpenAI API key (if using OpenAI) |
| `OSA_PM4PY_HTTP_URL` | string | `"http://localhost:8090"` | pm4py-rust API endpoint |
| `OSA_PM4PY_TIMEOUT` | integer | `30000` | pm4py request timeout |
| `OSA_BUSINESSOS_API_URL` | string | `"http://localhost:8001"` | BusinessOS API endpoint |
| `OSA_BUSINESSOS_API_TOKEN` | string | — | BusinessOS API token (if required) |
| `OSA_OLLAMA_URL` | string | `"http://localhost:11434"` | Ollama local model endpoint |

**Checked in:**
- `OptimalSystemAgent.Providers.*`
- `OptimalSystemAgent.Tools.Builtins.pm4py_discover`
- `OptimalSystemAgent.Tools.Builtins.businessos_api`

### Storage & Persistence

| Variable | Type | Default | Purpose |
|----------|------|---------|---------|
| `OSA_DB_URL` | string | SQLite in `~/.osa/osa.db` | Primary database (SQLite or PostgreSQL) |
| `OSA_POSTGRES_URL` | string | — | PostgreSQL connection (for multi-tenant) |
| `OSA_SKILL_DIR` | string | `~/.osa/skills` | Directory for skill YAML files |
| `OSA_CONFIG_DIR` | string | `~/.osa` | OSA config directory |
| `OSA_LOG_DIR` | string | `~/.osa/logs` | Log file directory |

**Checked in:**
- `OptimalSystemAgent.Application.start/2`
- `OptimalSystemAgent.Tools.Registry.SkillLoader`
- `OptimalSystemAgent.Machines`

### Telemetry & Observability

| Variable | Type | Default | Purpose |
|----------|------|---------|---------|
| `OTEL_EXPORTER_OTLP_ENDPOINT` | string | `"http://localhost:4317"` | OpenTelemetry collector endpoint |
| `OSA_LOG_LEVEL` | atom | `:info` | Logger level (`debug`, `info`, `warn`, `error`) |
| `OSA_METRICS_ENABLED` | boolean | `true` | Emit Prometheus metrics |
| `OSA_METRICS_PORT` | integer | `9090` | Prometheus scrape port |

**Checked in:**
- `OptimalSystemAgent.Application.start/2`
- Logger configuration

### Advanced / Experimental

| Variable | Type | Default | Purpose |
|----------|------|---------|---------|
| `OSA_COMPUTER_USE_ENABLED` | boolean | `false` | Enable computer_use tool (GUI automation) |
| `OSA_CONSENSUS_ENABLED` | boolean | `false` | Enable HotStuff BFT consensus (experimental) |
| `OSA_SIGNAL_THEORY_STRICT_MODE` | boolean | `false` | Reject all low S/N ratio signals |

**Checked in:**
- Feature-gated modules

---

## Application Configuration

Loaded from `config/config.exs` and runtime config.

### Core Config

```elixir
# config/config.exs
config :optimal_system_agent,
  # GenServer names and registry keys
  agent_registry: AgentRegistry,
  session_registry: SessionRegistry,

  # Supervisor specs
  restart_strategy: :rest_for_one,
  max_restarts: 5,
  max_seconds: 60,

  # Feature flags
  healing_enabled: true,
  consensus_enabled: false,

  # Paths
  config_dir: Application.get_env(:optimal_system_agent, :config_dir, "~/.osa"),
  skills_dir: Application.get_env(:optimal_system_agent, :skills_dir, "~/.osa/skills")
```

### Tool Configuration

```elixir
config :optimal_system_agent, :tools,
  builtins: [
    OptimalSystemAgent.Tools.Builtins.FileRead,
    OptimalSystemAgent.Tools.Builtins.FileWrite,
    OptimalSystemAgent.Tools.Builtins.ProcessDocument,
    # ... all 32+ tools
  ]
```

### Budget Configuration

```elixir
config :optimal_system_agent, :budget,
  critical: %{
    tokens_per_day: :unlimited,
    llm_calls_per_day: :unlimited,
    tool_calls_per_hour: 1000
  },
  high: %{
    tokens_per_day: 1_000_000,
    llm_calls_per_day: 5000,
    tool_calls_per_hour: 500
  },
  normal: %{
    tokens_per_day: 100_000,
    llm_calls_per_day: 1000,
    tool_calls_per_hour: 100
  },
  low: %{
    tokens_per_day: 10_000,
    llm_calls_per_day: 100,
    tool_calls_per_hour: 10
  }
```

---

## ETS Tables

All ETS tables are **in-memory**, created on application startup in `Application.start/2`.

### Named ETS Tables

| Table | Scope | Key | Value | TTL? | Purpose |
|-------|-------|-----|-------|------|---------|
| `:osa_sessions` | Bag | `session_id` | `{session_id, user_id, agent_id, started_at}` | Yes (30 min) | Active session tracking |
| `:osa_agents` | Bag | `agent_id` | `{agent_id, session_id, state, status}` | No | Running agents |
| `:osa_tools_cache` | Bag | `tool_name` | Tool metadata | No | Tool registry cache |
| `:osa_budget_counters` | Bag | `{agent_id, tier}` | `{tokens_spent, calls_made}` | Yes (1 day) | Budget tracking |
| `:osa_provider_failures` | Bag | `provider` | `{provider, failure_count, last_error}` | Yes (5 min) | Provider health |
| `:osa_memory_episodes` | Bag | `{agent_id, timestamp}` | Episode data | Yes (varies) | Episodic memory cache |
| `:osa_cancel_flags` | Bag | `session_id` | `{cancelled, reason}` | No | Cancellation signals |
| `:osa_context_cache` | Bag | `{session_id, turn}` | Context snapshot | No | Context compaction |
| `:osa_reflex_log` | Ordered Set | Auto-inc | `{timestamp, reflex, data}` | No | Reflex arc audit log |
| `:osa_task_queue` | Ordered Set | Auto-inc | Task metadata | No | Pending tasks |
| `:osa_pending_operations` | Bag | Operation ID | Operation state | Yes (varies) | In-flight operations |

### Usage Example

```elixir
# Create table at boot
:ets.new(:osa_sessions, [:named_table, :bag, :public])

# Write to table
:ets.insert(:osa_sessions, {session_id, user_id, agent_id, now})

# Read from table
case :ets.lookup(:osa_sessions, session_id) do
  [{^session_id, uid, aid, _ts}] -> {:ok, {uid, aid}}
  [] -> {:error, :not_found}
end

# Delete from table
:ets.delete(:osa_sessions, session_id)

# Check existence with guard
if :ets.lookup(:osa_sessions, session_id) != [] do
  # Session exists
end
```

### Table Cleanup

Critical rule: **Always check if table exists before deleting**

```elixir
# SAFE: Guard prevents crash on missing table
defp cleanup_stale_sessions do
  if :ets.whereis(:osa_sessions) != :undefined do
    :ets.delete_all_objects(:osa_sessions)
  end
end
```

---

## GenServer Processes & Registry

All long-lived processes are registered in either:

1. **Dynamic Registry** — agents created at runtime
2. **Named GenServer** — singleton services

### Named Singletons

| Process | Module | Registered As | Supervision | Purpose |
|---------|--------|---------------|-------------|---------|
| Agent Loop | `Agent.Loop` | Via Registry | Transient | Core ReAct loop |
| Tool Registry | `Tools.Registry` | By name | Permanent | Tool discovery |
| Healing Orchestrator | `Healing.Orchestrator` | By name | Permanent | Failure diagnosis/healing |
| Reflex Arcs | `Healing.ReflexArcs` | By name | Permanent | 5 autonomic reflexes |
| Events Bus | `Events.Bus` | By name | Permanent | Event pub/sub |
| Budget Tracker | `Agent.Budget` | By name | Permanent | Token/call counting |
| Health Checker | `Providers.HealthChecker` | By name | Permanent | Provider availability |
| Session Manager | `Sessions.Manager` | By name | Permanent | Session lifecycle |
| Skill Loader | `Tools.Registry.SkillLoader` | By name | Transient | Hot load YAML skills |

### Dynamic Processes (Per-Agent)

| Registry | Key Pattern | Module | Lifetime |
|----------|------------|--------|----------|
| `AgentRegistry` | `{:agent, agent_id}` | `Agent.Loop` | Session duration |
| `SessionRegistry` | `{:session, session_id}` | `Sessions.Supervisor` | Session active |
| `TaskRegistry` | `{:task, task_id}` | `Tasks.Executor` | Task completion |

### Registry Lookup

```elixir
# Find agent process
case Registry.lookup(AgentRegistry, {:agent, agent_id}) do
  [{pid, _meta}] -> {:ok, pid}
  [] -> {:error, :not_found}
end

# Via tuple for GenServer calls
pid = {:via, Registry, {AgentRegistry, {:agent, agent_id}}}
GenServer.call(pid, :status, 10_000)
```

---

## Supervision Tree Structure

```
OptimalSystemAgent.Supervisors.Root (:rest_for_one)
├─ OptimalSystemAgent.Supervisors.Infrastructure (:one_for_one)
│  ├─ Tools.Registry (permanent)
│  ├─ Events.Bus (permanent)
│  ├─ Sessions.Manager (permanent)
│  └─ AgentRegistry (permanent)
├─ OptimalSystemAgent.Supervisors.Healing (:one_for_one)
│  ├─ Healing.Orchestrator (permanent)
│  ├─ Healing.ReflexArcs (permanent)
│  └─ Providers.HealthChecker (permanent)
├─ OptimalSystemAgent.Supervisors.AgentServices (dynamic)
│  └─ Agent.Loop {:via, Registry, {AgentRegistry, id}} (transient)
└─ OptimalSystemAgent.Channels.HTTP.Server (permanent)
```

### Restart Strategies

- `:permanent` — Always restart on crash or exit
- `:transient` — Only restart on abnormal crash (not normal exit)
- `:temporary` — Never restart (manual management only)

### Failure Cascade

If a `permanent` process crashes multiple times within `max_seconds`, the entire supervisor restarts.

```elixir
# Example: Too many restarts
Supervisor.init(children,
  strategy: :one_for_one,
  max_restarts: 5,        # Restart up to 5 times
  max_seconds: 60         # Within 60 seconds
)

# If 5+ crashes in 60 sec: entire supervisor crashes
```

---

## Database Schema (SQLite / PostgreSQL)

### Core Tables

| Table | Columns | Indexes | Purpose |
|-------|---------|---------|---------|
| `sessions` | `id, user_id, agent_id, started_at, ended_at, status` | `(user_id, started_at)` | Session audit trail |
| `messages` | `id, session_id, role, content, created_at, tokens` | `(session_id, created_at)` | Message history |
| `tools_used` | `id, session_id, tool_name, params, result, latency_ms` | `(session_id, tool_name)` | Tool execution log |
| `budget_usage` | `id, agent_id, tier, tokens_spent, calls_made, date` | `(agent_id, date)` | Budget tracking |
| `healing_events` | `id, session_id, failure_mode, action, success, timestamp` | `(session_id, failure_mode)` | Healing audit |

### Access

```elixir
# Query sessions
{:ok, sessions} = Repo.all(Session)

# Insert new budget record
%BudgetUsage{}
|> BudgetUsage.changeset(%{agent_id: id, tier: tier, tokens_spent: 500})
|> Repo.insert()

# Get healing log
healing_events = Repo.all(
  from h in HealingEvent,
  where: h.session_id == ^session_id,
  order_by: [desc: h.timestamp]
)
```

---

## Hot Reload

Configuration can be reloaded **without restart**:

```elixir
# 1. Update config file
# config/config.exs: budget_tier changed

# 2. Trigger reload (at runtime)
OptimalSystemAgent.Application.reload_config()

# 3. Changes take effect immediately
# No process restart, no downtime
```

---

## Validation & Health Checks

### Application Startup Checks

```elixir
defmodule OptimalSystemAgent.Application do
  def start(_type, _args) do
    :ok = validate_config()
    :ok = validate_database()
    :ok = validate_providers()

    # Proceed with supervision tree
  end

  defp validate_config do
    case System.get_env("ANTHROPIC_API_KEY") do
      nil -> {:error, "ANTHROPIC_API_KEY not set"}
      _ -> :ok
    end
  end
end
```

### Runtime Health Check

```bash
# HTTP endpoint
curl -s http://localhost:8089/api/health

# Response
{
  "status": "ok",
  "version": "1.0.0",
  "uptime_ms": 3600000,
  "services": {
    "agents_running": 5,
    "tools_registered": 32,
    "budget_status": "normal",
    "provider_status": "ok"
  }
}
```

---

## Troubleshooting Checklist

| Problem | Check | Fix |
|---------|-------|-----|
| Agent won't start | `ANTHROPIC_API_KEY` set? | `export ANTHROPIC_API_KEY=...` |
| Tool not found | Tool file in `lib/.../tools/builtins/`? | Create file + restart |
| ETS table crash | Table exists? | Add `whereis` guard |
| Budget enforcement fails | Budget config in `config.exs`? | Add tier config |
| Healing not firing | `OSA_HEALING_ENABLED=true`? | Set env var |
| Session idle timeout not working | Reaper running? | Check `Healing.ReflexArcs.log()` |
| Provider failover stuck | Health checker working? | Check provider health |

---

## Related Documentation

- [Agent API Reference](./agent-api-reference.md) — Agent callbacks & lifecycle
- [Healing Patterns](./healing-patterns.md) — Failure modes & repair strategies
- [Tool Behaviour](../explanation/tool-behaviour.md) — Tool contract
- OSA CLAUDE.md — Build & test commands

