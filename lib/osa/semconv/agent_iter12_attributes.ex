defmodule OpenTelemetry.SemConv.AgentIter12Attributes do
  @moduledoc "Agent topology semantic convention attributes (iter12)."

  @spec agent_topology_type :: :"agent.topology.type"
  def agent_topology_type, do: :"agent.topology.type"

  @spec agent_task_status :: :"agent.task.status"
  def agent_task_status, do: :"agent.task.status"

  @spec agent_coordination_latency_ms :: :"agent.coordination.latency_ms"
  def agent_coordination_latency_ms, do: :"agent.coordination.latency_ms"
end
