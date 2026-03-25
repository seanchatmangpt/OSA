defmodule OpenTelemetry.SemConv.Incubating.SpanNames do
  @moduledoc """
  OTEL span name constants for ChatmanGPT operations.
  Generated from semconv/model/*/spans.yaml definitions.

  Do not hardcode span names in production code — use these constants.
  Schema change → compile error here.

  Usage:
      require OpenTelemetry.Tracer, as: Tracer
      alias OpenTelemetry.SemConv.Incubating.SpanNames

      Tracer.start_span(SpanNames.healing_diagnosis())
  """

  # Healing domain

  @spec healing_diagnosis() :: binary()
  def healing_diagnosis, do: "healing.diagnosis"

  @spec healing_reflex_arc() :: binary()
  def healing_reflex_arc, do: "healing.reflex_arc"

  # Agent domain

  @spec agent_decision() :: binary()
  def agent_decision, do: "agent.decision"

  @spec agent_llm_predict() :: binary()
  def agent_llm_predict, do: "agent.llm_predict"

  # Consensus domain (HotStuff BFT)

  @spec consensus_round() :: binary()
  def consensus_round, do: "consensus.round"

  # MCP domain

  @spec mcp_call() :: binary()
  def mcp_call, do: "mcp.call"

  @spec mcp_tool_execute() :: binary()
  def mcp_tool_execute, do: "mcp.tool_execute"

  # A2A domain

  @spec a2a_call() :: binary()
  def a2a_call, do: "a2a.call"

  @spec a2a_create_deal() :: binary()
  def a2a_create_deal, do: "a2a.create_deal"

  # Canopy domain

  @spec canopy_heartbeat() :: binary()
  def canopy_heartbeat, do: "canopy.heartbeat"

  @spec canopy_adapter_call() :: binary()
  def canopy_adapter_call, do: "canopy.adapter_call"

  # Workflow domain (YAWL)

  @spec workflow_execute() :: binary()
  def workflow_execute, do: "workflow.execute"

  @spec workflow_transition() :: binary()
  def workflow_transition, do: "workflow.transition"

  # Process Mining domain

  @spec process_mining_discovery() :: binary()
  def process_mining_discovery, do: "process.mining.discovery"

  @spec conformance_check() :: binary()
  def conformance_check, do: "conformance.check"

  # BusinessOS domain

  @spec bos_compliance_check() :: binary()
  def bos_compliance_check, do: "bos.compliance.check"

  @spec bos_decision_record() :: binary()
  def bos_decision_record, do: "bos.decision.record"

  @spec bos_workspace_operation() :: binary()
  def bos_workspace_operation, do: "bos.workspace.operation"
end
