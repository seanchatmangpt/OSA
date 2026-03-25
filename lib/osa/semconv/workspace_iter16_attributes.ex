defmodule OpenTelemetry.SemConv.WorkspaceIter16Attributes do
  @moduledoc "Wave 9 Iteration 16: Workspace Context Snapshot attributes."

  def workspace_context_snapshot_id, do: :"workspace.context.snapshot_id"
  def workspace_context_compression_ratio, do: :"workspace.context.compression_ratio"
  def workspace_context_size_tokens, do: :"workspace.context.size_tokens"
end
