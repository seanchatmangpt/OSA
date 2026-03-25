defmodule OpenTelemetry.SemConv.Incubating.WorkflowAttributes do
  @moduledoc """
  Workflow semantic convention attributes.

  Namespace: `workflow`

  This module is generated from the ChatmanGPT semantic convention registry.
  Do not edit manually — regenerate with:

      weaver registry generate -r ./semconv/model --templates ./semconv/templates elixir ./OSA/lib/osa/semconv/
  """

  @doc """
  Number of branches currently active in a multi-choice split.

  Attribute: `workflow.active_branches`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `1`, `2`, `3`
  """
  @spec workflow_active_branches() :: :"workflow.active_branches"
  def workflow_active_branches, do: :"workflow.active_branches"

  @doc """
  Number of active branches in a parallel split or join pattern.

  Attribute: `workflow.branch_count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `2`, `3`, `5`
  """
  @spec workflow_branch_count() :: :"workflow.branch_count"
  def workflow_branch_count, do: :"workflow.branch_count"

  @doc """
  Reason for cancellation of the workflow activity or region.

  Attribute: `workflow.cancel.reason`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `timeout`, `user_cancelled`, `sla_breach`
  """
  @spec workflow_cancel_reason() :: :"workflow.cancel.reason"
  def workflow_cancel_reason, do: :"workflow.cancel.reason"

  @doc """
  The evaluated condition expression used to select an XOR branch.

  Attribute: `workflow.choice.condition`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `status == approved`, `amount > 1000`
  """
  @spec workflow_choice_condition() :: :"workflow.choice.condition"
  def workflow_choice_condition, do: :"workflow.choice.condition"

  @doc """
  Workflow engine executing the workflow.

  Attribute: `workflow.engine`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `canopy`, `yawl`
  """
  @spec workflow_engine() :: :"workflow.engine"
  def workflow_engine, do: :"workflow.engine"

  @doc """
  Enumerated values for `workflow.engine`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `canopy` | `"canopy"` | canopy |
  | `yawl` | `"yawl"` | yawl |
  | `business_os` | `"business_os"` | business_os |
  """
  @spec workflow_engine_values() :: %{
    canopy: :canopy,
    yawl: :yawl,
    business_os: :business_os
  }
  def workflow_engine_values do
    %{
      canopy: :canopy,
      yawl: :yawl,
      business_os: :business_os
    }
  end

  defmodule WorkflowEngineValues do
    @moduledoc """
    Typed constants for the `workflow.engine` attribute.
    """

    @doc "canopy"
    @spec canopy() :: :canopy
    def canopy, do: :canopy

    @doc "yawl"
    @spec yawl() :: :yawl
    def yawl, do: :yawl

    @doc "business_os"
    @spec business_os() :: :business_os
    def business_os, do: :business_os

  end

  @doc """
  Number of branches that have fired/triggered so far.

  Attribute: `workflow.fired_branches`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `1`, `2`
  """
  @spec workflow_fired_branches() :: :"workflow.fired_branches"
  def workflow_fired_branches, do: :"workflow.fired_branches"

  @doc """
  Unique identifier for the workflow instance.

  Attribute: `workflow.id`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `wf-20260324-001`, `canopy-workflow-abc123`
  """
  @spec workflow_id() :: :"workflow.id"
  def workflow_id, do: :"workflow.id"

  @doc """
  Number of completed instances out of total in multi-instance activity.

  Attribute: `workflow.instance.completed`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `2`, `5`
  """
  @spec workflow_instance_completed() :: :"workflow.instance.completed"
  def workflow_instance_completed, do: :"workflow.instance.completed"

  @doc """
  Number of active instances in a multi-instance activity pattern.

  Attribute: `workflow.instance.count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `3`, `10`, `50`
  """
  @spec workflow_instance_count() :: :"workflow.instance.count"
  def workflow_instance_count, do: :"workflow.instance.count"

  @doc """
  Current iteration count of a structured loop activity.

  Attribute: `workflow.loop.iteration`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `1`, `5`, `100`
  """
  @spec workflow_loop_iteration() :: :"workflow.loop.iteration"
  def workflow_loop_iteration, do: :"workflow.loop.iteration"

  @doc """
  Maximum allowed iterations for a structured loop (boundedness guarantee).

  Attribute: `workflow.loop.max_iterations`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `100`, `1000`
  """
  @spec workflow_loop_max_iterations() :: :"workflow.loop.max_iterations"
  def workflow_loop_max_iterations, do: :"workflow.loop.max_iterations"

  @doc """
  Policy for merging concurrent branches at a join point.

  Attribute: `workflow.merge.policy`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `all`, `first`
  """
  @spec workflow_merge_policy() :: :"workflow.merge.policy"
  def workflow_merge_policy, do: :"workflow.merge.policy"

  @doc """
  Enumerated values for `workflow.merge.policy`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `first` | `"first"` | first |
  | `all` | `"all"` | all |
  | `threshold` | `"threshold"` | threshold |
  """
  @spec workflow_merge_policy_values() :: %{
    first: :first,
    all: :all,
    threshold: :threshold
  }
  def workflow_merge_policy_values do
    %{
      first: :first,
      all: :all,
      threshold: :threshold
    }
  end

  defmodule WorkflowMergePolicyValues do
    @moduledoc """
    Typed constants for the `workflow.merge.policy` attribute.
    """

    @doc "first"
    @spec first() :: :first
    def first, do: :first

    @doc "all"
    @spec all() :: :all
    def all, do: :all

    @doc "threshold"
    @spec threshold() :: :threshold
    def threshold, do: :threshold

  end

  @doc """
  Condition expression that gates milestone execution.

  Attribute: `workflow.milestone.condition`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `process.state == 'approved'`, `budget_approved == true`
  """
  @spec workflow_milestone_condition() :: :"workflow.milestone.condition"
  def workflow_milestone_condition, do: :"workflow.milestone.condition"

  @doc """
  Human-readable name of the workflow definition.

  Attribute: `workflow.name`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `agent_onboarding`, `deal_approval`, `compliance_check`
  """
  @spec workflow_name() :: :"workflow.name"
  def workflow_name, do: :"workflow.name"

  @doc """
  YAWL workflow control-flow pattern applied in this step.

  Attribute: `workflow.pattern`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `sequence`, `parallel_split`, `exclusive_choice`
  """
  @spec workflow_pattern() :: :"workflow.pattern"
  def workflow_pattern, do: :"workflow.pattern"

  @doc """
  Enumerated values for `workflow.pattern`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `sequence` | `"sequence"` | sequence |
  | `parallel_split` | `"parallel_split"` | parallel_split |
  | `synchronization` | `"synchronization"` | synchronization |
  | `exclusive_choice` | `"exclusive_choice"` | exclusive_choice |
  | `multi_choice` | `"multi_choice"` | multi_choice |
  | `structured_loop` | `"structured_loop"` | structured_loop |
  | `deferred_choice` | `"deferred_choice"` | deferred_choice |
  | `milestone` | `"milestone"` | milestone |
  | `discriminator` | `"discriminator"` | discriminator |
  | `n_out_of_m` | `"n_out_of_m"` | n_out_of_m |
  | `partial_join` | `"partial_join"` | partial_join |
  | `cancel_region` | `"cancel_region"` | cancel_region |
  | `interleaved_parallel` | `"interleaved_parallel"` | interleaved_parallel |
  | `critical_section` | `"critical_section"` | critical_section |
  | `recursion` | `"recursion"` | recursion |
  | `transient_trigger` | `"transient_trigger"` | transient_trigger |
  | `persistent_trigger` | `"persistent_trigger"` | persistent_trigger |
  | `event_based_choice` | `"event_based_choice"` | event_based_choice |
  | `cancel_activity` | `"cancel_activity"` | cancel_activity |
  | `multi_instance_sync` | `"multi_instance_sync"` | multi_instance_sync |
  | `simple_merge` | `"simple_merge"` | simple_merge |
  | `multiple_instance` | `"multiple_instance"` | multiple_instance |
  | `structured_sync_merge` | `"structured_sync_merge"` | structured_sync_merge |
  """
  @spec workflow_pattern_values() :: %{
    sequence: :sequence,
    parallel_split: :parallel_split,
    synchronization: :synchronization,
    exclusive_choice: :exclusive_choice,
    multi_choice: :multi_choice,
    structured_loop: :structured_loop,
    deferred_choice: :deferred_choice,
    milestone: :milestone,
    discriminator: :discriminator,
    n_out_of_m: :n_out_of_m,
    partial_join: :partial_join,
    cancel_region: :cancel_region,
    interleaved_parallel: :interleaved_parallel,
    critical_section: :critical_section,
    recursion: :recursion,
    transient_trigger: :transient_trigger,
    persistent_trigger: :persistent_trigger,
    event_based_choice: :event_based_choice,
    cancel_activity: :cancel_activity,
    multi_instance_sync: :multi_instance_sync,
    simple_merge: :simple_merge,
    multiple_instance: :multiple_instance,
    structured_sync_merge: :structured_sync_merge
  }
  def workflow_pattern_values do
    %{
      sequence: :sequence,
      parallel_split: :parallel_split,
      synchronization: :synchronization,
      exclusive_choice: :exclusive_choice,
      multi_choice: :multi_choice,
      structured_loop: :structured_loop,
      deferred_choice: :deferred_choice,
      milestone: :milestone,
      discriminator: :discriminator,
      n_out_of_m: :n_out_of_m,
      partial_join: :partial_join,
      cancel_region: :cancel_region,
      interleaved_parallel: :interleaved_parallel,
      critical_section: :critical_section,
      recursion: :recursion,
      transient_trigger: :transient_trigger,
      persistent_trigger: :persistent_trigger,
      event_based_choice: :event_based_choice,
      cancel_activity: :cancel_activity,
      multi_instance_sync: :multi_instance_sync,
      simple_merge: :simple_merge,
      multiple_instance: :multiple_instance,
      structured_sync_merge: :structured_sync_merge
    }
  end

  defmodule WorkflowPatternValues do
    @moduledoc """
    Typed constants for the `workflow.pattern` attribute.
    """

    @doc "sequence"
    @spec sequence() :: :sequence
    def sequence, do: :sequence

    @doc "parallel_split"
    @spec parallel_split() :: :parallel_split
    def parallel_split, do: :parallel_split

    @doc "synchronization"
    @spec synchronization() :: :synchronization
    def synchronization, do: :synchronization

    @doc "exclusive_choice"
    @spec exclusive_choice() :: :exclusive_choice
    def exclusive_choice, do: :exclusive_choice

    @doc "multi_choice"
    @spec multi_choice() :: :multi_choice
    def multi_choice, do: :multi_choice

    @doc "structured_loop"
    @spec structured_loop() :: :structured_loop
    def structured_loop, do: :structured_loop

    @doc "deferred_choice"
    @spec deferred_choice() :: :deferred_choice
    def deferred_choice, do: :deferred_choice

    @doc "milestone"
    @spec milestone() :: :milestone
    def milestone, do: :milestone

    @doc "discriminator"
    @spec discriminator() :: :discriminator
    def discriminator, do: :discriminator

    @doc "n_out_of_m"
    @spec n_out_of_m() :: :n_out_of_m
    def n_out_of_m, do: :n_out_of_m

    @doc "partial_join"
    @spec partial_join() :: :partial_join
    def partial_join, do: :partial_join

    @doc "cancel_region"
    @spec cancel_region() :: :cancel_region
    def cancel_region, do: :cancel_region

    @doc "interleaved_parallel"
    @spec interleaved_parallel() :: :interleaved_parallel
    def interleaved_parallel, do: :interleaved_parallel

    @doc "critical_section"
    @spec critical_section() :: :critical_section
    def critical_section, do: :critical_section

    @doc "recursion"
    @spec recursion() :: :recursion
    def recursion, do: :recursion

    @doc "transient_trigger"
    @spec transient_trigger() :: :transient_trigger
    def transient_trigger, do: :transient_trigger

    @doc "persistent_trigger"
    @spec persistent_trigger() :: :persistent_trigger
    def persistent_trigger, do: :persistent_trigger

    @doc "event_based_choice"
    @spec event_based_choice() :: :event_based_choice
    def event_based_choice, do: :event_based_choice

    @doc "cancel_activity"
    @spec cancel_activity() :: :cancel_activity
    def cancel_activity, do: :cancel_activity

    @doc "multi_instance_sync"
    @spec multi_instance_sync() :: :multi_instance_sync
    def multi_instance_sync, do: :multi_instance_sync

    @doc "simple_merge"
    @spec simple_merge() :: :simple_merge
    def simple_merge, do: :simple_merge

    @doc "multiple_instance"
    @spec multiple_instance() :: :multiple_instance
    def multiple_instance, do: :multiple_instance

    @doc "structured_sync_merge"
    @spec structured_sync_merge() :: :structured_sync_merge
    def structured_sync_merge, do: :structured_sync_merge

  end

  @doc """
  Number of branches required to complete before a N-out-of-M join activates.

  Attribute: `workflow.required_branches`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `2`, `3`
  """
  @spec workflow_required_branches() :: :"workflow.required_branches"
  def workflow_required_branches, do: :"workflow.required_branches"

  @doc """
  Number of concurrent branches created in a parallel split (WP-2).

  Attribute: `workflow.split.count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `2`, `3`, `5`
  """
  @spec workflow_split_count() :: :"workflow.split.count"
  def workflow_split_count, do: :"workflow.split.count"

  @doc """
  Execution state of the workflow instance.

  Attribute: `workflow.state`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `active`, `completed`, `failed`
  """
  @spec workflow_state() :: :"workflow.state"
  def workflow_state, do: :"workflow.state"

  @doc """
  Enumerated values for `workflow.state`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `pending` | `"pending"` | pending |
  | `active` | `"active"` | active |
  | `completed` | `"completed"` | completed |
  | `failed` | `"failed"` | failed |
  | `cancelled` | `"cancelled"` | cancelled |
  | `suspended` | `"suspended"` | suspended |
  """
  @spec workflow_state_values() :: %{
    pending: :pending,
    active: :active,
    completed: :completed,
    failed: :failed,
    cancelled: :cancelled,
    suspended: :suspended
  }
  def workflow_state_values do
    %{
      pending: :pending,
      active: :active,
      completed: :completed,
      failed: :failed,
      cancelled: :cancelled,
      suspended: :suspended
    }
  end

  defmodule WorkflowStateValues do
    @moduledoc """
    Typed constants for the `workflow.state` attribute.
    """

    @doc "pending"
    @spec pending() :: :pending
    def pending, do: :pending

    @doc "active"
    @spec active() :: :active
    def active, do: :active

    @doc "completed"
    @spec completed() :: :completed
    def completed, do: :completed

    @doc "failed"
    @spec failed() :: :failed
    def failed, do: :failed

    @doc "cancelled"
    @spec cancelled() :: :cancelled
    def cancelled, do: :cancelled

    @doc "suspended"
    @spec suspended() :: :suspended
    def suspended, do: :suspended

  end

  @doc """
  The current step or activity name within the workflow.

  Attribute: `workflow.step`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `validate_input`, `route_to_agent`, `generate_report`
  """
  @spec workflow_step() :: :"workflow.step"
  def workflow_step, do: :"workflow.step"

  @doc """
  Total number of steps completed so far in the workflow.

  Attribute: `workflow.step_count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `1`, `5`, `12`
  """
  @spec workflow_step_count() :: :"workflow.step_count"
  def workflow_step_count, do: :"workflow.step_count"

  @doc """
  Timeout in milliseconds for synchronized merge to complete (Armstrong WvdA bounded).

  Attribute: `workflow.sync.timeout_ms`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `5000`, `30000`
  """
  @spec workflow_sync_timeout_ms() :: :"workflow.sync.timeout_ms"
  def workflow_sync_timeout_ms, do: :"workflow.sync.timeout_ms"

  @doc """
  Total number of branches in a parallel split pattern (M in N-out-of-M).

  Attribute: `workflow.total_branches`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `3`, `5`
  """
  @spec workflow_total_branches() :: :"workflow.total_branches"
  def workflow_total_branches, do: :"workflow.total_branches"

  @doc """
  The type of trigger that initiated the workflow transition.

  Attribute: `workflow.trigger_type`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `timer`, `event`, `message`, `external`, `condition`
  """
  @spec workflow_trigger_type() :: :"workflow.trigger_type"
  def workflow_trigger_type, do: :"workflow.trigger_type"

  @doc """
  Enumerated values for `workflow.trigger_type`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `timer` | `"timer"` | timer |
  | `event` | `"event"` | event |
  | `signal` | `"signal"` | signal |
  | `manual` | `"manual"` | manual |
  | `message` | `"message"` | message |
  | `external` | `"external"` | external |
  | `condition` | `"condition"` | condition |
  """
  @spec workflow_trigger_type_values() :: %{
    timer: :timer,
    event: :event,
    signal: :signal,
    manual: :manual,
    message: :message,
    external: :external,
    condition: :condition
  }
  def workflow_trigger_type_values do
    %{
      timer: :timer,
      event: :event,
      signal: :signal,
      manual: :manual,
      message: :message,
      external: :external,
      condition: :condition
    }
  end

  defmodule WorkflowTriggerTypeValues do
    @moduledoc """
    Typed constants for the `workflow.trigger_type` attribute.
    """

    @doc "timer"
    @spec timer() :: :timer
    def timer, do: :timer

    @doc "event"
    @spec event() :: :event
    def event, do: :event

    @doc "signal"
    @spec signal() :: :signal
    def signal, do: :signal

    @doc "manual"
    @spec manual() :: :manual
    def manual, do: :manual

    @doc "message"
    @spec message() :: :message
    def message, do: :message

    @doc "external"
    @spec external() :: :external
    def external, do: :external

    @doc "condition"
    @spec condition() :: :condition
    def condition, do: :condition

  end

end