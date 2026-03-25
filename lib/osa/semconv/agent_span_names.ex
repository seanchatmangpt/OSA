defmodule OpenTelemetry.SemConv.Incubating.AgentSpanNames do
  @moduledoc """
  Agent semantic convention span names.

  Namespace: `agent`

  This module is generated from the ChatmanGPT semantic convention registry.
  Do not edit manually — regenerate with:

      weaver registry generate -r ./semconv/model --templates ./semconv/templates elixir ./OSA/lib/osa/semconv/
  """

  @doc """
  Agent capability catalog operation — registering or querying the catalog of agent capabilities.

  Span: `span.agent.capability.catalog`
  Kind: `internal`
  Stability: `development`
  """
  @spec agent_capability_catalog() :: String.t()
  def agent_capability_catalog, do: "agent.capability.catalog"

  @doc """
  Agent coordination operation — dispatching tasks to sub-agents in a topology.

  Span: `span.agent.coordinate`
  Kind: `client`
  Stability: `development`
  """
  @spec agent_coordinate() :: String.t()
  def agent_coordinate, do: "agent.coordinate"

  @doc """
  An autonomous decision made by an agent — action selection with confidence scoring.

  Span: `span.agent.decision`
  Kind: `internal`
  Stability: `development`
  """
  @spec agent_decision() :: String.t()
  def agent_decision, do: "agent.decision"

  @doc """
  Execution of an agent execution graph — traversing a DAG of agent steps to completion.

  Span: `span.agent.execution.graph`
  Kind: `internal`
  Stability: `development`
  """
  @spec agent_execution_graph() :: String.t()
  def agent_execution_graph, do: "agent.execution.graph"

  @doc """
  Agent handoff — transfers control and state to another agent based on capability, load, or priority.

  Span: `span.agent.handoff`
  Kind: `producer`
  Stability: `development`
  """
  @spec agent_handoff() :: String.t()
  def agent_handoff, do: "agent.handoff"

  @doc """
  LLM inference call made by an OSA agent.

  Span: `span.agent.llm_predict`
  Kind: `client`
  Stability: `development`
  """
  @spec agent_llm_predict() :: String.t()
  def agent_llm_predict, do: "agent.llm_predict"

  @doc """
  One iteration of the agent's main reasoning and action loop.

  Span: `span.agent.loop`
  Kind: `internal`
  Stability: `development`
  """
  @spec agent_loop() :: String.t()
  def agent_loop, do: "agent.loop"

  @doc """
  Synchronizing agent memory state with a federated memory pool shared across agents.

  Span: `span.agent.memory.federate`
  Kind: `client`
  Stability: `development`
  """
  @spec agent_memory_federate() :: String.t()
  def agent_memory_federate, do: "agent.memory.federate"

  @doc """
  Agent memory update — writing new information to agent working memory.

  Span: `span.agent.memory.update`
  Kind: `internal`
  Stability: `development`
  """
  @spec agent_memory_update() :: String.t()
  def agent_memory_update, do: "agent.memory.update"

  @doc """
  Execution of an agent pipeline stage — processes data through a defined transformation.

  Span: `span.agent.pipeline.execute`
  Kind: `internal`
  Stability: `development`
  """
  @spec agent_pipeline_execute() :: String.t()
  def agent_pipeline_execute, do: "agent.pipeline.execute"

  @doc """
  Agent reasoning trace — records the chain-of-thought steps an agent takes to reach a decision.

  Span: `span.agent.reasoning.trace`
  Kind: `internal`
  Stability: `development`
  """
  @spec agent_reasoning_trace() :: String.t()
  def agent_reasoning_trace, do: "agent.reasoning.trace"

  @doc """
  Agent spawning — creating a new child agent under the current supervision tree.

  Span: `span.agent.spawn`
  Kind: `internal`
  Stability: `development`
  """
  @spec agent_spawn() :: String.t()
  def agent_spawn, do: "agent.spawn"

  @doc """
  Agent spawn profiling — observing the performance characteristics of a child agent spawn operation.

  Span: `span.agent.spawn.profile`
  Kind: `internal`
  Stability: `development`
  """
  @spec agent_spawn_profile() :: String.t()
  def agent_spawn_profile, do: "agent.spawn.profile"

  @doc """
  Agent workflow checkpoint — capturing workflow state to enable resumption after interruption.

  Span: `span.agent.workflow.checkpoint`
  Kind: `internal`
  Stability: `development`
  """
  @spec agent_workflow_checkpoint() :: String.t()
  def agent_workflow_checkpoint, do: "agent.workflow.checkpoint"

  @doc """
  All span names in this namespace.
  """
  @spec all() :: [String.t()]
  def all do
    [
      agent_capability_catalog(),
      agent_coordinate(),
      agent_decision(),
      agent_execution_graph(),
      agent_handoff(),
      agent_llm_predict(),
      agent_loop(),
      agent_memory_federate(),
      agent_memory_update(),
      agent_pipeline_execute(),
      agent_reasoning_trace(),
      agent_spawn(),
      agent_spawn_profile(),
      agent_workflow_checkpoint()
    ]
  end
end