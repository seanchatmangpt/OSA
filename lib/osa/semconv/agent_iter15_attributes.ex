defmodule OpenTelemetry.SemConv.AgentIter15Attributes do
  @moduledoc "Agent Memory Federation semantic convention attributes (iter15)."

  @spec agent_memory_federation_id :: :"agent.memory.federation_id"
  def agent_memory_federation_id, do: :"agent.memory.federation_id"

  @spec agent_memory_federation_peer_count :: :"agent.memory.federation.peer_count"
  def agent_memory_federation_peer_count, do: :"agent.memory.federation.peer_count"

  @spec agent_memory_sync_latency_ms :: :"agent.memory.sync.latency_ms"
  def agent_memory_sync_latency_ms, do: :"agent.memory.sync.latency_ms"

  @spec agent_memory_federation_version :: :"agent.memory.federation.version"
  def agent_memory_federation_version, do: :"agent.memory.federation.version"
end
