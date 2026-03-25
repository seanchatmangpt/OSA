# Using PM4PyCoordinator Swarm in Agent Code

This guide shows how to integrate PM4PyCoordinator swarm launch into agent workflows.

## Basic Usage

### 1. Simple Swarm Launch

```elixir
defmodule MyAgent do
  alias OptimalSystemAgent.Providers.PM4PyCoordinator

  def discover_process_model(event_log) do
    case PM4PyCoordinator.launch_swarm(event_log, agent_count: 3) do
      {:ok, swarm_result} ->
        Logger.info("Swarm #{swarm_result["swarm_id"]} completed")
        {:ok, swarm_result}

      {:error, reason} ->
        Logger.error("Swarm failed: #{reason}")
        {:error, reason}
    end
  end
end
```

### 2. Swarm + A2A Post to BusinessOS

```elixir
defmodule ProcessDiscoveryAgent do
  alias OptimalSystemAgent.Providers.PM4PyCoordinator
  alias OptimalSystemAgent.Tools.Builtins.A2ACall

  def discover_and_post(event_log) do
    with {:ok, swarm_result} <-
           PM4PyCoordinator.launch_swarm(event_log, agent_count: 3),
         {:ok, a2a_response} <-
           post_to_businessos(swarm_result) do
      {:ok, %{swarm: swarm_result, a2a: a2a_response}}
    else
      error ->
        Logger.error("Discovery pipeline failed: #{inspect(error)}")
        error
    end
  end

  defp post_to_businessos(swarm_result) do
    a2a_metadata = swarm_result["a2a_call_metadata"]

    A2ACall.execute(%{
      "action" => "execute_tool",
      "agent_url" => "http://localhost:8001/api/integrations/a2a/agents",
      "tool_name" => "pm4py_discover",
      "arguments" => a2a_metadata["params"]
    })
  end
end
```

### 3. With Consensus Monitoring

```elixir
defmodule MonitoredDiscoveryAgent do
  alias OptimalSystemAgent.Providers.PM4PyCoordinator

  def discover_with_monitoring(event_log, opts \\ []) do
    agent_count = Keyword.get(opts, :agent_count, 3)

    {:ok, swarm_result} = PM4PyCoordinator.launch_swarm(event_log, agent_count: agent_count)

    consensus_level = swarm_result["consensus_level"]
    swarm_id = swarm_result["swarm_id"]

    case consensus_level do
      level when level >= 0.7 ->
        Logger.info("Swarm #{swarm_id}: Strong consensus (#{Float.round(level, 2)})")
        {:strong_consensus, swarm_result}

      level when level >= 0.5 ->
        Logger.warning("Swarm #{swarm_id}: Weak consensus (#{Float.round(level, 2)})")
        {:weak_consensus, swarm_result}

      level ->
        Logger.warning("Swarm #{swarm_id}: Low consensus (#{Float.round(level, 2)})")
        {:low_consensus, swarm_result}
    end
  end
end
```

### 4. ReAct Loop Integration

```elixir
defmodule ProcessMiningReAct do
  require Logger
  alias OptimalSystemAgent.Providers.PM4PyCoordinator

  def run_discovery_task(task, context) do
    Logger.info("[ReAct] Running: #{task}")

    # Assume task contains event_log in context
    event_log = Map.get(context, :event_log)

    case PM4PyCoordinator.launch_swarm(event_log, agent_count: 3) do
      {:ok, swarm_result} ->
        # Use swarm result in reasoning
        observation = format_observation(swarm_result)
        {:success, observation}

      {:error, reason} ->
        # Handle discovery failure
        observation = "Discovery failed: #{reason}"
        {:error, observation}
    end
  end

  defp format_observation(swarm_result) do
    swarm_id = swarm_result["swarm_id"]
    consensus = Float.round(swarm_result["consensus_level"], 2)
    model = swarm_result["consensus_model"]
    algorithm = swarm_result["algorithm"]
    execution_time = swarm_result["execution_time_ms"]

    """
    Swarm Discovery Result:
    - Swarm ID: #{swarm_id}
    - Algorithm: #{algorithm}
    - Consensus Level: #{consensus}
    - Model Activities: #{length(Map.get(model, "transitions", []))}
    - Execution Time: #{execution_time}ms
    """
  end
end
```

### 5. Error Handling with Retry

