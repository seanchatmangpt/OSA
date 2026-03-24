# MCP & A2A Testing Guide

> How to run, extend, and troubleshoot the MCP (Model Context Protocol) and A2A (Agent-to-Agent) test suites in OSA.

## Prerequisites

- **Elixir/OTP**: Elixir 1.17+ / OTP 27+
- **Mix**: Available on PATH (part of Elixir installation)
- **Dependencies**: Run `mix setup` before running tests
- **Compiled code**: Run `mix compile` before integration tests (mock server uses compiled Jason)

## Test Organization

Tests are organized into three layers across two protocol modules.

### MCP Tests (`test/optimal_system_agent/mcp/`)

| File | Type | Description | Tags |
|------|------|-------------|------|
| `config_validator_test.exs` | Unit | Config validation rules, defaults, error messages | `async: true` |
| `client_test.exs` | Unit | Client config resolution, tool caching, retry logic | `async: false` |
| `server_test.exs` | Unit | Module API contract, transport validation, whereis/stop | `async: false` |
| `mcp_http_transport_real_test.exs` | Integration | Real HTTP transport with connection, list_tools, call_tool | `:integration`, `:mcp_http` |
| `mcp_stdio_transport_real_test.exs` | Integration | Real stdio transport with subprocess, JSON-RPC, crash handling | `:integration`, `:mcp_stdio` |

### A2A Tests (`test/optimal_system_agent/a2a/`)

| File | Type | Description | Tags |
|------|------|-------------|------|
| `config_validator_test.exs` | Unit | Agent card validation, capabilities, input schemas | `async: true` |
| `task_stream_test.exs` | Integration | PubSub subscribe/publish, ordered events | `:skip` (requires PubSub) |
| `a2a_coordination_real_test.exs` | Integration | Multi-agent PubSub coordination, subscribe/unsubscribe | `:integration`, `:a2a` |
| `task_streaming_real_test.exs` | Integration | Task progress streaming with telemetry verification | `:integration`, `:a2a` |

### Cross-Project E2E (`test/integration/`)

| File | Type | Description | Tags |
|------|------|-------------|------|
| `mcp_a2a_cross_project_e2e_test.exs` | Integration | Module compilation, API contracts, signal theory consistency | `:integration` |

## Running Tests

### All MCP and A2A Tests

```bash
# Run all MCP tests
mix test test/optimal_system_agent/mcp/

# Run all A2A tests
mix test test/optimal_system_agent/a2a/

# Run both suites together
mix test test/optimal_system_agent/mcp/ test/optimal_system_agent/a2a/
```

### Specific Test Files

```bash
# Config validation only
mix test test/optimal_system_agent/mcp/config_validator_test.exs

# HTTP transport integration
mix test test/optimal_system_agent/mcp/mcp_http_transport_real_test.exs

# Stdio transport integration
mix test test/optimal_system_agent/mcp/mcp_stdio_transport_real_test.exs

# A2A coordination
mix test test/optimal_system_agent/a2a/a2a_coordination_real_test.exs

# Cross-project E2E
mix test test/integration/mcp_a2a_cross_project_e2e_test.exs
```

### Specific Tests by Name

```bash
# Run a single test by name pattern
mix test test/optimal_system_agent/mcp/client_test.exs --only "test:resolves default config path"

# Run all tests matching a describe block
mix test test/optimal_system_agent/mcp/ --only "describe:tool caching"
```

### Integration-Only Tests

```bash
# Run only integration-tagged tests
mix test --include integration

# Run only MCP HTTP integration tests
mix test --include mcp_http

# Run only MCP stdio integration tests
mix test --include mcp_stdio

# Run only A2A integration tests
mix test --include a2a
```

### Unit Tests Without App Boot

```bash
# Fast unit tests that do not start the application
mix test --no-start test/optimal_system_agent/mcp/config_validator_test.exs
mix test --no-start test/optimal_system_agent/a2a/config_validator_test.exs
```

## Telemetry Events

