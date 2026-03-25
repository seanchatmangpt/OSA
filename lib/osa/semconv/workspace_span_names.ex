defmodule OpenTelemetry.SemConv.Incubating.WorkspaceSpanNames do
  @moduledoc """
  Workspace semantic convention span names.

  Namespace: `workspace`

  This module is generated from the ChatmanGPT semantic convention registry.
  Do not edit manually — regenerate with:

      weaver registry generate -r ./semconv/model --templates ./semconv/templates elixir ./OSA/lib/osa/semconv/
  """

  @doc """
  Tracking a workspace activity — records type, duration, and context of user/agent actions.

  Span: `span.workspace.activity.track`
  Kind: `internal`
  Stability: `development`
  """
  @spec workspace_activity_track() :: String.t()
  def workspace_activity_track, do: "workspace.activity.track"

  @doc """
  Saving a workspace checkpoint — persisting agent state and task queue for recovery.

  Span: `span.workspace.checkpoint.save`
  Kind: `internal`
  Stability: `development`
  """
  @spec workspace_checkpoint_save() :: String.t()
  def workspace_checkpoint_save, do: "workspace.checkpoint.save"

  @doc """
  Creating a context checkpoint — snapshot of current workspace state for potential rollback.

  Span: `span.workspace.context.checkpoint`
  Kind: `internal`
  Stability: `development`
  """
  @spec workspace_context_checkpoint() :: String.t()
  def workspace_context_checkpoint, do: "workspace.context.checkpoint"

  @doc """
  Creating a compressed snapshot of workspace context for persistence or recovery.

  Span: `span.workspace.context.snapshot`
  Kind: `internal`
  Stability: `development`
  """
  @spec workspace_context_snapshot() :: String.t()
  def workspace_context_snapshot, do: "workspace.context.snapshot"

  @doc """
  Context window update — tokens added or pruned from the workspace context.

  Span: `span.workspace.context.update`
  Kind: `internal`
  Stability: `development`
  """
  @spec workspace_context_update() :: String.t()
  def workspace_context_update, do: "workspace.context.update"

  @doc """
  Workspace memory compaction — reducing memory footprint by consolidating and pruning stored context items.

  Span: `span.workspace.memory.compact`
  Kind: `internal`
  Stability: `development`
  """
  @spec workspace_memory_compact() :: String.t()
  def workspace_memory_compact, do: "workspace.memory.compact"

  @doc """
  Orchestrating work distribution across agents in the workspace.

  Span: `span.workspace.orchestrate`
  Kind: `internal`
  Stability: `development`
  """
  @spec workspace_orchestrate() :: String.t()
  def workspace_orchestrate, do: "workspace.orchestrate"

  @doc """
  Ending a workspace session — recording final metrics and persisting session state.

  Span: `span.workspace.session.end`
  Kind: `internal`
  Stability: `development`
  """
  @spec workspace_session_end() :: String.t()
  def workspace_session_end, do: "workspace.session.end"

  @doc """
  Workspace session initialization — agent begins processing in a new session context.

  Span: `span.workspace.session.start`
  Kind: `internal`
  Stability: `development`
  """
  @spec workspace_session_start() :: String.t()
  def workspace_session_start, do: "workspace.session.start"

  @doc """
  Sharing a workspace with other agents — granting access with defined permissions and scope.

  Span: `span.workspace.share`
  Kind: `internal`
  Stability: `development`
  """
  @spec workspace_share() :: String.t()
  def workspace_share, do: "workspace.share"

  @doc """
  Tool invocation within a workspace session.

  Span: `span.workspace.tool.invoke`
  Kind: `internal`
  Stability: `development`
  """
  @spec workspace_tool_invoke() :: String.t()
  def workspace_tool_invoke, do: "workspace.tool.invoke"

  @doc """
  All span names in this namespace.
  """
  @spec all() :: [String.t()]
  def all do
    [
      workspace_activity_track(),
      workspace_checkpoint_save(),
      workspace_context_checkpoint(),
      workspace_context_snapshot(),
      workspace_context_update(),
      workspace_memory_compact(),
      workspace_orchestrate(),
      workspace_session_end(),
      workspace_session_start(),
      workspace_share(),
      workspace_tool_invoke()
    ]
  end
end