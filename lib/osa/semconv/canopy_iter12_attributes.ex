defmodule OpenTelemetry.SemConv.CanopyIter12Attributes do
  @moduledoc "Canopy protocol versioning semantic convention attributes (iter12)."

  @spec canopy_protocol_version :: :"canopy.protocol.version"
  def canopy_protocol_version, do: :"canopy.protocol.version"

  @spec canopy_sync_strategy :: :"canopy.sync.strategy"
  def canopy_sync_strategy, do: :"canopy.sync.strategy"

  @spec canopy_conflict_count :: :"canopy.conflict.count"
  def canopy_conflict_count, do: :"canopy.conflict.count"
end
