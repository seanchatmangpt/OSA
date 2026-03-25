defmodule OpenTelemetry.SemConv.CanopyIter14Attributes do
  @moduledoc "Canopy snapshot semantic convention attributes (iter14)."

  @spec canopy_snapshot_id :: :"canopy.snapshot.id"
  def canopy_snapshot_id, do: :"canopy.snapshot.id"

  @spec canopy_snapshot_size_bytes :: :"canopy.snapshot.size_bytes"
  def canopy_snapshot_size_bytes, do: :"canopy.snapshot.size_bytes"

  @spec canopy_snapshot_compression_ratio :: :"canopy.snapshot.compression_ratio"
  def canopy_snapshot_compression_ratio, do: :"canopy.snapshot.compression_ratio"
end
