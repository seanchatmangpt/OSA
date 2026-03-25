defmodule OptimalSystemAgent.Semconv.SpanNames do
  @moduledoc "Span name constants matching chatmangpt semconv schema."

  # Healing
  def healing_diagnosis, do: "healing.diagnosis"
  def healing_reflex_arc, do: "healing.reflex_arc"
  def healing_fingerprint, do: "healing.fingerprint"
  def healing_escalation, do: "healing.escalation"

  # A2A
  def a2a_call, do: "a2a.call"
  def a2a_create_deal, do: "a2a.create_deal"
  def a2a_negotiate, do: "a2a.negotiate"
  def a2a_task_delegate, do: "a2a.task.delegate"

  # MCP
  def mcp_call, do: "mcp.call"
  def mcp_tool_execute, do: "mcp.tool.execute"

  # Agent
  def agent_decision, do: "agent.decision"

  # Process Mining
  def process_mining_discovery, do: "process.mining.discovery"
  def process_mining_conformance, do: "process.mining.conformance"
  def process_mining_dfg, do: "process.mining.dfg"

  # Signal
  def signal_classify, do: "signal.classify"
  def signal_filter, do: "signal.filter"
  def signal_encode, do: "signal.encode"

  # Workflow
  def workflow_execute, do: "workflow.execute"
  def workflow_transition, do: "workflow.transition"
  def workflow_milestone, do: "workflow.milestone"

  # Events
  def event_emit, do: "event.emit"
  def event_process, do: "event.process"

  # Consensus
  def consensus_round, do: "consensus.round"
  def consensus_vote, do: "consensus.vote"
end
