# Reference: Agent API Reference

> **Purpose**: Quick lookup for agent callbacks, configuration, available tools, signals, and event types.
>
> **Audience**: Developers implementing agents or extending OSA runtime.

## Agent Callbacks

All agents are GenServer-based processes that implement these callbacks. Not all are required.

| Callback | Required? | Signature | Returns | Purpose |
|----------|-----------|-----------|---------|---------|
| `init/1` | Yes | `def init(opts)` | `{:ok, state}` \| `{:error, reason}` | Initialize agent state, load config |
| `handle_call/3` | No | `def handle_call(request, from, state)` | `{:reply, reply, new_state}` | Synchronous request (use timeouts!) |
| `handle_cast/2` | No | `def handle_cast(msg, state)` | `{:noreply, new_state}` | Asynchronous message |
| `handle_info/2` | No | `def handle_info(msg, state)` | `{:noreply, new_state}` | Timeout, external signal, scheduled task |
| `terminate/2` | No | `def terminate(reason, state)` | `:ok` | Cleanup on shutdown (release resources) |
| `code_change/3` | No | `def code_change(old_vsn, state, extra)` | `{:ok, new_state}` | Handle hot code reload |

### Example Agent

```elixir
defmodule MyAgent do
  use GenServer
  require Logger

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: via_name(opts[:id]))
  end

  def init(opts) do
    agent_id = Keyword.fetch!(opts, :id)
    Logger.info("[#{agent_id}] Started")

    state = %{
      id: agent_id,
      tools: [],
      status: :ready
    }

    {:ok, state}
  end

  def handle_call({:process, input}, from, state) do
    # Long-running operation should use timeout
    {:reply, {:ok, "processed"}, state}
  end

  def handle_cast({:update_tools, tools}, state) do
    {:noreply, %{state | tools: tools}}
  end

  def handle_info(:heartbeat, state) do
    Logger.debug("[#{state.id}] Heartbeat")
    {:noreply, state}
  end

  def terminate(reason, state) do
    Logger.info("[#{state.id}] Terminating: #{inspect(reason)}")
    :ok
  end

  defp via_name(id) do
    {:via, Registry, {AgentRegistry, id}}
  end
end
```

---

## Agent Configuration

Configuration can come from:

1. **Application config** (`config/config.exs`)
2. **Environment variables** (`System.get_env/1`)
3. **Startup options** (`start_link/1` opts)
4. **Runtime reconfig** (hot reload, no restart)

### Config Sources (Priority Order)

1. **Highest**: Startup options to `start_link/1`
2. `System.get_env("VAR_NAME")`
3. `Application.get_env(:optimal_system_agent, :key, default)`
4. **Lowest**: Hardcoded defaults

### Common Agent Config Keys

```elixir
config :optimal_system_agent, :agent,
  # Per-agent budgets
  default_budget_tokens: 4000,
  budget_tier: :normal,  # critical | high | normal | low

  # Tool behavior
  max_tool_calls_per_turn: 10,
  tool_timeout_ms: 30_000,
  parallel_tool_execution: true,

  # Memory behavior
  max_context_tokens: 8000,
  context_compaction_threshold: 0.85,

  # Healing
  enable_healing: true,
  healing_timeout_ms: 10_000,

  # Timeouts
  llm_call_timeout_ms: 120_000,
  session_idle_timeout_ms: 300_000,

  # Permissions
  default_permission_tier: :workspace,
  allowed_tools: :all,  # :all | list of tool names
  blocked_tools: []
```

### Access Config in Code

```elixir
# Get with default
budget = Application.get_env(:optimal_system_agent, :default_budget_tokens, 4000)

# Get from System.get_env (for deployment)
api_key = System.get_env("ANTHROPIC_API_KEY") || ""

# Combine (Env → Config → Default)
timeout =
  case System.get_env("OSA_LLM_TIMEOUT_MS") do
    nil -> Application.get_env(:optimal_system_agent, :llm_call_timeout_ms, 120_000)
    str -> String.to_integer(str)
  end
```

