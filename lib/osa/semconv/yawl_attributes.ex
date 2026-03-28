defmodule OpenTelemetry.SemConv.Incubating.YawlAttributes do
  @moduledoc """
  Yawl semantic convention attributes.

  Namespace: `yawl`

  This module is generated from the ChatmanGPT semantic convention registry.
  Do not edit manually — regenerate with:

      weaver registry generate -r ./semconv/model --templates ./semconv/templates elixir ./OSA/lib/osa/semconv/
  """

  @doc """
  YAWL workflow case identifier — the root correlation key for a workflow instance.

  Attribute: `yawl.case.id`
  Type: `string`
  Stability: `development`
  Requirement: `required`
  Examples: `case-001`, `order-flow-42`, `repair-7391`
  """
  @spec yawl_case_id() :: :yawl_case_id
  def yawl_case_id, do: :yawl_case_id

  @doc """
  YAWL workflow event type from the SSE event stream.

  Attribute: `yawl.event.type`
  Type: `enum`
  Stability: `development`
  Requirement: `required`
  Examples: `TASK_STARTED`, `TASK_COMPLETED`, `INSTANCE_COMPLETED`
  """
  @spec yawl_event_type() :: :yawl_event_type
  def yawl_event_type, do: :yawl_event_type

  @doc """
  Enumerated values for `yawl.event.type`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `instance_created` | `"INSTANCE_CREATED"` | New workflow case started. |
  | `task_enabled` | `"TASK_ENABLED"` | Task enabled — input conditions have tokens (transition fireable). |
  | `task_started` | `"TASK_STARTED"` | Task started — input tokens consumed (transition fired). |
  | `task_completed` | `"TASK_COMPLETED"` | Task completed — output tokens produced to successor conditions. |
  | `task_failed` | `"TASK_FAILED"` | Task failed — tokens left in error condition. |
  | `instance_completed` | `"INSTANCE_COMPLETED"` | Workflow case reached output condition (Petri net reached final marking). |
  | `instance_cancelled` | `"INSTANCE_CANCELLED"` | Workflow case cancelled before completion. |
  """
  @spec yawl_event_type_values() :: %{
    instance_created: :INSTANCE_CREATED,
    task_enabled: :TASK_ENABLED,
    task_started: :TASK_STARTED,
    task_completed: :TASK_COMPLETED,
    task_failed: :TASK_FAILED,
    instance_completed: :INSTANCE_COMPLETED,
    instance_cancelled: :INSTANCE_CANCELLED
  }
  def yawl_event_type_values do
    %{
      instance_created: :INSTANCE_CREATED,
      task_enabled: :TASK_ENABLED,
      task_started: :TASK_STARTED,
      task_completed: :TASK_COMPLETED,
      task_failed: :TASK_FAILED,
      instance_completed: :INSTANCE_COMPLETED,
      instance_cancelled: :INSTANCE_CANCELLED
    }
  end

  defmodule YawlEventTypeValues do
    @moduledoc """
    Typed constants for the `yawl.event.type` attribute.
    """

    @doc "New workflow case started."
    @spec instance_created() :: :INSTANCE_CREATED
    def instance_created, do: :INSTANCE_CREATED

    @doc "Task enabled — input conditions have tokens (transition fireable)."
    @spec task_enabled() :: :TASK_ENABLED
    def task_enabled, do: :TASK_ENABLED

    @doc "Task started — input tokens consumed (transition fired)."
    @spec task_started() :: :TASK_STARTED
    def task_started, do: :TASK_STARTED

    @doc "Task completed — output tokens produced to successor conditions."
    @spec task_completed() :: :TASK_COMPLETED
    def task_completed, do: :TASK_COMPLETED

    @doc "Task failed — tokens left in error condition."
    @spec task_failed() :: :TASK_FAILED
    def task_failed, do: :TASK_FAILED

    @doc "Workflow case reached output condition (Petri net reached final marking)."
    @spec instance_completed() :: :INSTANCE_COMPLETED
    def instance_completed, do: :INSTANCE_COMPLETED

    @doc "Workflow case cancelled before completion."
    @spec instance_cancelled() :: :INSTANCE_CANCELLED
    def instance_cancelled, do: :INSTANCE_CANCELLED

  end

  @doc """
  YAWL task identifier within a workflow net (matches task id in YAWL XML spec).

  Attribute: `yawl.task.id`
  Type: `string`
  Stability: `development`
  Requirement: `required`
  Examples: `TaskA`, `approveOrder`, `InputCondition`
  """
  @spec yawl_task_id() :: :yawl_task_id
  def yawl_task_id, do: :yawl_task_id

  @doc """
  YAWL workflow instance identifier (internal engine identifier).

  Attribute: `yawl.instance.id`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `instance-001`
  """
  @spec yawl_instance_id() :: :yawl_instance_id
  def yawl_instance_id, do: :yawl_instance_id

  @doc """
  YAWL SSE event identifier from the event stream.

  Attribute: `yawl.spec.event_id`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `evt-001`, `evt-abc123`
  """
  @spec yawl_spec_event_id() :: :yawl_spec_event_id
  def yawl_spec_event_id, do: :yawl_spec_event_id

  @doc """
  YAWL specification URI — the workflow definition being executed.

  Attribute: `yawl.spec.uri`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `WCP01_Sequence`, `OrderManagement`, `RepairProcess`
  """
  @spec yawl_spec_uri() :: :yawl_spec_uri
  def yawl_spec_uri, do: :yawl_spec_uri

  @doc """
  Number of tokens consumed from input conditions when this task fires.

  Attribute: `yawl.token.consumed`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `1`, `2`
  """
  @spec yawl_token_consumed() :: :yawl_token_consumed
  def yawl_token_consumed, do: :yawl_token_consumed

  @doc """
  Number of tokens produced to output conditions after this task fires.

  Attribute: `yawl.token.produced`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `1`, `2`
  """
  @spec yawl_token_produced() :: :yawl_token_produced
  def yawl_token_produced, do: :yawl_token_produced

  @doc """
  YAWL work item unique identifier in caseID:taskID:uniqueID format.

  Attribute: `yawl.work_item.id`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `case-001:TaskA:001`, `repair-7391:diagnose:002`
  """
  @spec yawl_work_item_id() :: :yawl_work_item_id
  def yawl_work_item_id, do: :yawl_work_item_id

end