```elixir
defmodule ResilientDiscoveryAgent do
  alias OptimalSystemAgent.Providers.PM4PyCoordinator

  def discover_with_retry(event_log, max_attempts \\ 3) do
    discover_attempt(event_log, 1, max_attempts)
  end

  defp discover_attempt(event_log, attempt, max_attempts) when attempt > max_attempts do
    {:error, "Discovery failed after #{max_attempts} attempts"}
  end

  defp discover_attempt(event_log, attempt, max_attempts) do
    Logger.info("Attempt #{attempt}/#{max_attempts}")

    case PM4PyCoordinator.launch_swarm(event_log, agent_count: 3) do
      {:ok, swarm_result} ->
        {:ok, swarm_result}

      {:error, reason} ->
        if String.contains?(reason, "No valid discovery results") do
          # Retry on consensus failure
          Logger.warning("Attempt #{attempt} failed: #{reason}, retrying...")
          discover_attempt(event_log, attempt + 1, max_attempts)
        else
          # Don't retry on other errors
          {:error, reason}
        end
    end
  end
end
```

### 6. Configurable Consensus Threshold

```elixir
defmodule HighConsensusAgent do
  alias OptimalSystemAgent.Providers.PM4PyCoordinator

  def discover_strict_consensus(event_log) do
    # Set threshold to 0.9 (90% of agents must agree)
    case PM4PyCoordinator.launch_swarm(event_log,
           agent_count: 5,
           byzantine_threshold: 0.9) do
      {:ok, swarm_result} ->
        if swarm_result["consensus_level"] >= 0.9 do
          {:strict_consensus_reached, swarm_result}
        else
          {:strict_consensus_failed, swarm_result}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  def discover_loose_consensus(event_log) do
    # Set threshold to 0.5 (50% of agents must agree)
    case PM4PyCoordinator.launch_swarm(event_log,
           agent_count: 5,
           byzantine_threshold: 0.5) do
      {:ok, swarm_result} ->
        {:loose_consensus_reached, swarm_result}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
```

### 7. Full Agent Discovery Request Handler

```elixir
defmodule DiscoveryRequestHandler do
  require Logger
  alias OptimalSystemAgent.Providers.PM4PyCoordinator
  alias OptimalSystemAgent.Tools.Builtins.A2ACall

  @doc """
  Handle agent request: discover_process_model

  Request format:
  %{
    "event_log" => %{"events" => [...], ...},
    "agent_count" => 3,
    "algorithm" => "inductive_miner"
  }
  """
  def handle_discovery_request(request) do
    event_log = request["event_log"]
    agent_count = request["agent_count"] || 3
    algorithm = request["algorithm"] || "inductive_miner"

    Logger.info("Discovery request: #{agent_count} agents, algorithm: #{algorithm}")

    case PM4PyCoordinator.launch_swarm(event_log,
           agent_count: agent_count,
           algorithm: algorithm) do
      {:ok, swarm_result} ->
        # Post to BusinessOS if requested
        if request["post_to_businessos"] do
          post_result(swarm_result)
        else
          {:ok, swarm_result}
        end

      {:error, reason} ->
        {:error, "Discovery failed: #{reason}"}
    end
  end

  defp post_result(swarm_result) do
    a2a_metadata = swarm_result["a2a_call_metadata"]
    businessos_url = System.get_env("BUSINESSOS_A2A_URL",
                                     "http://localhost:8001/api/integrations/a2a/agents")

    case A2ACall.execute(%{
      "action" => "execute_tool",
      "agent_url" => businessos_url,
      "tool_name" => "pm4py_discover",
      "arguments" => a2a_metadata["params"]
    }) do
      {:ok, response} ->
        Logger.info("Posted to BusinessOS")
        {:ok, %{swarm: swarm_result, businessos_response: response}}

      {:error, reason} ->
        Logger.warning("Failed to post to BusinessOS: #{reason}")
        {:ok, swarm_result}  # Still return swarm result
    end
  end
end
```

## Pattern: Agent Task with Swarm Discovery

```elixir
defmodule DiscoveryAgentTask do
  require Logger
  alias OptimalSystemAgent.Providers.PM4PyCoordinator

  def run(task_request, context) do
    event_log = task_request["event_log"]
    user_id = task_request["user_id"] || "anonymous"

    Logger.info("[DiscoveryAgent:#{user_id}] Discovering process model...")

    start_time = System.monotonic_time(:millisecond)

    case PM4PyCoordinator.launch_swarm(event_log, agent_count: 3) do
      {:ok, swarm_result} ->
        elapsed = System.monotonic_time(:millisecond) - start_time

        response = %{
          status: "success",
          user_id: user_id,
          swarm_id: swarm_result["swarm_id"],
          consensus_level: swarm_result["consensus_level"],
          model_preview: format_model(swarm_result["consensus_model"]),
          execution_time_ms: elapsed
        }

        Logger.info("[DiscoveryAgent] ✓ Completed in #{elapsed}ms, consensus: #{swarm_result["consensus_level"]}")
        response

      {:error, reason} ->
        elapsed = System.monotonic_time(:millisecond) - start_time

        response = %{
          status: "failed",
          user_id: user_id,
          error: reason,
          execution_time_ms: elapsed
        }

        Logger.error("[DiscoveryAgent] ✗ Failed in #{elapsed}ms: #{reason}")
        response
    end
  end

  defp format_model(model) do
    %{
      places: length(Map.get(model, "places", [])),
      transitions: length(Map.get(model, "transitions", [])),
      arcs: length(Map.get(model, "arcs", []))
    }
  end
end
```