---

## Agent Lifecycle

```
start_link(opts)
  ↓
init(opts) — returns {:ok, state}
  ↓
Agent is registered and ready to receive messages
  ↓
handle_call/handle_cast/handle_info
  ↓
Process receives SHUTDOWN or supervisor kills it
  ↓
terminate(reason, state) — cleanup
```

### Restart Strategies

Set in supervisor spec:

```elixir
children = [
  # Permanent: restart if crashes OR exits normally
  {Agent, [id: 1], restart: :permanent},

  # Transient: restart only if crashes (not normal exit)
  {Agent, [id: 2], restart: :transient},

  # Temporary: never restart (manual management)
  {Agent, [id: 3], restart: :temporary}
]

Supervisor.init(children, strategy: :one_for_one)
```

---

## Available Built-In Tools

All tools implement `Tools.Behaviour`. Access via:

```bash
curl -s http://localhost:8089/api/tools | jq
```

Or in code:

```elixir
tools = OptimalSystemAgent.Tools.Registry.list_tools()
Enum.each(tools, fn t -> IO.inspect(t.name) end)
```

### Tool Safety Tiers

| Tier | Examples | Permission Required |
|------|----------|-------------------|
| `:read_only` | file_read, web_fetch, grep | `:workspace` |
| `:write_safe` | file_write, create_skill | `:workspace` |
| `:write_destructive` | file_delete, shell_execute | `:full` |
| `:terminal` | (reserved for future) | `:full` |

### All Built-In Tools (32+)

```
file_read              — Read file contents (read_only)
file_write             — Write file (write_safe)
file_edit              — Edit file (multi-file diff, write_safe)
file_delete            — Delete file (write_destructive)
file_grep              — Search files (read_only)
shell_execute          — Run shell command (write_destructive)
web_fetch              — Fetch URL + process with LLM (read_only)
ask_user               — Interactive prompt (read_only)
task_write             — Create task (write_safe)
memory_recall          — Query episodic memory (read_only)
git                    — Git operations (write_destructive)
pm4py_discover         — Process mining (read_only)
businessos_api         — Call BusinessOS API (depends on endpoint)
computer_use           — GUI automation (terminal)
create_skill           — Create reusable skill (write_safe)
download               — Download file (write_safe)
multi_file_edit        — Edit multiple files (write_safe)
delegate               — Call another agent (read_only)
message_agent          — Send message to agent (read_only)
peer_negotiate_task    — Peer-to-peer task (write_safe)
a2a_call               — Agent-to-agent RPC (read_only)
mcp_call               — Call MCP tool (depends)
process_document       — Parse docs (markdown, JSON, YAML) (read_only)
... and more
```

---

## Agent Signals (Input/Output)

Agents accept and emit signals in Signal Theory encoding:

### Signal Structure

```elixir
%{
  "mode" => "linguistic" | "visual" | "code" | "data" | "mixed",
  "genre" => "direct" | "brief" | "report" | "question" | "email" | ...,
  "type" => "direct" | "inform" | "commit" | "decide" | "express",
  "format" => "markdown" | "code" | "json" | "yaml" | "html",
  "weight" => 0.0..1.0,  # Signal importance/strength
  "content" => "actual message"
}
```

### Agent Input Genres

| Genre | Meaning | Example |
|-------|---------|---------|
| `direct` | Direct request, action required | "Write a unit test for the login function" |
| `question` | Query, information requested | "What is the max budget?" |
| `inform` | Informational only | "Budget increased to $1000" |
| `brief` | Executive summary needed | "Summarize the quarter results" |
| `report` | Detailed analysis | "Full incident report" |
| `email` | Email composition | "Draft a follow-up email" |

### Agent Output Signals

Agents emit signals during processing:

```elixir
# During tool calls
%{
  "mode" => "code",
  "genre" => "brief",
  "type" => "commit",
  "format" => "markdown",
  "weight" => 0.8,
  "content" => "Tool result: ..."
}

# Final response
%{
  "mode" => "linguistic",
  "genre" => "report",
  "type" => "inform",
  "format" => "markdown",
  "weight" => 0.95,
  "content" => "Final answer: ..."
}
```

---

## Event Types

The OSA event bus publishes events. Subscribe with:

```elixir
alias OptimalSystemAgent.Events.Bus

Bus.register_handler(:system_event, fn event -> handle_event(event) end)
```

### Event Categories

| Category | Type | Example | Emitted By |
|----------|------|---------|-----------|
| `system_event` | tuple | `{:agent_started, agent_id}` | Runtime |
| `tool_result` | tuple | `{:tool_executed, tool_name, result}` | ToolExecutor |
| `healing_event` | tuple | `{:healing, :deadlock_resolved, data}` | Healing |
| `budget_event` | tuple | `{:budget_warning, tier, remaining}` | Budget |

### Common Events

```elixir
# Agent lifecycle
{:agent_started, agent_id}
{:agent_stopping, agent_id}
{:agent_crashed, agent_id, reason}

# Tool execution
{:tool_invoked, tool_name, params}
{:tool_executed, tool_name, {:ok, result}}
{:tool_executed, tool_name, {:error, reason}}

# Healing
{:healing, :reflex_fired, reflex_name}
{:healing, :diagnosis_complete, failure_mode}
{:healing, :healing_applied, action}

# Budget
{:budget_warning, tier, percent_remaining}
{:budget_exhausted, tier}
{:budget_reset, tier}

# Session
{:session_created, session_id}
{:session_idle, session_id, idle_ms}
{:session_terminated, session_id}
```

### Emit Events

```elixir
alias OptimalSystemAgent.Events.Bus

Bus.publish(:system_event, {:custom_event, agent_id, data})
```

---

## Agent Modes & Operation Tiers

### Operation Modes

| Mode | Behavior | When To Use |
|------|----------|-----------|
| **Normal** | Full reasoning + tools | Standard operation |
| **Plan** | Single LLM call, no tools | Strategy/outline only |
| **Readonly** | Tools with `:read_only` safety | Read-only inspection |
| **Subagent** | Limited tools, parent controls | Delegated work |

Enable plan mode:

```elixir
# Agent starts in plan mode
GenServer.call(agent_pid, {:set_plan_mode, true})

# Agent processes message in plan mode (no tools)
# Returns structured plan without executing
```

### Permission Tiers

| Tier | Allowed Tools | Allowed Operations |
|------|---------------|-------------------|
| `:full` | All (including `:terminal`) | Everything |
| `:workspace` | `:read_only` + `:write_safe` | Read, edit, create |
| `:read_only` | `:read_only` only | Read files, web fetch, search |
| `:subagent` | Parent-specified list | Limited delegation |

Set permission:

```elixir
GenServer.call(agent_pid, {:set_permission_tier, :workspace})
```

---

## Agent Memory Layers

Agents have 4 memory types:

| Layer | Storage | Size Limit | Lifetime | Access |
|-------|---------|-----------|----------|--------|
| **Scratch** | In-process ETS | ~1MB | Session | Fast, transient |
| **Episodic** | SQLite/PostgreSQL | Unlimited | Permanent | Query by time range |
| **Semantic** | Vector DB (planned) | Unlimited | Permanent | Semantic search |
| **Procedural** | Skills YAML | Unlimited | Permanent | By skill name |

Access memory:

```elixir
# Recall from episodic
{:ok, memories} = OptimalSystemAgent.Memory.recall(agent_id, "query")

# Store new
:ok = OptimalSystemAgent.Memory.remember(agent_id, "event", metadata)
```

---

## Budget System