All telemetry events use the `:telemetry` library with the `[:osa, ...]` prefix.

### MCP Telemetry Events

#### `[:osa, :mcp, :server_start]`

Emitted when an MCP server process starts.

| Field | Type | Description |
|-------|------|-------------|
| `measurements.tools_count` | integer | Number of tools discovered from the server |
| `metadata.server_name` | string | Name of the MCP server |
| `metadata.transport` | string | Transport type (`"stdio"` or `"http"`) |
| `metadata.status` | atom | `:connected`, `:partial`, or `:failed` |
| `metadata.reason` | string | (Partial/failed only) Reason for non-connected status |

#### `[:osa, :mcp, :tool_call]`

Emitted on every tool invocation, whether from Client or Server.

| Field | Type | Description |
|-------|------|-------------|
| `measurements.duration` | integer | Execution time in nanoseconds (0 for cached) |
| `measurements.cached` | boolean | Whether the result was served from cache |
| `metadata.server` | string | MCP server name |
| `metadata.tool` | string | Tool name invoked |
| `metadata.status` | atom | `:ok` or `:error` |
| `metadata.reason` | string | (Error only) Inspected error reason |

#### `[:osa, :mcp, :server_reconnect]`

Emitted during reconnection attempts.

| Field | Type | Description |
|-------|------|-------------|
| `measurements.tools_count` | integer | Number of tools after reconnection |
| `metadata.server_name` | string | MCP server name |
| `metadata.transport` | string | Transport type |
| `metadata.status` | atom | `:failed` or `:reconnected` |
| `metadata.attempts` | integer | Reconnection attempt number |

### A2A Telemetry Events

#### `[:osa, :a2a, :task_stream]`

Emitted when a task status update is published.

| Field | Type | Description |
|-------|------|-------------|
| `measurements.duration` | integer | Publish duration in nanoseconds |
| `metadata.task_id` | string | Task identifier |
| `metadata.status` | string | Task status (`"created"`, `"running"`, `"completed"`, etc.) |
| `metadata.metadata` | map | Additional metadata attached to the event |

### Attaching Telemetry Handlers in Tests

```elixir
test "verifies telemetry event" do
  parent = self()
  ref = make_ref()

  handler_id = :telemetry.attach(
    {__MODULE__, ref},
    [:osa, :mcp, :tool_call],
    fn _event, measurements, metadata, _config ->
      send(parent, {ref, measurements, metadata})
    end,
    nil
  )

  on_exit(fn -> :telemetry.detach(handler_id) end)

  # ... trigger the event ...

  assert_receive {^ref, measurements, metadata}, 2000
  assert measurements[:duration] >= 0
end
```

## Mock MCP Server

### Location

```
test/support/mock_mcp_server.exs
```

An Elixir script that reads JSON-RPC requests from stdin and writes responses to stdout. Used by stdio transport integration tests.

### How It Works

The mock server implements the MCP JSON-RPC 2.0 protocol minimally:

1. Reads one line at a time from stdin
2. Parses the JSON-RPC request
3. Returns a response based on the method
4. Loops until EOF

### Supported Methods

| Method | Response |
|--------|----------|
| `initialize` | `protocolVersion: "2024-11-05"`, empty capabilities |
| `tools/list` | Empty tools array |
| Any other method | JSON-RPC error `-32601` (Method not found) |

### How Tests Invoke It

Tests use `/bin/sh -c "elixir <path>"` because `Port.open({:spawn_executable, ...})` requires a native binary and `elixir` is a shell script:

```elixir
defp mock_server_opts(name) do
  server_path = Path.expand("../../support/mock_mcp_server.exs", __DIR__)

  [
    name: name,
    transport: "stdio",
    command: "/bin/sh",
    args: ["-c", "elixir #{server_path}"]
  ]
end
```

### Dependencies

The mock server requires compiled Jason BEAM files:

```elixir
Code.append_path("_build/dev/lib/jason/ebin")
Code.append_path("_build/dev/lib/decimal/ebin")
```