## Testing Your Integration

### Unit Test Example

```elixir
defmodule MyAgentTest do
  use ExUnit.Case
  alias MyAgent

  test "agent discovers process model successfully" do
    event_log = %{
      "events" => [
        %{"case_id" => "1", "activity" => "Start"},
        %{"case_id" => "1", "activity" => "Process"},
        %{"case_id" => "1", "activity" => "End"}
      ],
      "trace_count" => 1,
      "event_count" => 3
    }

    case MyAgent.discover_process_model(event_log) do
      {:ok, swarm_result} ->
        assert Map.has_key?(swarm_result, "swarm_id")
        assert Map.has_key?(swarm_result, "consensus_model")
        assert swarm_result["consensus_level"] >= 0.0

      {:error, _reason} ->
        # PM4Py not running - that's OK in test
        assert true
    end
  end
end
```

## Environment Configuration

Set these environment variables to configure swarm behavior:

```bash
# Number of agents
export PM4PY_COORDINATOR_AGENTS=3

# Discovery algorithm
export PM4PY_COORDINATOR_ALGORITHM=inductive_miner

# Byzantine consensus threshold
export PM4PY_COORDINATOR_BYZANTINE=0.7

# PM4Py HTTP endpoint
export PM4PY_HTTP_URL=http://localhost:8089

# BusinessOS A2A endpoint
export BUSINESSOS_A2A_URL=http://localhost:8001/api/integrations/a2a/agents
```

## Monitoring & Observability

### Log Output Example

```
[PM4PyCoordinator.Swarm] Launching 3-agent swarm 63d707df718b4575
[PM4PyCoordinator.Swarm63d707df718b4575] Launching 3 agents in parallel
[PM4PyCoordinator.Swarm63d707df718b4575.Agent0] Discovering from partition
[PM4PyCoordinator.Swarm63d707df718b4575.Agent1] Discovering from partition
[PM4PyCoordinator.Swarm63d707df718b4575.Agent2] Discovering from partition
[PM4PyCoordinator.Consensus] Validated 2/3 results (level: 0.67)
[PM4PyCoordinator.Consensus] Fallback to first result (consensus < 0.7 threshold)
[PM4PyCoordinator.A2A] A2A metadata prepared: {...}
```

### Metrics to Track

- `swarm_id`: Unique identifier for audit trail
- `consensus_level`: Quality metric (0.0..1.0)
- `execution_time_ms`: Performance tracking
- `agent_count`: Scalability testing
- `algorithm`: Traceability

## Performance Tips

1. **Parallel Discovery**: 3-5 agents typically optimal (diminishing returns beyond)
2. **Timeout**: 30s per agent is default; increase for large logs
3. **Threshold**: Start with 0.7; adjust based on discovery stability
4. **Caching**: Cache discovered models by log fingerprint if applicable

## Troubleshooting

### "No valid discovery results from swarm"
- PM4Py service not running
- Invalid event log format
- Network connectivity issue

**Solution**:
```bash
# Verify PM4Py is running
curl http://localhost:8089/health

# Check event log structure
iex> log = %{"events" => [...], "trace_count" => N, "event_count" => M}
```

### Low Consensus Level (< 0.7)
- Log structure varies across agents
- Partitioning causing different discovery results
- Algorithm not suitable for log

**Solution**: Increase agent count or adjust consensus threshold

### Timeout Errors
- PM4Py service slow
- Large event logs
- Network latency

**Solution**: Increase timeout in `launch_parallel_swarm/3` from 30s to higher value

## References

- [PM4PyCoordinator Implementation](./pm4py_swarm_integration.md)
- [A2A Tool Documentation](../lib/optimal_system_agent/tools/builtins/a2a_call.ex)
- [OSA Swarm Patterns](../lib/optimal_system_agent/swarm/patterns.ex)