Every agent has a budget:

| Tier | Tokens/Day | LLM Calls/Day | Tool Calls/Hour |
|------|----------|---------------|-----------------|
| `critical` | Unlimited | Unlimited | 1000 |
| `high` | 1M | 5000 | 500 |
| `normal` | 100K | 1000 | 100 |
| `low` | 10K | 100 | 10 |

Monitor budget:

```elixir
{:ok, budget} = OptimalSystemAgent.Agent.Budget.get_budget(agent_id)
IO.inspect(budget)  # %{spent: 5000, limit: 100000, percent_used: 5.0}
```

---

## Common Patterns

### Pattern 1: Synchronous Tool Call

```elixir
# Send a call, wait for response (with timeout!)
result = GenServer.call(agent_pid, {:tool, "file_read", params}, 10_000)
```

### Pattern 2: Async Task Processing

```elixir
# Fire and forget, or wait later
task = Task.async(fn -> agent_process(pid, input) end)
result = Task.await(task, 30_000)
```

### Pattern 3: Event-Driven

```elixir
# Subscribe to events
Bus.register_handler(:tool_result, fn {tool, result} ->
  handle_tool_completion(tool, result)
end)
```

### Pattern 4: Healing on Failure

```elixir
# Catch failure, diagnose, heal
try do
  {:ok, result} = agent_call(pid, input)
rescue
  error ->
    {mode, _desc, _cause} = Diagnosis.diagnose(error)
    {:ok, healed} = Orchestrator.heal(mode, error)
    healed
end
```

---

## Debugging

### Check Agent Status

```elixir
# List all running agents
Supervisor.which_children(OptimalSystemAgent.Supervisors.AgentServices)

# Get agent state
{:ok, state} = GenServer.call(agent_pid, :debug_state)
IO.inspect(state)
```

### View Recent Events

```elixir
# Last 100 events
events = Bus.recent_events(:system_event, 100)
Enum.each(events, &IO.inspect/1)
```

### OTEL Tracing

All agent operations emit OTEL spans. View in Jaeger:

```bash
# Terminal 1: Start Jaeger
docker run -d -p 16686:16686 jaegertracing/all-in-one

# Terminal 2: Start OSA
mix osa.serve

# Terminal 3: Visit http://localhost:16686
# Search for service: optimal_system_agent
# Look for span_name: agent.process_message
```

### Logs

```bash
# Real-time logs
iex -S mix osa.serve

# Check log level
Application.get_env(:logger, :level)  # :debug, :info, :warn, :error

# Change level (runtime)
Logger.configure(level: :debug)
```

---

## Type Signatures (Common)

```elixir
# Agent state
%{
  session_id: String.t(),
  user_id: String.t(),
  channel: atom(),
  provider: atom(),
  model: String.t(),
  messages: [map()],
  status: :idle | :running | :thinking | :executing,
  tools: [String.t()],
  permission_tier: :full | :workspace | :read_only | :subagent
}

# Tool result
{:ok, result :: any()} | {:error, reason :: String.t()}

# Signal
%{
  "mode" => String.t(),
  "genre" => String.t(),
  "type" => String.t(),
  "format" => String.t(),
  "weight" => float(),
  "content" => String.t()
}

# Budget
%{
  spent: integer(),
  limit: integer(),
  tier: atom(),
  percent_used: float()
}

# Diagnosis result
{mode :: atom(), description :: String.t(), root_cause :: String.t()}
```

---

## Related References

- [Healing Patterns](./healing-patterns.md) — 11 failure modes + repair strategies
- [Tool Behaviour](../explanation/tool-behaviour.md) — Tool contract and lifecycle
- [Signal Theory](../explanation/signal-theory-quality-gates.md) — S=(M,G,T,F,W) encoding
- [Permission System](./permissions.md) — Role-based access control
- [OTEL Spans](../how-to/add-otel-spans.md) — Observability

