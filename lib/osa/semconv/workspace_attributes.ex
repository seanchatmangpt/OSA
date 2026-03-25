defmodule OpenTelemetry.SemConv.Incubating.WorkspaceAttributes do
  @moduledoc """
  Workspace session semantic convention attributes for ChatmanGPT.

  Namespace: `workspace`

  This module is generated from the ChatmanGPT semantic convention registry.
  Do not edit manually — regenerate with:

      weaver registry generate -r ./semconv/model --templates ./semconv/templates elixir ./OSA/lib/osa/semconv/

  Wave 9 iteration 8
  """

  @doc """
  Unique identifier for the workspace session.

  Attribute: `workspace.session.id`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `sess-abc123`, `ws-20260325-001`
  """
  @spec workspace_session_id() :: :"workspace.session.id"
  def workspace_session_id, do: :"workspace.session.id"

  @doc """
  Number of tokens or items in the current workspace context window.

  Attribute: `workspace.context.size`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `1024`, `8192`, `200000`
  """
  @spec workspace_context_size() :: :"workspace.context.size"
  def workspace_context_size, do: :"workspace.context.size"

  @doc """
  Name of the tool currently active in the workspace.

  Attribute: `workspace.tool.name`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `Read`, `Edit`, `Bash`, `Grep`
  """
  @spec workspace_tool_name() :: :"workspace.tool.name"
  def workspace_tool_name, do: :"workspace.tool.name"

  @doc """
  Number of tools available in the current workspace session.

  Attribute: `workspace.tool.count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `5`, `12`, `25`
  """
  @spec workspace_tool_count() :: :"workspace.tool.count"
  def workspace_tool_count, do: :"workspace.tool.count"

  @doc """
  The role of the agent operating in this workspace session.

  Attribute: `workspace.agent.role`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `planner`, `executor`, `reviewer`
  """
  @spec workspace_agent_role() :: :"workspace.agent.role"
  def workspace_agent_role, do: :"workspace.agent.role"

  @doc """
  Enumerated values for `workspace.agent.role`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `planner` | `"planner"` | Decomposes goals into tasks |
  | `executor` | `"executor"` | Executes individual tasks |
  | `reviewer` | `"reviewer"` | Reviews and validates outputs |
  | `coordinator` | `"coordinator"` | Orchestrates multi-agent workflows |
  | `researcher` | `"researcher"` | Gathers information and context |
  """
  @spec workspace_agent_role_values() :: %{
    planner: :planner,
    executor: :executor,
    reviewer: :reviewer,
    coordinator: :coordinator,
    researcher: :researcher
  }
  def workspace_agent_role_values do
    %{
      planner: :planner,
      executor: :executor,
      reviewer: :reviewer,
      coordinator: :coordinator,
      researcher: :researcher
    }
  end

  @doc """
  Current lifecycle phase of the workspace session.

  Attribute: `workspace.phase`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `startup`, `active`, `idle`, `shutdown`
  """
  @spec workspace_phase() :: :"workspace.phase"
  def workspace_phase, do: :"workspace.phase"

  @doc """
  Enumerated values for `workspace.phase`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `startup` | `"startup"` | Session is initializing |
  | `active` | `"active"` | Session is actively processing |
  | `idle` | `"idle"` | Session is awaiting input |
  | `shutdown` | `"shutdown"` | Session is shutting down |
  """
  @spec workspace_phase_values() :: %{
    startup: :startup,
    active: :active,
    idle: :idle,
    shutdown: :shutdown
  }
  def workspace_phase_values do
    %{
      startup: :startup,
      active: :active,
      idle: :idle,
      shutdown: :shutdown
    }
  end

end