Run `mix compile` before running stdio transport tests.

## Troubleshooting

### Escript / Mock Server Issues

**Problem**: `mix test test/optimal_system_agent/mcp/mcp_stdio_transport_real_test.exs` fails with `:enoent`

**Cause**: The `elixir` binary is not on PATH, or `_build/dev/lib/jason/ebin` does not exist.

**Fix**:
```bash
mix compile
which elixir  # Verify elixir is on PATH
```

### Port Conflicts

**Problem**: HTTP transport tests fail with "address already in use"

**Cause**: Another process is bound to the test ports (8081-8084).

**Fix**:
```bash
# Find and kill the process
lsof -i :8081
kill -9 <PID>
```

### Timeout Failures

**Problem**: Integration tests fail with `assert_receive` timeout

**Cause**: Telemetry events may not fire if the MCP server fails to start, or PubSub is not available.

**Fix**:
1. Ensure the application compiles cleanly: `mix compile --warnings-as-errors`
2. Check that Phoenix.PubSub is started (required for A2A tests)
3. Increase the timeout in `assert_receive` if running on a slow machine

### ETS Table Errors

**Problem**: `ArgumentError: argument error` when running client tests

**Cause**: The `:mcp_tool_cache` ETS table does not exist.

**Fix**: The test `setup_all` callback creates the table. If tests run in isolation, ensure the table is created:
```elixir
try do
  :ets.new(:mcp_tool_cache, [:named_table, :public, :set, read_concurrency: true])
rescue
  ArgumentError -> :ok
end
```

### `--no-start` Limitations

**Problem**: Integration tests fail or skip when run with `mix test --no-start`

**Cause**: `--no-start` does not start the application, so ETS tables, Registry, PubSub, and GenServers are unavailable.

**Fix**: Run integration tests with the full application:
```bash
mix test --include integration
```

Unit tests (`config_validator_test.exs`) work fine with `--no-start`.

## Test Coverage

The MCP and A2A test suites contain **45+ integration and unit tests** across 10 test files.

### Test Methodology

Tests follow the **Chicago TDD** methodology for integration tests, which emphasizes:

1. **Real subprocesses**: No mocks for transport layer -- actual `Port.open` and HTTP connections
2. **Crash testing**: Tests prefixed with `CRASH:` verify the system handles failures gracefully
3. **Telemetry verification**: Every integration test that fires telemetry attaches a handler and asserts on measurements and metadata
4. **Ordered event verification**: PubSub tests assert events arrive in the correct sequence
5. **Cleanup**: Every test uses `on_exit` callbacks to stop servers and detach handlers

### Coverage Summary

| Area | Unit Tests | Integration Tests | Total |
|------|-----------|-------------------|-------|
| MCP Config Validation | 15 | 0 | 15 |
| MCP Client | 12 | 0 | 12 |
| MCP Server API | 9 | 0 | 9 |
| MCP HTTP Transport | 0 | 7 | 7 |
| MCP Stdio Transport | 0 | 4 | 4 |
| A2A Config Validation | 12 | 0 | 12 |
| A2A Task Stream | 0 | 4 | 4 |
| A2A Coordination | 0 | 3 | 3 |
| A2A Task Streaming | 0 | 3 | 3 |
| Cross-Project E2E | 0 | 9 | 9 |
| **Total** | **48** | **30** | **78** |

### Smoke Tests

In addition to unit and integration tests, two smoke test scripts validate the running system:

- **MCP/A2A Smoke Test**: `scripts/mcp-a2a-smoke-test.sh` (10 tests)
- **Vision 2030 Smoke Test**: `scripts/vision2030-smoke-test.sh` (16 tests)

Both scripts require OSA running on `http://localhost:9089` (or set `OSA_URL`).

## Clean Compilation Verification

After any change, verify the project compiles with zero warnings:

```bash
mix compile --warnings-as-errors
```

This is the project's zero-tolerance compilation gate. No PR should be merged with warnings.
