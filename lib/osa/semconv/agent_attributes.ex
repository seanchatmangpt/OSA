defmodule OpenTelemetry.SemConv.Incubating.AgentAttributes do
  @moduledoc """
  Agent semantic convention attributes.

  Namespace: `agent`

  This module is generated from the ChatmanGPT semantic convention registry.
  Do not edit manually — regenerate with:

      weaver registry generate -r ./semconv/model --templates ./semconv/templates elixir ./OSA/lib/osa/semconv/
  """

  @doc """
  Remaining time budget for the agent operation in milliseconds.

  Attribute: `agent.budget.remaining_ms`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `4500`, `2000`, `500`
  """
  @spec agent_budget_remaining_ms() :: :"agent.budget.remaining_ms"
  def agent_budget_remaining_ms, do: :"agent.budget.remaining_ms"

  @doc """
  The priority tier of the agent operation (affects budget allocation).

  Attribute: `agent.budget.tier`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `critical`, `normal`
  """
  @spec agent_budget_tier() :: :"agent.budget.tier"
  def agent_budget_tier, do: :"agent.budget.tier"

  @doc """
  Enumerated values for `agent.budget.tier`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `critical` | `"critical"` | critical |
  | `high` | `"high"` | high |
  | `normal` | `"normal"` | normal |
  | `low` | `"low"` | low |
  """
  @spec agent_budget_tier_values() :: %{
    critical: :critical,
    high: :high,
    normal: :normal,
    low: :low
  }
  def agent_budget_tier_values do
    %{
      critical: :critical,
      high: :high,
      normal: :normal,
      low: :low
    }
  end

  defmodule AgentBudgetTierValues do
    @moduledoc """
    Typed constants for the `agent.budget.tier` attribute.
    """

    @doc "critical"
    @spec critical() :: :critical
    def critical, do: :critical

    @doc "high"
    @spec high() :: :high
    def high, do: :high

    @doc "normal"
    @spec normal() :: :normal
    def normal, do: :normal

    @doc "low"
    @spec low() :: :low
    def low, do: :low

  end

  @doc """
  Unique identifier for the agent capability catalog.

  Attribute: `agent.capability.catalog_id`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `catalog-v1`, `agent-caps-2026`
  """
  @spec agent_capability_catalog_id() :: :"agent.capability.catalog_id"
  def agent_capability_catalog_id, do: :"agent.capability.catalog_id"

  @doc """
  Version string of the agent capability catalog.

  Attribute: `agent.capability.catalog_version`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `1.0.0`, `2.3.1`
  """
  @spec agent_capability_catalog_version() :: :"agent.capability.catalog_version"
  def agent_capability_catalog_version, do: :"agent.capability.catalog_version"

  @doc """
  Number of capabilities registered by this agent.

  Attribute: `agent.capability.count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `1`, `5`, `20`
  """
  @spec agent_capability_count() :: :"agent.capability.count"
  def agent_capability_count, do: :"agent.capability.count"

  @doc """
  Scope of the agent capability catalog (local node, cluster, or federated).

  Attribute: `agent.capability.scope`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `cluster`, `federated`
  """
  @spec agent_capability_scope() :: :"agent.capability.scope"
  def agent_capability_scope, do: :"agent.capability.scope"

  @doc """
  Enumerated values for `agent.capability.scope`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `local` | `"local"` | local |
  | `cluster` | `"cluster"` | cluster |
  | `federated` | `"federated"` | federated |
  """
  @spec agent_capability_scope_values() :: %{
    local: :local,
    cluster: :cluster,
    federated: :federated
  }
  def agent_capability_scope_values do
    %{
      local: :local,
      cluster: :cluster,
      federated: :federated
    }
  end

  defmodule AgentCapabilityScopeValues do
    @moduledoc """
    Typed constants for the `agent.capability.scope` attribute.
    """

    @doc "local"
    @spec local() :: :local
    def local, do: :local

    @doc "cluster"
    @spec cluster() :: :cluster
    def cluster, do: :cluster

    @doc "federated"
    @spec federated() :: :federated
    def federated, do: :federated

  end

  @doc """
  Latency in milliseconds for agent coordination messages (round-trip).

  Attribute: `agent.coordination.latency_ms`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `5`, `50`, `500`
  """
  @spec agent_coordination_latency_ms() :: :"agent.coordination.latency_ms"
  def agent_coordination_latency_ms, do: :"agent.coordination.latency_ms"

  @doc """
  Confidence score for the agent's decision, range [0.0, 1.0].

  Attribute: `agent.decision.confidence`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0.92`, `0.75`, `0.55`
  """
  @spec agent_decision_confidence() :: :"agent.decision.confidence"
  def agent_decision_confidence, do: :"agent.decision.confidence"

  @doc """
  The type of decision made by the agent.

  Attribute: `agent.decision.type`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `action`, `delegation`
  """
  @spec agent_decision_type() :: :"agent.decision.type"
  def agent_decision_type, do: :"agent.decision.type"

  @doc """
  Enumerated values for `agent.decision.type`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `action` | `"action"` | action |
  | `delegation` | `"delegation"` | delegation |
  | `escalation` | `"escalation"` | escalation |
  | `defer` | `"defer"` | defer |
  | `reject` | `"reject"` | reject |
  """
  @spec agent_decision_type_values() :: %{
    action: :action,
    delegation: :delegation,
    escalation: :escalation,
    defer: :defer,
    reject: :reject
  }
  def agent_decision_type_values do
    %{
      action: :action,
      delegation: :delegation,
      escalation: :escalation,
      defer: :defer,
      reject: :reject
    }
  end

  defmodule AgentDecisionTypeValues do
    @moduledoc """
    Typed constants for the `agent.decision.type` attribute.
    """

    @doc "action"
    @spec action() :: :action
    def action, do: :action

    @doc "delegation"
    @spec delegation() :: :delegation
    def delegation, do: :delegation

    @doc "escalation"
    @spec escalation() :: :escalation
    def escalation, do: :escalation

    @doc "defer"
    @spec defer() :: :defer
    def defer, do: :defer

    @doc "reject"
    @spec reject() :: :reject
    def reject, do: :reject

  end

  @doc """
  Duration of the critical path through the execution graph in milliseconds.

  Attribute: `agent.execution.critical_path_ms`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `150`, `500`, `2000`
  """
  @spec agent_execution_critical_path_ms() :: :"agent.execution.critical_path_ms"
  def agent_execution_critical_path_ms, do: :"agent.execution.critical_path_ms"

  @doc """
  Number of edges (dependencies) in the execution graph.

  Attribute: `agent.execution.edge_count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `2`, `9`, `30`
  """
  @spec agent_execution_edge_count() :: :"agent.execution.edge_count"
  def agent_execution_edge_count, do: :"agent.execution.edge_count"

  @doc """
  Unique identifier for the agent execution graph (DAG of agent steps).

  Attribute: `agent.execution.graph_id`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `graph-exec-001`, `dag-run-42`
  """
  @spec agent_execution_graph_id() :: :"agent.execution.graph_id"
  def agent_execution_graph_id, do: :"agent.execution.graph_id"

  @doc """
  Number of nodes (steps) in the execution graph.

  Attribute: `agent.execution.node_count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `3`, `10`, `25`
  """
  @spec agent_execution_node_count() :: :"agent.execution.node_count"
  def agent_execution_node_count, do: :"agent.execution.node_count"

  @doc """
  Reason the agent handoff was initiated.

  Attribute: `agent.handoff.reason`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `capability`, `load`
  """
  @spec agent_handoff_reason() :: :"agent.handoff.reason"
  def agent_handoff_reason, do: :"agent.handoff.reason"

  @doc """
  Enumerated values for `agent.handoff.reason`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `capability` | `"capability"` | capability |
  | `load` | `"load"` | load |
  | `timeout` | `"timeout"` | timeout |
  | `priority` | `"priority"` | priority |
  """
  @spec agent_handoff_reason_values() :: %{
    capability: :capability,
    load: :load,
    timeout: :timeout,
    priority: :priority
  }
  def agent_handoff_reason_values do
    %{
      capability: :capability,
      load: :load,
      timeout: :timeout,
      priority: :priority
    }
  end

  defmodule AgentHandoffReasonValues do
    @moduledoc """
    Typed constants for the `agent.handoff.reason` attribute.
    """

    @doc "capability"
    @spec capability() :: :capability
    def capability, do: :capability

    @doc "load"
    @spec load() :: :load
    def load, do: :load

    @doc "timeout"
    @spec timeout() :: :timeout
    def timeout, do: :timeout

    @doc "priority"
    @spec priority() :: :priority
    def priority, do: :priority

  end

  @doc """
  Time taken to transfer state to the receiving agent in milliseconds.

  Attribute: `agent.handoff.state_transfer_ms`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `10`, `50`, `200`
  """
  @spec agent_handoff_state_transfer_ms() :: :"agent.handoff.state_transfer_ms"
  def agent_handoff_state_transfer_ms, do: :"agent.handoff.state_transfer_ms"

  @doc """
  Identifier of the agent receiving the handoff.

  Attribute: `agent.handoff.target_id`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `agent-7`, `osa-executor-2`
  """
  @spec agent_handoff_target_id() :: :"agent.handoff.target_id"
  def agent_handoff_target_id, do: :"agent.handoff.target_id"

  @doc """
  Unique identifier of the agent.

  Attribute: `agent.id`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `agent-1`, `osa-react-agent`, `healing-agent-1`
  """
  @spec agent_id() :: :"agent.id"
  def agent_id, do: :"agent.id"

  @doc """
  The LLM model used for agent inference.

  Attribute: `agent.llm_model`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `claude-sonnet-4-6`, `claude-haiku-4-5`
  """
  @spec agent_llm_model() :: :"agent.llm_model"
  def agent_llm_model, do: :"agent.llm_model"

  @doc """
  Current iteration of the agent's main processing loop.

  Attribute: `agent.loop.iteration`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `1`, `5`, `42`
  """
  @spec agent_loop_iteration() :: :"agent.loop.iteration"
  def agent_loop_iteration, do: :"agent.loop.iteration"

  @doc """
  Number of peer agents sharing the same federated memory pool.

  Attribute: `agent.memory.federation.peer_count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `2`, `5`, `10`
  """
  @spec agent_memory_federation_peer_count() :: :"agent.memory.federation.peer_count"
  def agent_memory_federation_peer_count, do: :"agent.memory.federation.peer_count"

  @doc """
  Monotonically increasing version counter for federated memory consistency.

  Attribute: `agent.memory.federation.version`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `1`, `42`, `1000`
  """
  @spec agent_memory_federation_version() :: :"agent.memory.federation.version"
  def agent_memory_federation_version, do: :"agent.memory.federation.version"

  @doc """
  Identifier of the federated memory pool shared across multiple agents.

  Attribute: `agent.memory.federation_id`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `fed-mem-pool-1`, `cluster-memory-abc`
  """
  @spec agent_memory_federation_id() :: :"agent.memory.federation_id"
  def agent_memory_federation_id, do: :"agent.memory.federation_id"

  @doc """
  Current size of the agent's working memory in tokens or items.

  Attribute: `agent.memory.size`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `100`, `1000`, `10000`
  """
  @spec agent_memory_size() :: :"agent.memory.size"
  def agent_memory_size, do: :"agent.memory.size"

  @doc """
  Latency in milliseconds for synchronizing state with federated memory peers.

  Attribute: `agent.memory.sync.latency_ms`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `5`, `25`, `100`
  """
  @spec agent_memory_sync_latency_ms() :: :"agent.memory.sync.latency_ms"
  def agent_memory_sync_latency_ms, do: :"agent.memory.sync.latency_ms"

  @doc """
  Type of memory the agent is accessing or updating.

  Attribute: `agent.memory.type`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `short_term`, `long_term`
  """
  @spec agent_memory_type() :: :"agent.memory.type"
  def agent_memory_type, do: :"agent.memory.type"

  @doc """
  Enumerated values for `agent.memory.type`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `short_term` | `"short_term"` | short_term |
  | `long_term` | `"long_term"` | long_term |
  | `episodic` | `"episodic"` | episodic |
  | `semantic` | `"semantic"` | semantic |
  """
  @spec agent_memory_type_values() :: %{
    short_term: :short_term,
    long_term: :long_term,
    episodic: :episodic,
    semantic: :semantic
  }
  def agent_memory_type_values do
    %{
      short_term: :short_term,
      long_term: :long_term,
      episodic: :episodic,
      semantic: :semantic
    }
  end

  defmodule AgentMemoryTypeValues do
    @moduledoc """
    Typed constants for the `agent.memory.type` attribute.
    """

    @doc "short_term"
    @spec short_term() :: :short_term
    def short_term, do: :short_term

    @doc "long_term"
    @spec long_term() :: :long_term
    def long_term, do: :long_term

    @doc "episodic"
    @spec episodic() :: :episodic
    def episodic, do: :episodic

    @doc "semantic"
    @spec semantic() :: :semantic
    def semantic, do: :semantic

  end

  @doc """
  Number of messages exchanged by this agent during the current operation.

  Attribute: `agent.message.count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `1`, `5`, `42`
  """
  @spec agent_message_count() :: :"agent.message.count"
  def agent_message_count, do: :"agent.message.count"

  @doc """
  Identifier of the orchestrating agent supervising this agent (Armstrong supervision tree).

  Attribute: `agent.orchestrator.id`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `osa-root`, `coordinator-1`
  """
  @spec agent_orchestrator_id() :: :"agent.orchestrator.id"
  def agent_orchestrator_id, do: :"agent.orchestrator.id"

  @doc """
  Outcome of the agent decision.

  Attribute: `agent.outcome`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `success`, `failure`, `escalated`
  """
  @spec agent_outcome() :: :"agent.outcome"
  def agent_outcome, do: :"agent.outcome"

  @doc """
  Enumerated values for `agent.outcome`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `success` | `"success"` | success |
  | `failure` | `"failure"` | failure |
  | `escalated` | `"escalated"` | escalated |
  """
  @spec agent_outcome_values() :: %{
    success: :success,
    failure: :failure,
    escalated: :escalated
  }
  def agent_outcome_values do
    %{
      success: :success,
      failure: :failure,
      escalated: :escalated
    }
  end

  defmodule AgentOutcomeValues do
    @moduledoc """
    Typed constants for the `agent.outcome` attribute.
    """

    @doc "success"
    @spec success() :: :success
    def success, do: :success

    @doc "failure"
    @spec failure() :: :failure
    def failure, do: :failure

    @doc "escalated"
    @spec escalated() :: :escalated
    def escalated, do: :escalated

  end

  @doc """
  Identifier of the agent pipeline being executed.

  Attribute: `agent.pipeline.id`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `pipeline-001`, `pl-extract-transform-load`
  """
  @spec agent_pipeline_id() :: :"agent.pipeline.id"
  def agent_pipeline_id, do: :"agent.pipeline.id"

  @doc """
  Retry policy for the agent pipeline stage.

  Attribute: `agent.pipeline.retry_policy`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  """
  @spec agent_pipeline_retry_policy() :: :"agent.pipeline.retry_policy"
  def agent_pipeline_retry_policy, do: :"agent.pipeline.retry_policy"

  @doc """
  Enumerated values for `agent.pipeline.retry_policy`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `none` | `"none"` | none |
  | `fixed_delay` | `"fixed_delay"` | fixed_delay |
  | `exponential_backoff` | `"exponential_backoff"` | exponential_backoff |
  | `circuit_breaker` | `"circuit_breaker"` | circuit_breaker |
  """
  @spec agent_pipeline_retry_policy_values() :: %{
    none: :none,
    fixed_delay: :fixed_delay,
    exponential_backoff: :exponential_backoff,
    circuit_breaker: :circuit_breaker
  }
  def agent_pipeline_retry_policy_values do
    %{
      none: :none,
      fixed_delay: :fixed_delay,
      exponential_backoff: :exponential_backoff,
      circuit_breaker: :circuit_breaker
    }
  end

  defmodule AgentPipelineRetryPolicyValues do
    @moduledoc """
    Typed constants for the `agent.pipeline.retry_policy` attribute.
    """

    @doc "none"
    @spec none() :: :none
    def none, do: :none

    @doc "fixed_delay"
    @spec fixed_delay() :: :fixed_delay
    def fixed_delay, do: :fixed_delay

    @doc "exponential_backoff"
    @spec exponential_backoff() :: :exponential_backoff
    def exponential_backoff, do: :exponential_backoff

    @doc "circuit_breaker"
    @spec circuit_breaker() :: :circuit_breaker
    def circuit_breaker, do: :circuit_breaker

  end

  @doc """
  Current stage name in the agent pipeline.

  Attribute: `agent.pipeline.stage`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `extract`, `transform`, `validate`, `load`
  """
  @spec agent_pipeline_stage() :: :"agent.pipeline.stage"
  def agent_pipeline_stage, do: :"agent.pipeline.stage"

  @doc """
  Total number of stages in the pipeline.

  Attribute: `agent.pipeline.stage_count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `3`, `5`, `8`
  """
  @spec agent_pipeline_stage_count() :: :"agent.pipeline.stage_count"
  def agent_pipeline_stage_count, do: :"agent.pipeline.stage_count"

  @doc """
  Change in confidence score from start to end of the reasoning trace, range [-1.0, 1.0].

  Attribute: `agent.reasoning.confidence_delta`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0.15`, `-0.05`
  """
  @spec agent_reasoning_confidence_delta() :: :"agent.reasoning.confidence_delta"
  def agent_reasoning_confidence_delta, do: :"agent.reasoning.confidence_delta"

  @doc """
  Duration in milliseconds of the complete reasoning trace.

  Attribute: `agent.reasoning.duration_ms`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `250`, `1500`
  """
  @spec agent_reasoning_duration_ms() :: :"agent.reasoning.duration_ms"
  def agent_reasoning_duration_ms, do: :"agent.reasoning.duration_ms"

  @doc """
  Number of reasoning steps in the agent's chain-of-thought trace.

  Attribute: `agent.reasoning.step_count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `5`, `12`
  """
  @spec agent_reasoning_step_count() :: :"agent.reasoning.step_count"
  def agent_reasoning_step_count, do: :"agent.reasoning.step_count"

  @doc """
  Unique identifier for an agent reasoning trace (chain-of-thought record).

  Attribute: `agent.reasoning.trace_id`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `trace-abc123`, `cot-run-007`
  """
  @spec agent_reasoning_trace_id() :: :"agent.reasoning.trace_id"
  def agent_reasoning_trace_id, do: :"agent.reasoning.trace_id"

  @doc """
  Number of child agents spawned by this agent in the current session.

  Attribute: `agent.spawn.count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0`, `3`, `10`
  """
  @spec agent_spawn_count() :: :"agent.spawn.count"
  def agent_spawn_count, do: :"agent.spawn.count"

  @doc """
  Time in milliseconds from spawn request to agent ready state.

  Attribute: `agent.spawn.latency_ms`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `50`, `200`, `1500`
  """
  @spec agent_spawn_latency_ms() :: :"agent.spawn.latency_ms"
  def agent_spawn_latency_ms, do: :"agent.spawn.latency_ms"

  @doc """
  Identifier of the parent agent that initiated the spawn operation.

  Attribute: `agent.spawn.parent_id`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `orchestrator-1`, `pipeline-root`
  """
  @spec agent_spawn_parent_id() :: :"agent.spawn.parent_id"
  def agent_spawn_parent_id, do: :"agent.spawn.parent_id"

  @doc """
  Strategy used to create the spawned agent.

  Attribute: `agent.spawn.strategy`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `on_demand`, `pre_warmed`, `pooled`
  """
  @spec agent_spawn_strategy() :: :"agent.spawn.strategy"
  def agent_spawn_strategy, do: :"agent.spawn.strategy"

  @doc """
  Enumerated values for `agent.spawn.strategy`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `on_demand` | `"on_demand"` | on_demand |
  | `pre_warmed` | `"pre_warmed"` | pre_warmed |
  | `pooled` | `"pooled"` | pooled |
  """
  @spec agent_spawn_strategy_values() :: %{
    on_demand: :on_demand,
    pre_warmed: :pre_warmed,
    pooled: :pooled
  }
  def agent_spawn_strategy_values do
    %{
      on_demand: :on_demand,
      pre_warmed: :pre_warmed,
      pooled: :pooled
    }
  end

  defmodule AgentSpawnStrategyValues do
    @moduledoc """
    Typed constants for the `agent.spawn.strategy` attribute.
    """

    @doc "on_demand"
    @spec on_demand() :: :on_demand
    def on_demand, do: :on_demand

    @doc "pre_warmed"
    @spec pre_warmed() :: :pre_warmed
    def pre_warmed, do: :pre_warmed

    @doc "pooled"
    @spec pooled() :: :pooled
    def pooled, do: :pooled

  end

  @doc """
  The current execution status of the agent task.

  Attribute: `agent.task.status`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `running`, `completed`
  """
  @spec agent_task_status() :: :"agent.task.status"
  def agent_task_status, do: :"agent.task.status"

  @doc """
  Enumerated values for `agent.task.status`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `pending` | `"pending"` | pending |
  | `running` | `"running"` | running |
  | `completed` | `"completed"` | completed |
  | `failed` | `"failed"` | failed |
  | `cancelled` | `"cancelled"` | cancelled |
  """
  @spec agent_task_status_values() :: %{
    pending: :pending,
    running: :running,
    completed: :completed,
    failed: :failed,
    cancelled: :cancelled
  }
  def agent_task_status_values do
    %{
      pending: :pending,
      running: :running,
      completed: :completed,
      failed: :failed,
      cancelled: :cancelled
    }
  end

  defmodule AgentTaskStatusValues do
    @moduledoc """
    Typed constants for the `agent.task.status` attribute.
    """

    @doc "pending"
    @spec pending() :: :pending
    def pending, do: :pending

    @doc "running"
    @spec running() :: :running
    def running, do: :running

    @doc "completed"
    @spec completed() :: :completed
    def completed, do: :completed

    @doc "failed"
    @spec failed() :: :failed
    def failed, do: :failed

    @doc "cancelled"
    @spec cancelled() :: :cancelled
    def cancelled, do: :cancelled

  end

  @doc """
  Total token count for the agent inference.

  Attribute: `agent.token_count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `256`, `1024`, `4096`
  """
  @spec agent_token_count() :: :"agent.token_count"
  def agent_token_count, do: :"agent.token_count"

  @doc """
  The coordination topology of agents in this multi-agent system.

  Attribute: `agent.topology.type`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `pipeline`, `fan_out`, `hierarchical`
  """
  @spec agent_topology_type() :: :"agent.topology.type"
  def agent_topology_type, do: :"agent.topology.type"

  @doc """
  Enumerated values for `agent.topology.type`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `pipeline` | `"pipeline"` | pipeline |
  | `fan_out` | `"fan_out"` | fan_out |
  | `hierarchical` | `"hierarchical"` | hierarchical |
  | `mesh` | `"mesh"` | mesh |
  | `star` | `"star"` | star |
  """
  @spec agent_topology_type_values() :: %{
    pipeline: :pipeline,
    fan_out: :fan_out,
    hierarchical: :hierarchical,
    mesh: :mesh,
    star: :star
  }
  def agent_topology_type_values do
    %{
      pipeline: :pipeline,
      fan_out: :fan_out,
      hierarchical: :hierarchical,
      mesh: :mesh,
      star: :star
    }
  end

  defmodule AgentTopologyTypeValues do
    @moduledoc """
    Typed constants for the `agent.topology.type` attribute.
    """

    @doc "pipeline"
    @spec pipeline() :: :pipeline
    def pipeline, do: :pipeline

    @doc "fan_out"
    @spec fan_out() :: :fan_out
    def fan_out, do: :fan_out

    @doc "hierarchical"
    @spec hierarchical() :: :hierarchical
    def hierarchical, do: :hierarchical

    @doc "mesh"
    @spec mesh() :: :mesh
    def mesh, do: :mesh

    @doc "star"
    @spec star() :: :star
    def star, do: :star

  end

  @doc """
  Unique identifier for the workflow checkpoint.

  Attribute: `agent.workflow.checkpoint_id`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `chk-abc123`, `wf-checkpoint-47`
  """
  @spec agent_workflow_checkpoint_id() :: :"agent.workflow.checkpoint_id"
  def agent_workflow_checkpoint_id, do: :"agent.workflow.checkpoint_id"

  @doc """
  Step number at which the checkpoint was captured.

  Attribute: `agent.workflow.checkpoint_step`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `5`, `12`, `100`
  """
  @spec agent_workflow_checkpoint_step() :: :"agent.workflow.checkpoint_step"
  def agent_workflow_checkpoint_step, do: :"agent.workflow.checkpoint_step"

  @doc """
  Number of times this workflow has been resumed from a checkpoint.

  Attribute: `agent.workflow.resume_count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0`, `1`, `3`
  """
  @spec agent_workflow_resume_count() :: :"agent.workflow.resume_count"
  def agent_workflow_resume_count, do: :"agent.workflow.resume_count"

end