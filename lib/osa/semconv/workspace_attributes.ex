defmodule OpenTelemetry.SemConv.Incubating.WorkspaceAttributes do
  @moduledoc """
  Workspace semantic convention attributes.

  Namespace: `workspace`

  This module is generated from the ChatmanGPT semantic convention registry.
  Do not edit manually — regenerate with:

      weaver registry generate -r ./semconv/model --templates ./semconv/templates elixir ./OSA/lib/osa/semconv/
  """

  @doc """
  Total number of activities performed in the workspace session.

  Attribute: `workspace.activity.count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `5`, `25`, `100`
  """
  @spec workspace_activity_count() :: :"workspace.activity.count"
  def workspace_activity_count, do: :"workspace.activity.count"

  @doc """
  Duration of the workspace activity in milliseconds.

  Attribute: `workspace.activity.duration_ms`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `10`, `500`, `5000`
  """
  @spec workspace_activity_duration_ms() :: :"workspace.activity.duration_ms"
  def workspace_activity_duration_ms, do: :"workspace.activity.duration_ms"

  @doc """
  Type of activity performed in the workspace.

  Attribute: `workspace.activity.type`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  """
  @spec workspace_activity_type() :: :"workspace.activity.type"
  def workspace_activity_type, do: :"workspace.activity.type"

  @doc """
  Enumerated values for `workspace.activity.type`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `code_edit` | `"code_edit"` | code_edit |
  | `file_read` | `"file_read"` | file_read |
  | `terminal_exec` | `"terminal_exec"` | terminal_exec |
  | `web_search` | `"web_search"` | web_search |
  | `agent_spawn` | `"agent_spawn"` | agent_spawn |
  | `tool_call` | `"tool_call"` | tool_call |
  | `memory_update` | `"memory_update"` | memory_update |
  """
  @spec workspace_activity_type_values() :: %{
    code_edit: :code_edit,
    file_read: :file_read,
    terminal_exec: :terminal_exec,
    web_search: :web_search,
    agent_spawn: :agent_spawn,
    tool_call: :tool_call,
    memory_update: :memory_update
  }
  def workspace_activity_type_values do
    %{
      code_edit: :code_edit,
      file_read: :file_read,
      terminal_exec: :terminal_exec,
      web_search: :web_search,
      agent_spawn: :agent_spawn,
      tool_call: :tool_call,
      memory_update: :memory_update
    }
  end

  defmodule WorkspaceActivityTypeValues do
    @moduledoc """
    Typed constants for the `workspace.activity.type` attribute.
    """

    @doc "code_edit"
    @spec code_edit() :: :code_edit
    def code_edit, do: :code_edit

    @doc "file_read"
    @spec file_read() :: :file_read
    def file_read, do: :file_read

    @doc "terminal_exec"
    @spec terminal_exec() :: :terminal_exec
    def terminal_exec, do: :terminal_exec

    @doc "web_search"
    @spec web_search() :: :web_search
    def web_search, do: :web_search

    @doc "agent_spawn"
    @spec agent_spawn() :: :agent_spawn
    def agent_spawn, do: :agent_spawn

    @doc "tool_call"
    @spec tool_call() :: :tool_call
    def tool_call, do: :tool_call

    @doc "memory_update"
    @spec memory_update() :: :memory_update
    def memory_update, do: :memory_update

  end

  @doc """
  Number of active agents in this workspace session.

  Attribute: `workspace.agent.count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `1`, `3`, `10`
  """
  @spec workspace_agent_count() :: :"workspace.agent.count"
  def workspace_agent_count, do: :"workspace.agent.count"

  @doc """
  The role of the agent in this workspace session.

  Attribute: `workspace.agent.role`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `planner`, `executor`
  """
  @spec workspace_agent_role() :: :"workspace.agent.role"
  def workspace_agent_role, do: :"workspace.agent.role"

  @doc """
  Enumerated values for `workspace.agent.role`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `planner` | `"planner"` | planner |
  | `executor` | `"executor"` | executor |
  | `reviewer` | `"reviewer"` | reviewer |
  | `coordinator` | `"coordinator"` | coordinator |
  | `researcher` | `"researcher"` | researcher |
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

  defmodule WorkspaceAgentRoleValues do
    @moduledoc """
    Typed constants for the `workspace.agent.role` attribute.
    """

    @doc "planner"
    @spec planner() :: :planner
    def planner, do: :planner

    @doc "executor"
    @spec executor() :: :executor
    def executor, do: :executor

    @doc "reviewer"
    @spec reviewer() :: :reviewer
    def reviewer, do: :reviewer

    @doc "coordinator"
    @spec coordinator() :: :coordinator
    def coordinator, do: :coordinator

    @doc "researcher"
    @spec researcher() :: :researcher
    def researcher, do: :researcher

  end

  @doc """
  Unique identifier of the workspace checkpoint or savepoint.

  Attribute: `workspace.checkpoint.id`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `ckpt-001`, `ckpt-2026-03-25-abc`
  """
  @spec workspace_checkpoint_id() :: :"workspace.checkpoint.id"
  def workspace_checkpoint_id, do: :"workspace.checkpoint.id"

  @doc """
  Compression ratio achieved when compressing context [0.0, 1.0].

  Attribute: `workspace.context.compression_ratio`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0.3`, `0.65`, `0.8`
  """
  @spec workspace_context_compression_ratio() :: :"workspace.context.compression_ratio"
  def workspace_context_compression_ratio, do: :"workspace.context.compression_ratio"

  @doc """
  Current context window usage in tokens.

  Attribute: `workspace.context.size`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `1024`, `8192`, `32768`
  """
  @spec workspace_context_size() :: :"workspace.context.size"
  def workspace_context_size, do: :"workspace.context.size"

  @doc """
  Size of the workspace context in tokens before compression.

  Attribute: `workspace.context.size_tokens`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `2048`, `8192`, `32000`
  """
  @spec workspace_context_size_tokens() :: :"workspace.context.size_tokens"
  def workspace_context_size_tokens, do: :"workspace.context.size_tokens"

  @doc """
  Identifier of the workspace context snapshot.

  Attribute: `workspace.context.snapshot_id`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `snap-001`, `ctx-snapshot-abc`
  """
  @spec workspace_context_snapshot_id() :: :"workspace.context.snapshot_id"
  def workspace_context_snapshot_id, do: :"workspace.context.snapshot_id"

  @doc """
  Maximum context window size in tokens for this workspace session.

  Attribute: `workspace.context.window_size`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `8192`, `32768`, `200000`
  """
  @spec workspace_context_window_size() :: :"workspace.context.window_size"
  def workspace_context_window_size, do: :"workspace.context.window_size"

  @doc """
  Number of orchestration iterations completed in this workspace session.

  Attribute: `workspace.iteration.count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `1`, `10`, `100`
  """
  @spec workspace_iteration_count() :: :"workspace.iteration.count"
  def workspace_iteration_count, do: :"workspace.iteration.count"

  @doc """
  Duration of the memory compaction operation in milliseconds.

  Attribute: `workspace.memory.compaction_ms`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `150`, `800`, `2000`
  """
  @spec workspace_memory_compaction_ms() :: :"workspace.memory.compaction_ms"
  def workspace_memory_compaction_ms, do: :"workspace.memory.compaction_ms"

  @doc """
  Ratio of memory reduced by compaction, range (0.0, 1.0). Value of 0.4 means 40% reduction.

  Attribute: `workspace.memory.compaction_ratio`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0.4`, `0.65`, `0.2`
  """
  @spec workspace_memory_compaction_ratio() :: :"workspace.memory.compaction_ratio"
  def workspace_memory_compaction_ratio, do: :"workspace.memory.compaction_ratio"

  @doc """
  Number of memory items after compaction.

  Attribute: `workspace.memory.items_after`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `300`, `1200`, `6000`
  """
  @spec workspace_memory_items_after() :: :"workspace.memory.items_after"
  def workspace_memory_items_after, do: :"workspace.memory.items_after"

  @doc """
  Number of memory items before compaction.

  Attribute: `workspace.memory.items_before`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `500`, `2000`, `10000`
  """
  @spec workspace_memory_items_before() :: :"workspace.memory.items_before"
  def workspace_memory_items_before, do: :"workspace.memory.items_before"

  @doc """
  Current memory usage of the workspace context in bytes.

  Attribute: `workspace.memory.usage_bytes`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `1024`, `65536`, `1048576`
  """
  @spec workspace_memory_usage_bytes() :: :"workspace.memory.usage_bytes"
  def workspace_memory_usage_bytes, do: :"workspace.memory.usage_bytes"

  @doc """
  The orchestration pattern governing how agents coordinate work in this workspace.

  Attribute: `workspace.orchestration.pattern`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `sequential`, `parallel`, `reactive`
  """
  @spec workspace_orchestration_pattern() :: :"workspace.orchestration.pattern"
  def workspace_orchestration_pattern, do: :"workspace.orchestration.pattern"

  @doc """
  Enumerated values for `workspace.orchestration.pattern`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `sequential` | `"sequential"` | sequential |
  | `parallel` | `"parallel"` | parallel |
  | `reactive` | `"reactive"` | reactive |
  | `proactive` | `"proactive"` | proactive |
  | `event_driven` | `"event_driven"` | event_driven |
  """
  @spec workspace_orchestration_pattern_values() :: %{
    sequential: :sequential,
    parallel: :parallel,
    reactive: :reactive,
    proactive: :proactive,
    event_driven: :event_driven
  }
  def workspace_orchestration_pattern_values do
    %{
      sequential: :sequential,
      parallel: :parallel,
      reactive: :reactive,
      proactive: :proactive,
      event_driven: :event_driven
    }
  end

  defmodule WorkspaceOrchestrationPatternValues do
    @moduledoc """
    Typed constants for the `workspace.orchestration.pattern` attribute.
    """

    @doc "sequential"
    @spec sequential() :: :sequential
    def sequential, do: :sequential

    @doc "parallel"
    @spec parallel() :: :parallel
    def parallel, do: :parallel

    @doc "reactive"
    @spec reactive() :: :reactive
    def reactive, do: :reactive

    @doc "proactive"
    @spec proactive() :: :proactive
    def proactive, do: :proactive

    @doc "event_driven"
    @spec event_driven() :: :event_driven
    def event_driven, do: :event_driven

  end

  @doc """
  Current lifecycle phase of the workspace session.

  Attribute: `workspace.phase`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `active`, `idle`
  """
  @spec workspace_phase() :: :"workspace.phase"
  def workspace_phase, do: :"workspace.phase"

  @doc """
  Enumerated values for `workspace.phase`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `startup` | `"startup"` | startup |
  | `active` | `"active"` | active |
  | `idle` | `"idle"` | idle |
  | `shutdown` | `"shutdown"` | shutdown |
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

  defmodule WorkspacePhaseValues do
    @moduledoc """
    Typed constants for the `workspace.phase` attribute.
    """

    @doc "startup"
    @spec startup() :: :startup
    def startup, do: :startup

    @doc "active"
    @spec active() :: :active
    def active, do: :active

    @doc "idle"
    @spec idle() :: :idle
    def idle, do: :idle

    @doc "shutdown"
    @spec shutdown() :: :shutdown
    def shutdown, do: :shutdown

  end

  @doc """
  Duration of the workspace session in milliseconds.

  Attribute: `workspace.session.duration_ms`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `5000`, `60000`, `3600000`
  """
  @spec workspace_session_duration_ms() :: :"workspace.session.duration_ms"
  def workspace_session_duration_ms, do: :"workspace.session.duration_ms"

  @doc """
  Unique identifier for the workspace session.

  Attribute: `workspace.session.id`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `session-abc123`, `ws-20260325-001`
  """
  @spec workspace_session_id() :: :"workspace.session.id"
  def workspace_session_id, do: :"workspace.session.id"

  @doc """
  Total tokens consumed across all LLM calls in the workspace session.

  Attribute: `workspace.session.token_budget_used`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `1024`, `8192`, `65536`
  """
  @spec workspace_session_token_budget_used() :: :"workspace.session.token_budget_used"
  def workspace_session_token_budget_used, do: :"workspace.session.token_budget_used"

  @doc """
  Total number of tool calls made during the workspace session.

  Attribute: `workspace.session.tool_call_count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `5`, `42`, `200`
  """
  @spec workspace_session_tool_call_count() :: :"workspace.session.tool_call_count"
  def workspace_session_tool_call_count, do: :"workspace.session.tool_call_count"

  @doc """
  Number of agents that have access to the shared workspace.

  Attribute: `workspace.sharing.agent_count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `1`, `5`, `20`
  """
  @spec workspace_sharing_agent_count() :: :"workspace.sharing.agent_count"
  def workspace_sharing_agent_count, do: :"workspace.sharing.agent_count"

  @doc """
  Comma-separated list of permissions granted in the shared workspace (read,write,execute).

  Attribute: `workspace.sharing.permissions`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `read`, `read,write`, `read,write,execute`
  """
  @spec workspace_sharing_permissions() :: :"workspace.sharing.permissions"
  def workspace_sharing_permissions, do: :"workspace.sharing.permissions"

  @doc """
  Scope of workspace sharing — who can access the shared workspace.

  Attribute: `workspace.sharing.scope`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `private`, `team`
  """
  @spec workspace_sharing_scope() :: :"workspace.sharing.scope"
  def workspace_sharing_scope, do: :"workspace.sharing.scope"

  @doc """
  Enumerated values for `workspace.sharing.scope`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `private` | `"private"` | private |
  | `team` | `"team"` | team |
  | `org` | `"org"` | org |
  | `public` | `"public"` | public |
  """
  @spec workspace_sharing_scope_values() :: %{
    private: :private,
    team: :team,
    org: :org,
    public: :public
  }
  def workspace_sharing_scope_values do
    %{
      private: :private,
      team: :team,
      org: :org,
      public: :public
    }
  end

  defmodule WorkspaceSharingScopeValues do
    @moduledoc """
    Typed constants for the `workspace.sharing.scope` attribute.
    """

    @doc "private"
    @spec private() :: :private
    def private, do: :private

    @doc "team"
    @spec team() :: :team
    def team, do: :team

    @doc "org"
    @spec org() :: :org
    def org, do: :org

    @doc "public"
    @spec public() :: :public
    def public, do: :public

  end

  @doc """
  Current depth of the workspace task queue — pending tasks awaiting dispatch.

  Attribute: `workspace.task.queue.depth`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0`, `5`, `100`
  """
  @spec workspace_task_queue_depth() :: :"workspace.task.queue.depth"
  def workspace_task_queue_depth, do: :"workspace.task.queue.depth"

  @doc """
  Functional category of the workspace tool being invoked.

  Attribute: `workspace.tool.category`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `read`, `write`, `search`
  """
  @spec workspace_tool_category() :: :"workspace.tool.category"
  def workspace_tool_category, do: :"workspace.tool.category"

  @doc """
  Enumerated values for `workspace.tool.category`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `read` | `"read"` | read |
  | `write` | `"write"` | write |
  | `search` | `"search"` | search |
  | `compute` | `"compute"` | compute |
  | `communicate` | `"communicate"` | communicate |
  | `transform` | `"transform"` | transform |
  """
  @spec workspace_tool_category_values() :: %{
    read: :read,
    write: :write,
    search: :search,
    compute: :compute,
    communicate: :communicate,
    transform: :transform
  }
  def workspace_tool_category_values do
    %{
      read: :read,
      write: :write,
      search: :search,
      compute: :compute,
      communicate: :communicate,
      transform: :transform
    }
  end

  defmodule WorkspaceToolCategoryValues do
    @moduledoc """
    Typed constants for the `workspace.tool.category` attribute.
    """

    @doc "read"
    @spec read() :: :read
    def read, do: :read

    @doc "write"
    @spec write() :: :write
    def write, do: :write

    @doc "search"
    @spec search() :: :search
    def search, do: :search

    @doc "compute"
    @spec compute() :: :compute
    def compute, do: :compute

    @doc "communicate"
    @spec communicate() :: :communicate
    def communicate, do: :communicate

    @doc "transform"
    @spec transform() :: :transform
    def transform, do: :transform

  end

  @doc """
  Total number of tool invocations in this workspace session.

  Attribute: `workspace.tool.count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `1`, `15`, `100`
  """
  @spec workspace_tool_count() :: :"workspace.tool.count"
  def workspace_tool_count, do: :"workspace.tool.count"

  @doc """
  Name of the tool being invoked in the workspace.

  Attribute: `workspace.tool.name`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `Bash`, `Read`, `Edit`, `Agent`
  """
  @spec workspace_tool_name() :: :"workspace.tool.name"
  def workspace_tool_name, do: :"workspace.tool.name"

  @doc """
  Provider or source of the workspace tool (e.g., "built-in", "mcp", "plugin").

  Attribute: `workspace.tool.provider`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `built-in`, `mcp`, `plugin`
  """
  @spec workspace_tool_provider() :: :"workspace.tool.provider"
  def workspace_tool_provider, do: :"workspace.tool.provider"

end