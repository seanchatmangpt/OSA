defmodule OpenTelemetry.SemConv.WorkspaceIter13Attributes do
  @moduledoc "Workspace orchestration semantic convention attributes (iter13)."
  def workspace_orchestration_pattern, do: :"workspace.orchestration.pattern"
  def workspace_task_queue_depth, do: :"workspace.task.queue.depth"
  def workspace_iteration_count, do: :"workspace.iteration.count"
end
