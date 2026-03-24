# MCP/A2A Troubleshooting Guide

## MCP Issues

### MCP server fails to start

**Symptom:** `MCP.Client` logs `Failed to start MCP server <name>`

**Checks:**
1. Verify `~/.osa/mcp.json` is valid JSON: `jq . ~/.osa/mcp.json`
2. Check the `command` and `args` fields point to existing executables
3. For npm-based servers: `npx -y @modelcontextprotocol/server-<name>` must resolve
4. Check transport: `"stdio"` requires local process, `"http"` requires reachable URL

### MCP tools not appearing in registry

**Symptom:** `Tools.Registry.list_tools()` returns no `mcp_` prefixed tools

**Checks:**
1. MCP client must be running: `Process.whereis(OptimalSystemAgent.MCP.Client)`
2. Tools load lazily — call `MCP.Client.reload_servers/0` to refresh
3. Check server responded to `tools/list` JSON-RPC request
4. Verify `import_deps: [:plug]` in `.formatter.exs` if using HTTP transport

### MCP config validation errors

**Symptom:** Config validator rejects `mcp.json`

**Checks:**
1. Each server must have `name` (unique), `transport`, and `command`/`url`
2. Transport must be `"stdio"` or `"http"` — no other values
3. Run: `mix test test/optimal_system_agent/mcp/config_validator_test.exs --no-start`

---

## A2A Issues

### A2A routes returning 404

**Symptom:** `POST /api/v1/a2a` returns 404

**Checks:**
1. Verify routes mounted in `channels/http/api/router.ex`
2. Check `A2ARoutes` module compiles: `Code.ensure_compiled(OptimalSystemAgent.Channels.HTTP.API.A2ARoutes)`
3. Ensure Bandit/Plug pipeline includes JSON body parser before A2A routes

### a2a_call tool not found

**Symptom:** Tool registry doesn't include `a2a_call`

**Checks:**
1. Module must compile: `Code.ensure_compiled(OptimalSystemAgent.Tools.Builtins.A2ACall)`
2. Must implement `name/0` and `execute/1` callbacks
3. Run: `mix test test/optimal_system_agent/tools/builtins/a2a_call_test.exs --no-start`

### A2A config validation errors

**Symptom:** Config validator rejects A2A configuration

**Checks:**
1. Agent cards must have `name`, `url`, and `version` fields
2. URLs must be valid HTTP(S) endpoints
3. Run: `mix test test/optimal_system_agent/a2a/config_validator_test.exs --no-start`

---

## Cross-Project Issues

### OSA cannot reach BusinessOS

**Symptom:** A2A call to BusinessOS times out

**Checks:**
1. BusinessOS running: `curl http://localhost:8001/api/health`
2. A2A routes registered: `curl http://localhost:8001/api/integrations/a2a/agents`
3. Check `OSA_BUSINESSOS_URL` env var or default `http://localhost:8001`

### Canopy cannot connect to OSA

**Symptom:** OSA adapter connection refused

**Checks:**
1. OSA running: `curl http://localhost:8089/health`
2. Check `shared_secret` auth in Canopy adapter config
3. Verify `osa_url` in Canopy's agent configuration

---

## Smoke Tests

```bash
# MCP/A2A smoke test (10 checks)
bash scripts/mcp-a2a-smoke-test.sh

# Vision 2030 smoke test (16 checks)
bash OSA/scripts/vision2030-smoke-test.sh

# E2E integration tests (10 tests)
cd OSA && mix test test/integration/mcp_a2a_cross_project_e2e_test.exs --no-start --include integration
```

---

## Common Error Messages

| Error | Cause | Fix |
|-------|-------|-----|
| `server_not_found` | MCP server name not in config | Add server to `~/.osa/mcp.json` |
| `proposal_not_found` | Consensus vote on unknown proposal | Create proposal first via `propose_vote/3` |
| `no process` | GenServer not running | Start app or check supervision tree |
| `invalid_fleet_id` | Empty string fleet ID | Use non-empty string |
| `invalid_agent_list` | Fewer than 4 agents | BFT requires minimum 4 agents |
